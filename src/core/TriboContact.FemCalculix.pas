unit TriboContact.FemCalculix;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics, Winapi.Windows,
  TriboContact.Models, TriboContact.CcxManager, TriboContact.FemMesh,
  TriboContact.ElasticLayered;

type
  TFrdData = record
    NodeCount: Integer;
    HasDisp: Boolean;
    HasForce: Boolean;
    HasContact: Boolean;
    DispX, DispY: TDoubleArray;
    ForceX, ForceY: TDoubleArray;
    CPress: TDoubleArray;
  end;

  TElemStressBlock = record
    Sxx, Syy, Szz, Sxy: array[0..7] of Double;
    Peeq: array[0..7] of Double;
    GPCount: Integer;
    HasPeeq: Boolean;
  end;

  TDatData = record
    Step1TotalRF2: Double;
    HasStep1RF: Boolean;
    Step2CenterTopUy: Double;
    HasStep2Uy: Boolean;
    Step2TotalRF2: Double;
    ElemData: TArray<TElemStressBlock>;
  end;

function GenerateCalculixInp(const ACase: TContactCase; AMesh: TFemMesh;
  ADeltaTrialUm, APenaltyScale: Double; AIncludeUnloading: Boolean;
  out AActualElementStr: string): string;
function ParseFrdFile(const AFilePath: string; ANodeCount: Integer): TFrdData;
function ParseDatFile(const AFilePath: string; AMaxElemId, ACenterTopNodeId: Integer): TDatData;
function ComputeAxisymmetricPressureForce(const AR, AP: TDoubleArray): Double;
function SolveFemCalculix(const ACase: TContactCase; const ALogCallback: TProc<string> = nil;
  ACancelFlag: PBoolean = nil; AElasticHint: TContactResult = nil): TContactResult;

implementation

uses
  System.IOUtils, System.StrUtils, System.Generics.Collections;

function FormatIntListLines(const AIds: TArray<Integer>): string;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to High(AIds) do
    begin
      SB.Append(AIds[I]);
      if I < High(AIds) then
      begin
        if (I + 1) mod 12 = 0 then
          SB.AppendLine(',')
        else
          SB.Append(', ');
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure EmitMaterialCards(ASB: TStringBuilder; const AMatName: string;
  const AMat: TMaterial; AForceElasticOnly: Boolean = False; AOverrideE: Double = 0.0);
var
  EVal, Et, HPrime: Double;
  I: Integer;
begin
  if AOverrideE > 0.0 then
    EVal := AOverrideE
  else
    EVal := AMat.EGpa;

  ASB.AppendLine('*MATERIAL, NAME=' + AMatName);
  ASB.AppendLine('*ELASTIC');
  ASB.AppendLine(Format('%.8g, %.6g', [EVal, AMat.Nu], TFormatSettings.Invariant));

  if (not AForceElasticOnly) and AMat.HasSigmaY then
  begin
    ASB.AppendLine('*PLASTIC');
    if Length(AMat.HardeningCurve) > 0 then
    begin
      for I := 0 to High(AMat.HardeningCurve) do
        ASB.AppendLine(Format('%.8g, %.8g',
          [AMat.HardeningCurve[I].TrueStressGpa, AMat.HardeningCurve[I].PlasticStrain],
          TFormatSettings.Invariant));
    end
    else
    begin
      Et := AMat.EffectiveTangentGpa;
      HPrime := (EVal * Et) / (EVal - Et);
      ASB.AppendLine(Format('%.8g, 0.0', [AMat.SigmaYGpa], TFormatSettings.Invariant));
      ASB.AppendLine(Format('%.8g, 0.1', [AMat.SigmaYGpa + HPrime * 0.1], TFormatSettings.Invariant));
      ASB.AppendLine(Format('%.8g, 0.5', [AMat.SigmaYGpa + HPrime * 0.5], TFormatSettings.Invariant));
    end;
  end;
end;

function GenerateCalculixInp(const ACase: TContactCase; AMesh: TFemMesh;
  ADeltaTrialUm, APenaltyScale: Double; AIncludeUnloading: Boolean;
  out AActualElementStr: string): string;
var
  SB: TStringBuilder;
  I, K, N: Integer;
  TopMat, BallMat: TMaterial;
  InvE, EEff, Kp, KpCap, KpMin, MinSy, PScale, DrBall0, Sagitta, MaxE, ERigid, RWrite: Double;
  ElSetName, MatName: string;
  HasAnyPlastic: Boolean;
