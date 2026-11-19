unit TriboContact.CcxManager;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows;

function ResolveCcxPath(const AConfiguredPath: string = ''): string;
function SetupCcx(const AUrl: string = ''; const ALogCallback: TProc<string> = nil): string;
function RunCcxCapture(const ACcxPath, AWorkDir, AJobName: string; ATimeoutS: Integer;
  out AOutputText: string; out AExitCode: DWORD;
  const ALogCallback: TProc<string> = nil; ACancelFlag: PBoolean = nil): Boolean;
function SmokeTestCcx(const ACcxPath: string; out ADiagnostics: string): Boolean;
function DetectCax4FaceLabels(const ACcxPath: string;
  out ASpecTopFace, ABallBotFace, ADiagnostics: string): Boolean;

implementation

uses
  System.IOUtils, System.Net.HttpClient, System.Zip, System.Diagnostics,
  TriboContact.Materials;

const
  DefaultCcxUrls: array[0..1] of string = (
    'http://www.dhondt.de/calculix_2.23_4win.zip',
    'http://www.dhondt.de/calculix_2.22_4win.zip'
  );

function UserCcxDir: string;
var
  LocalAppData: string;
begin
  LocalAppData := Trim(GetEnvironmentVariable('LOCALAPPDATA'));
  if LocalAppData <> '' then
    Result := TPath.Combine(LocalAppData, 'TriboContact\ccx')
  else
    Result := TPath.Combine(TPath.GetHomePath, 'TriboContact\ccx');
end;

function CanWriteDir(const ADir: string): Boolean;
var
  ProbeFile: string;
begin
  try
    TDirectory.CreateDirectory(ADir);
    ProbeFile := TPath.Combine(ADir, '.write_test_' + TPath.GetRandomFileName);
    TFile.WriteAllText(ProbeFile, 'ok');
    TFile.Delete(ProbeFile);
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
end;

function ResolveCcxPath(const AConfiguredPath: string): string;
var
  EnvPath, RepoBin, PathEnv, Dir, Candidate: string;
  Dirs: TArray<string>;
  Names: TArray<string>;
  Name: string;
begin
  if (Trim(AConfiguredPath) <> '') and TFile.Exists(Trim(AConfiguredPath)) then
    Exit(TPath.GetFullPath(Trim(AConfiguredPath)));

  EnvPath := Trim(GetEnvironmentVariable('TRIBOCONTACT_CCX'));
  if (EnvPath <> '') and TFile.Exists(EnvPath) then
    Exit(TPath.GetFullPath(EnvPath));

  RepoBin := TPath.Combine(FindRepoRoot, 'bin\ccx\ccx.exe');
  if TFile.Exists(RepoBin) then
    Exit(TPath.GetFullPath(RepoBin));

  Candidate := TPath.Combine(ExtractFilePath(ParamStr(0)), 'ccx.exe');
  if TFile.Exists(Candidate) then
    Exit(TPath.GetFullPath(Candidate));

  Candidate := TPath.Combine(UserCcxDir, 'ccx.exe');
  if TFile.Exists(Candidate) then
    Exit(TPath.GetFullPath(Candidate));

  PathEnv := GetEnvironmentVariable('PATH');
  if PathEnv <> '' then
  begin
    Dirs := PathEnv.Split([';']);
    Names := ['ccx.exe', 'ccx_static.exe', 'ccx_dynamic.exe'];
    for Dir in Dirs do
    begin
      if Trim(Dir) = '' then
        Continue;
      for Name in Names do
      begin
        Candidate := TPath.Combine(Trim(Dir), Name);
        if TFile.Exists(Candidate) then
          Exit(TPath.GetFullPath(Candidate));
      end;
    end;
  end;

  Result := '';
end;

function RunCcxCapture(const ACcxPath, AWorkDir, AJobName: string; ATimeoutS: Integer;
  out AOutputText: string; out AExitCode: DWORD;
  const ALogCallback: TProc<string>; ACancelFlag: PBoolean): Boolean;
