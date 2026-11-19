unit TriboContact.FemMesh;

interface

uses
  System.SysUtils, System.Classes, System.Math,
  TriboContact.Models;

type
  TMeshNode = record
    Id: Integer;
    R: Double;
    Y: Double;
  end;

  TMeshQuad = record
    Id: Integer;
    N1, N2, N3, N4: Integer;
    RegionId: Integer;
    MaterialIdx: Integer;
    IsBall: Boolean;
    IsContactZone: Boolean;
  end;

  TFemMesh = class
  public
    Nodes: TArray<TMeshNode>;
    Quads: TArray<TMeshQuad>;
    AxisNodes: TArray<Integer>;
    SpecBottomNodes: TArray<Integer>;
    SpecRimNodes: TArray<Integer>;
    BallTopNodes: TArray<Integer>;
    SpecTopNodes: TArray<Integer>;
    BallArcNodes: TArray<Integer>;
    SpecCenterTopNode: Integer;
    LayerElSets: TArray<TArray<Integer>>;
    SubstrateElSet: TArray<Integer>;
    BallElSet: TArray<Integer>;
    SpecTopQuads: TArray<Integer>;
    BallBotQuads: TArray<Integer>;
    SpecRCoords: TDoubleArray;
    SpecZCoords: TDoubleArray;
    SpecNodeGrid: array of TArray<Integer>;
    LayerStartRow: TArray<Integer>;
    LayerEndRow: TArray<Integer>;
    SubStartRow: Integer;
    SubEndRow: Integer;
    BallRCoords: TDoubleArray;
    RDomUm: Double;
    HSubUm: Double;
    RFineUm: Double;
    DrMinUm: Double;
    EstRadiusUm: Double;
    EstDepthUm: Double;
    NrAcrossA: Integer;
    NzTopFilm: Integer;
    MaxContactZoneAspectRatio: Double;
    MinJacobian: Double;
    SpecNodeCount: Integer;
    RigidBall: Boolean;
  end;

function GenerateFemMesh(const ACase: TContactCase; AEstRadiusUm, AEstDepthUm,
  AMaxYieldRatio: Double): TFemMesh;
function ValidateFemMesh(AMesh: TFemMesh; const ACase: TContactCase;
  out AReport: string): Boolean;

implementation

uses
  System.Generics.Collections;

function BuildGraded1D(AStart, AEnd, AFirstStep, ARatioMax: Double; AMinSegs: Integer;
  AMaxStep: Double = 1e30): TDoubleArray;
var
  List: TList<Double>;
  Pos, Step, Remaining: Double;
  NUniform, I: Integer;
begin
  List := TList<Double>.Create;
  try
    List.Add(AStart);
    if AEnd <= AStart then
    begin
      Result := List.ToArray;
      Exit;
    end;
    Pos := AStart;
    Step := Min(AMaxStep, Min(AFirstStep, (AEnd - AStart) / Max(1, AMinSegs)));
    while Pos + Step < AEnd - 1e-12 do
    begin
      Remaining := AEnd - Pos;
      if Remaining <= 2.2 * Step then
      begin
        NUniform := Max(2, Round(Remaining / Step));
        for I := 1 to NUniform - 1 do
          List.Add(Pos + Remaining * (I / NUniform));
        Break;
      end;
      Pos := Pos + Step;
      List.Add(Pos);
      Step := Min(AMaxStep, Min(Step * ARatioMax, Remaining * 0.45));
    end;
    List.Add(AEnd);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function BuildLayerZCoords(AZStart, AThickness, ADrFine: Double; AMinSegs: Integer): TDoubleArray;
var
  Pts, HalfPts: TDoubleArray;
  I, K, Segs: Integer;
  HalfH: Double;
begin
  Segs := Max(2, AMinSegs);
  if AThickness <= Segs * 2.0 * ADrFine then
  begin
    SetLength(Result, Segs);
    for I := 1 to Segs do
      Result[I - 1] := AZStart + AThickness * (I / Segs);
    Exit;
  end;

  HalfH := 0.5 * AThickness;
  HalfPts := BuildGraded1D(0.0, HalfH, Min(ADrFine, HalfH * 0.5), 1.25, Max(2, Segs div 2), 6.0 * ADrFine);
  SetLength(Pts, 2 * High(HalfPts));
  K := 0;
  for I := 1 to High(HalfPts) do
  begin
    Pts[K] := AZStart + HalfPts[I];
    Inc(K);
  end;
  for I := High(HalfPts) - 1 downto 1 do
  begin
    Pts[K] := AZStart + AThickness - HalfPts[I];
    Inc(K);
  end;
  Pts[K] := AZStart + AThickness;
  Result := Pts;