begin
  if ACase.Solver.ElementType = etCAX4R then
    AActualElementStr := 'CAX4R'
  else
    AActualElementStr := 'CAX4';

  N := Length(ACase.Layers);
  if N > 0 then
    TopMat := ACase.Layers[0].Material
  else
    TopMat := ACase.Substrate;
  BallMat := ACase.Ball.Material;

  InvE := (1.0 - Sqr(TopMat.Nu)) / TopMat.EGpa;
  if not ACase.Ball.Rigid then
    InvE := InvE + (1.0 - Sqr(BallMat.Nu)) / BallMat.EGpa;
  EEff := 1.0 / InvE;
  Kp := 10.0 * EEff / Max(1e-6, AMesh.DrMinUm) * APenaltyScale;

  HasAnyPlastic := ACase.Substrate.HasSigmaY;
  if HasAnyPlastic then
    MinSy := ACase.Substrate.SigmaYGpa
  else
    MinSy := Infinity;
  for K := 0 to N - 1 do
    if ACase.Layers[K].Material.HasSigmaY then
    begin
      HasAnyPlastic := True;
      if ACase.Layers[K].Material.SigmaYGpa < MinSy then
        MinSy := ACase.Layers[K].Material.SigmaYGpa;
    end;
  if HasAnyPlastic then
    PScale := 3.0 * MinSy
  else
    PScale := 0.02 * EEff;

  if Length(AMesh.BallRCoords) >= 2 then
    DrBall0 := AMesh.BallRCoords[1] - AMesh.BallRCoords[0]
  else
    DrBall0 := AMesh.DrMinUm;
  Sagitta := Sqr(DrBall0) / (8.0 * ACase.Ball.RadiusUm);
  KpCap := 0.5 * PScale / Max(1e-9, Sagitta) * APenaltyScale;
  KpMin := 0.5 * EEff / Max(1e-6, AMesh.EstRadiusUm);
  Kp := Max(KpMin, Min(Kp, KpCap));

  MaxE := ACase.Substrate.EGpa;
  if BallMat.EGpa > MaxE then MaxE := BallMat.EGpa;
  for K := 0 to N - 1 do
    if ACase.Layers[K].Material.EGpa > MaxE then
      MaxE := ACase.Layers[K].Material.EGpa;
  ERigid := 1.0e4 * MaxE;

  SB := TStringBuilder.Create(65536);
  try
    SB.AppendLine('*HEADING');
    SB.AppendLine('TriboContact Axisymmetric Contact: ' + ACase.CaseName);

    SB.AppendLine('*NODE');
    for I := 0 to High(AMesh.Nodes) do
    begin
      RWrite := AMesh.Nodes[I].R;
      if Abs(RWrite) < 1e-12 then
        RWrite := 1e-3 * AMesh.DrMinUm;
      SB.AppendLine(Format('%d, %.10g, %.10g',
        [AMesh.Nodes[I].Id, RWrite, AMesh.Nodes[I].Y], TFormatSettings.Invariant));
    end;

    for K := 0 to N - 1 do
    begin
      ElSetName := Format('EL_LAYER_%d', [K + 1]);
      SB.AppendLine(Format('*ELEMENT, TYPE=%s, ELSET=%s', [AActualElementStr, ElSetName]));
      for I := 0 to High(AMesh.LayerElSets[K]) do
      begin
        var Q := AMesh.Quads[AMesh.LayerElSets[K][I] - 1];
        SB.AppendLine(Format('%d, %d, %d, %d, %d', [Q.Id, Q.N1, Q.N2, Q.N3, Q.N4]));
      end;
    end;

    SB.AppendLine(Format('*ELEMENT, TYPE=%s, ELSET=EL_SUBSTRATE', [AActualElementStr]));
    for I := 0 to High(AMesh.SubstrateElSet) do
    begin
      var Q := AMesh.Quads[AMesh.SubstrateElSet[I] - 1];
      SB.AppendLine(Format('%d, %d, %d, %d, %d', [Q.Id, Q.N1, Q.N2, Q.N3, Q.N4]));
    end;

    SB.AppendLine(Format('*ELEMENT, TYPE=%s, ELSET=EL_BALL', [AActualElementStr]));
    for I := 0 to High(AMesh.BallElSet) do
    begin
      var Q := AMesh.Quads[AMesh.BallElSet[I] - 1];
      SB.AppendLine(Format('%d, %d, %d, %d, %d', [Q.Id, Q.N1, Q.N2, Q.N3, Q.N4]));
    end;

    SB.AppendLine('*NSET, NSET=AXIS_NODES');
    SB.AppendLine(FormatIntListLines(AMesh.AxisNodes));
    SB.AppendLine('*NSET, NSET=SPEC_BOTTOM');
    SB.AppendLine(FormatIntListLines(AMesh.SpecBottomNodes));
    SB.AppendLine('*NSET, NSET=SPEC_RIM');
    SB.AppendLine(FormatIntListLines(AMesh.SpecRimNodes));
    SB.AppendLine('*NSET, NSET=BALL_TOP');
    SB.AppendLine(FormatIntListLines(AMesh.BallTopNodes));
    SB.AppendLine('*NSET, NSET=SPEC_TOP_NODES');
    SB.AppendLine(FormatIntListLines(AMesh.SpecTopNodes));
    SB.AppendLine('*NSET, NSET=SPEC_CENTER_TOP');
    SB.AppendLine(IntToStr(AMesh.SpecCenterTopNode));

    SB.AppendLine('*ELSET, ELSET=EL_SPEC_TOP');
    SB.AppendLine(FormatIntListLines(AMesh.SpecTopQuads));
    SB.AppendLine('*ELSET, ELSET=EL_BALL_BOT');
    SB.AppendLine(FormatIntListLines(AMesh.BallBotQuads));

    SB.AppendLine('*SURFACE, NAME=SURF_SPECIMEN, TYPE=ELEMENT');
    SB.AppendLine('EL_SPEC_TOP, S3');
    SB.AppendLine('*SURFACE, NAME=SURF_BALL, TYPE=ELEMENT');
    SB.AppendLine('EL_BALL_BOT, S1');

    for K := 0 to N - 1 do
    begin
      MatName := Format('MAT_LAYER_%d', [K + 1]);
      EmitMaterialCards(SB, MatName, ACase.Layers[K].Material);
      SB.AppendLine(Format('*SOLID SECTION, ELSET=EL_LAYER_%d, MATERIAL=%s', [K + 1, MatName]));
    end;

    EmitMaterialCards(SB, 'MAT_SUBSTRATE', ACase.Substrate);
    SB.AppendLine('*SOLID SECTION, ELSET=EL_SUBSTRATE, MATERIAL=MAT_SUBSTRATE');

    if ACase.Ball.Rigid then
      EmitMaterialCards(SB, 'MAT_BALL', BallMat, True, ERigid)
    else
      EmitMaterialCards(SB, 'MAT_BALL', BallMat, True, 0.0);
    SB.AppendLine('*SOLID SECTION, ELSET=EL_BALL, MATERIAL=MAT_BALL');

    SB.AppendLine('*SURFACE INTERACTION, NAME=INT_CONTACT');
    SB.AppendLine('*SURFACE BEHAVIOR, PRESSURE-OVERCLOSURE=LINEAR');
    SB.AppendLine(Format('%.8g', [Kp], TFormatSettings.Invariant));
    SB.AppendLine('*CONTACT PAIR, INTERACTION=INT_CONTACT, TYPE=SURFACE TO SURFACE');
    SB.AppendLine('SURF_SPECIMEN, SURF_BALL');

    SB.AppendLine('*BOUNDARY');
    SB.AppendLine('AXIS_NODES, 1, 1, 0.0');
    SB.AppendLine('SPEC_BOTTOM, 2, 2, 0.0');
    SB.AppendLine('SPEC_RIM, 1, 1, 0.0');

    SB.AppendLine('*AMPLITUDE, NAME=AMP_LOAD');
    SB.AppendLine('0.0, 0.0, 1.0, 1.0');
    if AIncludeUnloading then
    begin
      SB.AppendLine('*AMPLITUDE, NAME=AMP_UNLOAD');
      SB.AppendLine('0.0, 1.0, 1.0, 0.0');
    end;

    SB.AppendLine('*STEP, NLGEOM, INC=200');
    SB.AppendLine('*STATIC');
    SB.AppendLine('0.05, 1.0, 1e-6, 0.1');
    SB.AppendLine('*BOUNDARY, AMPLITUDE=AMP_LOAD');
    SB.AppendLine(Format('BALL_TOP, 2, 2, %.10g', [-ADeltaTrialUm], TFormatSettings.Invariant));
    SB.AppendLine('*NODE FILE, OUTPUT=2D');
    SB.AppendLine('U, RF');
    SB.AppendLine('*EL FILE, OUTPUT=2D');
    SB.AppendLine('S, PEEQ');
    SB.AppendLine('*CONTACT FILE');
    SB.AppendLine('CSTR, CDIS');
    SB.AppendLine('*NODE PRINT, NSET=BALL_TOP, TOTALS=ONLY, FREQUENCY=9999');
    SB.AppendLine('RF');
    SB.AppendLine('*CONTACT PRINT, SLAVE=SURF_SPECIMEN, MASTER=SURF_BALL, FREQUENCY=9999');
    SB.AppendLine('CSTR, CDIS');
    for K := 0 to N - 1 do
    begin
      SB.AppendLine(Format('*EL PRINT, ELSET=EL_LAYER_%d, FREQUENCY=9999', [K + 1]));
      SB.AppendLine('S, PEEQ');
    end;
    SB.AppendLine('*EL PRINT, ELSET=EL_SUBSTRATE, FREQUENCY=9999');
    SB.AppendLine('S, PEEQ');
    SB.AppendLine('*END STEP');

    if AIncludeUnloading then
    begin
      SB.AppendLine('*STEP, NLGEOM, INC=200');
      SB.AppendLine('*STATIC');
      SB.AppendLine('0.05, 1.0, 1e-6, 0.1');
      SB.AppendLine('*BOUNDARY, AMPLITUDE=AMP_UNLOAD');
      SB.AppendLine(Format('BALL_TOP, 2, 2, %.10g', [-ADeltaTrialUm], TFormatSettings.Invariant));
      SB.AppendLine('*NODE PRINT, NSET=SPEC_CENTER_TOP, FREQUENCY=9999');
      SB.AppendLine('U');
      SB.AppendLine('*NODE PRINT, NSET=BALL_TOP, TOTALS=ONLY, FREQUENCY=9999');
      SB.AppendLine('RF');
      SB.AppendLine('*END STEP');
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function ParseFrdFixedFloat(const ALine: string; AStartPos1, ALen: Integer;
  out AValue: Double): Boolean;
var
  S: string;
begin
  Result := False;
  AValue := 0.0;
  if Length(ALine) < AStartPos1 then
    Exit;
  S := Trim(Copy(ALine, AStartPos1, ALen));
  if S = '' then
    Exit;
  Result := TryStrToFloat(S, AValue, TFormatSettings.Invariant);
end;

