unit TriboContact.CliRunner;

interface

uses
  System.SysUtils;

function RunCli(const AArgs: TArray<string>;
  const AWriteOut, AWriteErr: TProc<string>): Integer;

implementation

uses
  Winapi.Windows, Winapi.ShellAPI,
  System.IOUtils, System.Classes, System.Math, System.StrUtils,
  Vcl.Graphics,
  TriboContact.Models, TriboContact.Materials, TriboContact.CcxManager,
  TriboContact.Runner, TriboContact.PlotRenderer, TriboContact.Export;

procedure PrintUsage(const AWriteOut: TProc<string>);
begin
  if not Assigned(AWriteOut) then
    Exit;
  AWriteOut('TriboContact CLI');
  AWriteOut('Usage:');
  AWriteOut('  TriboContactCLI solve <case.json> [--engine elastic|fem|both] [--out-dir <dir>] [--pdf]');
  AWriteOut('  TriboContactCLI sweep <case.json> --loads-mn 10,50,100,500 [--engine elastic|fem|both] [--out-dir <dir>]');
  AWriteOut('  TriboContactCLI gui');
  AWriteOut('  TriboContactCLI setup-ccx [--url <zip_url>]');
  AWriteOut('  TriboContactCLI validate');
end;

function ParseLoadsList(const AText: string): TDoubleArray;
var
  Parts: TArray<string>;
  I: Integer;
  Val: Double;
begin
  Parts := Trim(AText).Split([','], TStringSplitOptions.ExcludeEmpty);
  if Length(Parts) = 0 then
    raise EArgumentException.Create('--loads-mn requires at least one numeric load value');
  SetLength(Result, Length(Parts));
  for I := 0 to High(Parts) do
  begin
    if (not TryStrToFloat(Trim(Parts[I]), Val, TFormatSettings.Invariant)) or (Val <= 0.0) then
      raise EArgumentException.CreateFmt('Invalid positive load value in --loads-mn: %s', [Parts[I]]);
    Result[I] := Val;
  end;
end;

function DefaultOutDirForCase(const ACasePath, ASuffix: string): string;
var
  FullPath, Dir, Base: string;
begin
  FullPath := TPath.GetFullPath(ACasePath);
  Dir := ExtractFileDir(FullPath);
  Base := ChangeFileExt(ExtractFileName(FullPath), '');
  if Dir = '' then
    Dir := GetCurrentDir;
  Result := TPath.Combine(Dir, Base + '_' + ASuffix);
end;

procedure EmitBundleSummary(ABundle: TComparisonBundle; const AWriteOut: TProc<string>);
  procedure PrintRow(const AName: string; R: TContactResult);
  var
    HrStr, PeeqStr: string;
  begin
    if R = nil then
      Exit;
    if R.HasResidualDepth then
      HrStr := Format('%.4f', [R.ResidualDepthUm], TFormatSettings.Invariant)
    else
      HrStr := '-';
    if R.HasMaxPeeq then
      PeeqStr := Format('%.4g', [R.MaxPeeq], TFormatSettings.Invariant)
    else
      PeeqStr := '-';
    AWriteOut(Format('  %-16s a=%8.3f um  delta=%8.4f um  hr=%7s um  p_max=%7.4f GPa  p_mean=%7.4f GPa  yr=%6.3f  peeq=%s',
      [AName, R.ContactRadiusUm, R.PenetrationDepthUm, HrStr, R.PMaxGpa, R.PMeanGpa, R.MaxYieldRatio, PeeqStr],
      TFormatSettings.Invariant));
  end;
begin
  if not Assigned(AWriteOut) then
    Exit;
  AWriteOut(Format('Summary (%s):', [ABundle.CaseName]));
  PrintRow('Hertz Sub', ABundle.HertzSubstrate);
  PrintRow('Hertz Film', ABundle.HertzTopFilm);
  PrintRow('Elastic Layered', ABundle.ElasticLayered);
  PrintRow('CalculiX FEM', ABundle.FemCalculix);
end;

function ExecuteSolve(const AArgs: TArray<string>;
  const AWriteOut, AWriteErr: TProc<string>): Integer;
var
  CasePath, OutDir: string;
  HaveEngine, IncludePdf: Boolean;
  EngineOverride: TSolverEngineKind;
  I: Integer;
  C: TContactCase;
  Bundle: TComparisonBundle;
