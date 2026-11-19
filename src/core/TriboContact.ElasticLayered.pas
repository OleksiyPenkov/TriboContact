unit TriboContact.ElasticLayered;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics,
  TriboContact.Models, TriboContact.Hertz, TriboContact.SpecialMath;

type
  TMat2x2 = array[0..1, 0..1] of Double;

  TSMMLayerData = record
    EGpa: Double;
    Nu: Double;
    Mu: Double;
    Kappa: Double;
    ThicknessUm: Double;
    ZTopUm: Double;
    ZBotUm: Double;
    K11, K12, K21, K22: TMat2x2;
    Tk: TMat2x2;
    Ksh11, Ksh12, Ksh21, Ksh22: Double;
    Tsh: Double;
  end;

  TSMMSystem = record
    Layers: TArray<TSMMLayerData>;
    SubEGpa: Double;
    SubNu: Double;
    SubMu: Double;
    SubKappa: Double;
    BallEGpa: Double;
    BallNu: Double;
    BallRigid: Boolean;
    HasContrast: Boolean;
    MinThicknessUm: Double;
  end;

procedure InitSMMSystem(const ACase: TContactCase; out ASys: TSMMSystem);
function EvaluateCoatedCompliance(var ASys: TSMMSystem; AXi: Double;
  out AGCoated: TMat2x2): Double;
function EvaluateTotalCompliance(var ASys: TSMMSystem; AXi: Double): Double;
function SolveElasticLayered(const ACase: TContactCase): TContactResult;

implementation

function Mat2Mul(const A, B: TMat2x2): TMat2x2; inline;
begin
  Result[0, 0] := A[0, 0] * B[0, 0] + A[0, 1] * B[1, 0];
  Result[0, 1] := A[0, 0] * B[0, 1] + A[0, 1] * B[1, 1];
  Result[1, 0] := A[1, 0] * B[0, 0] + A[1, 1] * B[1, 0];
  Result[1, 1] := A[1, 0] * B[0, 1] + A[1, 1] * B[1, 1];
end;

function Mat2Inv(const A: TMat2x2): TMat2x2; inline;
var
  Det, InvDet: Double;
begin
  Det := A[0, 0] * A[1, 1] - A[0, 1] * A[1, 0];
  InvDet := 1.0 / Det;
  Result[0, 0] := A[1, 1] * InvDet;
  Result[0, 1] := -A[0, 1] * InvDet;
  Result[1, 0] := -A[1, 0] * InvDet;
  Result[1, 1] := A[0, 0] * InvDet;
end;

function Mat2Neg(const A: TMat2x2): TMat2x2; inline;
begin
  Result[0, 0] := -A[0, 0];
  Result[0, 1] := -A[0, 1];
  Result[1, 0] := -A[1, 0];
  Result[1, 1] := -A[1, 1];
end;

function Mat2Add(const A, B: TMat2x2): TMat2x2; inline;
begin
  Result[0, 0] := A[0, 0] + B[0, 0];
  Result[0, 1] := A[0, 1] + B[0, 1];
  Result[1, 0] := A[1, 0] + B[1, 0];
  Result[1, 1] := A[1, 1] + B[1, 1];
end;

function Mat2Transpose(const A: TMat2x2): TMat2x2; inline;
begin
  Result[0, 0] := A[0, 0];
  Result[0, 1] := A[1, 0];
  Result[1, 0] := A[0, 1];
  Result[1, 1] := A[1, 1];
end;

procedure Mat2VecMul(const A: TMat2x2; V0, V1: Double; out R0, R1: Double); inline;
begin
  R0 := A[0, 0] * V0 + A[0, 1] * V1;
  R1 := A[1, 0] * V0 + A[1, 1] * V1;
end;

procedure BuildLayerStiffness(var ALayer: TSMMLayerData; AXi: Double;
  out AD1, AD2, AEExp, AOneMinusE: Double);
var
  Eta, E, OneMinusE, OneMinusE2, D1, D2, N12, M12: Double;
  Scale1, Scale2, Mu, Nu, Kappa, OneMinusNu: Double;
  K1_11, K1_12, K1_22, K2_11, K2_12, K2_22: Double;
begin
  Mu := ALayer.Mu;
  Nu := ALayer.Nu;
  Kappa := ALayer.Kappa;
  OneMinusNu := 1.0 - Nu;
  Eta := AXi * ALayer.ThicknessUm;
  E := Exp(-Eta);
  OneMinusE := OneMinusExpNeg(Eta);
  OneMinusE2 := OneMinusExpNeg(2.0 * Eta);

  if Eta < 1e-3 then
  begin
    // Taylor form prevents catastrophic subtraction between kappa*(1-E^2) and 2*eta*E.
    D1 := 2.0 * Eta * ((Kappa - 1.0) * (1.0 - Eta) +
      ((2.0 / 3.0) * Kappa - 0.5) * Eta * Eta -
      ((1.0 / 3.0) * Kappa - 1.0 / 6.0) * Eta * Eta * Eta +
      ((2.0 / 15.0) * Kappa - 1.0 / 24.0) * Sqr(Eta * Eta));
    N12 := 2.0 * Eta * (-2.0 * Nu * (1.0 - Eta) +
      ((2.0 / 3.0) * (1.0 - 2.0 * Nu) - 0.5) * Eta * Eta -
      ((1.0 / 3.0) * (1.0 - 2.0 * Nu) - 1.0 / 6.0) * Eta * Eta * Eta +
      ((2.0 / 15.0) * (1.0 - 2.0 * Nu) - 1.0 / 24.0) * Sqr(Eta * Eta));
  end
  else
  begin
    D1 := Kappa * OneMinusE2 - 2.0 * Eta * E;
    N12 := (1.0 - 2.0 * Nu) * OneMinusE2 - 2.0 * Eta * E;
  end;

  D2 := Kappa * OneMinusE2 + 2.0 * Eta * E;
  M12 := (1.0 - 2.0 * Nu) * OneMinusE2 + 2.0 * Eta * E;

  Scale1 := 2.0 * Mu * AXi / D1;
  K1_11 := Scale1 * 2.0 * OneMinusNu * Sqr(OneMinusE);
  K1_12 := Scale1 * N12;
  K1_22 := Scale1 * 2.0 * OneMinusNu * Sqr(1.0 + E);

  Scale2 := 2.0 * Mu * AXi / D2;
  K2_11 := Scale2 * 2.0 * OneMinusNu * Sqr(1.0 + E);
  K2_12 := Scale2 * M12;
  K2_22 := Scale2 * 2.0 * OneMinusNu * Sqr(OneMinusE);

  ALayer.K11[0, 0] := 0.5 * (K1_11 + K2_11);
  ALayer.K11[0, 1] := 0.5 * (K1_12 + K2_12);
  ALayer.K11[1, 0] := ALayer.K11[0, 1];
  ALayer.K11[1, 1] := 0.5 * (K1_22 + K2_22);

  ALayer.K12[0, 0] := 0.5 * (K1_11 - K2_11);
  ALayer.K12[0, 1] := 0.5 * (-K1_12 + K2_12);
  ALayer.K12[1, 0] := 0.5 * (K1_12 - K2_12);
  ALayer.K12[1, 1] := 0.5 * (-K1_22 + K2_22);

  ALayer.K21 := Mat2Transpose(ALayer.K12);

  ALayer.K22[0, 0] := ALayer.K11[0, 0];
  ALayer.K22[0, 1] := -ALayer.K11[0, 1];
  ALayer.K22[1, 0] := -ALayer.K11[1, 0];
  ALayer.K22[1, 1] := ALayer.K11[1, 1];

  AD1 := D1;
  AD2 := D2;
  AEExp := E;
  AOneMinusE := OneMinusE;
end;

procedure InitSMMSystem(const ACase: TContactCase; out ASys: TSMMSystem);
var
  I, N: Integer;
  ZCurr: Double;
begin
  ASys := Default(TSMMSystem);
  N := Length(ACase.Layers);
  SetLength(ASys.Layers, N);
  ZCurr := 0.0;
  ASys.MinThicknessUm := Infinity;
  for I := 0 to N - 1 do
  begin
    ASys.Layers[I].EGpa := ACase.Layers[I].Material.EGpa;
    ASys.Layers[I].Nu := ACase.Layers[I].Material.Nu;
    ASys.Layers[I].Mu := ASys.Layers[I].EGpa / (2.0 * (1.0 + ASys.Layers[I].Nu));
    ASys.Layers[I].Kappa := 3.0 - 4.0 * ASys.Layers[I].Nu;
    ASys.Layers[I].ThicknessUm := ACase.Layers[I].ThicknessUm;
    ASys.Layers[I].ZTopUm := ZCurr;
    ZCurr := ZCurr + ASys.Layers[I].ThicknessUm;
    ASys.Layers[I].ZBotUm := ZCurr;
    if ASys.Layers[I].ThicknessUm < ASys.MinThicknessUm then
      ASys.MinThicknessUm := ASys.Layers[I].ThicknessUm;
  end;
  ASys.SubEGpa := ACase.Substrate.EGpa;
  ASys.SubNu := ACase.Substrate.Nu;
  ASys.SubMu := ASys.SubEGpa / (2.0 * (1.0 + ASys.SubNu));
  ASys.SubKappa := 3.0 - 4.0 * ASys.SubNu;
  ASys.BallEGpa := ACase.Ball.Material.EGpa;
  ASys.BallNu := ACase.Ball.Material.Nu;
  ASys.BallRigid := ACase.Ball.Rigid;

  ASys.HasContrast := False;
  for I := 0 to N - 1 do
  begin
    if (Abs(ASys.Layers[I].EGpa - ASys.SubEGpa) > 1e-12 * ASys.SubEGpa) or
       (Abs(ASys.Layers[I].Nu - ASys.SubNu) > 1e-12) then
    begin
      ASys.HasContrast := True;
      Break;
    end;
  end;
end;

function EvaluateCoatedCompliance(var ASys: TSMMSystem; AXi: Double;
  out AGCoated: TMat2x2): Double;
var
  KBelow, InvSum: TMat2x2;
  Scale, D1, D2, EExp, OneMinusE: Double;
  K, N: Integer;
begin
  Scale := 2.0 * ASys.SubMu * AXi / ASys.SubKappa;
  KBelow[0, 0] := Scale * 2.0 * (1.0 - ASys.SubNu);
  KBelow[0, 1] := Scale * (1.0 - 2.0 * ASys.SubNu);
  KBelow[1, 0] := KBelow[0, 1];
  KBelow[1, 1] := KBelow[0, 0];

  N := Length(ASys.Layers);
  for K := N - 1 downto 0 do
  begin
    BuildLayerStiffness(ASys.Layers[K], AXi, D1, D2, EExp, OneMinusE);
    InvSum := Mat2Inv(Mat2Add(ASys.Layers[K].K22, KBelow));
    ASys.Layers[K].Tk := Mat2Neg(Mat2Mul(InvSum, ASys.Layers[K].K21));
    KBelow := Mat2Add(ASys.Layers[K].K11, Mat2Mul(ASys.Layers[K].K12, ASys.Layers[K].Tk));
  end;

  AGCoated := Mat2Inv(KBelow);
  Result := AGCoated[1, 1];
end;

function EvaluateTotalCompliance(var ASys: TSMMSystem; AXi: Double): Double;
var
  GCoated: TMat2x2;
begin
  Result := EvaluateCoatedCompliance(ASys, AXi, GCoated);
  if not ASys.BallRigid then
    Result := Result + 2.0 * (1.0 - Sqr(ASys.BallNu)) / (ASys.BallEGpa * AXi);