function ParseFrdFile(const AFilePath: string; ANodeCount: Integer): TFrdData;
var
  Reader: TStreamReader;
  Line, TrimLine, BlockName: string;
  InDataBlock, IsStep1: Boolean;
  BlockStepTime: Double;
  NodeId: Integer;
  V0, V1, V3: Double;
  Tokens: TArray<string>;
begin
  Result := Default(TFrdData);
  Result.NodeCount := ANodeCount;
  SetLength(Result.DispX, ANodeCount + 1);
  SetLength(Result.DispY, ANodeCount + 1);
  SetLength(Result.ForceX, ANodeCount + 1);
  SetLength(Result.ForceY, ANodeCount + 1);
  SetLength(Result.CPress, ANodeCount + 1);

  if not TFile.Exists(AFilePath) then
    raise EFileNotFoundException.CreateFmt('.frd file not found: %s', [AFilePath]);

  InDataBlock := False;
  IsStep1 := True;
  BlockName := '';

  Reader := TStreamReader.Create(AFilePath, TEncoding.ASCII);
  try
    while not Reader.EndOfStream do
    begin
      Line := Reader.ReadLine;
      TrimLine := Trim(Line);
      if TrimLine = '' then
        Continue;

      if StartsStr('  100CL', Line) or StartsStr(' 100CL', Line) or (Pos('100CL', Line) in [1..4]) then
      begin
        Tokens := TrimLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
        if Length(Tokens) >= 3 then
        begin
          if TryStrToFloat(Tokens[2], BlockStepTime, TFormatSettings.Invariant) then
            IsStep1 := BlockStepTime <= 1.0001;
        end;
        Continue;
      end;

      if (Pos(' -4  ', Line) = 1) or (Pos('-4  ', TrimLine) = 1) then
      begin
        Tokens := TrimLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
        if Length(Tokens) >= 2 then
        begin
          BlockName := UpperCase(Tokens[1]);
          InDataBlock := IsStep1 and ((BlockName = 'DISP') or (BlockName = 'FORC') or (BlockName = 'CONTACT'));
        end
        else
          InDataBlock := False;
        Continue;
      end;

      if TrimLine = '-3' then
      begin
        InDataBlock := False;
        BlockName := '';
        Continue;
      end;

      if not InDataBlock then
        Continue;

      if StartsStr(' -1', Line) or StartsStr('-1', Line) then
      begin
        // Fixed-width columns: node ID cols 4..13, 12-char values from col 14 onward.
        if not TryStrToInt(Trim(Copy(Line, 4, 10)), NodeId) then
          Continue;
        if (NodeId < 1) or (NodeId > ANodeCount) then
          Continue;

        if BlockName = 'DISP' then
        begin
          if ParseFrdFixedFloat(Line, 14, 12, V0) then Result.DispX[NodeId] := V0;
          if ParseFrdFixedFloat(Line, 26, 12, V1) then Result.DispY[NodeId] := V1;
          Result.HasDisp := True;
        end
        else if BlockName = 'FORC' then
        begin
          if ParseFrdFixedFloat(Line, 14, 12, V0) then Result.ForceX[NodeId] := V0;
          if ParseFrdFixedFloat(Line, 26, 12, V1) then Result.ForceY[NodeId] := V1;
          Result.HasForce := True;
        end
        else if BlockName = 'CONTACT' then
        begin
          if ParseFrdFixedFloat(Line, 50, 12, V3) then
            Result.CPress[NodeId] := V3;
          Result.HasContact := True;
        end;
      end;
    end;
  finally
    Reader.Free;
  end;
end;

function ExtractDatHeaderTime(const ATrimLine: string; out ATime: Double): Boolean;
var
  Tokens: TArray<string>;
begin
  Result := False;
  ATime := 0.0;
  if Pos('time', LowerCase(ATrimLine)) = 0 then
    Exit;
  Tokens := ATrimLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
  if Length(Tokens) > 0 then
    Result := TryStrToFloat(Tokens[High(Tokens)], ATime, TFormatSettings.Invariant);
end;

function ParseDatFile(const AFilePath: string; AMaxElemId, ACenterTopNodeId: Integer): TDatData;
type
  TDatSection = (dsNone, dsTotalForce, dsDisplacements, dsStresses, dsPeeq);
var
  Reader: TStreamReader;
  Line, TrimLine, LowerLine: string;
  Tokens: TArray<string>;
  CurrStep: Integer;
  Section: TDatSection;
  ElId, GpId, NodeId: Integer;
  V1, V2, V3, V4, SecTime: Double;
begin
  Result := Default(TDatData);
  SetLength(Result.ElemData, AMaxElemId + 1);
  CurrStep := 1;
  Section := dsNone;

  if not TFile.Exists(AFilePath) then
    raise EFileNotFoundException.CreateFmt('.dat file not found: %s', [AFilePath]);

  Reader := TStreamReader.Create(AFilePath, TEncoding.ASCII);
  try
    while not Reader.EndOfStream do
    begin
      Line := Reader.ReadLine;
      TrimLine := Trim(Line);
      if TrimLine = '' then
        Continue;
      LowerLine := LowerCase(TrimLine);

      if Pos('s t e p', LowerLine) > 0 then
      begin
        Tokens := TrimLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
        if Length(Tokens) >= 5 then
          TryStrToInt(Tokens[High(Tokens)], CurrStep);
        Section := dsNone;
        Continue;
      end;

      if Pos('total force', LowerLine) = 1 then
      begin
        if ExtractDatHeaderTime(TrimLine, SecTime) then
        begin
          if SecTime <= 1.0001 then CurrStep := 1 else CurrStep := 2;
        end;
        Section := dsTotalForce;
        Continue;
      end
      else if Pos('displacements', LowerLine) = 1 then
      begin
        if ExtractDatHeaderTime(TrimLine, SecTime) then
        begin
          if SecTime <= 1.0001 then CurrStep := 1 else CurrStep := 2;
        end;
        Section := dsDisplacements;
        Continue;
      end
      else if Pos('stresses (elem', LowerLine) = 1 then
      begin
        if ExtractDatHeaderTime(TrimLine, SecTime) then
        begin
          if SecTime <= 1.0001 then CurrStep := 1 else CurrStep := 2;
        end;
        Section := dsStresses;
        Continue;
      end
      else if Pos('equivalent plastic strain', LowerLine) = 1 then
      begin
        if ExtractDatHeaderTime(TrimLine, SecTime) then
        begin
          if SecTime <= 1.0001 then CurrStep := 1 else CurrStep := 2;
        end;
        Section := dsPeeq;
        Continue;
      end
      else if (Pos('contact stress', LowerLine) = 1) or
              (Pos('relative contact', LowerLine) = 1) or
              (Pos('increment', LowerLine) = 1) then
      begin
        if ExtractDatHeaderTime(TrimLine, SecTime) then
        begin
          if SecTime <= 1.0001 then CurrStep := 1 else CurrStep := 2;
        end;
        Section := dsNone;
        Continue;
      end;

      Tokens := TrimLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
      case Section of
        dsTotalForce:
          begin
            if Length(Tokens) >= 3 then
            begin
              if TryStrToFloat(Tokens[1], V2, TFormatSettings.Invariant) then
              begin
                if CurrStep = 1 then
                begin
                  Result.Step1TotalRF2 := V2;
                  Result.HasStep1RF := True;
                end
                else if CurrStep = 2 then
                  Result.Step2TotalRF2 := V2;
              end;
              Section := dsNone;
            end;
          end;
        dsDisplacements:
          begin
            if (CurrStep = 2) and (Length(Tokens) >= 4) and
               TryStrToInt(Tokens[0], NodeId) and (NodeId = ACenterTopNodeId) and
               TryStrToFloat(Tokens[2], V2, TFormatSettings.Invariant) then
            begin
              Result.Step2CenterTopUy := V2;
              Result.HasStep2Uy := True;
            end;
          end;
        dsStresses:
          begin
            if (CurrStep = 1) and (Length(Tokens) >= 6) and
               TryStrToInt(Tokens[0], ElId) and TryStrToInt(Tokens[1], GpId) then
            begin
              if (ElId >= 1) and (ElId <= AMaxElemId) and (GpId >= 1) and (GpId <= 8) then
              begin
                if TryStrToFloat(Tokens[2], V1, TFormatSettings.Invariant) and
                   TryStrToFloat(Tokens[3], V2, TFormatSettings.Invariant) and
                   TryStrToFloat(Tokens[4], V3, TFormatSettings.Invariant) and
                   TryStrToFloat(Tokens[5], V4, TFormatSettings.Invariant) then
                begin
                  Result.ElemData[ElId].Sxx[GpId - 1] := V1;
                  Result.ElemData[ElId].Syy[GpId - 1] := V2;
                  Result.ElemData[ElId].Szz[GpId - 1] := V3;
                  Result.ElemData[ElId].Sxy[GpId - 1] := V4;
                  if GpId > Result.ElemData[ElId].GPCount then
                    Result.ElemData[ElId].GPCount := GpId;
                end;
              end;
            end;
          end;
        dsPeeq:
          begin
            if (CurrStep = 1) and (Length(Tokens) >= 3) and
               TryStrToInt(Tokens[0], ElId) and TryStrToInt(Tokens[1], GpId) then
            begin
              if (ElId >= 1) and (ElId <= AMaxElemId) and (GpId >= 1) and (GpId <= 8) then
              begin
                if TryStrToFloat(Tokens[2], V1, TFormatSettings.Invariant) then
                begin
                  Result.ElemData[ElId].Peeq[GpId - 1] := Max(0.0, V1);
                  Result.ElemData[ElId].HasPeeq := True;
                  if GpId > Result.ElemData[ElId].GPCount then
                    Result.ElemData[ElId].GPCount := GpId;
                end;
              end;
            end;
          end;
      end;
    end;
  finally
    Reader.Free;
  end;