var
  SA: TSecurityAttributes;
  ReadPipe, WritePipe: THandle;
  SI: TStartupInfoW;
  PI: TProcessInformation;
  CmdLine, BufferStr, Line: string;
  Buf: array[0..4095] of AnsiChar;
  BytesAvail, BytesRead: DWORD;
  WaitRes: DWORD;
  Timer: TStopwatch;
  NewLinePos: Integer;
  Finished, TimedOut, Canceled: Boolean;
begin
  AOutputText := '';
  AExitCode := DWORD(-1);
  if not TFile.Exists(ACcxPath) then
    raise EFileNotFoundException.CreateFmt('CalculiX executable not found: %s', [ACcxPath]);

  SA.nLength := SizeOf(SA);
  SA.lpSecurityDescriptor := nil;
  SA.bInheritHandle := True;
  if not CreatePipe(ReadPipe, WritePipe, @SA, 0) then
    RaiseLastOSError;

  try
    SetHandleInformation(ReadPipe, HANDLE_FLAG_INHERIT, 0);
    ZeroMemory(@SI, SizeOf(SI));
    SI.cb := SizeOf(SI);
    SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    SI.wShowWindow := SW_HIDE;
    SI.hStdOutput := WritePipe;
    SI.hStdError := WritePipe;
    SI.hStdInput := 0;

    SetEnvironmentVariable('OMP_NUM_THREADS', '4');
    CmdLine := Format('"%s" -i "%s"', [ACcxPath, AJobName]);
    UniqueString(CmdLine);

    ZeroMemory(@PI, SizeOf(PI));
    if not CreateProcessW(nil, PWideChar(CmdLine), nil, nil, True,
      CREATE_NO_WINDOW, nil, PWideChar(AWorkDir), SI, PI) then
    begin
      CloseHandle(WritePipe);
      RaiseLastOSError;
    end;

    // Close write end in parent immediately so ReadFile/PeekNamedPipe sees EOF on exit.
    CloseHandle(WritePipe);
    WritePipe := 0;

    try
      Timer := TStopwatch.StartNew;
      BufferStr := '';
      TimedOut := False;
      Canceled := False;

      repeat
        Finished := False;
        WaitRes := WaitForSingleObject(PI.hProcess, 25);
        if WaitRes = WAIT_OBJECT_0 then
          Finished := True;

        while PeekNamedPipe(ReadPipe, nil, 0, nil, @BytesAvail, nil) and (BytesAvail > 0) do
        begin
          if not ReadFile(ReadPipe, Buf, SizeOf(Buf) - 1, BytesRead, nil) or (BytesRead = 0) then
            Break;
          Buf[BytesRead] := #0;
          BufferStr := BufferStr + string(AnsiString(PAnsiChar(@Buf[0])));
          NewLinePos := Pos(#10, BufferStr);
          while NewLinePos > 0 do
          begin
            Line := TrimRight(Copy(BufferStr, 1, NewLinePos - 1));
            Delete(BufferStr, 1, NewLinePos);
            AOutputText := AOutputText + Line + sLineBreak;
            if Assigned(ALogCallback) then
              ALogCallback(Line);
            NewLinePos := Pos(#10, BufferStr);
          end;
        end;

        if (ACancelFlag <> nil) and ACancelFlag^ then
        begin
          Canceled := True;
          TerminateProcess(PI.hProcess, 1);
          Break;
        end;

        if (ATimeoutS > 0) and (Timer.Elapsed.TotalSeconds > ATimeoutS) then
        begin
          TimedOut := True;
          TerminateProcess(PI.hProcess, 1);
          Break;
        end;
      until Finished;

      if BufferStr <> '' then
      begin
        Line := TrimRight(BufferStr);
        AOutputText := AOutputText + Line + sLineBreak;
        if Assigned(ALogCallback) then
          ALogCallback(Line);
      end;

      if Canceled or TimedOut then
        WaitForSingleObject(PI.hProcess, 2000);

      GetExitCodeProcess(PI.hProcess, AExitCode);
      Result := (not Canceled) and (not TimedOut) and (AExitCode = 0);
    finally
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
    end;
  finally
    if WritePipe <> 0 then
      CloseHandle(WritePipe);
    CloseHandle(ReadPipe);
  end;
end;

function SmokeTestCcx(const ACcxPath: string; out ADiagnostics: string): Boolean;
var
  WorkDir, InpPath, DatPath, FrdPath, StdOutText, DatText, FrdText: string;
  Inp: TStringList;
  ExitCode: DWORD;
  ExpectedLoadMn, FoundRf, RelErr: Double;
  Lines: TArray<string>;
  Line, TrimLine: string;
  Tokens: TArray<string>;
  InRfBlock, Found2C, FoundNode1: Boolean;
begin
  Result := False;
  ADiagnostics := '';
  if not TFile.Exists(ACcxPath) then
  begin
    ADiagnostics := 'ccx.exe not found';
    Exit;
  end;

  WorkDir := TPath.Combine(TPath.GetTempPath, 'tc_ccx_smoke_' + TPath.GetRandomFileName);
  TDirectory.CreateDirectory(WorkDir);
  try
    InpPath := TPath.Combine(WorkDir, 'smoke.inp');
    Inp := TStringList.Create;
    try
      Inp.Add('*HEADING');
      Inp.Add('TriboContact 1-element CAX4 smoke test');
      Inp.Add('*NODE');
      Inp.Add('1, 0.0, -1.0');
      Inp.Add('2, 1.0, -1.0');
      Inp.Add('3, 1.0, 0.0');
      Inp.Add('4, 0.0, 0.0');
      Inp.Add('*ELEMENT, TYPE=CAX4, ELSET=EALL');
      Inp.Add('1, 1, 2, 3, 4');
      Inp.Add('*NSET, NSET=AXIS');
      Inp.Add('1, 4');
      Inp.Add('*NSET, NSET=BOT');
      Inp.Add('1, 2');
      Inp.Add('*NSET, NSET=TOP');
      Inp.Add('3, 4');
      Inp.Add('*MATERIAL, NAME=MAT1');
      Inp.Add('*ELASTIC');
      Inp.Add('200.0, 0.3');
      Inp.Add('*SOLID SECTION, ELSET=EALL, MATERIAL=MAT1');
      Inp.Add('*BOUNDARY');
      Inp.Add('AXIS, 1, 1, 0.0');
      Inp.Add('BOT, 2, 2, 0.0');
      Inp.Add('*STEP');
      Inp.Add('*STATIC');
      Inp.Add('*BOUNDARY');
      Inp.Add('TOP, 2, 2, -0.001');
      Inp.Add('*NODE FILE, OUTPUT=2D');
      Inp.Add('U, RF');
      Inp.Add('*EL FILE, OUTPUT=2D');
      Inp.Add('S');
      Inp.Add('*NODE PRINT, NSET=TOP, TOTALS=ONLY');
      Inp.Add('RF');
      Inp.Add('*END STEP');
      Inp.SaveToFile(InpPath, TEncoding.ASCII);
    finally
      Inp.Free;
    end;

    if not RunCcxCapture(ACcxPath, WorkDir, 'smoke', 30, StdOutText, ExitCode) then
    begin
      ADiagnostics := Format('ccx failed (exit=%d): %s', [ExitCode, StdOutText]);
      Exit(False);
    end;

    DatPath := TPath.Combine(WorkDir, 'smoke.dat');
    FrdPath := TPath.Combine(WorkDir, 'smoke.frd');
    if not TFile.Exists(DatPath) or not TFile.Exists(FrdPath) then
    begin
      ADiagnostics := 'Missing .dat or .frd output';
      Exit(False);
    end;

    DatText := TFile.ReadAllText(DatPath, TEncoding.ASCII);
    Lines := DatText.Split([#10]);
    InRfBlock := False;
    FoundRf := 0.0;
    for Line in Lines do
    begin
      TrimLine := Trim(Line);
      if Pos('total force', LowerCase(TrimLine)) > 0 then
        InRfBlock := True
      else if InRfBlock and (TrimLine <> '') then
      begin
        Tokens := TrimLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
        if Length(Tokens) >= 2 then
        begin
          if TryStrToFloat(Tokens[1], FoundRf, TFormatSettings.Invariant) then
            Break;
        end;
      end;
    end;

    ExpectedLoadMn := Pi * 1.0 * 200.0 * 0.001 * ((1.0 - 0.3) / ((1.0 + 0.3) * (1.0 - 2.0 * 0.3)));
    FoundRf := 180.0 * Abs(FoundRf);
    RelErr := Abs(FoundRf - ExpectedLoadMn) / ExpectedLoadMn;

    FrdText := TFile.ReadAllText(FrdPath, TEncoding.ASCII);
    Found2C := Pos('    2C', FrdText) > 0;
    FoundNode1 := (Pos(' -1         1', FrdText) > 0) or (Pos('-1         1', FrdText) > 0);

    ADiagnostics := Format('1-elem smoke F_360=%.6f mN (expected=%.6f mN, rel_err=%.4f), frd2D=%s/%s',
      [FoundRf, ExpectedLoadMn, RelErr, BoolToStr(Found2C, True), BoolToStr(FoundNode1, True)],
      TFormatSettings.Invariant);
    Result := Found2C and (FoundRf > 0.0);
  finally
    if TDirectory.Exists(WorkDir) then
      TDirectory.Delete(WorkDir, True);
  end;
end;

function DetectCax4FaceLabels(const ACcxPath: string;
  out ASpecTopFace, ABallBotFace, ADiagnostics: string): Boolean;
const
  TopCandidates: array[0..1] of string = ('S3', 'S5');
  BotCandidates: array[0..1] of string = ('S1', 'S3');
var
  Idx: Integer;
  WorkDir, InpPath, DatPath, FrdPath, StdOutText, DatText, FrdText: string;
  Inp: TStringList;
  ExitCode: DWORD;
  TopFace, BotFace, Line, TrimLine: string;
  Lines, Tokens: TArray<string>;
  HasContactPrint, InRfBlock: Boolean;
  FoundRf: Double;
begin
  Result := False;
  ASpecTopFace := 'S3';
  ABallBotFace := 'S1';
  ADiagnostics := '';

  for Idx := 0 to 1 do
  begin
    TopFace := TopCandidates[Idx];
    BotFace := BotCandidates[Idx];
    WorkDir := TPath.Combine(TPath.GetTempPath, 'tc_face_' + TPath.GetRandomFileName);
    TDirectory.CreateDirectory(WorkDir);
    try
      InpPath := TPath.Combine(WorkDir, 'cprobe.inp');
      Inp := TStringList.Create;
      try
        Inp.Add('*HEADING');
        Inp.Add('CAX4 contact face probe');
        Inp.Add('*NODE');
        Inp.Add('1, 0.0, -1.0');
        Inp.Add('2, 0.5, -1.0');
        Inp.Add('3, 1.0, -1.0');
        Inp.Add('4, 0.0,  0.0');
        Inp.Add('5, 0.5,  0.0');
        Inp.Add('6, 1.0,  0.0');
        Inp.Add('7, 0.0,  0.0');
        Inp.Add('8, 0.5,  0.0');
        Inp.Add('9, 1.0,  0.0');
        Inp.Add('10, 0.0, 1.0');
        Inp.Add('11, 0.5, 1.0');
        Inp.Add('12, 1.0, 1.0');
        Inp.Add('*ELEMENT, TYPE=CAX4, ELSET=ESPEC');
        Inp.Add('1, 1, 2, 5, 4');
        Inp.Add('2, 2, 3, 6, 5');
        Inp.Add('*ELEMENT, TYPE=CAX4, ELSET=EBALL');
        Inp.Add('3, 7, 8, 11, 10');
        Inp.Add('4, 8, 9, 12, 11');
        Inp.Add('*NSET, NSET=AXIS');
        Inp.Add('1, 4, 7, 10');
        Inp.Add('*NSET, NSET=BOT');
        Inp.Add('1, 2, 3');
        Inp.Add('*NSET, NSET=TOP');
        Inp.Add('10, 11, 12');
        Inp.Add('*SURFACE, NAME=SSPEC, TYPE=ELEMENT');
        Inp.Add('ESPEC, ' + TopFace);
        Inp.Add('*SURFACE, NAME=SBALL, TYPE=ELEMENT');
        Inp.Add('EBALL, ' + BotFace);
        Inp.Add('*MATERIAL, NAME=M1');
        Inp.Add('*ELASTIC');
        Inp.Add('200.0, 0.3');
        Inp.Add('*SOLID SECTION, ELSET=ESPEC, MATERIAL=M1');
        Inp.Add('*SOLID SECTION, ELSET=EBALL, MATERIAL=M1');
        Inp.Add('*SURFACE INTERACTION, NAME=INTC');
        Inp.Add('*SURFACE BEHAVIOR, PRESSURE-OVERCLOSURE=LINEAR');
        Inp.Add('10000.0');
        Inp.Add('*CONTACT PAIR, INTERACTION=INTC, TYPE=SURFACE TO SURFACE');
        Inp.Add('SSPEC, SBALL');
        Inp.Add('*BOUNDARY');
        Inp.Add('AXIS, 1, 1, 0.0');
        Inp.Add('BOT, 2, 2, 0.0');
        Inp.Add('*STEP, NLGEOM, INC=50');
        Inp.Add('*STATIC');
        Inp.Add('0.5, 1.0, 1e-5, 0.5');
        Inp.Add('*BOUNDARY');
        Inp.Add('TOP, 2, 2, -0.05');
        Inp.Add('*NODE FILE, OUTPUT=2D');
        Inp.Add('U, RF');
        Inp.Add('*CONTACT FILE');
        Inp.Add('CSTR, CDIS');
        Inp.Add('*NODE PRINT, NSET=TOP, TOTALS=ONLY');
        Inp.Add('RF');
        Inp.Add('*CONTACT PRINT, SLAVE=SSPEC, MASTER=SBALL');
        Inp.Add('CSTR, CDIS');
        Inp.Add('*END STEP');
        Inp.SaveToFile(InpPath, TEncoding.ASCII);
      finally
        Inp.Free;
      end;

      if RunCcxCapture(ACcxPath, WorkDir, 'cprobe', 30, StdOutText, ExitCode) then
      begin
        DatPath := TPath.Combine(WorkDir, 'cprobe.dat');
        FrdPath := TPath.Combine(WorkDir, 'cprobe.frd');
        if TFile.Exists(DatPath) and TFile.Exists(FrdPath) then
        begin
          DatText := TFile.ReadAllText(DatPath, TEncoding.ASCII);
          FrdText := TFile.ReadAllText(FrdPath, TEncoding.ASCII);
          FoundRf := 0.0;
          InRfBlock := False;
          Lines := DatText.Split([#10]);
          for Line in Lines do
          begin
            TrimLine := Trim(Line);
            if Pos('total force', LowerCase(TrimLine)) > 0 then
              InRfBlock := True
            else if InRfBlock and (TrimLine <> '') then
            begin
              Tokens := TrimLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
              if Length(Tokens) >= 2 then
                TryStrToFloat(Tokens[1], FoundRf, TFormatSettings.Invariant);
              InRfBlock := False;
            end;
          end;
          FoundRf := 180.0 * Abs(FoundRf);
          HasContactPrint := Pos('contact stress', LowerCase(DatText)) > 0;
          if HasContactPrint and (FoundRf > 1.0) and (Pos('CONTACT', UpperCase(FrdText)) > 0) then
          begin
            ASpecTopFace := TopFace;
            ABallBotFace := BotFace;
            ADiagnostics := Format('Verified CAX4 faces: spec_top=%s, ball_bot=%s, F_360=%.3f mN',
              [TopFace, BotFace, FoundRf], TFormatSettings.Invariant);
            Exit(True);
          end;
        end;
      end;
    finally
      if TDirectory.Exists(WorkDir) then
        TDirectory.Delete(WorkDir, True);
    end;
  end;
end;

function SetupCcx(const AUrl: string; const ALogCallback: TProc<string>): string;
var
  BinDir, TargetExe, TempDir, ZipPath, ExtractDir, Url, Diag: string;
  Urls: TArray<string>;
  Http: THTTPClient;
  Stream: TFileStream;
  Resp: IHTTPResponse;
  Exes, Dlls: TArray<string>;
  ChosenExe, Candidate, FileName, DllFile: string;
  Downloaded: Boolean;
begin
  BinDir := TPath.Combine(FindRepoRoot, 'bin\ccx');
  if not CanWriteDir(BinDir) then
  begin
    BinDir := UserCcxDir;
    TDirectory.CreateDirectory(BinDir);
  end;
  TargetExe := TPath.Combine(BinDir, 'ccx.exe');

  if Trim(AUrl) <> '' then
    Urls := [Trim(AUrl)]
  else
    Urls := [DefaultCcxUrls[0], DefaultCcxUrls[1]];

  TempDir := TPath.Combine(TPath.GetTempPath, 'tc_setup_ccx_' + TPath.GetRandomFileName);
  TDirectory.CreateDirectory(TempDir);
  try
    ZipPath := TPath.Combine(TempDir, 'calculix.zip');
    ExtractDir := TPath.Combine(TempDir, 'unzipped');
    TDirectory.CreateDirectory(ExtractDir);

    Downloaded := False;
    Http := THTTPClient.Create;
    try
      Http.ConnectionTimeout := 20000;
      Http.ResponseTimeout := 120000;
      for Url in Urls do
      begin
        if Assigned(ALogCallback) then
          ALogCallback('Downloading CalculiX from ' + Url);
        try
          Stream := TFileStream.Create(ZipPath, fmCreate);
          try
            Resp := Http.Get(Url, Stream);
            if (Resp.StatusCode >= 200) and (Resp.StatusCode < 300) and (Stream.Size > 1000000) then
            begin
              Downloaded := True;
              Break;
            end;
          finally
            Stream.Free;
          end;
        except
          on E: Exception do
          begin
            if Assigned(ALogCallback) then
              ALogCallback('Download attempt failed: ' + E.Message);
          end;
        end;
      end;
    finally
      Http.Free;
    end;

    if not Downloaded then
      raise Exception.Create('Failed to download CalculiX archive from any configured URL');

    if Assigned(ALogCallback) then
      ALogCallback('Extracting archive...');
    TZipFile.ExtractZipFile(ZipPath, ExtractDir);

    Exes := TDirectory.GetFiles(ExtractDir, '*.exe', TSearchOption.soAllDirectories);
    ChosenExe := '';
    for Candidate in Exes do
    begin
      FileName := LowerCase(ExtractFileName(Candidate));
      if FileName = 'ccx.exe' then
      begin
        ChosenExe := Candidate;
        Break;
      end;
    end;
    if ChosenExe = '' then
      for Candidate in Exes do
      begin
        FileName := LowerCase(ExtractFileName(Candidate));
        if (FileName = 'ccx_static.exe') or (Pos('ccx_', FileName) = 1) or (Pos('ccx', FileName) = 1) then
        begin
          ChosenExe := Candidate;
          if FileName = 'ccx_static.exe' then
            Break;
        end;
      end;

    if ChosenExe = '' then
      raise Exception.Create('Could not locate ccx*.exe inside downloaded CalculiX archive');

    TFile.Copy(ChosenExe, TargetExe, True);
    Dlls := TDirectory.GetFiles(ExtractDir, '*.dll', TSearchOption.soAllDirectories);
    for DllFile in Dlls do
      TFile.Copy(DllFile, TPath.Combine(BinDir, ExtractFileName(DllFile)), True);

    if Assigned(ALogCallback) then
      ALogCallback('Running 1-element smoke test on ' + TargetExe);
    if not SmokeTestCcx(TargetExe, Diag) then
      raise Exception.Create('CalculiX smoke test failed: ' + Diag);
    if Assigned(ALogCallback) then
      ALogCallback('CalculiX ready: ' + Diag);
    Result := TargetExe;
  finally
    if TDirectory.Exists(TempDir) then
      TDirectory.Delete(TempDir, True);
  end;
end;

end.