end;

function PhiDisk(AR, AR0: Double): Double;
var
  M: Double;
begin
  if AR0 <= 0.0 then
    Exit(0.0);
  if AR < AR0 then
  begin
    M := Sqr(AR / AR0);
    Result := (4.0 / Pi) * AR0 * EllipE(M);
  end
  else if AR = AR0 then
    Result := (4.0 / Pi) * AR0
  else
  begin
    M := Sqr(AR0 / AR);
    Result := (4.0 / Pi) * AR * EllipE_Minus_OneMinusMK(M);
  end;
end;

function FilonIntegral(AXa, AXb, AWa, AWb, AOmega: Double; IsCos: Boolean): Double;
var
  Slope, Len, SinA, SinB, CosA, CosB, W2: Double;
begin
  Len := AXb - AXa;
  if Abs(AOmega) < 1e-12 then
  begin
    if IsCos then
      Result := 0.5 * (AWa + AWb) * Len
    else
      Result := 0.5 * (AWa * AXa + AWb * AXb) * AOmega * Len;
    Exit;
  end;

  Slope := (AWb - AWa) / Len;
  W2 := AOmega * AOmega;
  SinA := Sin(AOmega * AXa);
  SinB := Sin(AOmega * AXb);
  CosA := Cos(AOmega * AXa);
  CosB := Cos(AOmega * AXb);

  if IsCos then
    Result := (AWb * SinB - AWa * SinA) / AOmega + Slope * (CosB - CosA) / W2
  else
    Result := -(AWb * CosB - AWa * CosA) / AOmega + Slope * (SinB - SinA) / W2;
end;

procedure BuildInfluenceMatrix(var ASys: TSMMSystem; const AREdge, ARBar: TDoubleArray;
  out AD: TDoubleMatrix);
var
  M, I, J, Q, NPanels, P, QTotal, NGL: Integer;
  TopE, TopNu, InvEStarTop, RMax, H1, XiMax, XiSplit, PanW, Xi0, Xi1, HalfW, Mid, Xi: Double;
  GLNodes, GLWeights: TDoubleArray;
  XiList, WDeltaC: TDoubleArray;
  GCoated: TMat2x2;
  Gzz, CTop, PrevJ1, CurrJ1, TailA, TailB: Double;
  J0Mat, DJ1Mat: TDoubleMatrix;
  Sum: Double;
  TailCount: Integer;
  TailXi, TailF: TDoubleArray;
  LogA, LogB, Xa, Xb, Wa, Wb, Factor: Double;
begin
  M := Length(ARBar);
  SetLength(AD, M, M);

  if Length(ASys.Layers) > 0 then
  begin
    TopE := ASys.Layers[0].EGpa;
    TopNu := ASys.Layers[0].Nu;
    H1 := ASys.Layers[0].ThicknessUm;
  end
  else
  begin
    TopE := ASys.SubEGpa;
    TopNu := ASys.SubNu;
    H1 := 1.0;
  end;

  InvEStarTop := (1.0 - Sqr(TopNu)) / TopE;
  if not ASys.BallRigid then
    InvEStarTop := InvEStarTop + (1.0 - Sqr(ASys.BallNu)) / ASys.BallEGpa;

  for I := 0 to M - 1 do
    for J := 0 to M - 1 do
      AD[I, J] := InvEStarTop * (PhiDisk(ARBar[I], AREdge[J + 1]) - PhiDisk(ARBar[I], AREdge[J]));

  if not ASys.HasContrast then
    Exit;

  RMax := AREdge[M];
  XiMax := Max(25.0 / H1, 30.0 / RMax);
  if ASys.MinThicknessUm < H1 then
    XiMax := Max(XiMax, 25.0 / ASys.MinThicknessUm);
  XiSplit := Min(XiMax, 1600.0 / RMax);

  NGL := 12;
  GaussLegendreRule(NGL, GLNodes, GLWeights);
  PanW := 2.0 * Pi / RMax;
  NPanels := Ceil(XiSplit / PanW);
  if NPanels < 8 then
    NPanels := 8;
  PanW := XiSplit / NPanels;
  QTotal := NPanels * NGL;

  SetLength(XiList, QTotal);
  SetLength(WDeltaC, QTotal);
  SetLength(J0Mat, QTotal, M);
  SetLength(DJ1Mat, QTotal, M);

  Q := 0;
  for P := 0 to NPanels - 1 do
  begin
    Xi0 := P * PanW;
    Xi1 := (P + 1) * PanW;
    HalfW := 0.5 * (Xi1 - Xi0);
    Mid := 0.5 * (Xi0 + Xi1);
    for I := 0 to NGL - 1 do
    begin
      Xi := Mid + HalfW * GLNodes[I];
      XiList[Q] := Xi;
      Gzz := EvaluateCoatedCompliance(ASys, Xi, GCoated);
      CTop := 2.0 * (1.0 - Sqr(TopNu)) / (TopE * Xi);
      WDeltaC[Q] := HalfW * GLWeights[I] * (Gzz - CTop);
      Inc(Q);
    end;
  end;

  for Q := 0 to QTotal - 1 do
  begin
    Xi := XiList[Q];
    for I := 0 to M - 1 do
      J0Mat[Q, I] := BesselJ0(Xi * ARBar[I]);
    PrevJ1 := 0.0;
    for J := 0 to M - 1 do
    begin
      CurrJ1 := AREdge[J + 1] * BesselJ1(Xi * AREdge[J + 1]);
      DJ1Mat[Q, J] := CurrJ1 - PrevJ1;
      PrevJ1 := CurrJ1;
    end;
  end;

  for I := 0 to M - 1 do
    for J := 0 to M - 1 do
    begin
      Sum := 0.0;
      for Q := 0 to QTotal - 1 do
        Sum := Sum + WDeltaC[Q] * J0Mat[Q, I] * DJ1Mat[Q, J];
      AD[I, J] := AD[I, J] + Sum;
    end;

  if XiMax > XiSplit * (1.0 + 1e-6) then
  begin
    TailCount := 72;
    SetLength(TailXi, TailCount + 1);
    SetLength(TailF, TailCount + 1);
    LogA := Ln(XiSplit);
    LogB := Ln(XiMax);
    for P := 0 to TailCount do
    begin
      Xi := Exp(LogA + (LogB - LogA) * (P / TailCount));
      TailXi[P] := Xi;
      Gzz := EvaluateCoatedCompliance(ASys, Xi, GCoated);
      CTop := 2.0 * (1.0 - Sqr(TopNu)) / (TopE * Xi);
      TailF[P] := (Gzz - CTop) / (Pi * Xi);
    end;

    for I := 0 to M - 1 do
      for J := 0 to M - 1 do
      begin
        Sum := 0.0;
        for P := 0 to TailCount - 1 do
        begin
          Xa := TailXi[P];
          Xb := TailXi[P + 1];
          Factor := Sqrt(AREdge[J + 1] / ARBar[I]);
          Wa := TailF[P] * Factor;
          Wb := TailF[P + 1] * Factor;
          TailB := FilonIntegral(Xa, Xb, Wa, Wb, AREdge[J + 1] - ARBar[I], False) -
            FilonIntegral(Xa, Xb, Wa, Wb, AREdge[J + 1] + ARBar[I], True);
          if J > 0 then
          begin
            Factor := Sqrt(AREdge[J] / ARBar[I]);
            Wa := TailF[P] * Factor;
            Wb := TailF[P + 1] * Factor;
            TailA := FilonIntegral(Xa, Xb, Wa, Wb, AREdge[J] - ARBar[I], False) -
              FilonIntegral(Xa, Xb, Wa, Wb, AREdge[J] + ARBar[I], True);
          end
          else
            TailA := 0.0;
          Sum := Sum + (TailB - TailA);
        end;
        AD[I, J] := AD[I, J] + Sum;
      end;
  end;
end;

procedure SolvePolonskyKeerCG(const AD: TDoubleMatrix; const AArea, ARBar, AHGap: TDoubleArray;
  ATargetLoadMn: Double; out AP: TDoubleArray; out ADelta, AForceErr: Double;
  out AIterations: Integer);
var
  M, I, J, Iter: Integer;
  AreaSum, WSum, GBar, GNormSq, GNormSqOld, Beta, Alpha, Denom, TNorm, GapRms, PMaxRef: Double;
  W, G, TDir, RDir: TDoubleArray;
  Active, Dropped: TArray<Boolean>;
  Delta0, LoadNow, Shift, RmsNum, PScale: Double;
  ActiveCount: Integer;
  HasOverlap, ActiveChanged: Boolean;
begin
  M := Length(ARBar);
  SetLength(AP, M);
  SetLength(W, M);
  SetLength(G, M);
  SetLength(TDir, M);
  SetLength(RDir, M);
  SetLength(Active, M);
  SetLength(Dropped, M);

  AreaSum := 0.0;
  for J := 0 to M - 1 do
    AreaSum := AreaSum + AArea[J];
  PScale := ATargetLoadMn / AreaSum;
  for J := 0 to M - 1 do
    AP[J] := PScale;

  GNormSqOld := 1.0;
  AIterations := 0;

  for Iter := 1 to 2500 do
  begin
    AIterations := Iter;
    for I := 0 to M - 1 do
    begin
      WSum := 0.0;
      for J := 0 to M - 1 do
        WSum := WSum + AD[I, J] * AP[J];
      W[I] := WSum;
    end;

    ActiveCount := 0;
    WSum := 0.0;
    AreaSum := 0.0;
    for I := 0 to M - 1 do
    begin
      if AP[I] > 0.0 then
      begin
        Active[I] := True;
        Inc(ActiveCount);
        WSum := WSum + AArea[I] * (W[I] + AHGap[I]);
        AreaSum := AreaSum + AArea[I];
      end
      else
        Active[I] := False;
    end;
    if ActiveCount = 0 then
    begin
      Active[0] := True;
      GBar := W[0] + AHGap[0];
    end
    else
      GBar := WSum / AreaSum;

    Delta0 := GBar;
    GNormSq := 0.0;
    for I := 0 to M - 1 do
    begin
      G[I] := W[I] + AHGap[I] - Delta0;
      if Active[I] then
        GNormSq := GNormSq + AArea[I] * G[I] * G[I];
    end;

    if (Iter = 1) or (GNormSqOld <= 0.0) then
      Beta := 0.0
    else
      Beta := GNormSq / GNormSqOld;

    for I := 0 to M - 1 do
    begin
      if Active[I] then
        TDir[I] := G[I] + Beta * TDir[I]
      else
        TDir[I] := 0.0;
    end;

    for I := 0 to M - 1 do
    begin
      WSum := 0.0;
      for J := 0 to M - 1 do
        WSum := WSum + AD[I, J] * TDir[J];
      RDir[I] := WSum;
    end;

    WSum := 0.0;
    AreaSum := 0.0;
    for I := 0 to M - 1 do
      if Active[I] then
      begin
        WSum := WSum + AArea[I] * RDir[I];
        AreaSum := AreaSum + AArea[I];
      end;
    if AreaSum > 0.0 then
    begin
      Shift := WSum / AreaSum;
      for I := 0 to M - 1 do
        RDir[I] := RDir[I] - Shift;
    end;

    Denom := 0.0;
    TNorm := 0.0;
    for I := 0 to M - 1 do
      if Active[I] then
      begin
        TNorm := TNorm + AArea[I] * G[I] * TDir[I];
        Denom := Denom + AArea[I] * TDir[I] * RDir[I];
      end;

    if Denom > 1e-30 then
      Alpha := TNorm / Denom
    else
      Alpha := 0.0;

    ActiveChanged := False;
    for I := 0 to M - 1 do
    begin
      Dropped[I] := False;
      if Active[I] then
      begin
        AP[I] := AP[I] - Alpha * TDir[I];
        if AP[I] <= 0.0 then
        begin
          AP[I] := 0.0;
          Dropped[I] := True;
          ActiveChanged := True;
        end;
      end;
    end;

    HasOverlap := False;
    for I := 0 to M - 1 do
    begin
      if (not Active[I]) and (G[I] < 0.0) then
      begin
        HasOverlap := True;
        ActiveChanged := True;
        AP[I] := AP[I] - Alpha * G[I];
        if AP[I] < 0.0 then
          AP[I] := 0.0;
      end;
    end;

    if ActiveChanged then
      GNormSqOld := 0.0
    else
      GNormSqOld := GNormSq;

    LoadNow := 0.0;
    for I := 0 to M - 1 do
      LoadNow := LoadNow + AArea[I] * AP[I];
    if LoadNow > 0.0 then
    begin
      PScale := ATargetLoadMn / LoadNow;
      for I := 0 to M - 1 do
        AP[I] := AP[I] * PScale;
    end;

    PMaxRef := 0.0;
    for I := 0 to M - 1 do
      if AP[I] > PMaxRef then
        PMaxRef := AP[I];

    RmsNum := 0.0;
    AreaSum := 0.0;
    for I := 0 to M - 1 do
      if AP[I] > 1e-12 * PMaxRef then
      begin
        RmsNum := RmsNum + AArea[I] * G[I] * G[I];
        AreaSum := AreaSum + AArea[I];
      end;
    if AreaSum > 0.0 then
      GapRms := Sqrt(RmsNum / AreaSum) / Max(Abs(Delta0), 1e-12)
    else
      GapRms := 0.0;

    AForceErr := Abs(LoadNow - ATargetLoadMn) / ATargetLoadMn;
    if (not HasOverlap) and (GapRms < 1e-8) and (Iter > 5) then
      Break;
  end;

  for I := 0 to M - 1 do
  begin
    WSum := 0.0;
    for J := 0 to M - 1 do
      WSum := WSum + AD[I, J] * AP[J];
    W[I] := WSum;
  end;
  WSum := 0.0;
  AreaSum := 0.0;
  for I := 0 to M - 1 do
    if AP[I] > 0.0 then
    begin
      WSum := WSum + AArea[I] * (W[I] + AHGap[I]);
      AreaSum := AreaSum + AArea[I];
    end;
  if AreaSum > 0.0 then
    ADelta := WSum / AreaSum
  else
    ADelta := Delta0;

  LoadNow := 0.0;
  for I := 0 to M - 1 do
    LoadNow := LoadNow + AArea[I] * AP[I];
  AForceErr := Abs(LoadNow - ATargetLoadMn) / ATargetLoadMn;