end;

function ComputeAxisymmetricPressureForce(const AR, AP: TDoubleArray): Double;
var
  I: Integer;
  R0, R1, P0, P1: Double;
begin
  Result := 0.0;
  for I := 0 to High(AR) - 1 do
  begin
    R0 := AR[I];
    R1 := AR[I + 1];
    P0 := Max(0.0, AP[I]);
    P1 := Max(0.0, AP[I + 1]);
    Result := Result + Pi * ((R1 - R0) / 3.0) * (P0 * (2.0 * R0 + R1) + P1 * (R0 + 2.0 * R1));
  end;
end;

procedure AccumulateElementStressesToRegion(AMesh: TFemMesh; const AElIds: TArray<Integer>;
  const ADat: TDatData; var NSrr, NStt, NSzz, NTrz, NPeeq: TDoubleArray;
  var NCount: TArray<Integer>; out AMaxRegionPeeq: Double);
const
  WPP = 1.8660254037844386;
  WPM = -0.5;
  WMM = 0.13397459621556135;
var
  I, ElId, K: Integer;
  Q: TMeshQuad;
  Ed: TElemStressBlock;
  GpSrr, GpStt, GpSzz, GpTrz, GpPe: array[0..3] of Double;
  NodeIds: array[0..3] of Integer;
  SrrC, SttC, SzzC, TrzC, PeC: Double;
begin
  AMaxRegionPeeq := 0.0;
  for I := 0 to High(AElIds) do
  begin
    ElId := AElIds[I];
    Q := AMesh.Quads[ElId - 1];
    Ed := ADat.ElemData[ElId];
    if Ed.GPCount = 0 then
      Continue;

    if Ed.GPCount >= 8 then
    begin
      // CAX4 expands to 8 wedge points: (1,5)=BL, (2,6)=BR, (3,7)=TL, (4,8)=TR.
      for K := 0 to 3 do
      begin
        GpSrr[K] := 0.5 * (Ed.Sxx[K] + Ed.Sxx[K + 4]);
        GpStt[K] := 0.5 * (Ed.Szz[K] + Ed.Szz[K + 4]);
        GpSzz[K] := 0.5 * (Ed.Syy[K] + Ed.Syy[K + 4]);
        GpTrz[K] := -0.5 * (Ed.Sxy[K] + Ed.Sxy[K + 4]);
        if Ed.HasPeeq then
          GpPe[K] := 0.5 * (Ed.Peeq[K] + Ed.Peeq[K + 4])
        else
          GpPe[K] := 0.0;
        if GpPe[K] > AMaxRegionPeeq then
          AMaxRegionPeeq := GpPe[K];
      end;
    end
    else
    begin
      // CAX4R single center integration point (two wedge layers 1, 2).
      SrrC := 0.0; SttC := 0.0; SzzC := 0.0; TrzC := 0.0; PeC := 0.0;
      for K := 0 to Ed.GPCount - 1 do
      begin
        SrrC := SrrC + Ed.Sxx[K];
        SttC := SttC + Ed.Szz[K];
        SzzC := SzzC + Ed.Syy[K];
        TrzC := TrzC - Ed.Sxy[K];
        if Ed.HasPeeq then
          PeC := PeC + Ed.Peeq[K];
      end;
      SrrC := SrrC / Ed.GPCount;
      SttC := SttC / Ed.GPCount;
      SzzC := SzzC / Ed.GPCount;
      TrzC := TrzC / Ed.GPCount;
      PeC := PeC / Ed.GPCount;
      if PeC > AMaxRegionPeeq then
        AMaxRegionPeeq := PeC;
      for K := 0 to 3 do
      begin
        GpSrr[K] := SrrC;
        GpStt[K] := SttC;
        GpSzz[K] := SzzC;
        GpTrz[K] := TrzC;
        GpPe[K] := PeC;
      end;
    end;

    NodeIds[0] := Q.N1;
    NodeIds[1] := Q.N2;
    NodeIds[2] := Q.N4;
    NodeIds[3] := Q.N3;

    // Corner extrapolation map for gp indices 0=BL, 1=BR, 2=TL, 3=TR.
    for K := 0 to 3 do
    begin
      var Opp := 3 - K;
      var Adj1, Adj2: Integer;
      case K of
        0: begin Adj1 := 1; Adj2 := 2; end;
        1: begin Adj1 := 0; Adj2 := 3; end;
        2: begin Adj1 := 0; Adj2 := 3; end;
      else
        Adj1 := 1; Adj2 := 2;
      end;
      var Nid := NodeIds[K];
      NSrr[Nid] := NSrr[Nid] + WPP * GpSrr[K] + WPM * (GpSrr[Adj1] + GpSrr[Adj2]) + WMM * GpSrr[Opp];
      NStt[Nid] := NStt[Nid] + WPP * GpStt[K] + WPM * (GpStt[Adj1] + GpStt[Adj2]) + WMM * GpStt[Opp];
      NSzz[Nid] := NSzz[Nid] + WPP * GpSzz[K] + WPM * (GpSzz[Adj1] + GpSzz[Adj2]) + WMM * GpSzz[Opp];
      NTrz[Nid] := NTrz[Nid] + WPP * GpTrz[K] + WPM * (GpTrz[Adj1] + GpTrz[Adj2]) + WMM * GpTrz[Opp];
      NPeeq[Nid] := NPeeq[Nid] + Max(0.0, WPP * GpPe[K] + WPM * (GpPe[Adj1] + GpPe[Adj2]) + WMM * GpPe[Opp]);
      Inc(NCount[Nid]);
    end;
  end;
end;

function ExtractFemContactRadius(AMesh: TFemMesh; const AFrd: TFrdData;
  const AR, AP: TDoubleArray; APMax: Double): Double;