end;

function QuadCornerJacobian(const N1, N2, N3, N4: TMeshNode; AXi, AEta: Double): Double;
var
  DxdXi, DxdEta, DydXi, DydEta: Double;
begin
  DxdXi := 0.25 * (-(1 - AEta) * N1.R + (1 - AEta) * N2.R + (1 + AEta) * N3.R - (1 + AEta) * N4.R);
  DxdEta := 0.25 * (-(1 - AXi) * N1.R - (1 + AXi) * N2.R + (1 + AXi) * N3.R + (1 - AXi) * N4.R);
  DydXi := 0.25 * (-(1 - AEta) * N1.Y + (1 - AEta) * N2.Y + (1 + AEta) * N3.Y - (1 + AEta) * N4.Y);
  DydEta := 0.25 * (-(1 - AXi) * N1.Y - (1 + AXi) * N2.Y + (1 + AXi) * N3.Y + (1 - AXi) * N4.Y);
  Result := DxdXi * DydEta - DxdEta * DydXi;
end;

function GenerateFemMesh(const ACase: TContactCase; AEstRadiusUm, AEstDepthUm,
  AMaxYieldRatio: Double): TFemMesh;
var
  N, K, Ir, Iz, NrFine, NrSpec, NzSub, NzTotal, NrBall, NzBall: Integer;
  AEff, HTotal, RDom, HSub, RFine, DrFine, DrMin, MinLayerDz, DzK, DzSub0: Double;
  NrAcrossA, NzTopMin, NzK, FineCap: Integer;
  SpecROuter, SpecZSub: TDoubleArray;
  ZList: TList<Double>;
  LayerCounts: TArray<Integer>;
  NodeList: TList<TMeshNode>;
  QuadList: TList<TMeshQuad>;
  AxisList, BotList, RimList, BallTopList, SpecTopList, BallArcList: TList<Integer>;
  SubEls, BallEls, SpecTopQ, BallBotQ: TList<Integer>;
  LayerElLists: TArray<TList<Integer>>;
  Node: TMeshNode;
  Quad: TMeshQuad;
  ZCurr, Wb, YArcWb, YTop, DrBall, YArc, HCol: Double;
  BallROuter, LayerZs, BallYAxis: TDoubleArray;
  BallNodeGrid: array of TArray<Integer>;
  HasPlastic: Boolean;
  I, J, NodeId, QuadId: Integer;
  RBallFineLim, TParam: Double;
  N1, N2, N3, N4: TMeshNode;
  Width, Height, Asp, Jac: Double;
  Cors: array[0..4, 0..1] of Double;