end;

function ComputeSubRingContactRadius(const AREdge, ARBar, AP: TDoubleArray): Double;
var
  M, LastActive, I: Integer;
  PThresh, P1Sq, P2Sq, R1, R2, RZero: Double;
begin
  M := Length(AP);
  PThresh := 0.0;
  for I := 0 to M - 1 do
    if AP[I] > PThresh then
      PThresh := AP[I];
  PThresh := 1e-5 * PThresh;

  LastActive := -1;
  for I := M - 1 downto 0 do
    if AP[I] > PThresh then
    begin
      LastActive := I;
      Break;
    end;

  if LastActive < 0 then
    Exit(0.0);
  if LastActive = 0 then
    Exit(AREdge[1]);

  P1Sq := Sqr(AP[LastActive - 1]);
  P2Sq := Sqr(AP[LastActive]);
  if P1Sq > P2Sq * (1.0 + 1e-9) then
  begin
    R1 := ARBar[LastActive - 1];
    R2 := ARBar[LastActive];
    RZero := R2 + P2Sq * (R2 - R1) / (P1Sq - P2Sq);
    if RZero < AREdge[LastActive] then
      RZero := AREdge[LastActive];
    if RZero > AREdge[LastActive + 1] then
      RZero := AREdge[LastActive + 1];
    Result := RZero;
  end
  else
    Result := AREdge[LastActive + 1];
end;

function RingPressureMomentIntegral(AR: Double; const AREdge, AP: TDoubleArray): Double;
var
  J: Integer;
  R0, R1, IntegralSum: Double;
begin
  if AR <= 0.0 then
  begin
    if Length(AP) > 0 then
      Result := 0.5 * AP[0]
    else
      Result := 0.0;
    Exit;
  end;
  IntegralSum := 0.0;
  for J := 0 to High(AP) do
  begin
    R0 := AREdge[J];
    R1 := AREdge[J + 1];
    if AR <= R0 then
      Break;
    if AR >= R1 then
      IntegralSum := IntegralSum + 0.5 * AP[J] * (R1 * R1 - R0 * R0)
    else
    begin
      IntegralSum := IntegralSum + 0.5 * AP[J] * (AR * AR - R0 * R0);
      Break;
    end;
  end;
  Result := IntegralSum / (AR * AR);
end;

function InterpolateRingPressure(AR: Double; const ARBar, AP: TDoubleArray): Double;
var
  I, M: Integer;
  T: Double;
begin
  M := Length(AP);
  if M = 0 then
    Exit(0.0);
  if AR <= ARBar[0] then
    Exit(AP[0]);
  if AR >= ARBar[M - 1] then
    Exit(0.0);
  for I := 0 to M - 2 do
  begin
    if (AR >= ARBar[I]) and (AR <= ARBar[I + 1]) then
    begin
      T := (AR - ARBar[I]) / (ARBar[I + 1] - ARBar[I]);
      Exit(AP[I] * (1.0 - T) + AP[I + 1] * T);
    end;
  end;
  Result := 0.0;
end;

procedure ComputeSlidingSurfaceAndPlane(var ASys: TSMMSystem; const ACase: TContactCase;
  const AREdge, ARBar, AP: TDoubleArray; AContactRadius: Double; AResult: TContactResult;
  var AMatMaxVm: TDoubleArray); forward;

function I1Disk(AR, AR0: Double): Double;
var
  M: Double;
begin
  if (AR0 <= 0.0) or (AR <= 0.0) then
    Exit(0.0);
  if AR < AR0 then
  begin
    M := Sqr(AR / AR0);
    Result := (2.0 / Pi) * (AR / AR0) * (EllipK_Minus_E(M) / M);
  end
  else if AR > AR0 then
  begin
    M := Sqr(AR0 / AR);
    Result := (2.0 / Pi) * EllipK_Minus_E(M);
  end
  else
    Result := 0.0;
end;

function I2Disk(AR, AR0: Double): Double;
var
  M, K, E, RRatio: Double;
begin
  if (AR0 <= 0.0) or (AR <= 0.0) then
    Exit(0.0);
  if AR < AR0 then
  begin
    RRatio := AR / AR0;
    M := Sqr(RRatio);
    if M < 1e-4 then
    begin
      Result := (RRatio / 8.0) * (1.0 + M * (0.25 + M * ((15.0 / 128.0) +
        M * ((35.0 / 512.0) + M * (735.0 / 16384.0)))));
    end
    else
    begin
      EllipKE(M, K, E);
      Result := (2.0 / (3.0 * Pi)) * Power(AR0 / AR, 3) * ((2.0 - M) * E - 2.0 * (1.0 - M) * K);
    end;
  end
  else if AR > AR0 then
  begin
    M := Sqr(AR0 / AR);
    if M < 1e-4 then
    begin
      Result := 0.5 * M * (1.0 - M * ((3.0 / 8.0) + M * ((5.0 / 64.0) +
        M * ((35.0 / 1024.0) + M * (315.0 / 16384.0)))));
    end
    else
    begin
      EllipKE(M, K, E);
      Result := (2.0 / (3.0 * Pi)) * ((2.0 * M - 1.0) * E + (1.0 - M) * K);
    end;
  end
  else
    Result := (2.0 / (3.0 * Pi));
end;

function EvaluateCoatedSHCompliance(var ASys: TSMMSystem; AXi: Double): Double;
var
  KBelow, Eta, E, Den, Scale, K11, K12, K22: Double;
  K, N: Integer;
begin
  KBelow := ASys.SubMu * AXi;
  N := Length(ASys.Layers);
  for K := N - 1 downto 0 do
  begin
    Eta := AXi * ASys.Layers[K].ThicknessUm;
    E := Exp(-Eta);
    Den := OneMinusExpNeg(2.0 * Eta);
    Scale := ASys.Layers[K].Mu * AXi / Den;
    K11 := Scale * (1.0 + E * E);
    K12 := -2.0 * Scale * E;
    K22 := K11;
    ASys.Layers[K].Ksh11 := K11;
    ASys.Layers[K].Ksh12 := K12;
    ASys.Layers[K].Ksh21 := K12;
    ASys.Layers[K].Ksh22 := K22;
    ASys.Layers[K].Tsh := -K12 / (K22 + KBelow);
    KBelow := K11 + K12 * ASys.Layers[K].Tsh;
  end;
  Result := 1.0 / KBelow;
end;

procedure ComputeSubsurfaceStresses(var ASys: TSMMSystem; const ACase: TContactCase;
  const AREdge, ARBar, AP: TDoubleArray; AContactRadius: Double; AResult: TContactResult);
var
  N, Nr, Nz, Ir, Iz, K, M, P, Q, NPanels, NGL, LayerIdx: Integer;
  RMax, ZMax, ZStart, ZEnd, ZVal, XiMax, PanW, Xi0, Xi1, HalfW, Mid, Xi: Double;
  TopE, TopNu, TopMu, SubZMax: Double;
  RGrid, ZGrid: TDoubleArray;
  RowLayer: TArray<Integer>;
  GLNodes, GLWeights: TDoubleArray;
  XiArr, WtArr: TDoubleArray;
  LayerZPts: Integer;
  D1, D2, EExp, OneMinusE, InvD1, InvD2: Double;
  U1, W1, U2, W2, A1L, A2L, B1L, B2L, C1, C2, C3, C4: Double;
  GCoated: TMat2x2;
  J1Val, PrevJ1, PTildeSum: Double;
  Eta1, Eta2, E1, E2, UVal, SVal, TVal: Double;
  Mu, Nu, Kappa, SigR0, SigT0, Srr, Stt, Szz, Trz: Double;
  Grid: TStressGrid;
  IfIdx, AboveRow, BelowRow: Integer;
  IfSummary: TInterfaceStressSummary;
  SrrMinA, SrrMaxA, SrrMinB, SrrMaxB, TrzMax, SvmMaxA, SvmMaxB: Double;
  MatMaxVm: TDoubleArray;
  YieldEntry: TYieldRatioEntry;
  YieldList: TArray<TYieldRatioEntry>;
  MatCount, YCount: Integer;
  PVal, IMom: Double;
  C0, S0, UTop, WTop, UBot, WBot, Zeta: Double;
  LogA, LogB, Wt, ZValPos: Double;