var
  I, J, LastActive, LastCore, MaxCheckIdx, Nib, Nid: Integer;
  Thresh, ThreshCore, R1, R2, P1, P2, ZeroR, BallY, TFrac, MinClamp, MaxClamp: Double;
  BallRDef, BallYDef, SpecRDef, Gap: TDoubleArray;
begin
  Thresh := 1e-3 * Max(1e-9, APMax);
  LastActive := -1;
  for I := High(AP) downto 0 do
    if AP[I] > Thresh then
    begin
      LastActive := I;
      Break;
    end;
  if LastActive < 0 then
    Exit(0.0);

  if AFrd.HasDisp and (Length(AMesh.BallArcNodes) >= 2) and (LastActive >= 1) then
  begin
    SetLength(BallRDef, Length(AMesh.BallArcNodes));
    SetLength(BallYDef, Length(AMesh.BallArcNodes));
    for J := 0 to High(AMesh.BallArcNodes) do
    begin
      Nib := AMesh.BallArcNodes[J];
      BallRDef[J] := AMesh.Nodes[Nib - 1].R + AFrd.DispX[Nib];
      BallYDef[J] := AMesh.Nodes[Nib - 1].Y + AFrd.DispY[Nib];
    end;

    MaxCheckIdx := Min(High(AR), LastActive + 2);
    SetLength(SpecRDef, MaxCheckIdx + 1);
    SetLength(Gap, MaxCheckIdx + 1);
    for I := 0 to MaxCheckIdx do
    begin
      Nid := AMesh.SpecTopNodes[I];
      SpecRDef[I] := AMesh.Nodes[Nid - 1].R + AFrd.DispX[Nid];
      if SpecRDef[I] <= BallRDef[0] then
        BallY := BallYDef[0]
      else if SpecRDef[I] >= BallRDef[High(BallRDef)] then
        BallY := BallYDef[High(BallYDef)]
      else
      begin
        BallY := BallYDef[High(BallYDef)];
        for J := 0 to High(BallRDef) - 1 do
          if (SpecRDef[I] >= BallRDef[J]) and (SpecRDef[I] <= BallRDef[J + 1]) then
          begin
            TFrac := (SpecRDef[I] - BallRDef[J]) / Max(1e-12, BallRDef[J + 1] - BallRDef[J]);
            BallY := BallYDef[J] + TFrac * (BallYDef[J + 1] - BallYDef[J]);
            Break;
          end;
      end;
      Gap[I] := BallY - (AMesh.Nodes[Nid - 1].Y + AFrd.DispY[Nid]);
    end;

    for I := Min(MaxCheckIdx - 1, LastActive + 1) downto 0 do
    begin
      if (Gap[I] <= 0.0) and (Gap[I + 1] > 0.0) then
      begin
        ZeroR := SpecRDef[I] + (SpecRDef[I + 1] - SpecRDef[I]) * (-Gap[I] / (Gap[I + 1] - Gap[I]));
        MinClamp := AR[Max(0, LastActive - 2)];
        MaxClamp := AR[Min(High(AR), LastActive + 1)];
        if ZeroR < MinClamp then ZeroR := MinClamp;
        if ZeroR > MaxClamp then ZeroR := MaxClamp;
        Exit(ZeroR);
      end;
    end;
  end;

  ThreshCore := 0.05 * Max(1e-9, APMax);
  LastCore := -1;
  for I := High(AP) downto 0 do
    if AP[I] > ThreshCore then
    begin
      LastCore := I;
      Break;
    end;
  if LastCore < 0 then
    Exit(AR[LastActive]);
  if (LastCore >= 1) and (AP[LastCore - 1] > AP[LastCore]) then
  begin
    R1 := AR[LastCore - 1];
    R2 := AR[LastCore];
    P1 := AP[LastCore - 1];
    P2 := AP[LastCore];
    ZeroR := R1 + (R2 - R1) * (P1 / (P1 - P2));
    MaxClamp := AR[Min(High(AR), LastCore + 1)];
    if ZeroR < R2 then ZeroR := R2;
    if ZeroR > MaxClamp then ZeroR := MaxClamp;
    Result := ZeroR;
  end
  else
    Result := AR[LastCore];
end;

function BuildDeformedTopRadii(AMesh: TFemMesh; const AFrd: TFrdData): TDoubleArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AMesh.SpecRCoords));
  for I := 0 to High(AMesh.SpecRCoords) do
  begin
    if I = 0 then
      Result[0] := 0.0
    else if AFrd.HasDisp then
      Result[I] := Max(0.0, AMesh.SpecRCoords[I] + AFrd.DispX[AMesh.SpecTopNodes[I]])
    else
      Result[I] := AMesh.SpecRCoords[I];
  end;
end;

function RunSingleCcxTrial(const ACase: TContactCase; AMesh: TFemMesh; const ACcxExe, AWorkDir: string;
  const AJobName: string; ADeltaTrialUm: Double; AIncludeUnloading: Boolean;
  const ALogCallback: TProc<string>; ACancelFlag: PBoolean;
  out AFrd: TFrdData; out ADat: TDatData; out AForce360Mn: Double;
  out AActualElemStr: string): Boolean;
var
  PenaltyScales: array[0..2] of Double;
  Idx, I, NrTop: Integer;
  InpText, InpPath, StdOutText, DatPath, FrdPath: string;
  ExitCode: DWORD;
  BallRfSum, FInt, BalErr, BestBalErr: Double;
  TopRDef, TopP: TDoubleArray;
  BestValid: Boolean;
  BestFrd: TFrdData;
  BestDat: TDatData;
  BestForce: Double;
  BestElemStr: string;
begin
  Result := False;
  PenaltyScales[0] := 1.0;
  PenaltyScales[1] := 0.35;
  PenaltyScales[2] := 0.12;
  BestValid := False;
  BestBalErr := Infinity;
  BestForce := 0.0;
  BestFrd := Default(TFrdData);
  BestDat := Default(TDatData);
  BestElemStr := 'CAX4';

  NrTop := Length(AMesh.SpecRCoords);
  SetLength(TopP, NrTop);

  for Idx := 0 to High(PenaltyScales) do
  begin
    InpText := GenerateCalculixInp(ACase, AMesh, ADeltaTrialUm, PenaltyScales[Idx],
      AIncludeUnloading, AActualElemStr);
    InpPath := TPath.Combine(AWorkDir, AJobName + '.inp');
    TFile.WriteAllText(InpPath, InpText, TEncoding.ASCII);

    if Assigned(ALogCallback) then
      ALogCallback(Format('Running ccx -i %s (delta=%.6g um, penalty_scale=%.2g)...',
        [AJobName, ADeltaTrialUm, PenaltyScales[Idx]], TFormatSettings.Invariant));

    if RunCcxCapture(ACcxExe, AWorkDir, AJobName, ACase.Solver.TimeoutS,
      StdOutText, ExitCode, ALogCallback, ACancelFlag) then
    begin
      DatPath := TPath.Combine(AWorkDir, AJobName + '.dat');
      FrdPath := TPath.Combine(AWorkDir, AJobName + '.frd');
      if TFile.Exists(DatPath) and TFile.Exists(FrdPath) then
      begin
        AFrd := ParseFrdFile(FrdPath, Length(AMesh.Nodes));
        ADat := ParseDatFile(DatPath, Length(AMesh.Quads), AMesh.SpecCenterTopNode);
        if ADat.HasStep1RF then
          AForce360Mn := 180.0 * Abs(ADat.Step1TotalRF2)
        else if AFrd.HasForce then
        begin
          BallRfSum := 0.0;
          for I := 0 to High(AMesh.BallTopNodes) do
            BallRfSum := BallRfSum + AFrd.ForceY[AMesh.BallTopNodes[I]];
          AForce360Mn := 180.0 * Abs(BallRfSum);
        end
        else
          AForce360Mn := 0.0;

        if AForce360Mn > 0.0 then
        begin
          TopRDef := BuildDeformedTopRadii(AMesh, AFrd);
          for I := 0 to NrTop - 1 do
            TopP[I] := Max(0.0, AFrd.CPress[AMesh.SpecTopNodes[I]]);
          FInt := ComputeAxisymmetricPressureForce(TopRDef, TopP);
          BalErr := Abs(FInt - AForce360Mn) / AForce360Mn;
          if BalErr < 0.03 then
            Exit(True);

          if BalErr < BestBalErr then
          begin
            BestValid := True;
            BestBalErr := BalErr;
            BestFrd := AFrd;
            BestDat := ADat;
            BestForce := AForce360Mn;
            BestElemStr := AActualElemStr;
          end;
        end;
      end;
    end;
    if (ACancelFlag <> nil) and ACancelFlag^ then
      Exit(False);
  end;

  if BestValid then
  begin
    AFrd := BestFrd;
    ADat := BestDat;
    AForce360Mn := BestForce;
    AActualElemStr := BestElemStr;
    Exit(True);
  end;