begin
  ACase.Validate;
  N := Length(ACase.Layers);
  HTotal := ACase.TotalCoatingThicknessUm;

  HasPlastic := ACase.Substrate.HasSigmaY;
  for K := 0 to N - 1 do
    if ACase.Layers[K].Material.HasSigmaY then
      HasPlastic := True;

  if AMaxYieldRatio > 1.0 then
    AEff := AEstRadiusUm * Max(1.0, 0.58 * Sqrt(AMaxYieldRatio))
  else
    AEff := AEstRadiusUm;

  RDom := Max(60.0 * AEff, 25.0 * HTotal);
  HSub := Max(60.0 * AEff, 25.0 * HTotal);
  RFine := Max(2.0 * AEff, 3.0 * HTotal);
  if HasPlastic then
    RFine := Max(RFine, 2.8 * AEff);
  RFine := Min(RFine, 0.45 * RDom);

  case ACase.Solver.MeshDensity of
    mdCoarse:
      begin
        NrAcrossA := 16;
        NzTopMin := 3;
      end;
    mdStandard:
      begin
        NrAcrossA := 26;
        NzTopMin := 5;
      end;
    mdFine:
      begin
        NrAcrossA := 38;
        NzTopMin := 6;
      end;
  else
    NrAcrossA := 26;
    NzTopMin := 4;
  end;

  DrFine := AEff / NrAcrossA;
  SetLength(LayerCounts, N);
  MinLayerDz := Infinity;
  for K := 0 to N - 1 do
  begin
    if K = 0 then
      NzK := NzTopMin
    else
      NzK := Max(2, NzTopMin - 1);
    if ACase.Layers[K].ThicknessUm > NzK * 2.0 * DrFine then
      DzK := Min(DrFine, ACase.Layers[K].ThicknessUm / NzK)
    else
      DzK := ACase.Layers[K].ThicknessUm / NzK;
    LayerCounts[K] := NzK;
    if DzK < MinLayerDz then
      MinLayerDz := DzK;
  end;

  if (N > 0) and (DrFine > 7.5 * MinLayerDz) then
  begin
    FineCap := 320;
    NrFine := Ceil(RFine / (7.5 * MinLayerDz));
    if NrFine > FineCap then
      NrFine := FineCap;
    DrFine := RFine / NrFine;
  end
  else
  begin
    NrFine := Ceil(RFine / DrFine);
    if NrFine < NrAcrossA then
      NrFine := NrAcrossA;
    DrFine := RFine / NrFine;
  end;

  DrMin := DrFine;
  SpecROuter := BuildGraded1D(RFine, RDom, DrFine, 1.24, 6);
  NrSpec := NrFine + Length(SpecROuter) - 1;

  Result := TFemMesh.Create;
  NodeList := TList<TMeshNode>.Create;
  QuadList := TList<TMeshQuad>.Create;
  AxisList := TList<Integer>.Create;
  BotList := TList<Integer>.Create;
  RimList := TList<Integer>.Create;
  BallTopList := TList<Integer>.Create;
  SpecTopList := TList<Integer>.Create;
  BallArcList := TList<Integer>.Create;
  SubEls := TList<Integer>.Create;
  BallEls := TList<Integer>.Create;
  SpecTopQ := TList<Integer>.Create;
  BallBotQ := TList<Integer>.Create;
  ZList := TList<Double>.Create;
  SetLength(LayerElLists, N);
  for K := 0 to N - 1 do
    LayerElLists[K] := TList<Integer>.Create;

  try
    SetLength(Result.SpecRCoords, NrSpec + 1);
    for Ir := 0 to NrFine do
      Result.SpecRCoords[Ir] := RFine * (Ir / NrFine);
    for Ir := 1 to High(SpecROuter) do
      Result.SpecRCoords[NrFine + Ir] := SpecROuter[Ir];

    SetLength(Result.LayerStartRow, N);
    SetLength(Result.LayerEndRow, N);
    ZCurr := 0.0;
    ZList.Add(0.0);
    for K := 0 to N - 1 do
    begin
      Result.LayerStartRow[K] := ZList.Count - 1;
      LayerZs := BuildLayerZCoords(ZCurr, ACase.Layers[K].ThicknessUm, DrFine, LayerCounts[K]);
      LayerCounts[K] := Length(LayerZs);
      for Iz := 0 to High(LayerZs) do
        ZList.Add(LayerZs[Iz]);
      ZCurr := ZCurr + ACase.Layers[K].ThicknessUm;
      Result.LayerEndRow[K] := ZList.Count - 1;
    end;

    Result.SubStartRow := ZList.Count - 1;
    if N > 0 then
      DzSub0 := Min(DrFine, Max(ZList[ZList.Count - 1] - ZList[ZList.Count - 2], 0.35 * DrFine))
    else
      DzSub0 := DrFine;
    if ZCurr < 1.5 * RFine then
    begin
      SpecZSub := BuildGraded1D(ZCurr, 1.5 * RFine, DzSub0, 1.18, 4, 6.0 * DrFine);
      for Iz := 1 to High(SpecZSub) do
        ZList.Add(SpecZSub[Iz]);
      DzSub0 := Min(6.0 * DrFine, SpecZSub[High(SpecZSub)] - SpecZSub[High(SpecZSub) - 1]);
      ZCurr := 1.5 * RFine;
    end;
    SpecZSub := BuildGraded1D(ZCurr, HTotal + HSub, DzSub0, 1.24, 10);
    for Iz := 1 to High(SpecZSub) do
      ZList.Add(SpecZSub[Iz]);
    Result.SubEndRow := ZList.Count - 1;
    NzSub := Result.SubEndRow - Result.SubStartRow;
    NzTotal := ZList.Count - 1;

    Result.SpecZCoords := ZList.ToArray;
    SetLength(Result.SpecNodeGrid, NzTotal + 1);
    for Iz := 0 to NzTotal do
    begin
      SetLength(Result.SpecNodeGrid[Iz], NrSpec + 1);
      for Ir := 0 to NrSpec do
      begin
        NodeId := NodeList.Count + 1;
        Node.Id := NodeId;
        Node.R := Result.SpecRCoords[Ir];
        Node.Y := -Result.SpecZCoords[Iz];
        NodeList.Add(Node);
        Result.SpecNodeGrid[Iz, Ir] := NodeId;

        if Ir = 0 then
          AxisList.Add(NodeId);
        if Ir = NrSpec then
          RimList.Add(NodeId);
        if Iz = 0 then
          SpecTopList.Add(NodeId);
        if Iz = NzTotal then
          BotList.Add(NodeId);
      end;
    end;
    Result.SpecCenterTopNode := Result.SpecNodeGrid[0, 0];
    Result.SpecNodeCount := NodeList.Count;

    for K := 0 to N - 1 do
    begin
      for Iz := Result.LayerStartRow[K] to Result.LayerEndRow[K] - 1 do
        for Ir := 0 to NrSpec - 1 do
        begin
          QuadId := QuadList.Count + 1;
          Quad.Id := QuadId;
          Quad.N1 := Result.SpecNodeGrid[Iz + 1, Ir];
          Quad.N2 := Result.SpecNodeGrid[Iz + 1, Ir + 1];
          Quad.N3 := Result.SpecNodeGrid[Iz, Ir + 1];
          Quad.N4 := Result.SpecNodeGrid[Iz, Ir];
          Quad.RegionId := K;
          Quad.MaterialIdx := K;
          Quad.IsBall := False;
          Quad.IsContactZone := (Ir < NrFine) and (Result.SpecZCoords[Iz + 1] <= RFine * 1.5);
          QuadList.Add(Quad);
          LayerElLists[K].Add(QuadId);
          if (K = 0) and (Iz = 0) then
            SpecTopQ.Add(QuadId);
        end;
    end;

    for Iz := Result.SubStartRow to Result.SubEndRow - 1 do
      for Ir := 0 to NrSpec - 1 do
      begin
        QuadId := QuadList.Count + 1;
        Quad.Id := QuadId;
        Quad.N1 := Result.SpecNodeGrid[Iz + 1, Ir];
        Quad.N2 := Result.SpecNodeGrid[Iz + 1, Ir + 1];
        Quad.N3 := Result.SpecNodeGrid[Iz, Ir + 1];
        Quad.N4 := Result.SpecNodeGrid[Iz, Ir];
        Quad.RegionId := N;
        Quad.MaterialIdx := N;
        Quad.IsBall := False;
        Quad.IsContactZone := (Ir < NrFine) and (Result.SpecZCoords[Iz + 1] <= RFine * 1.5);
        QuadList.Add(Quad);
        SubEls.Add(QuadId);
        if (N = 0) and (Iz = 0) then
          SpecTopQ.Add(QuadId);
      end;

    Result.RigidBall := ACase.Ball.Rigid;
    if ACase.Ball.Rigid then
      DrBall := 0.75 * DrFine
    else
      DrBall := 1.0 * DrFine;
    if ACase.Ball.Rigid then
      Wb := Min(0.90 * ACase.Ball.RadiusUm, Max(3.0 * RFine, 4.0 * AEff))
    else
      Wb := Min(0.92 * ACase.Ball.RadiusUm, Max(60.0 * AEff, 2.5 * RFine));

    RBallFineLim := Min(0.85 * Wb, RFine);
    NrBall := Ceil(RBallFineLim / DrBall);
    if NrBall < 10 then
      NrBall := 10;
    DrBall := RBallFineLim / NrBall;
    BallROuter := BuildGraded1D(RBallFineLim, Wb, DrBall, 1.24, 4);
    SetLength(Result.BallRCoords, NrBall + Length(BallROuter));
    for Ir := 0 to NrBall do
      Result.BallRCoords[Ir] := RBallFineLim * (Ir / NrBall);
    for Ir := 1 to High(BallROuter) do
      Result.BallRCoords[NrBall + Ir] := BallROuter[Ir];
    NrBall := High(Result.BallRCoords);

    YArcWb := ACase.Ball.RadiusUm - Sqrt(Max(0.0, Sqr(ACase.Ball.RadiusUm) - Sqr(Wb)));
    if ACase.Ball.Rigid then
    begin
      YTop := YArcWb + 2.0 * DrBall;
      NzBall := 2;
      SetLength(BallYAxis, NzBall + 1);
      for Iz := 0 to NzBall do
        BallYAxis[Iz] := YTop * (Iz / NzBall);
    end
    else
    begin
      YTop := Max(YArcWb + 0.25 * Wb, Min(ACase.Ball.RadiusUm, 60.0 * AEff));
      BallYAxis := BuildGraded1D(0.0, YTop, DrBall, 1.24, 14);
      NzBall := High(BallYAxis);
    end;

    SetLength(BallNodeGrid, NzBall + 1, NrBall + 1);
    for Ir := 0 to NrBall do
    begin
      YArc := ACase.Ball.RadiusUm - Sqrt(Max(0.0, Sqr(ACase.Ball.RadiusUm) - Sqr(Result.BallRCoords[Ir])));
      HCol := YTop - YArc;
      for Iz := 0 to NzBall do
      begin
        TParam := BallYAxis[Iz] / YTop;
        NodeId := NodeList.Count + 1;
        Node.Id := NodeId;
        Node.R := Result.BallRCoords[Ir];
        Node.Y := YArc + HCol * TParam;
        NodeList.Add(Node);
        BallNodeGrid[Iz, Ir] := NodeId;
        if Ir = 0 then AxisList.Add(NodeId);
        if Iz = 0 then BallArcList.Add(NodeId);
        if Iz = NzBall then BallTopList.Add(NodeId);
      end;
    end;

    for Iz := 0 to NzBall - 1 do
      for Ir := 0 to NrBall - 1 do
      begin
        QuadId := QuadList.Count + 1;
        Quad.Id := QuadId;
        Quad.N1 := BallNodeGrid[Iz, Ir];
        Quad.N2 := BallNodeGrid[Iz, Ir + 1];
        Quad.N3 := BallNodeGrid[Iz + 1, Ir + 1];
        Quad.N4 := BallNodeGrid[Iz + 1, Ir];
        Quad.RegionId := N + 1;
        Quad.MaterialIdx := -1;
        Quad.IsBall := True;
        Quad.IsContactZone := (Result.BallRCoords[Ir + 1] <= RFine) and (Iz < 4);
        QuadList.Add(Quad);
        BallEls.Add(QuadId);
        if Iz = 0 then
          BallBotQ.Add(QuadId);
      end;

    Result.Nodes := NodeList.ToArray;
    Result.Quads := QuadList.ToArray;
    Result.AxisNodes := AxisList.ToArray;
    Result.SpecBottomNodes := BotList.ToArray;
    Result.SpecRimNodes := RimList.ToArray;
    Result.BallTopNodes := BallTopList.ToArray;
    Result.SpecTopNodes := SpecTopList.ToArray;
    Result.BallArcNodes := BallArcList.ToArray;
    SetLength(Result.LayerElSets, N);
    for K := 0 to N - 1 do
      Result.LayerElSets[K] := LayerElLists[K].ToArray;
    Result.SubstrateElSet := SubEls.ToArray;
    Result.BallElSet := BallEls.ToArray;
    Result.SpecTopQuads := SpecTopQ.ToArray;
    Result.BallBotQuads := BallBotQ.ToArray;

    Result.RDomUm := RDom;
    Result.HSubUm := HSub;
    Result.RFineUm := RFine;
    Result.DrMinUm := DrMin;
    Result.EstRadiusUm := AEff;
    Result.EstDepthUm := AEstDepthUm;
    Result.NrAcrossA := NrAcrossA;
    if N > 0 then
      Result.NzTopFilm := LayerCounts[0]
    else
      Result.NzTopFilm := NzSub;

    Result.MaxContactZoneAspectRatio := 0.0;
    Result.MinJacobian := Infinity;
    Cors[0, 0] := -1; Cors[0, 1] := -1;
    Cors[1, 0] :=  1; Cors[1, 1] := -1;
    Cors[2, 0] :=  1; Cors[2, 1] :=  1;
    Cors[3, 0] := -1; Cors[3, 1] :=  1;
    Cors[4, 0] :=  0; Cors[4, 1] :=  0;

    for I := 0 to High(Result.Quads) do
    begin
      Quad := Result.Quads[I];
      N1 := Result.Nodes[Quad.N1 - 1];
      N2 := Result.Nodes[Quad.N2 - 1];
      N3 := Result.Nodes[Quad.N3 - 1];
      N4 := Result.Nodes[Quad.N4 - 1];
      for J := 0 to 4 do
      begin
        Jac := QuadCornerJacobian(N1, N2, N3, N4, Cors[J, 0], Cors[J, 1]);
        if Jac < Result.MinJacobian then
          Result.MinJacobian := Jac;
      end;
      if Quad.IsContactZone and (not Quad.IsBall) then
      begin
        Width := Abs(N2.R - N1.R);
        Height := Abs(N4.Y - N1.Y);
        Asp := Max(Width / Max(1e-12, Height), Height / Max(1e-12, Width));
        if Asp > Result.MaxContactZoneAspectRatio then
          Result.MaxContactZoneAspectRatio := Asp;
      end;
    end;
  finally
    for K := 0 to N - 1 do
      LayerElLists[K].Free;
    ZList.Free;
    BallBotQ.Free;
    SpecTopQ.Free;
    BallEls.Free;
    SubEls.Free;
    BallArcList.Free;
    SpecTopList.Free;
    BallTopList.Free;
    RimList.Free;
    BotList.Free;
    AxisList.Free;
    QuadList.Free;
    NodeList.Free;
  end;