begin
  N := Length(ASys.Layers);
  M := Length(AP);
  RMax := AREdge[M];

  if N > 0 then
  begin
    TopE := ASys.Layers[0].EGpa;
    TopNu := ASys.Layers[0].Nu;
  end
  else
  begin
    TopE := ASys.SubEGpa;
    TopNu := ASys.SubNu;
  end;
  TopMu := TopE / (2.0 * (1.0 + TopNu));

  Nr := 51;
  SetLength(RGrid, Nr);
  RGrid[0] := 0.0;
  for Ir := 1 to 35 do
    RGrid[Ir] := 1.15 * AContactRadius * (Ir / 35.0);
  for Ir := 36 to Nr - 1 do
    RGrid[Ir] := 1.15 * AContactRadius + (1.5 * AContactRadius - 1.15 * AContactRadius) * ((Ir - 35) / (Nr - 36));

  SubZMax := Max(3.0 * AContactRadius, ACase.TotalCoatingThicknessUm + 2.0 * AContactRadius);
  ZMax := SubZMax;

  LayerZPts := 6;
  Nz := 1 + N * (LayerZPts + 2) + 17;
  SetLength(ZGrid, Nz);
  SetLength(RowLayer, Nz);

  Iz := 0;
  ZGrid[Iz] := 0.0;
  if N > 0 then
    RowLayer[Iz] := 0
  else
    RowLayer[Iz] := 0;
  Inc(Iz);

  ZStart := 0.0;
  for K := 0 to N - 1 do
  begin
    ZEnd := ZStart + ASys.Layers[K].ThicknessUm;
    for P := 1 to LayerZPts do
    begin
      ZGrid[Iz] := ZStart + (ZEnd - ZStart) * (P / (LayerZPts + 1));
      RowLayer[Iz] := K;
      Inc(Iz);
    end;
    ZGrid[Iz] := ZEnd;
    RowLayer[Iz] := K;
    Inc(Iz);
    ZGrid[Iz] := ZEnd;
    RowLayer[Iz] := K + 1;
    Inc(Iz);
    ZStart := ZEnd;
  end;

  ZEnd := ZStart;
  for P := 1 to 17 do
  begin
    ZVal := ZEnd + (ZMax - ZEnd) * Power(P / 17.0, 1.4);
    ZGrid[Iz] := ZVal;
    RowLayer[Iz] := N;
    Inc(Iz);
  end;
  Nz := Iz;
  SetLength(ZGrid, Nz);
  SetLength(RowLayer, Nz);

  Grid := TStressGrid.Create;
  Grid.RUm := RGrid;
  Grid.ZUm := ZGrid;
  SetLength(Grid.SigmaRRGpa, Nz, Nr);
  SetLength(Grid.SigmaTTGpa, Nz, Nr);
  SetLength(Grid.SigmaZZGpa, Nz, Nr);
  SetLength(Grid.TauRZGpa, Nz, Nr);
  SetLength(Grid.SigmaVmGpa, Nz, Nr);

  for Iz := 0 to Nz - 1 do
  begin
    ZVal := ZGrid[Iz];
    LayerIdx := RowLayer[Iz];
    if LayerIdx < N then
    begin
      Mu := ASys.Layers[LayerIdx].Mu;
      Nu := ASys.Layers[LayerIdx].Nu;
      Kappa := ASys.Layers[LayerIdx].Kappa;
    end
    else
    begin
      Mu := ASys.SubMu;
      Nu := ASys.SubNu;
      Kappa := ASys.SubKappa;
    end;

    if ZVal = 0.0 then
    begin
      for Ir := 0 to Nr - 1 do
      begin
        PVal := InterpolateRingPressure(RGrid[Ir], ARBar, AP);
        IMom := RingPressureMomentIntegral(RGrid[Ir], AREdge, AP);
        Grid.SigmaZZGpa[Iz, Ir] := -PVal;
        Grid.TauRZGpa[Iz, Ir] := 0.0;
        Grid.SigmaRRGpa[Iz, Ir] := -PVal + (1.0 - 2.0 * TopNu) * IMom;
        Grid.SigmaTTGpa[Iz, Ir] := -2.0 * TopNu * PVal - (1.0 - 2.0 * TopNu) * IMom;
      end;

      if ASys.HasContrast then
      begin
        XiMax := Max(25.0 / ASys.Layers[0].ThicknessUm, 30.0 / RMax);
        XiMax := Min(XiMax, 600.0 / AContactRadius);
        NGL := 12;
        GaussLegendreRule(NGL, GLNodes, GLWeights);
        PanW := 2.0 * Pi / Max(RMax, 1.5 * AContactRadius);
        NPanels := Ceil(XiMax / PanW);
        if NPanels < 8 then
          NPanels := 8;
        PanW := XiMax / NPanels;
        SetLength(XiArr, NPanels * NGL);
        SetLength(WtArr, NPanels * NGL);
        Q := 0;
        for P := 0 to NPanels - 1 do
        begin
          Xi0 := P * PanW;
          Xi1 := (P + 1) * PanW;
          HalfW := 0.5 * (Xi1 - Xi0);
          Mid := 0.5 * (Xi0 + Xi1);
          for K := 0 to NGL - 1 do
          begin
            XiArr[Q] := Mid + HalfW * GLNodes[K];
            WtArr[Q] := HalfW * GLWeights[K];
            Inc(Q);
          end;
        end;

        for Q := 0 to High(XiArr) do
        begin
          Xi := XiArr[Q];
          PTildeSum := 0.0;
          PrevJ1 := 0.0;
          for K := 0 to M - 1 do
          begin
            J1Val := AREdge[K + 1] * BesselJ1(Xi * AREdge[K + 1]);
            PTildeSum := PTildeSum + AP[K] * (J1Val - PrevJ1);
            PrevJ1 := J1Val;
          end;
          PTildeSum := PTildeSum / Xi;
          EvaluateCoatedCompliance(ASys, Xi, GCoated);
          UTop := GCoated[0, 1] * PTildeSum - (-(1.0 - 2.0 * TopNu) / (2.0 * TopMu * Xi)) * PTildeSum;
          SigR0 := (2.0 * TopMu / (1.0 - TopNu)) * Xi * UTop;
          SigT0 := (2.0 * TopMu * TopNu / (1.0 - TopNu)) * Xi * UTop;
          for Ir := 0 to Nr - 1 do
          begin
            if RGrid[Ir] = 0.0 then
            begin
              C0 := 1.0;
              S0 := 0.5 * Xi;
            end
            else
            begin
              C0 := BesselJ0(Xi * RGrid[Ir]);
              S0 := BesselJ1(Xi * RGrid[Ir]) / RGrid[Ir];
            end;
            Grid.SigmaRRGpa[Iz, Ir] := Grid.SigmaRRGpa[Iz, Ir] +
              WtArr[Q] * Xi * (SigR0 * C0 - 2.0 * TopMu * UTop * S0);
            Grid.SigmaTTGpa[Iz, Ir] := Grid.SigmaTTGpa[Iz, Ir] +
              WtArr[Q] * Xi * (SigT0 * C0 + 2.0 * TopMu * UTop * S0);
          end;
        end;
      end;

      for Ir := 0 to Nr - 1 do
      begin
        Srr := Grid.SigmaRRGpa[Iz, Ir];
        Stt := Grid.SigmaTTGpa[Iz, Ir];
        Szz := Grid.SigmaZZGpa[Iz, Ir];
        Trz := Grid.TauRZGpa[Iz, Ir];
        Grid.SigmaVmGpa[Iz, Ir] := Sqrt(0.5 * (Sqr(Srr - Stt) + Sqr(Stt - Szz) + Sqr(Szz - Srr)) + 3.0 * Sqr(Trz));
      end;
      Continue;
    end;

    ZValPos := Max(ZVal, 0.01 * AContactRadius);
    XiMax := Max(28.0 / ZValPos, 40.0 / AContactRadius);
    if XiMax > 300.0 / AContactRadius then
      XiMax := 300.0 / AContactRadius;

    NGL := 12;
    GaussLegendreRule(NGL, GLNodes, GLWeights);
    PanW := 2.0 * Pi / Max(RMax, 1.5 * AContactRadius);
    NPanels := Ceil(XiMax / PanW);
    if NPanels < 8 then
      NPanels := 8;
    if NPanels > 90 then
      NPanels := 90;
    PanW := XiMax / NPanels;
    SetLength(XiArr, NPanels * NGL);
    SetLength(WtArr, NPanels * NGL);
    Q := 0;
    for P := 0 to NPanels - 1 do
    begin
      Xi0 := P * PanW;
      Xi1 := (P + 1) * PanW;
      HalfW := 0.5 * (Xi1 - Xi0);
      Mid := 0.5 * (Xi0 + Xi1);
      for K := 0 to NGL - 1 do
      begin
        XiArr[Q] := Mid + HalfW * GLNodes[K];
        WtArr[Q] := HalfW * GLWeights[K];
        Inc(Q);
      end;
    end;

    for Q := 0 to High(XiArr) do
    begin
      Xi := XiArr[Q];
      PTildeSum := 0.0;
      PrevJ1 := 0.0;
      for K := 0 to M - 1 do
      begin
        J1Val := AREdge[K + 1] * BesselJ1(Xi * AREdge[K + 1]);
        PTildeSum := PTildeSum + AP[K] * (J1Val - PrevJ1);
        PrevJ1 := J1Val;
      end;
      PTildeSum := PTildeSum / Xi;

      EvaluateCoatedCompliance(ASys, Xi, GCoated);
      UTop := GCoated[0, 1] * PTildeSum;
      WTop := GCoated[1, 1] * PTildeSum;

      for K := 0 to LayerIdx - 1 do
      begin
        if K >= N then
          Break;
        Mat2VecMul(ASys.Layers[K].Tk, UTop, WTop, UBot, WBot);
        if K < LayerIdx - 1 then
        begin
          UTop := UBot;
          WTop := WBot;
        end
        else if LayerIdx = N then
        begin
          UTop := UBot;
          WTop := WBot;
        end
        else
        begin
          UTop := UBot;
          WTop := WBot;
        end;
      end;

      if LayerIdx < N then
      begin
        BuildLayerStiffness(ASys.Layers[LayerIdx], Xi, D1, D2, EExp, OneMinusE);
        Mat2VecMul(ASys.Layers[LayerIdx].Tk, UTop, WTop, UBot, WBot);

        U1 := 0.5 * (UTop + UBot);
        W1 := 0.5 * (WTop - WBot);
        U2 := 0.5 * (UTop - UBot);
        W2 := 0.5 * (WTop + WBot);

        InvD1 := 1.0 / D1;
        InvD2 := 1.0 / D2;
        A1L := InvD1 * ((ASys.Layers[LayerIdx].Kappa * OneMinusE - Xi * ASys.Layers[LayerIdx].ThicknessUm * EExp) * U1 -
          (Xi * ASys.Layers[LayerIdx].ThicknessUm * EExp) * W1);
        A2L := InvD1 * (-OneMinusE * U1 + (1.0 + EExp) * W1);

        B1L := InvD2 * ((ASys.Layers[LayerIdx].Kappa * (1.0 + EExp) + Xi * ASys.Layers[LayerIdx].ThicknessUm * EExp) * U2 +
          (Xi * ASys.Layers[LayerIdx].ThicknessUm * EExp) * W2);
        B2L := InvD2 * (-(1.0 + EExp) * U2 + OneMinusE * W2);

        C1 := A1L + B1L;
        C2 := A2L + B2L;
        C3 := A1L - B1L;
        C4 := A2L - B2L;

        Eta1 := Xi * (ZVal - ASys.Layers[LayerIdx].ZTopUm);
        Eta2 := Xi * (ASys.Layers[LayerIdx].ZBotUm - ZVal);
        E1 := Exp(-Eta1);
        E2 := Exp(-Eta2);

        UVal := (C1 + Eta1 * C2) * E1 + (C3 + Eta2 * C4) * E2;
        SVal := -2.0 * Mu * Xi * ((C1 + (2.0 * (1.0 - Nu) + Eta1) * C2) * E1 +
          (C3 + (2.0 * (1.0 - Nu) + Eta2) * C4) * E2);
        TVal := -2.0 * Mu * Xi * ((C1 + (1.0 - 2.0 * Nu + Eta1) * C2) * E1 -
          (C3 + (1.0 - 2.0 * Nu + Eta2) * C4) * E2);
      end
      else
      begin
        if N > 0 then
          Zeta := Xi * (ZVal - ASys.Layers[N - 1].ZBotUm)
        else
          Zeta := Xi * ZVal;
        E1 := Exp(-Zeta);
        C1 := UTop;
        C2 := (WTop - UTop) / Kappa;
        UVal := (C1 + Zeta * C2) * E1;
        SVal := -2.0 * Mu * Xi * (C1 + (2.0 * (1.0 - Nu) + Zeta) * C2) * E1;
        TVal := -2.0 * Mu * Xi * (C1 + (1.0 - 2.0 * Nu + Zeta) * C2) * E1;
      end;

      SigR0 := (Nu / (1.0 - Nu)) * SVal + (2.0 * Mu / (1.0 - Nu)) * Xi * UVal;
      SigT0 := (Nu / (1.0 - Nu)) * SVal + (2.0 * Mu * Nu / (1.0 - Nu)) * Xi * UVal;

      for Ir := 0 to Nr - 1 do
      begin
        if RGrid[Ir] = 0.0 then
        begin
          C0 := 1.0;
          S0 := 0.5 * Xi;
          J1Val := 0.0;
        end
        else
        begin
          BesselJ012(Xi * RGrid[Ir], C0, J1Val, E2);
          S0 := J1Val / RGrid[Ir];
        end;
        Grid.SigmaRRGpa[Iz, Ir] := Grid.SigmaRRGpa[Iz, Ir] +
          WtArr[Q] * Xi * (SigR0 * C0 - 2.0 * Mu * UVal * S0);
        Grid.SigmaTTGpa[Iz, Ir] := Grid.SigmaTTGpa[Iz, Ir] +
          WtArr[Q] * Xi * (SigT0 * C0 + 2.0 * Mu * UVal * S0);
        Grid.SigmaZZGpa[Iz, Ir] := Grid.SigmaZZGpa[Iz, Ir] +
          WtArr[Q] * Xi * SVal * C0;
        Grid.TauRZGpa[Iz, Ir] := Grid.TauRZGpa[Iz, Ir] +
          WtArr[Q] * Xi * TVal * J1Val;
      end;
    end;

    // For very shallow depths z < 0.015*a where XiMax is truncated at 300/a, compute centerline exactly via log-spaced GL.
    if (ZVal > 0.0) and (ZVal < 0.015 * AContactRadius) then
    begin
      Grid.SigmaRRGpa[Iz, 0] := 0.0;
      Grid.SigmaTTGpa[Iz, 0] := 0.0;
      Grid.SigmaZZGpa[Iz, 0] := 0.0;
      Grid.TauRZGpa[Iz, 0] := 0.0;

      XiMax := Max(35.0 / ZVal, 100.0 / AContactRadius);
      NGL := 12;
      GaussLegendreRule(NGL, GLNodes, GLWeights);
      NPanels := 24;
      LogA := Ln(1e-4 / AContactRadius);
      LogB := Ln(XiMax);
      for P := 0 to NPanels - 1 do
      begin
        Xi0 := Exp(LogA + (LogB - LogA) * (P / NPanels));
        Xi1 := Exp(LogA + (LogB - LogA) * ((P + 1) / NPanels));
        HalfW := 0.5 * (Xi1 - Xi0);
        Mid := 0.5 * (Xi0 + Xi1);
        for K := 0 to NGL - 1 do
        begin
          Xi := Mid + HalfW * GLNodes[K];
          Wt := HalfW * GLWeights[K];

          PTildeSum := 0.0;
          PrevJ1 := 0.0;
          for LayerIdx := 0 to M - 1 do
          begin
            J1Val := AREdge[LayerIdx + 1] * BesselJ1(Xi * AREdge[LayerIdx + 1]);
            PTildeSum := PTildeSum + AP[LayerIdx] * (J1Val - PrevJ1);
            PrevJ1 := J1Val;
          end;
          PTildeSum := PTildeSum / Xi;

          EvaluateCoatedCompliance(ASys, Xi, GCoated);
          UTop := GCoated[0, 1] * PTildeSum;
          WTop := GCoated[1, 1] * PTildeSum;
          LayerIdx := RowLayer[Iz];
          for IfIdx := 0 to LayerIdx - 1 do
          begin
            if IfIdx >= N then
              Break;
            Mat2VecMul(ASys.Layers[IfIdx].Tk, UTop, WTop, UBot, WBot);
            UTop := UBot;
            WTop := WBot;
          end;

          if LayerIdx < N then
          begin
            BuildLayerStiffness(ASys.Layers[LayerIdx], Xi, D1, D2, EExp, OneMinusE);
            Mat2VecMul(ASys.Layers[LayerIdx].Tk, UTop, WTop, UBot, WBot);
            U1 := 0.5 * (UTop + UBot);
            W1 := 0.5 * (WTop - WBot);
            U2 := 0.5 * (UTop - UBot);
            W2 := 0.5 * (WTop + WBot);
            InvD1 := 1.0 / D1;
            InvD2 := 1.0 / D2;
            A1L := InvD1 * ((ASys.Layers[LayerIdx].Kappa * OneMinusE - Xi * ASys.Layers[LayerIdx].ThicknessUm * EExp) * U1 -
              (Xi * ASys.Layers[LayerIdx].ThicknessUm * EExp) * W1);
            A2L := InvD1 * (-OneMinusE * U1 + (1.0 + EExp) * W1);
            B1L := InvD2 * ((ASys.Layers[LayerIdx].Kappa * (1.0 + EExp) + Xi * ASys.Layers[LayerIdx].ThicknessUm * EExp) * U2 +
              (Xi * ASys.Layers[LayerIdx].ThicknessUm * EExp) * W2);
            B2L := InvD2 * (-(1.0 + EExp) * U2 + OneMinusE * W2);
            C1 := A1L + B1L;
            C2 := A2L + B2L;
            C3 := A1L - B1L;
            C4 := A2L - B2L;
            Eta1 := Xi * (ZVal - ASys.Layers[LayerIdx].ZTopUm);
            Eta2 := Xi * (ASys.Layers[LayerIdx].ZBotUm - ZVal);
            E1 := Exp(-Eta1);
            E2 := Exp(-Eta2);
            UVal := (C1 + Eta1 * C2) * E1 + (C3 + Eta2 * C4) * E2;
            SVal := -2.0 * Mu * Xi * ((C1 + (2.0 * (1.0 - Nu) + Eta1) * C2) * E1 +
              (C3 + (2.0 * (1.0 - Nu) + Eta2) * C4) * E2);
          end
          else
          begin
            if N > 0 then
              Zeta := Xi * (ZVal - ASys.Layers[N - 1].ZBotUm)
            else
              Zeta := Xi * ZVal;
            E1 := Exp(-Zeta);
            C1 := UTop;
            C2 := (WTop - UTop) / Kappa;
            UVal := (C1 + Zeta * C2) * E1;
            SVal := -2.0 * Mu * Xi * (C1 + (2.0 * (1.0 - Nu) + Zeta) * C2) * E1;
          end;
          SigR0 := (Nu / (1.0 - Nu)) * SVal + (Mu * (1.0 + Nu) / (1.0 - Nu)) * Xi * UVal;
          Grid.SigmaRRGpa[Iz, 0] := Grid.SigmaRRGpa[Iz, 0] + Wt * Xi * SigR0;
          Grid.SigmaTTGpa[Iz, 0] := Grid.SigmaRRGpa[Iz, 0];
          Grid.SigmaZZGpa[Iz, 0] := Grid.SigmaZZGpa[Iz, 0] + Wt * Xi * SVal;
        end;
      end;
    end;

    for Ir := 0 to Nr - 1 do
    begin
      Srr := Grid.SigmaRRGpa[Iz, Ir];
      Stt := Grid.SigmaTTGpa[Iz, Ir];
      Szz := Grid.SigmaZZGpa[Iz, Ir];
      Trz := Grid.TauRZGpa[Iz, Ir];
      Grid.SigmaVmGpa[Iz, Ir] := Sqrt(0.5 * (Sqr(Srr - Stt) + Sqr(Stt - Szz) + Sqr(Szz - Srr)) + 3.0 * Sqr(Trz));
    end;
  end;

  AResult.StressGrid := Grid;

  SetLength(AResult.ZCenterlineUm, Nz);
  SetLength(AResult.CenterlineSigmaVmGpa, Nz);
  SetLength(AResult.CenterlineSigmaRRGpa, Nz);
  SetLength(AResult.CenterlineSigmaZZGpa, Nz);
  for Iz := 0 to Nz - 1 do
  begin
    AResult.ZCenterlineUm[Iz] := ZGrid[Iz];
    AResult.CenterlineSigmaVmGpa[Iz] := Grid.SigmaVmGpa[Iz, 0];
    AResult.CenterlineSigmaRRGpa[Iz] := Grid.SigmaRRGpa[Iz, 0];
    AResult.CenterlineSigmaZZGpa[Iz] := Grid.SigmaZZGpa[Iz, 0];
  end;

  SetLength(AResult.Interfaces, N);
  for IfIdx := 0 to N - 1 do
  begin
    AboveRow := -1;
    BelowRow := -1;
    for Iz := 0 to Nz - 2 do
    begin
      if (RowLayer[Iz] = IfIdx) and (RowLayer[Iz + 1] = IfIdx + 1) and
         (Abs(ZGrid[Iz] - ASys.Layers[IfIdx].ZBotUm) < 1e-12) then
      begin
        AboveRow := Iz;
        BelowRow := Iz + 1;
        Break;
      end;
    end;

    IfSummary := Default(TInterfaceStressSummary);
    IfSummary.InterfaceIndex := IfIdx + 1;
    IfSummary.DepthUm := ASys.Layers[IfIdx].ZBotUm;
    IfSummary.AboveLabel := Format('Layer %d (%s)', [IfIdx + 1, ACase.Layers[IfIdx].Material.Name]);
    if IfIdx + 1 < N then
      IfSummary.BelowLabel := Format('Layer %d (%s)', [IfIdx + 2, ACase.Layers[IfIdx + 1].Material.Name])
    else
      IfSummary.BelowLabel := Format('Substrate (%s)', [ACase.Substrate.Name]);

    if (AboveRow >= 0) and (BelowRow >= 0) then
    begin
      SrrMaxA := -Infinity;
      SrrMinA := Infinity;
      SrrMaxB := -Infinity;
      SrrMinB := Infinity;
      TrzMax := 0.0;
      SvmMaxA := 0.0;
      SvmMaxB := 0.0;
      for Ir := 0 to Nr - 1 do
      begin
        if Grid.SigmaRRGpa[AboveRow, Ir] > SrrMaxA then SrrMaxA := Grid.SigmaRRGpa[AboveRow, Ir];
        if Grid.SigmaRRGpa[AboveRow, Ir] < SrrMinA then SrrMinA := Grid.SigmaRRGpa[AboveRow, Ir];
        if Grid.SigmaRRGpa[BelowRow, Ir] > SrrMaxB then SrrMaxB := Grid.SigmaRRGpa[BelowRow, Ir];
        if Grid.SigmaRRGpa[BelowRow, Ir] < SrrMinB then SrrMinB := Grid.SigmaRRGpa[BelowRow, Ir];
        if Abs(Grid.TauRZGpa[AboveRow, Ir]) > TrzMax then TrzMax := Abs(Grid.TauRZGpa[AboveRow, Ir]);
        if Abs(Grid.TauRZGpa[BelowRow, Ir]) > TrzMax then TrzMax := Abs(Grid.TauRZGpa[BelowRow, Ir]);
        if Grid.SigmaVmGpa[AboveRow, Ir] > SvmMaxA then SvmMaxA := Grid.SigmaVmGpa[AboveRow, Ir];
        if Grid.SigmaVmGpa[BelowRow, Ir] > SvmMaxB then SvmMaxB := Grid.SigmaVmGpa[BelowRow, Ir];
      end;
      IfSummary.MaxSigmaRRAboveGpa := SrrMaxA;
      IfSummary.MinSigmaRRAboveGpa := SrrMinA;
      IfSummary.MaxSigmaRRBelowGpa := SrrMaxB;
      IfSummary.MinSigmaRRBelowGpa := SrrMinB;
      IfSummary.MaxAbsTauRZGpa := TrzMax;
      IfSummary.MaxSigmaVmAboveGpa := SvmMaxA;
      IfSummary.MaxSigmaVmBelowGpa := SvmMaxB;
    end;
    AResult.Interfaces[IfIdx] := IfSummary;
  end;

  MatCount := N + 1;
  SetLength(MatMaxVm, MatCount);
  for K := 0 to MatCount - 1 do
    MatMaxVm[K] := 0.0;
  for Iz := 0 to Nz - 1 do
  begin
    K := RowLayer[Iz];
    for Ir := 0 to Nr - 1 do
      if Grid.SigmaVmGpa[Iz, Ir] > MatMaxVm[K] then
        MatMaxVm[K] := Grid.SigmaVmGpa[Iz, Ir];
  end;

  if ACase.LoadCase.FrictionCoeff > 0.0 then
    ComputeSlidingSurfaceAndPlane(ASys, ACase, AREdge, ARBar, AP, AContactRadius, AResult, MatMaxVm);

  SetLength(YieldList, MatCount);
  YCount := 0;
  AResult.YieldWarning := False;
  for K := 0 to N - 1 do
  begin
    if ACase.Layers[K].Material.HasSigmaY then
    begin
      YieldEntry.MaterialLabel := Format('Layer %d (%s)', [K + 1, ACase.Layers[K].Material.Name]);
      YieldEntry.Ratio := MatMaxVm[K] / ACase.Layers[K].Material.SigmaYGpa;
      YieldList[YCount] := YieldEntry;
      Inc(YCount);
      if YieldEntry.Ratio > 0.95 then
        AResult.YieldWarning := True;
    end;
  end;
  if ACase.Substrate.HasSigmaY then
  begin
    YieldEntry.MaterialLabel := Format('Substrate (%s)', [ACase.Substrate.Name]);
    YieldEntry.Ratio := MatMaxVm[N] / ACase.Substrate.SigmaYGpa;
    YieldList[YCount] := YieldEntry;
    Inc(YCount);
    if YieldEntry.Ratio > 0.95 then
      AResult.YieldWarning := True;
  end;
  SetLength(YieldList, YCount);
  AResult.LayerYieldRatios := YieldList;