end;

function SolveFemCalculix(const ACase: TContactCase; const ALogCallback: TProc<string>;
  ACancelFlag: PBoolean; AElasticHint: TContactResult): TContactResult;
var
  Timer: TStopwatch;
  CcxExe, WorkDir, MeshReport, ActualElemStr: string;
  OwnedHint, ElasticRef: TContactResult;
  EstA, EstDelta, EstMaxYield, DeltaCur, DeltaPrev, DeltaNext, ForceCur, ForcePrev: Double;
  TargetLoad, RelErr, AlphaExp, MaxDeltaJump: Double;
  Mesh: TFemMesh;
  Frd: TFrdData;
  Dat: TDatData;
  MaxBrackets, BracketIdx, N, K, Ir, Iz, NrSpec: Integer;
  OwnWorkDir: Boolean;
  NeedUnloadingStep: Boolean;
  TopR, TopRDef, TopP: TDoubleArray;
  PMax, FInt, ForceBalanceErr, ContactA, PMean: Double;
  Grid: TStressGrid;
  RCount, ZCount, RLimitIdx, RowOut: Integer;
  ZGridList: TList<Double>;
  RowRegionList: TList<Integer>;
  RowGridZIdxList: TList<Integer>;
  NSrr, NStt, NSzz, NTrz, NPeeq: TDoubleArray;
  NCount: TArray<Integer>;
  RegionMaxVm, RegionMaxPeeq: TDoubleArray;
  RegId, Nid: Integer;
  Srr, Stt, Szz, Trz, Svm, PeVal, RegMaxPeeqOut, OverallMaxPeeq: Double;
  IfIdx, AboveRow, BelowRow: Integer;
  IfSummary: TInterfaceStressSummary;
  SrrMaxA, SrrMinA, SrrMaxB, SrrMinB, TrzMax, SvmMaxA, SvmMaxB, PeMaxA, PeMaxB, EAbove, EBelow: Double;
  YieldList: TArray<TYieldRatioEntry>;
  YCount: Integer;
  AnyPeeq: Boolean;