begin
  CasePath := '';
  OutDir := '';
  HaveEngine := False;
  EngineOverride := seBoth;
  IncludePdf := False;

  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--engine') and (I + 1 < Length(AArgs)) then
    begin
      EngineOverride := StrToSolverEngine(AArgs[I + 1]);
      HaveEngine := True;
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--out-dir') and (I + 1 < Length(AArgs)) then
    begin
      OutDir := AArgs[I + 1];
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--pdf') then
    begin
      IncludePdf := True;
      Inc(I);
    end
    else if (not StartsStr('-', AArgs[I])) and (CasePath = '') then
    begin
      CasePath := AArgs[I];
      Inc(I);
    end
    else
    begin
      if Assigned(AWriteErr) then
        AWriteErr('Unknown or incomplete solve argument: ' + AArgs[I]);
      Exit(2);
    end;
  end;

  if CasePath = '' then
  begin
    if Assigned(AWriteErr) then
      AWriteErr('solve requires <case.json>');
    Exit(2);
  end;

  C := TContactCase.LoadFromFile(CasePath);
  if HaveEngine then
    C.Solver.Engine := EngineOverride;
  if OutDir = '' then
    OutDir := DefaultOutDirForCase(CasePath, 'out');

  Bundle := RunCase(C,
    procedure(Msg: string)
    begin
      if Assigned(AWriteOut) then
        AWriteOut(Msg);
    end);
  try
    EmitBundleSummary(Bundle, AWriteOut);
    TDirectory.CreateDirectory(OutDir);
    ExportBundleJSON(Bundle, TPath.Combine(OutDir, 'results.json'));
    ExportBundleCSV(Bundle, OutDir);
    ExportBundlePlots(Bundle, C, OutDir, IncludePdf);
    if Assigned(AWriteOut) then
      AWriteOut('Outputs written to: ' + OutDir);
  finally
    Bundle.Free;
  end;
  Result := 0;
end;

function ExecuteSweep(const AArgs: TArray<string>;
  const AWriteOut, AWriteErr: TProc<string>): Integer;
var
  CasePath, OutDir, LoadsStr: string;
  HaveEngine: Boolean;
  EngineOverride: TSolverEngineKind;
  I: Integer;
  Loads: TDoubleArray;
  C: TContactCase;
  Pts: TArray<TSweepPoint>;
  Bmp: TBitmap;
begin
  CasePath := '';
  OutDir := '';
  LoadsStr := '';
  HaveEngine := False;
  EngineOverride := seElastic;

  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--loads-mn') and (I + 1 < Length(AArgs)) then
    begin
      LoadsStr := AArgs[I + 1];
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--engine') and (I + 1 < Length(AArgs)) then
    begin
      EngineOverride := StrToSolverEngine(AArgs[I + 1]);
      HaveEngine := True;
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--out-dir') and (I + 1 < Length(AArgs)) then
    begin
      OutDir := AArgs[I + 1];
      Inc(I, 2);
    end
    else if (not StartsStr('-', AArgs[I])) and (CasePath = '') then
    begin
      CasePath := AArgs[I];
      Inc(I);
    end
    else
    begin
      if Assigned(AWriteErr) then
        AWriteErr('Unknown or incomplete sweep argument: ' + AArgs[I]);
      Exit(2);
    end;
  end;

  if (CasePath = '') or (LoadsStr = '') then
  begin
    if Assigned(AWriteErr) then
      AWriteErr('sweep requires <case.json> and --loads-mn <list>');
    Exit(2);
  end;

  Loads := ParseLoadsList(LoadsStr);
  C := TContactCase.LoadFromFile(CasePath);
  if HaveEngine then
    C.Solver.Engine := EngineOverride;
  if OutDir = '' then
    OutDir := DefaultOutDirForCase(CasePath, 'sweep');

  Pts := RunLoadSweep(C, Loads,
    procedure(Msg: string)
    begin
      if Assigned(AWriteOut) then
        AWriteOut(Msg);
    end);

  TDirectory.CreateDirectory(OutDir);
  ExportSweepCSV(Pts, TPath.Combine(OutDir, 'sweep.csv'));
  ExportSweepJSON(Pts, TPath.Combine(OutDir, 'sweep.json'));
  Bmp := RenderLoadSweepBitmap(Pts);
  try
    ExportBitmapPNG(Bmp, TPath.Combine(OutDir, 'sweep.png'));
  finally
    Bmp.Free;
  end;

  if Assigned(AWriteOut) then
    AWriteOut(Format('Sweep (%d loads) written to: %s', [Length(Pts), OutDir]));
  Result := 0;
end;

function ExecuteSetupCcx(const AArgs: TArray<string>;
  const AWriteOut, AWriteErr: TProc<string>): Integer;
var
  Url, ExePath, Diag: string;
  I: Integer;