end;

procedure ComputeSlidingSurfaceAndPlane(var ASys: TSMMSystem; const ACase: TContactCase;
  const AREdge, ARBar, AP: TDoubleArray; AContactRadius: Double; AResult: TContactResult;
  var AMatMaxVm: TDoubleArray);
var
  Grid: TStressGrid;
  N, M, Nr, Nz, Ir, Iz, K, P, Q, NPanels, NGL, NxPlane, IXPos, IXNeg, LayerIdx: Integer;
  MuFric, RMax, TopE, TopNu, TopMu, XiMax, PanW, Xi0, Xi1, HalfW, Mid, Xi: Double;
  GLNodes, GLWeights, XiArr, WtArr: TDoubleArray;
  SurfPosR, NormSrrPos, SlideSrrPos: TDoubleArray;
  SrrSlideHom, SrrNormHom, I1Sum, I2Sum, Qj, IMom, S0Norm: Double;
  GCoated: TMat2x2;
  GSH, QTildeSum, PrevJ1, J1Val, C0, J2Val: Double;
  UTopNorm, UTopPsv, WTopPsv, VTopSH, UBotPsv, WBotPsv, VBotSH: Double;
  DeltaUNorm, DeltaUPsv, DeltaUV, SigR0, FacSlide: Double;
  RowLayer: TArray<Integer>;
  ZVal, ZValPos, Mu, Nu, Kappa, Eta, EExp, OneMinusE, D1, D2, InvD1, InvD2: Double;
  U1, W1, U2, W2, A1L, A2L, B1L, B2L, C1, C2, C3, C4, Eta1, Eta2, E1, E2: Double;
  UVal, SVal, TVal, VVal, VpVal, Den, C1sh, C2sh, Zeta: Double;
  SigR0S, SigT0S, J1p, J1OverXiR, Sgn: Double;
  Sxx, Syy, Szz, Txz, Svm: Double;
  SlideSrrR, SlideSttR, SlideSzzR, SlideTrzR: TDoubleArray;
  ThetaEdge, STheta, QTheta, SMid: TDoubleArray;
  NTheta, NPos, LastIdx: Integer;
  RVal, P0Val, TFrac, TipDen, DTheta, Q0, Q1, Dq: Double;