begin
  ACase.Validate;
  Timer := TStopwatch.StartNew;

  CcxExe := ResolveCcxPath(ACase.Solver.CcxPath);
  if CcxExe = '' then
    raise EFileNotFoundException.Create('CalculiX (ccx.exe) not found. Run setup-ccx first.');

  OwnedHint := nil;
  try
    if AElasticHint <> nil then
      ElasticRef := AElasticHint
    else
    begin
      OwnedHint := SolveElasticLayered(ACase);
      ElasticRef := OwnedHint;
    end;
    EstA := ElasticRef.ContactRadiusUm;
    EstDelta := ElasticRef.PenetrationDepthUm;
    EstMaxYield := ElasticRef.MaxYieldRatio;
  finally
    OwnedHint.Free;
  end;

  Mesh := GenerateFemMesh(ACase, EstA, EstDelta, EstMaxYield);
  try
    if not ValidateFemMesh(Mesh, ACase, MeshReport) then
      raise Exception.Create('Invalid FEM mesh: ' + MeshReport);

    if Trim(ACase.Solver.WorkDir) <> '' then
    begin
      WorkDir := Trim(ACase.Solver.WorkDir);
      TDirectory.CreateDirectory(WorkDir);
      OwnWorkDir := False;
    end
    else
    begin
      WorkDir := TPath.Combine(TPath.GetTempPath, 'tc_fem_' + TPath.GetRandomFileName);
      TDirectory.CreateDirectory(WorkDir);
      OwnWorkDir := True;
    end;

    try
      TargetLoad := ACase.LoadCase.NormalLoadMn;
      MaxBrackets := ACase.Solver.MaxLoadBrackets;
      DeltaCur := EstDelta;
      DeltaPrev := 0.0;
      ForcePrev := 0.0;
      ForceCur := 0.0;
      ActualElemStr := 'CAX4';

      for BracketIdx := 0 to MaxBrackets do
      begin
        NeedUnloadingStep := False;
        if not RunSingleCcxTrial(ACase, Mesh, CcxExe, WorkDir,
          Format('job_%d', [BracketIdx]), DeltaCur, NeedUnloadingStep,
          ALogCallback, ACancelFlag, Frd, Dat, ForceCur, ActualElemStr) then
        begin
          if (ACancelFlag <> nil) and ACancelFlag^ then
            raise EOperationCancelled.Create('CalculiX solve cancelled by user');
          raise Exception.Create(Format('CalculiX failed to converge on trial %d (delta=%.6g um)',
            [BracketIdx, DeltaCur], TFormatSettings.Invariant));
        end;

        RelErr := Abs(ForceCur - TargetLoad) / TargetLoad;
        if Assigned(ALogCallback) then
          ALogCallback(Format('Bracket %d: delta=%.6g um -> F=%.4f mN (target=%.4f mN, err=%.2f%%)',
            [BracketIdx, DeltaCur, ForceCur, TargetLoad, 100.0 * RelErr], TFormatSettings.Invariant));

        if RelErr <= ACase.Solver.LoadToleranceRel then
          Break;
        if BracketIdx = MaxBrackets then
          Break;

        if BracketIdx = 0 then
          DeltaNext := DeltaCur * Power(TargetLoad / ForceCur, 2.0 / 3.0)
        else
        begin
          if (Abs(DeltaCur - DeltaPrev) > 1e-15) and (ForceCur > 0.0) and (ForcePrev > 0.0) and
             (Abs(ForceCur - ForcePrev) > 1e-12 * TargetLoad) then
          begin
            AlphaExp := Ln(ForceCur / ForcePrev) / Ln(DeltaCur / DeltaPrev);
            AlphaExp := EnsureRange(AlphaExp, 0.5, 2.5);
            DeltaNext := DeltaCur * Power(TargetLoad / ForceCur, 1.0 / AlphaExp);
          end
          else
            DeltaNext := DeltaCur * Power(TargetLoad / ForceCur, 2.0 / 3.0);
        end;

        MaxDeltaJump := 4.0 * DeltaCur;
        if DeltaNext > MaxDeltaJump then DeltaNext := MaxDeltaJump;
        if DeltaNext < 0.25 * DeltaCur then DeltaNext := 0.25 * DeltaCur;

        DeltaPrev := DeltaCur;
        ForcePrev := ForceCur;
        DeltaCur := DeltaNext;
      end;

      if ACase.Solver.IncludeUnloading then
      begin
        if not RunSingleCcxTrial(ACase, Mesh, CcxExe, WorkDir,
          'job_unload', DeltaCur, True, ALogCallback, ACancelFlag,
          Frd, Dat, ForceCur, ActualElemStr) then
        begin
          if (ACancelFlag <> nil) and ACancelFlag^ then
            raise EOperationCancelled.Create('CalculiX unloading solve cancelled by user');
          raise Exception.Create('CalculiX unloading step failed to converge');
        end;
      end;

      NrSpec := Length(Mesh.SpecRCoords);
      SetLength(TopR, NrSpec);
      SetLength(TopP, NrSpec);
      PMax := 0.0;
      for Ir := 0 to NrSpec - 1 do
      begin
        TopR[Ir] := Mesh.SpecRCoords[Ir];
        TopP[Ir] := Max(0.0, Frd.CPress[Mesh.SpecTopNodes[Ir]]);
        if TopP[Ir] > PMax then
          PMax := TopP[Ir];
      end;

      TopRDef := BuildDeformedTopRadii(Mesh, Frd);
      FInt := ComputeAxisymmetricPressureForce(TopRDef, TopP);
      ForceBalanceErr := Abs(FInt - ForceCur) / Max(1e-12, ForceCur);
      if ForceBalanceErr >= 0.03 then
        raise Exception.Create(Format('FEM force balance integral error %.4f >= 0.03 (F_int=%.4f, F_rf=%.4f)',
          [ForceBalanceErr, FInt, ForceCur], TFormatSettings.Invariant));

      ContactA := ExtractFemContactRadius(Mesh, Frd, TopR, TopP, PMax);
      PMean := ForceCur / Max(1e-12, Pi * Sqr(ContactA));

      Result := TContactResult.Create;
      try
        Result.SolverName := 'fem_calculix';
        Result.ContactRadiusUm := ContactA;
        Result.PenetrationDepthUm := DeltaCur;
        if ACase.Solver.IncludeUnloading and Dat.HasStep2Uy then
        begin
          Result.HasResidualDepth := True;
          Result.ResidualDepthUm := Max(0.0, -Dat.Step2CenterTopUy);
        end;
        Result.PMaxGpa := PMax;
        Result.PMeanGpa := PMean;
        Result.ActualLoadMn := ForceCur;
        Result.ForceBalanceErrorRel := ForceBalanceErr;

        RLimitIdx := 0;
        for Ir := 0 to NrSpec - 1 do
        begin
          if TopR[Ir] <= Max(2.0 * ContactA, 1.5 * EstA) then
            RLimitIdx := Ir;
        end;
        if RLimitIdx < 10 then
          RLimitIdx := Min(NrSpec - 1, 30);

        SetLength(Result.RUm, RLimitIdx + 1);
        SetLength(Result.PGpa, RLimitIdx + 1);
        for Ir := 0 to RLimitIdx do
        begin
          Result.RUm[Ir] := TopR[Ir];
          Result.PGpa[Ir] := TopP[Ir];
        end;

        N := Length(ACase.Layers);
        SetLength(RegionMaxVm, N + 1);
        SetLength(RegionMaxPeeq, N + 1);
        AnyPeeq := False;
        OverallMaxPeeq := 0.0;

        ZGridList := TList<Double>.Create;
        RowRegionList := TList<Integer>.Create;
        RowGridZIdxList := TList<Integer>.Create;
        try
          for K := 0 to N - 1 do
          begin
            for Iz := Mesh.LayerStartRow[K] to Mesh.LayerEndRow[K] do
            begin
              ZGridList.Add(Mesh.SpecZCoords[Iz]);
              RowRegionList.Add(K);
              RowGridZIdxList.Add(Iz);
            end;
          end;
          for Iz := Mesh.SubStartRow to Mesh.SubEndRow do
          begin
            if Mesh.SpecZCoords[Iz] > Max(3.5 * ContactA, ACase.TotalCoatingThicknessUm + 2.5 * ContactA) then
              if (Iz - Mesh.SubStartRow) > 6 then
                Break;
            ZGridList.Add(Mesh.SpecZCoords[Iz]);
            RowRegionList.Add(N);
            RowGridZIdxList.Add(Iz);
          end;

          RCount := RLimitIdx + 1;
          ZCount := ZGridList.Count;
          Grid := TStressGrid.Create;
          Grid.RUm := Copy(Result.RUm);
          Grid.ZUm := ZGridList.ToArray;
          SetLength(Grid.SigmaRRGpa, ZCount, RCount);
          SetLength(Grid.SigmaTTGpa, ZCount, RCount);
          SetLength(Grid.SigmaZZGpa, ZCount, RCount);
          SetLength(Grid.TauRZGpa, ZCount, RCount);
          SetLength(Grid.SigmaVmGpa, ZCount, RCount);
          SetLength(Grid.Peeq, ZCount, RCount);
          Grid.HasPeeq := True;

          SetLength(NSrr, Length(Mesh.Nodes) + 1);
          SetLength(NStt, Length(Mesh.Nodes) + 1);
          SetLength(NSzz, Length(Mesh.Nodes) + 1);
          SetLength(NTrz, Length(Mesh.Nodes) + 1);
          SetLength(NPeeq, Length(Mesh.Nodes) + 1);
          SetLength(NCount, Length(Mesh.Nodes) + 1);

          for RegId := 0 to N do
          begin
            FillChar(NSrr[0], Length(NSrr) * SizeOf(Double), 0);
            FillChar(NStt[0], Length(NStt) * SizeOf(Double), 0);
            FillChar(NSzz[0], Length(NSzz) * SizeOf(Double), 0);
            FillChar(NTrz[0], Length(NTrz) * SizeOf(Double), 0);
            FillChar(NPeeq[0], Length(NPeeq) * SizeOf(Double), 0);
            FillChar(NCount[0], Length(NCount) * SizeOf(Integer), 0);

            if RegId < N then
              AccumulateElementStressesToRegion(Mesh, Mesh.LayerElSets[RegId], Dat,
                NSrr, NStt, NSzz, NTrz, NPeeq, NCount, RegMaxPeeqOut)
            else
              AccumulateElementStressesToRegion(Mesh, Mesh.SubstrateElSet, Dat,
                NSrr, NStt, NSzz, NTrz, NPeeq, NCount, RegMaxPeeqOut);

            RegionMaxPeeq[RegId] := RegMaxPeeqOut;
            if RegMaxPeeqOut > OverallMaxPeeq then
              OverallMaxPeeq := RegMaxPeeqOut;
            if RegMaxPeeqOut > 0.0 then
              AnyPeeq := True;

            for RowOut := 0 to ZCount - 1 do
            begin
              if RowRegionList[RowOut] <> RegId then
                Continue;
              Iz := RowGridZIdxList[RowOut];
              for Ir := 0 to RCount - 1 do
              begin
                Nid := Mesh.SpecNodeGrid[Iz, Ir];
                if NCount[Nid] > 0 then
                begin
                  Srr := NSrr[Nid] / NCount[Nid];
                  Stt := NStt[Nid] / NCount[Nid];
                  Szz := NSzz[Nid] / NCount[Nid];
                  Trz := NTrz[Nid] / NCount[Nid];
                  PeVal := Max(0.0, NPeeq[Nid] / NCount[Nid]);
                end
                else
                begin
                  Srr := 0.0; Stt := 0.0; Szz := 0.0; Trz := 0.0; PeVal := 0.0;
                end;
                Svm := Sqrt(0.5 * (Sqr(Srr - Stt) + Sqr(Stt - Szz) + Sqr(Szz - Srr)) + 3.0 * Sqr(Trz));
                Grid.SigmaRRGpa[RowOut, Ir] := Srr;
                Grid.SigmaTTGpa[RowOut, Ir] := Stt;
                Grid.SigmaZZGpa[RowOut, Ir] := Szz;
                Grid.TauRZGpa[RowOut, Ir] := Trz;
                Grid.SigmaVmGpa[RowOut, Ir] := Svm;
                Grid.Peeq[RowOut, Ir] := PeVal;
                if Svm > RegionMaxVm[RegId] then
                  RegionMaxVm[RegId] := Svm;
              end;
            end;
          end;

          Result.StressGrid := Grid;
          if AnyPeeq then
          begin
            Result.HasMaxPeeq := True;
            Result.MaxPeeq := OverallMaxPeeq;
          end
          else
          begin
            Result.HasMaxPeeq := True;
            Result.MaxPeeq := 0.0;
          end;

          SetLength(Result.ZCenterlineUm, ZCount);
          SetLength(Result.CenterlineSigmaVmGpa, ZCount);
          SetLength(Result.CenterlineSigmaRRGpa, ZCount);
          SetLength(Result.CenterlineSigmaZZGpa, ZCount);
          for RowOut := 0 to ZCount - 1 do
          begin
            Result.ZCenterlineUm[RowOut] := Grid.ZUm[RowOut];
            Result.CenterlineSigmaVmGpa[RowOut] := Grid.SigmaVmGpa[RowOut, 0];
            Result.CenterlineSigmaRRGpa[RowOut] := Grid.SigmaRRGpa[RowOut, 0];
            Result.CenterlineSigmaZZGpa[RowOut] := Grid.SigmaZZGpa[RowOut, 0];
          end;

          SetLength(Result.Interfaces, N);
          for IfIdx := 0 to N - 1 do
          begin
            AboveRow := -1;
            BelowRow := -1;
            for RowOut := 0 to ZCount - 2 do
            begin
              if (RowRegionList[RowOut] = IfIdx) and (RowRegionList[RowOut + 1] = IfIdx + 1) and
                 (Abs(Grid.ZUm[RowOut] - Grid.ZUm[RowOut + 1]) < 1e-12) then
              begin
                AboveRow := RowOut;
                BelowRow := RowOut + 1;
                Break;
              end;
            end;

            IfSummary := Default(TInterfaceStressSummary);
            IfSummary.InterfaceIndex := IfIdx + 1;
            IfSummary.DepthUm := Mesh.SpecZCoords[Mesh.LayerEndRow[IfIdx]];
            IfSummary.AboveLabel := Format('Layer %d (%s)', [IfIdx + 1, ACase.Layers[IfIdx].Material.Name]);
            if IfIdx + 1 < N then
              IfSummary.BelowLabel := Format('Layer %d (%s)', [IfIdx + 2, ACase.Layers[IfIdx + 1].Material.Name])
            else
              IfSummary.BelowLabel := Format('Substrate (%s)', [ACase.Substrate.Name]);

            if (AboveRow >= 0) and (BelowRow >= 0) then
            begin
              EAbove := ACase.Layers[IfIdx].Material.EGpa;
              if IfIdx + 1 < N then
                EBelow := ACase.Layers[IfIdx + 1].Material.EGpa
              else
                EBelow := ACase.Substrate.EGpa;

              SrrMaxA := -Infinity; SrrMinA := Infinity;
              SrrMaxB := -Infinity; SrrMinB := Infinity;
              TrzMax := 0.0; SvmMaxA := 0.0; SvmMaxB := 0.0;
              PeMaxA := 0.0; PeMaxB := 0.0;
              for Ir := 0 to RCount - 1 do
              begin
                if Grid.SigmaRRGpa[AboveRow, Ir] > SrrMaxA then SrrMaxA := Grid.SigmaRRGpa[AboveRow, Ir];
                if Grid.SigmaRRGpa[AboveRow, Ir] < SrrMinA then SrrMinA := Grid.SigmaRRGpa[AboveRow, Ir];
                if Grid.SigmaRRGpa[BelowRow, Ir] > SrrMaxB then SrrMaxB := Grid.SigmaRRGpa[BelowRow, Ir];
                if Grid.SigmaRRGpa[BelowRow, Ir] < SrrMinB then SrrMinB := Grid.SigmaRRGpa[BelowRow, Ir];
                if EBelow <= EAbove then
                begin
                  if Abs(Grid.TauRZGpa[BelowRow, Ir]) > TrzMax then
                    TrzMax := Abs(Grid.TauRZGpa[BelowRow, Ir]);
                end
                else
                begin
                  if Abs(Grid.TauRZGpa[AboveRow, Ir]) > TrzMax then
                    TrzMax := Abs(Grid.TauRZGpa[AboveRow, Ir]);
                end;
                if Grid.SigmaVmGpa[AboveRow, Ir] > SvmMaxA then SvmMaxA := Grid.SigmaVmGpa[AboveRow, Ir];
                if Grid.SigmaVmGpa[BelowRow, Ir] > SvmMaxB then SvmMaxB := Grid.SigmaVmGpa[BelowRow, Ir];
                if Grid.Peeq[AboveRow, Ir] > PeMaxA then PeMaxA := Grid.Peeq[AboveRow, Ir];
                if Grid.Peeq[BelowRow, Ir] > PeMaxB then PeMaxB := Grid.Peeq[BelowRow, Ir];
              end;
              IfSummary.MaxSigmaRRAboveGpa := SrrMaxA;
              IfSummary.MinSigmaRRAboveGpa := SrrMinA;
              IfSummary.MaxSigmaRRBelowGpa := SrrMaxB;
              IfSummary.MinSigmaRRBelowGpa := SrrMinB;
              IfSummary.MaxAbsTauRZGpa := TrzMax;
              IfSummary.MaxSigmaVmAboveGpa := SvmMaxA;
              IfSummary.MaxSigmaVmBelowGpa := SvmMaxB;
              IfSummary.HasPeeq := True;
              IfSummary.MaxPeeqAbove := PeMaxA;
              IfSummary.MaxPeeqBelow := PeMaxB;
            end;
            Result.Interfaces[IfIdx] := IfSummary;
          end;
        finally
          RowGridZIdxList.Free;
          RowRegionList.Free;
          ZGridList.Free;
        end;

        SetLength(YieldList, N + 1);
        YCount := 0;
        Result.YieldWarning := False;
        for K := 0 to N - 1 do
          if ACase.Layers[K].Material.HasSigmaY then
          begin
            YieldList[YCount].MaterialLabel := Format('Layer %d (%s)', [K + 1, ACase.Layers[K].Material.Name]);
            YieldList[YCount].Ratio := RegionMaxVm[K] / ACase.Layers[K].Material.SigmaYGpa;
            if YieldList[YCount].Ratio > 0.95 then
              Result.YieldWarning := True;
            Inc(YCount);
          end;
        if ACase.Substrate.HasSigmaY then
        begin
          YieldList[YCount].MaterialLabel := Format('Substrate (%s)', [ACase.Substrate.Name]);
          YieldList[YCount].Ratio := RegionMaxVm[N] / ACase.Substrate.SigmaYGpa;
          if YieldList[YCount].Ratio > 0.95 then
            Result.YieldWarning := True;
          Inc(YCount);
        end;
        SetLength(YieldList, YCount);
        Result.LayerYieldRatios := YieldList;

        Result.Diagnostics.Add('mesh=' + MeshReport);
        Result.Diagnostics.Add('element_type=' + ActualElemStr);
        if ACase.Solver.ElementType = etCAX4I then
          Result.Diagnostics.Add('element_type_note=CAX4I mapped to CAX4 (unsupported by ccx 2.23)');
        Result.Diagnostics.Add(Format('force_balance_err_rel=%.6f', [ForceBalanceErr], TFormatSettings.Invariant));

        Timer.Stop;
        Result.RuntimeS := Timer.Elapsed.TotalSeconds;
      except
        Result.Free;
        raise;
      end;
    finally
      if OwnWorkDir and TDirectory.Exists(WorkDir) then
        TDirectory.Delete(WorkDir, True);
    end;
  finally
    Mesh.Free;
  end;
end;

end.