end;

function ValidateFemMesh(AMesh: TFemMesh; const ACase: TContactCase;
  out AReport: string): Boolean;
var
  I, J, K, NId, NrSpec, NzTotal, ExpectedNr, ExpectedNz: Integer;
  Area2, Jac: Double;
  Quad: TMeshQuad;
  N1, N2, N3, N4: TMeshNode;
  Cors: array[0..4, 0..1] of Double;
  NodeCount: Integer;
  NodeBuckets: TDictionary<Int64, TList<Integer>>;
  Key: Int64;
  Bucket: TList<Integer>;
  Idx: Integer;
  Tol: Double;
  Pair: TPair<Int64, TList<Integer>>;
begin
  Result := True;
  AReport := '';
  if AMesh = nil then
  begin
    AReport := 'Mesh is nil';
    Exit(False);
  end;

  NodeCount := Length(AMesh.Nodes);
  if (NodeCount = 0) or (Length(AMesh.Quads) = 0) then
  begin
    AReport := 'Empty mesh';
    Exit(False);
  end;

  for NId in AMesh.AxisNodes do
  begin
    if Abs(AMesh.Nodes[NId - 1].R) > 1e-12 then
    begin
      AReport := Format('Axis node %d has R=%g != 0', [NId, AMesh.Nodes[NId - 1].R]);
      Exit(False);
    end;
  end;

  Cors[0, 0] := -1; Cors[0, 1] := -1;
  Cors[1, 0] :=  1; Cors[1, 1] := -1;
  Cors[2, 0] :=  1; Cors[2, 1] :=  1;
  Cors[3, 0] := -1; Cors[3, 1] :=  1;
  Cors[4, 0] :=  0; Cors[4, 1] :=  0;

  for I := 0 to High(AMesh.Quads) do
  begin
    Quad := AMesh.Quads[I];
    N1 := AMesh.Nodes[Quad.N1 - 1];
    N2 := AMesh.Nodes[Quad.N2 - 1];
    N3 := AMesh.Nodes[Quad.N3 - 1];
    N4 := AMesh.Nodes[Quad.N4 - 1];
    Area2 := (N2.R - N1.R) * (N3.Y - N1.Y) - (N2.Y - N1.Y) * (N3.R - N1.R) +
             (N3.R - N1.R) * (N4.Y - N1.Y) - (N3.Y - N1.Y) * (N4.R - N1.R);
    if Area2 <= 0.0 then
    begin
      AReport := Format('Quad %d is not CCW (Area2=%g)', [Quad.Id, Area2]);
      Exit(False);
    end;
    for J := 0 to 4 do
    begin
      Jac := QuadCornerJacobian(N1, N2, N3, N4, Cors[J, 0], Cors[J, 1]);
      if Jac <= 0.0 then
      begin
        AReport := Format('Quad %d has non-positive Jacobian %g', [Quad.Id, Jac]);
        Exit(False);
      end;
    end;
  end;

  Tol := 1e-7 * Max(1e-6, AMesh.DrMinUm);
  for var Body := 0 to 1 do
  begin
    var StartIdx, EndIdx: Integer;
    if Body = 0 then
    begin
      StartIdx := 0;
      EndIdx := AMesh.SpecNodeCount - 1;
    end
    else
    begin
      StartIdx := AMesh.SpecNodeCount;
      EndIdx := NodeCount - 1;
    end;
    NodeBuckets := TDictionary<Int64, TList<Integer>>.Create;
    try
      for I := StartIdx to EndIdx do
      begin
        Key := Round(AMesh.Nodes[I].R / Max(1e-9, Tol)) * 73856093 xor
               Round(AMesh.Nodes[I].Y / Max(1e-9, Tol)) * 19349663;
        if not NodeBuckets.TryGetValue(Key, Bucket) then
        begin
          Bucket := TList<Integer>.Create;
          NodeBuckets.Add(Key, Bucket);
        end;
        for Idx in Bucket do
        begin
          if (Abs(AMesh.Nodes[I].R - AMesh.Nodes[Idx].R) < Tol) and
             (Abs(AMesh.Nodes[I].Y - AMesh.Nodes[Idx].Y) < Tol) then
          begin
            AReport := Format('Duplicate/coincident nodes %d and %d in body %d at (%g, %g)',
              [AMesh.Nodes[Idx].Id, AMesh.Nodes[I].Id, Body, AMesh.Nodes[I].R, AMesh.Nodes[I].Y]);
            Exit(False);
          end;
        end;
        Bucket.Add(I);
      end;
    finally
      for Pair in NodeBuckets do
        Pair.Value.Free;
      NodeBuckets.Free;
    end;
  end;

  NrSpec := Length(AMesh.SpecRCoords) - 1;
  NzTotal := Length(AMesh.SpecZCoords) - 1;
  for K := 0 to High(ACase.Layers) - 1 do
  begin
    if AMesh.LayerEndRow[K] <> AMesh.LayerStartRow[K + 1] then
    begin
      AReport := 'Interface row mismatch between coating layers';
      Exit(False);
    end;
  end;
  if (Length(ACase.Layers) > 0) and
     (AMesh.LayerEndRow[High(ACase.Layers)] <> AMesh.SubStartRow) then
  begin
    AReport := 'Interface row mismatch between coating and substrate';
    Exit(False);
  end;
  if (Length(AMesh.SpecNodeGrid) <> NzTotal + 1) or
     (Length(AMesh.SpecNodeGrid[0]) <> NrSpec + 1) then
  begin
    AReport := 'SpecNodeGrid dimensions invalid';
    Exit(False);
  end;

  case ACase.Solver.MeshDensity of
    mdCoarse: begin ExpectedNr := 15; ExpectedNz := 3; end;
    mdStandard: begin ExpectedNr := 24; ExpectedNz := 4; end;
    mdFine: begin ExpectedNr := 36; ExpectedNz := 6; end;
  else
    ExpectedNr := 24; ExpectedNz := 4;
  end;
  if AMesh.NrAcrossA < ExpectedNr then
  begin
    AReport := Format('NrAcrossA=%d < %d', [AMesh.NrAcrossA, ExpectedNr]);
    Exit(False);
  end;
  if (Length(ACase.Layers) > 0) and (AMesh.NzTopFilm < ExpectedNz) then
  begin
    AReport := Format('NzTopFilm=%d < %d', [AMesh.NzTopFilm, ExpectedNz]);
    Exit(False);
  end;
  if AMesh.MaxContactZoneAspectRatio > 10.0 then
  begin
    AReport := Format('Contact-zone aspect ratio %g > 10.0', [AMesh.MaxContactZoneAspectRatio]);
    Exit(False);
  end;

  AReport := Format('Valid mesh: %d nodes, %d quads, maxAspect=%.2f, minJac=%.4g',
    [NodeCount, Length(AMesh.Quads), AMesh.MaxContactZoneAspectRatio, AMesh.MinJacobian],
    TFormatSettings.Invariant);
end;

end.