begin
  Grid := AResult.StressGrid;
  MuFric := ACase.LoadCase.FrictionCoeff;
  N := Length(ASys.Layers);
  M := Length(AP);
  RMax := AREdge[M];
  Nr := Length(Grid.RUm);
  Nz := Length(Grid.ZUm);

  if N > 0 then
  begin
    TopE := ASys.Layers[0].EGpa;
    TopNu := ASys.Layers[0].Nu;
  end
  else
  begin
    TopE := ASys.SubEGpa;
    TopNu := ASys.SubNu;
  end;
  TopMu := TopE / (2.0 * (1.0 + TopNu));

  SetLength(RowLayer, Nz);
  K := 0;
  for Iz := 0 to Nz - 1 do
  begin
    while (K < N) and (Grid.ZUm[Iz] > ASys.Layers[K].ZBotUm + 1e-12) do
      Inc(K);
    if (K < N) and (Iz > 0) and (Abs(Grid.ZUm[Iz] - ASys.Layers[K].ZBotUm) < 1e-12) and
       (Abs(Grid.ZUm[Iz - 1] - ASys.Layers[K].ZBotUm) < 1e-12) then
      Inc(K);
    RowLayer[Iz] := K;
  end;

  NTheta := 320;
  SetLength(ThetaEdge, NTheta + 1);
  SetLength(STheta, NTheta + 1);
  SetLength(QTheta, NTheta + 1);
  SetLength(SMid, NTheta);

  LastIdx := -1;
  for K := M - 1 downto 0 do
    if (ARBar[K] < AContactRadius) and (AP[K] > 0.0) then
    begin
      LastIdx := K;
      Break;
    end;
  if (M >= 2) and (AP[0] >= AP[1]) then
    P0Val := (9.0 / 8.0) * AP[0] - 0.125 * AP[1]
  else
    P0Val := AP[0];

  DTheta := (0.5 * Pi) / NTheta;
  for K := 0 to NTheta do
  begin
    ThetaEdge[K] := K * DTheta;
    STheta[K] := AContactRadius * Sin(ThetaEdge[K]);
    RVal := STheta[K];
    if (K = NTheta) or (LastIdx < 0) then
      QTheta[K] := 0.0
    else if RVal <= ARBar[0] then
    begin
      TFrac := RVal / ARBar[0];
      QTheta[K] := MuFric * (P0Val * (1.0 - TFrac) + AP[0] * TFrac);
    end
    else if RVal <= ARBar[LastIdx] then
      QTheta[K] := MuFric * InterpolateRingPressure(RVal, ARBar, AP)
    else
    begin
      TipDen := Max(1e-12, Sqr(AContactRadius) - Sqr(ARBar[LastIdx]));
      QTheta[K] := MuFric * AP[LastIdx] * Sqrt(Max(0.0, Sqr(AContactRadius) - Sqr(RVal)) / TipDen);
    end;
  end;
  for K := 0 to NTheta - 1 do
    SMid[K] := 0.5 * (STheta[K] + STheta[K + 1]);

  NPos := M + 1;
  SetLength(SurfPosR, NPos);
  for K := 0 to M - 1 do
    SurfPosR[K] := ARBar[K];
  SurfPosR[M] := AContactRadius;
  for K := 0 to NPos - 2 do
  begin
    for P := K + 1 to NPos - 1 do
      if SurfPosR[P] < SurfPosR[K] then
      begin
        RVal := SurfPosR[K];
        SurfPosR[K] := SurfPosR[P];
        SurfPosR[P] := RVal;
      end;
  end;

  SetLength(NormSrrPos, NPos);
  SetLength(SlideSrrPos, NPos);
  for K := 0 to NPos - 1 do
  begin
    RVal := SurfPosR[K];
    if Abs(RVal - AContactRadius) < 1e-9 * AContactRadius then
    begin
      IMom := 0.5 * AResult.PMeanGpa;
      SrrNormHom := (1.0 - 2.0 * TopNu) * IMom;
      I1Sum := 0.0;
      I2Sum := 0.0;
      for P := 0 to NTheta - 1 do
      begin
        Q0 := QTheta[P];
        Q1 := QTheta[P + 1];
        Dq := Q0 - Q1;
        if Dq <> 0.0 then
        begin
          I1Sum := I1Sum + Dq * I1Disk(RVal, SMid[P]);
          I2Sum := I2Sum + Dq * I2Disk(RVal, SMid[P]);
        end;
      end;
    end
    else
    begin
      IMom := RingPressureMomentIntegral(RVal, AREdge, AP);
      SrrNormHom := -InterpolateRingPressure(RVal, ARBar, AP) + (1.0 - 2.0 * TopNu) * IMom;
      I1Sum := 0.0;
      I2Sum := 0.0;
      for P := 0 to M - 1 do
      begin
        if AP[P] <= 0.0 then
          Continue;
        Qj := MuFric * AP[P];
        I1Sum := I1Sum + Qj * (I1Disk(RVal, AREdge[P + 1]) - I1Disk(RVal, AREdge[P]));
        I2Sum := I2Sum + Qj * (I2Disk(RVal, AREdge[P + 1]) - I2Disk(RVal, AREdge[P]));
      end;
    end;
    SrrSlideHom := -2.0 * I1Sum - 2.0 * TopNu * I2Sum;
    NormSrrPos[K] := SrrNormHom;
    SlideSrrPos[K] := SrrSlideHom;
  end;

  if ASys.HasContrast then
  begin
    XiMax := Max(25.0 / ASys.Layers[0].ThicknessUm, 30.0 / RMax);
    XiMax := Min(XiMax, 600.0 / AContactRadius);
    NGL := 12;
    GaussLegendreRule(NGL, GLNodes, GLWeights);
    PanW := 2.0 * Pi / Max(RMax, 1.5 * AContactRadius);
    NPanels := Ceil(XiMax / PanW);
    if NPanels < 8 then
      NPanels := 8;
    PanW := XiMax / NPanels;
    SetLength(XiArr, NPanels * NGL);
    SetLength(WtArr, NPanels * NGL);
    Q := 0;
    for P := 0 to NPanels - 1 do
    begin
      Xi0 := P * PanW;
      Xi1 := (P + 1) * PanW;
      HalfW := 0.5 * (Xi1 - Xi0);
      Mid := 0.5 * (Xi0 + Xi1);
      for K := 0 to NGL - 1 do
      begin
        XiArr[Q] := Mid + HalfW * GLNodes[K];
        WtArr[Q] := HalfW * GLWeights[K];
        Inc(Q);
      end;
    end;

    for Q := 0 to High(XiArr) do
    begin
      Xi := XiArr[Q];
      QTildeSum := 0.0;
      PrevJ1 := 0.0;
      for K := 0 to M - 1 do
      begin
        J1Val := AREdge[K + 1] * BesselJ1(Xi * AREdge[K + 1]);
        QTildeSum := QTildeSum + AP[K] * (J1Val - PrevJ1);
        PrevJ1 := J1Val;
      end;
      QTildeSum := QTildeSum / Xi;

      EvaluateCoatedCompliance(ASys, Xi, GCoated);
      GSH := EvaluateCoatedSHCompliance(ASys, Xi);

      UTopNorm := GCoated[0, 1] * QTildeSum;
      DeltaUNorm := UTopNorm - (-(1.0 - 2.0 * TopNu) / (2.0 * TopMu * Xi)) * QTildeSum;

      UTopPsv := -GCoated[0, 0] * (MuFric * QTildeSum);
      VTopSH := GSH * (MuFric * QTildeSum);
      DeltaUPsv := UTopPsv - (-(1.0 - TopNu) / (TopMu * Xi)) * (MuFric * QTildeSum);
      DeltaUV := (UTopPsv + VTopSH) - (TopNu / (TopMu * Xi)) * (MuFric * QTildeSum);

      SigR0 := (2.0 * TopMu / (1.0 - TopNu)) * Xi * DeltaUNorm;
      FacSlide := (2.0 * TopMu / (1.0 - TopNu)) * Xi * DeltaUPsv;

      for K := 0 to NPos - 1 do
      begin
        BesselJ012(Xi * SurfPosR[K], C0, J1Val, J2Val);
        S0Norm := J1Val / SurfPosR[K];
        NormSrrPos[K] := NormSrrPos[K] +
          WtArr[Q] * Xi * (SigR0 * C0 - 2.0 * TopMu * DeltaUNorm * S0Norm);
        SlideSrrPos[K] := SlideSrrPos[K] +
          WtArr[Q] * Xi * (FacSlide * J1Val - 2.0 * TopMu * DeltaUV * (J2Val / SurfPosR[K]));
      end;
    end;
  end;

  SetLength(Grid.SlidingSurfaceXUm, 2 * NPos + 1);
  SetLength(Grid.SlidingSurfaceSigmaXXGpa, 2 * NPos + 1);
  for K := 0 to NPos - 1 do
  begin
    Grid.SlidingSurfaceXUm[K] := -SurfPosR[NPos - 1 - K];
    Grid.SlidingSurfaceSigmaXXGpa[K] := NormSrrPos[NPos - 1 - K] - SlideSrrPos[NPos - 1 - K];
  end;
  Grid.SlidingSurfaceXUm[NPos] := 0.0;
  Grid.SlidingSurfaceSigmaXXGpa[NPos] := Grid.SigmaRRGpa[0, 0];
  for K := 0 to NPos - 1 do
  begin
    Grid.SlidingSurfaceXUm[NPos + 1 + K] := SurfPosR[K];
    Grid.SlidingSurfaceSigmaXXGpa[NPos + 1 + K] := NormSrrPos[K] + SlideSrrPos[K];
  end;

  NxPlane := 2 * Nr - 1;
  SetLength(Grid.SlidingPlaneXUm, NxPlane);
  for Ir := 0 to Nr - 1 do
    Grid.SlidingPlaneXUm[Nr - 1 + Ir] := Grid.RUm[Ir];
  for Ir := 1 to Nr - 1 do
    Grid.SlidingPlaneXUm[Nr - 1 - Ir] := -Grid.RUm[Ir];

  SetLength(Grid.SlidingPlaneSigmaXXGpa, Nz, NxPlane);
  SetLength(Grid.SlidingPlaneTauXZGpa, Nz, NxPlane);
  SetLength(Grid.SlidingPlaneSigmaVmGpa, Nz, NxPlane);
  SetLength(SlideSrrR, Nr);
  SetLength(SlideSttR, Nr);
  SetLength(SlideSzzR, Nr);
  SetLength(SlideTrzR, Nr);

  for Iz := 0 to Nz - 1 do
  begin
    ZVal := Grid.ZUm[Iz];
    K := RowLayer[Iz];
    if K < N then
    begin
      Mu := ASys.Layers[K].Mu;
      Nu := ASys.Layers[K].Nu;
      Kappa := ASys.Layers[K].Kappa;
    end
    else
    begin
      Mu := ASys.SubMu;
      Nu := ASys.SubNu;
      Kappa := ASys.SubKappa;
    end;

    for Ir := 0 to Nr - 1 do
    begin
      SlideSrrR[Ir] := 0.0;
      SlideSttR[Ir] := 0.0;
      SlideSzzR[Ir] := 0.0;
      SlideTrzR[Ir] := 0.0;
    end;

    if ZVal = 0.0 then
    begin
      for Ir := 0 to Nr - 1 do
      begin
        if Grid.RUm[Ir] = 0.0 then
          SlideSrrR[Ir] := 0.0
        else
        begin
          I1Sum := 0.0;
          I2Sum := 0.0;
          for P := 0 to M - 1 do
          begin
            if AP[P] <= 0.0 then
              Continue;
            Qj := MuFric * AP[P];
            I1Sum := I1Sum + Qj * (I1Disk(Grid.RUm[Ir], AREdge[P + 1]) - I1Disk(Grid.RUm[Ir], AREdge[P]));
            I2Sum := I2Sum + Qj * (I2Disk(Grid.RUm[Ir], AREdge[P + 1]) - I2Disk(Grid.RUm[Ir], AREdge[P]));
          end;
          SlideSrrR[Ir] := -2.0 * I1Sum - 2.0 * TopNu * I2Sum;
          SlideSttR[Ir] := -2.0 * TopNu * I1Sum + 2.0 * TopNu * I2Sum;
        end;
        SlideTrzR[Ir] := -MuFric * InterpolateRingPressure(Grid.RUm[Ir], ARBar, AP);
      end;

      if ASys.HasContrast then
      begin
        XiMax := Max(25.0 / ASys.Layers[0].ThicknessUm, 30.0 / RMax);
        XiMax := Min(XiMax, 600.0 / AContactRadius);
        NGL := 12;
        GaussLegendreRule(NGL, GLNodes, GLWeights);
        PanW := 2.0 * Pi / Max(RMax, 1.5 * AContactRadius);
        NPanels := Ceil(XiMax / PanW);
        if NPanels < 8 then
          NPanels := 8;
        PanW := XiMax / NPanels;
        for P := 0 to NPanels - 1 do
        begin
          Xi0 := P * PanW;
          Xi1 := (P + 1) * PanW;
          HalfW := 0.5 * (Xi1 - Xi0);
          Mid := 0.5 * (Xi0 + Xi1);
          for Q := 0 to NGL - 1 do
          begin
            Xi := Mid + HalfW * GLNodes[Q];
            QTildeSum := 0.0;
            PrevJ1 := 0.0;
            for LayerIdx := 0 to M - 1 do
            begin
              J1Val := AREdge[LayerIdx + 1] * BesselJ1(Xi * AREdge[LayerIdx + 1]);
              QTildeSum := QTildeSum + AP[LayerIdx] * (J1Val - PrevJ1);
              PrevJ1 := J1Val;
            end;
            QTildeSum := MuFric * QTildeSum / Xi;

            EvaluateCoatedCompliance(ASys, Xi, GCoated);
            GSH := EvaluateCoatedSHCompliance(ASys, Xi);
            UTopPsv := -GCoated[0, 0] * QTildeSum;
            VTopSH := GSH * QTildeSum;
            DeltaUPsv := UTopPsv - (-(1.0 - TopNu) / (TopMu * Xi)) * QTildeSum;
            DeltaUV := (UTopPsv + VTopSH) - (TopNu / (TopMu * Xi)) * QTildeSum;
            SigR0S := (2.0 * TopMu / (1.0 - TopNu)) * Xi * DeltaUPsv;
            SigT0S := (2.0 * TopMu * TopNu / (1.0 - TopNu)) * Xi * DeltaUPsv;
            for Ir := 1 to Nr - 1 do
            begin
              BesselJ012(Xi * Grid.RUm[Ir], C0, J1Val, J2Val);
              SlideSrrR[Ir] := SlideSrrR[Ir] + HalfW * GLWeights[Q] * Xi *
                (SigR0S * J1Val - 2.0 * TopMu * DeltaUV * (J2Val / Grid.RUm[Ir]));
              SlideSttR[Ir] := SlideSttR[Ir] + HalfW * GLWeights[Q] * Xi *
                (SigT0S * J1Val + 2.0 * TopMu * DeltaUV * (J2Val / Grid.RUm[Ir]));
            end;
          end;
        end;
      end;
    end
    else
    begin
      ZValPos := Max(ZVal, 0.01 * AContactRadius);
      XiMax := Max(28.0 / ZValPos, 40.0 / AContactRadius);
      if XiMax > 300.0 / AContactRadius then
        XiMax := 300.0 / AContactRadius;
      NGL := 12;
      GaussLegendreRule(NGL, GLNodes, GLWeights);
      PanW := 2.0 * Pi / Max(RMax, 1.5 * AContactRadius);
      NPanels := Ceil(XiMax / PanW);
      if NPanels < 8 then
        NPanels := 8;
      if NPanels > 90 then
        NPanels := 90;
      PanW := XiMax / NPanels;
      SetLength(XiArr, NPanels * NGL);
      SetLength(WtArr, NPanels * NGL);
      Q := 0;
      for P := 0 to NPanels - 1 do
      begin
        Xi0 := P * PanW;
        Xi1 := (P + 1) * PanW;
        HalfW := 0.5 * (Xi1 - Xi0);
        Mid := 0.5 * (Xi0 + Xi1);
        for LayerIdx := 0 to NGL - 1 do
        begin
          XiArr[Q] := Mid + HalfW * GLNodes[LayerIdx];
          WtArr[Q] := HalfW * GLWeights[LayerIdx];
          Inc(Q);
        end;
      end;

      for Q := 0 to High(XiArr) do
      begin
        Xi := XiArr[Q];
        QTildeSum := 0.0;
        PrevJ1 := 0.0;
        for LayerIdx := 0 to M - 1 do
        begin
          J1Val := AREdge[LayerIdx + 1] * BesselJ1(Xi * AREdge[LayerIdx + 1]);
          QTildeSum := QTildeSum + AP[LayerIdx] * (J1Val - PrevJ1);
          PrevJ1 := J1Val;
        end;
        QTildeSum := MuFric * QTildeSum / Xi;

        EvaluateCoatedCompliance(ASys, Xi, GCoated);
        GSH := EvaluateCoatedSHCompliance(ASys, Xi);
        UTopPsv := -GCoated[0, 0] * QTildeSum;
        WTopPsv := -GCoated[1, 0] * QTildeSum;
        VTopSH := GSH * QTildeSum;

        for LayerIdx := 0 to K - 1 do
        begin
          if LayerIdx >= N then
            Break;
          Mat2VecMul(ASys.Layers[LayerIdx].Tk, UTopPsv, WTopPsv, UBotPsv, WBotPsv);
          UTopPsv := UBotPsv;
          WTopPsv := WBotPsv;
          VTopSH := ASys.Layers[LayerIdx].Tsh * VTopSH;
        end;

        if K < N then
        begin
          BuildLayerStiffness(ASys.Layers[K], Xi, D1, D2, EExp, OneMinusE);
          Mat2VecMul(ASys.Layers[K].Tk, UTopPsv, WTopPsv, UBotPsv, WBotPsv);
          U1 := 0.5 * (UTopPsv + UBotPsv);
          W1 := 0.5 * (WTopPsv - WBotPsv);
          U2 := 0.5 * (UTopPsv - UBotPsv);
          W2 := 0.5 * (WTopPsv + WBotPsv);
          InvD1 := 1.0 / D1;
          InvD2 := 1.0 / D2;
          A1L := InvD1 * ((ASys.Layers[K].Kappa * OneMinusE - Xi * ASys.Layers[K].ThicknessUm * EExp) * U1 -
            (Xi * ASys.Layers[K].ThicknessUm * EExp) * W1);
          A2L := InvD1 * (-OneMinusE * U1 + (1.0 + EExp) * W1);
          B1L := InvD2 * ((ASys.Layers[K].Kappa * (1.0 + EExp) + Xi * ASys.Layers[K].ThicknessUm * EExp) * U2 +
            (Xi * ASys.Layers[K].ThicknessUm * EExp) * W2);
          B2L := InvD2 * (-(1.0 + EExp) * U2 + OneMinusE * W2);
          C1 := A1L + B1L;
          C2 := A2L + B2L;
          C3 := A1L - B1L;
          C4 := A2L - B2L;

          Eta := Xi * ASys.Layers[K].ThicknessUm;
          VBotSH := ASys.Layers[K].Tsh * VTopSH;
          Den := OneMinusExpNeg(2.0 * Eta);
          C1sh := (VTopSH - EExp * VBotSH) / Den;
          C2sh := (VBotSH - EExp * VTopSH) / Den;

          Eta1 := Xi * (ZVal - ASys.Layers[K].ZTopUm);
          Eta2 := Xi * (ASys.Layers[K].ZBotUm - ZVal);
          E1 := Exp(-Eta1);
          E2 := Exp(-Eta2);

          UVal := (C1 + Eta1 * C2) * E1 + (C3 + Eta2 * C4) * E2;
          SVal := -2.0 * Mu * Xi * ((C1 + (2.0 * (1.0 - Nu) + Eta1) * C2) * E1 +
            (C3 + (2.0 * (1.0 - Nu) + Eta2) * C4) * E2);
          TVal := -2.0 * Mu * Xi * ((C1 + (1.0 - 2.0 * Nu + Eta1) * C2) * E1 -
            (C3 + (1.0 - 2.0 * Nu + Eta2) * C4) * E2);
          VVal := C1sh * E1 + C2sh * E2;
          VpVal := Xi * (-C1sh * E1 + C2sh * E2);
        end
        else
        begin
          if N > 0 then
            Zeta := Xi * (ZVal - ASys.Layers[N - 1].ZBotUm)
          else
            Zeta := Xi * ZVal;
          E1 := Exp(-Zeta);
          C1 := UTopPsv;
          C2 := (WTopPsv - UTopPsv) / Kappa;
          UVal := (C1 + Zeta * C2) * E1;
          SVal := -2.0 * Mu * Xi * (C1 + (2.0 * (1.0 - Nu) + Zeta) * C2) * E1;
          TVal := -2.0 * Mu * Xi * (C1 + (1.0 - 2.0 * Nu + Zeta) * C2) * E1;
          VVal := VTopSH * E1;
          VpVal := -Xi * VTopSH * E1;
        end;

        SigR0S := (Nu / (1.0 - Nu)) * SVal + (2.0 * Mu / (1.0 - Nu)) * Xi * UVal;
        SigT0S := (Nu / (1.0 - Nu)) * SVal + (2.0 * Mu * Nu / (1.0 - Nu)) * Xi * UVal;

        for Ir := 0 to Nr - 1 do
        begin
          if Grid.RUm[Ir] = 0.0 then
          begin
            J1Val := 0.0;
            J1p := 0.5;
            J1OverXiR := 0.5;
            SlideTrzR[Ir] := SlideTrzR[Ir] + WtArr[Q] * Xi * (-TVal * J1p + Mu * VpVal * J1OverXiR);
          end
          else
          begin
            BesselJ012(Xi * Grid.RUm[Ir], C0, J1Val, J2Val);
            J1p := 0.5 * (C0 - J2Val);
            J1OverXiR := 0.5 * (C0 + J2Val);
            SlideSrrR[Ir] := SlideSrrR[Ir] + WtArr[Q] * Xi *
              (SigR0S * J1Val - 2.0 * Mu * (UVal + VVal) * (J2Val / Grid.RUm[Ir]));
            SlideSttR[Ir] := SlideSttR[Ir] + WtArr[Q] * Xi *
              (SigT0S * J1Val + 2.0 * Mu * (UVal + VVal) * (J2Val / Grid.RUm[Ir]));
            SlideSzzR[Ir] := SlideSzzR[Ir] + WtArr[Q] * Xi * SVal * J1Val;
            SlideTrzR[Ir] := SlideTrzR[Ir] + WtArr[Q] * Xi * (-TVal * J1p + Mu * VpVal * J1OverXiR);
          end;
        end;
      end;
    end;

    for Ir := 0 to Nr - 1 do
    begin
      IXPos := Nr - 1 + Ir;
      Sgn := 1.0;
      Sxx := Grid.SigmaRRGpa[Iz, Ir] + Sgn * SlideSrrR[Ir];
      Syy := Grid.SigmaTTGpa[Iz, Ir] + Sgn * SlideSttR[Ir];
      Szz := Grid.SigmaZZGpa[Iz, Ir] + Sgn * SlideSzzR[Ir];
      Txz := Sgn * Grid.TauRZGpa[Iz, Ir] + SlideTrzR[Ir];
      Svm := Sqrt(0.5 * (Sqr(Sxx - Syy) + Sqr(Syy - Szz) + Sqr(Szz - Sxx)) + 3.0 * Sqr(Txz));
      Grid.SlidingPlaneSigmaXXGpa[Iz, IXPos] := Sxx;
      Grid.SlidingPlaneTauXZGpa[Iz, IXPos] := Txz;
      Grid.SlidingPlaneSigmaVmGpa[Iz, IXPos] := Svm;
      if Svm > AMatMaxVm[K] then
        AMatMaxVm[K] := Svm;

      if Ir > 0 then
      begin
        IXNeg := Nr - 1 - Ir;
        Sgn := -1.0;
        Sxx := Grid.SigmaRRGpa[Iz, Ir] + Sgn * SlideSrrR[Ir];
        Syy := Grid.SigmaTTGpa[Iz, Ir] + Sgn * SlideSttR[Ir];
        Szz := Grid.SigmaZZGpa[Iz, Ir] + Sgn * SlideSzzR[Ir];
        Txz := Sgn * Grid.TauRZGpa[Iz, Ir] + SlideTrzR[Ir];
        Svm := Sqrt(0.5 * (Sqr(Sxx - Syy) + Sqr(Syy - Szz) + Sqr(Szz - Sxx)) + 3.0 * Sqr(Txz));
        Grid.SlidingPlaneSigmaXXGpa[Iz, IXNeg] := Sxx;
        Grid.SlidingPlaneTauXZGpa[Iz, IXNeg] := Txz;
        Grid.SlidingPlaneSigmaVmGpa[Iz, IXNeg] := Svm;
        if Svm > AMatMaxVm[K] then
          AMatMaxVm[K] := Svm;
      end;
    end;
  end;

  Grid.HasSliding := True;
  AResult.Diagnostics.Add('sliding_model=goodman_m1_harmonic (Dundurs normal-shear coupling neglected)');