begin
  Url := '';
  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--url') and (I + 1 < Length(AArgs)) then
    begin
      Url := AArgs[I + 1];
      Inc(I, 2);
    end
    else
    begin
      if Assigned(AWriteErr) then
        AWriteErr('Unknown setup-ccx argument: ' + AArgs[I]);
      Exit(2);
    end;
  end;

  ExePath := SetupCcx(Url,
    procedure(Msg: string)
    begin
      if Assigned(AWriteOut) then
        AWriteOut(Msg);
    end);
  if not SmokeTestCcx(ExePath, Diag) then
  begin
    if Assigned(AWriteErr) then
      AWriteErr('Smoke test failed: ' + Diag);
    Exit(1);
  end;
  if Assigned(AWriteOut) then
    AWriteOut('CalculiX installed and verified: ' + ExePath);
  Result := 0;
end;

function ExecuteValidate(const AWriteOut, AWriteErr: TProc<string>): Integer;
var
  Root, SameDirExe, TestExe, CmdLine: string;
  SI: TStartupInfoW;
  PI: TProcessInformation;
  ExitCode: DWORD;
begin
  Root := FindRepoRoot;
  SameDirExe := TPath.Combine(ExtractFilePath(ParamStr(0)), 'TriboContactTests.exe');
  if TFile.Exists(SameDirExe) then
    TestExe := SameDirExe
  else
    TestExe := TPath.Combine(Root, 'out\bin\TriboContactTests.exe');
  if not TFile.Exists(TestExe) then
  begin
    if Assigned(AWriteErr) then
      AWriteErr('Test executable not found: ' + TestExe + ' (run build.cmd or tests\run_tests.cmd first)');
    Exit(1);
  end;

  if Assigned(AWriteOut) then
    AWriteOut('Running verification suite: ' + TestExe);

  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  ZeroMemory(@PI, SizeOf(PI));
  CmdLine := Format('"%s" -exit:Continue', [TestExe]);
  UniqueString(CmdLine);

  if not CreateProcessW(nil, PWideChar(CmdLine), nil, nil, False, 0, nil,
    PWideChar(Root), SI, PI) then
    RaiseLastOSError;
  try
    WaitForSingleObject(PI.hProcess, INFINITE);
    ExitCode := 1;
    GetExitCodeProcess(PI.hProcess, ExitCode);
    Result := Integer(ExitCode);
  finally
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
  end;
end;

function ExecuteGui(const AWriteOut, AWriteErr: TProc<string>): Integer;
var
  GuiExe: string;
  Res: HINST;
begin
  GuiExe := TPath.Combine(ExtractFilePath(ParamStr(0)), 'TriboContact.exe');
  if not TFile.Exists(GuiExe) then
    GuiExe := TPath.Combine(FindRepoRoot, 'out\bin\TriboContact.exe');
  if not TFile.Exists(GuiExe) then
  begin
    if Assigned(AWriteErr) then
      AWriteErr('GUI executable not found: ' + GuiExe + ' (run build.cmd first)');
    Exit(1);
  end;

  if Assigned(AWriteOut) then
    AWriteOut('Launching ' + GuiExe);
  Res := ShellExecuteW(0, 'open', PWideChar(GuiExe), nil, PWideChar(ExtractFileDir(GuiExe)), SW_SHOWNORMAL);
  if NativeInt(Res) <= 32 then
  begin
    if Assigned(AWriteErr) then
      AWriteErr(Format('Failed to launch GUI (ShellExecute error %d)', [NativeInt(Res)]));
    Exit(1);
  end;
  Result := 0;
end;

function RunCli(const AArgs: TArray<string>;
  const AWriteOut, AWriteErr: TProc<string>): Integer;
var
  Cmd: string;
begin
  if Length(AArgs) = 0 then
  begin
    PrintUsage(AWriteOut);
    Exit(0);
  end;

  Cmd := LowerCase(Trim(AArgs[0]));
  try
    if (Cmd = '--help') or (Cmd = '-h') or (Cmd = 'help') then
    begin
      PrintUsage(AWriteOut);
      Result := 0;
    end
    else if Cmd = 'solve' then
      Result := ExecuteSolve(AArgs, AWriteOut, AWriteErr)
    else if Cmd = 'sweep' then
      Result := ExecuteSweep(AArgs, AWriteOut, AWriteErr)
    else if Cmd = 'setup-ccx' then
      Result := ExecuteSetupCcx(AArgs, AWriteOut, AWriteErr)
    else if Cmd = 'validate' then
      Result := ExecuteValidate(AWriteOut, AWriteErr)
    else if Cmd = 'gui' then
      Result := ExecuteGui(AWriteOut, AWriteErr)
    else
    begin
      if Assigned(AWriteErr) then
        AWriteErr('Unknown command: ' + AArgs[0]);
      PrintUsage(AWriteOut);
      Result := 2;
    end;
  except
    on E: Exception do
    begin
      if Assigned(AWriteErr) then
        AWriteErr('Error: ' + E.Message);
      Result := 1;
    end;
  end;
end;

end.