end;

function SolveElasticLayered(const ACase: TContactCase): TContactResult;
var
  Timer: TStopwatch;
  HSub, HFilm: TContactResult;
  Sys: TSMMSystem;
  M, J, RegridCount, IterCount: Integer;
  RMax, Dr, ContactA, Delta, ForceErr, PMax, PMean, P0Extrap: Double;
  REdge, RBar, Area, HGap, P: TDoubleArray;
  D: TDoubleMatrix;
  UseExactGap: Boolean;
begin
  ACase.Validate;
  Timer := TStopwatch.StartNew;

  ComputeHertzBaselines(ACase, HSub, HFilm);
  try
    RMax := 2.0 * Max(HSub.ContactRadiusUm, HFilm.ContactRadiusUm);
  finally
    HFilm.Free;
    HSub.Free;
  end;

  InitSMMSystem(ACase, Sys);
  M := ACase.Solver.NRings;
  Result := TContactResult.Create;
  try
    Result.SolverName := 'elastic_layered';

    for RegridCount := 0 to 2 do
    begin
      SetLength(REdge, M + 1);
      SetLength(RBar, M);
      SetLength(Area, M);
      SetLength(HGap, M);
      Dr := RMax / M;
      for J := 0 to M do
        REdge[J] := J * Dr;
      UseExactGap := (RMax / ACase.Ball.RadiusUm) > 0.05;
      for J := 0 to M - 1 do
      begin
        RBar[J] := 0.5 * (REdge[J] + REdge[J + 1]);
        Area[J] := Pi * (Sqr(REdge[J + 1]) - Sqr(REdge[J]));
        if UseExactGap then
          HGap[J] := ACase.Ball.RadiusUm - Sqrt(Max(0.0, Sqr(ACase.Ball.RadiusUm) - Sqr(RBar[J])))
        else
          HGap[J] := Sqr(RBar[J]) / (2.0 * ACase.Ball.RadiusUm);
      end;

      BuildInfluenceMatrix(Sys, REdge, RBar, D);
      SolvePolonskyKeerCG(D, Area, RBar, HGap, ACase.LoadCase.NormalLoadMn,
        P, Delta, ForceErr, IterCount);
      ContactA := ComputeSubRingContactRadius(REdge, RBar, P);

      if (RegridCount < 2) and (ContactA > 0.0) and
         ((ContactA > 0.85 * RMax) or (ContactA < 0.25 * RMax)) then
      begin
        RMax := 1.6 * ContactA;
        Continue;
      end;
      Break;
    end;

    PMax := 0.0;
    for J := 0 to M - 1 do
      if P[J] > PMax then
        PMax := P[J];
    if (M >= 3) and (P[0] > P[1]) and (P[1] > P[2]) then
    begin
      P0Extrap := (9.0 / 8.0) * P[0] - 0.125 * P[1];
      if P0Extrap > PMax then
        PMax := P0Extrap;
    end;
    PMean := ACase.LoadCase.NormalLoadMn / (Pi * Sqr(ContactA));

    Result.ContactRadiusUm := ContactA;
    Result.PenetrationDepthUm := Delta;
    Result.PMaxGpa := PMax;
    Result.PMeanGpa := PMean;
    Result.ActualLoadMn := ACase.LoadCase.NormalLoadMn;
    Result.ForceBalanceErrorRel := ForceErr;
    Result.RUm := RBar;
    Result.PGpa := P;

    ComputeSubsurfaceStresses(Sys, ACase, REdge, RBar, P, ContactA, Result);

    Result.Diagnostics.Add(Format('n_rings=%d', [M]));
    Result.Diagnostics.Add(Format('r_max_um=%.6g', [RMax], TFormatSettings.Invariant));
    Result.Diagnostics.Add(Format('cg_iterations=%d', [IterCount]));
    Result.Diagnostics.Add(Format('regrid_count=%d', [RegridCount]));

    Timer.Stop;
    Result.RuntimeS := Timer.Elapsed.TotalSeconds;
  except
    Result.Free;
    raise;
  end;
end;

end.
