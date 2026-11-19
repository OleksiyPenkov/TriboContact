unit TriboContact.PlotRenderer;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.StrUtils, System.Types,
  Vcl.Graphics,
  TriboContact.Models, TriboContact.FemMesh, TriboContact.Runner;

type
  THeatmapField = (hfSigmaVm, hfSigmaRR, hfTauRZ, hfPeeq, hfSlidingSigmaXX);

function RenderPressureProfileBitmap(ABundle: TComparisonBundle;
  AWidth: Integer = 1000; AHeight: Integer = 640): TBitmap;
function RenderSubsurfaceHeatmapBitmap(ARes: TContactResult; const ACase: TContactCase;
  AField: THeatmapField; AWidth: Integer = 1000; AHeight: Integer = 640): TBitmap;
function RenderCenterlineProfileBitmap(ABundle: TComparisonBundle;
  AWidth: Integer = 1000; AHeight: Integer = 640): TBitmap;
function RenderLoadSweepBitmap(const APoints: TArray<TSweepPoint>;
  AWidth: Integer = 1100; AHeight: Integer = 760): TBitmap;
function RenderFemMeshBitmap(AMesh: TFemMesh; const ACase: TContactCase;
  AZoomContactZone: Boolean = True; AWidth: Integer = 1000; AHeight: Integer = 640): TBitmap;

implementation

type
  TRgbTriple = record
    R, G, B: Byte;
  end;

const
  ColBg: TColor = $00FFFFFF;
  ColPlotBg: TColor = $00FCFCFC;
  ColGrid: TColor = $00E6E6E6;
  ColAxis: TColor = $00404040;
  ColText: TColor = $00202020;
  ColHertzSub: TColor = $008C8C8C;
  ColHertzFilm: TColor = $003C8E38;
  ColElastic: TColor = $00B4771F;
  ColFem: TColor = $002827D6;
  ColElasticRR: TColor = $00A05010;
  ColFemRR: TColor = $001455C8;

  ViridisAnchors: array[0..8] of TRgbTriple = (
    (R: 68; G: 1; B: 84),
    (R: 71; G: 44; B: 122),
    (R: 59; G: 81; B: 139),
    (R: 44; G: 113; B: 142),
    (R: 33; G: 144; B: 141),
    (R: 39; G: 173; B: 129),
    (R: 92; G: 200; B: 99),
    (R: 170; G: 220; B: 50),
    (R: 253; G: 231; B: 37)
  );

  CoolwarmAnchors: array[0..8] of TRgbTriple = (
    (R: 59; G: 76; B: 192),
    (R: 98; G: 130; B: 234),
    (R: 141; G: 176; B: 254),
    (R: 184; G: 208; B: 249),
    (R: 221; G: 221; B: 221),
    (R: 245; G: 196; B: 173),
    (R: 244; G: 154; B: 123),
    (R: 222; G: 96; B: 77),
    (R: 180; G: 4; B: 38)
  );

var
  ViridisLUT: array[0..255] of TRgbTriple;
  CoolwarmLUT: array[0..255] of TRgbTriple;
  LutsReady: Boolean = False;

procedure EnsureColorLuts;
var
  I, Idx0, Idx1, CountAnchors: Integer;
  Pos, T: Double;
begin
  if LutsReady then
    Exit;
  CountAnchors := High(ViridisAnchors);
  for I := 0 to 255 do
  begin
    Pos := (I / 255.0) * CountAnchors;
    Idx0 := Trunc(Pos);
    if Idx0 >= CountAnchors then
      Idx0 := CountAnchors - 1;
    Idx1 := Idx0 + 1;
    T := Pos - Idx0;

    ViridisLUT[I].R := Round(ViridisAnchors[Idx0].R + T * (ViridisAnchors[Idx1].R - ViridisAnchors[Idx0].R));
    ViridisLUT[I].G := Round(ViridisAnchors[Idx0].G + T * (ViridisAnchors[Idx1].G - ViridisAnchors[Idx0].G));
    ViridisLUT[I].B := Round(ViridisAnchors[Idx0].B + T * (ViridisAnchors[Idx1].B - ViridisAnchors[Idx0].B));

    CoolwarmLUT[I].R := Round(CoolwarmAnchors[Idx0].R + T * (CoolwarmAnchors[Idx1].R - CoolwarmAnchors[Idx0].R));
    CoolwarmLUT[I].G := Round(CoolwarmAnchors[Idx0].G + T * (CoolwarmAnchors[Idx1].G - CoolwarmAnchors[Idx0].G));
    CoolwarmLUT[I].B := Round(CoolwarmAnchors[Idx0].B + T * (CoolwarmAnchors[Idx1].B - CoolwarmAnchors[Idx0].B));
  end;
  LutsReady := True;
end;

function CreateCanvasBitmap(AWidth, AHeight: Integer): TBitmap;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize(Max(200, AWidth), Max(160, AHeight));
  Result.Canvas.Font.Name := 'Segoe UI';
  Result.Canvas.Font.Size := 9;
  Result.Canvas.Brush.Color := ColBg;
  Result.Canvas.Brush.Style := bsSolid;
  Result.Canvas.FillRect(Rect(0, 0, Result.Width, Result.Height));
end;

function ComputeNiceStep(ARange: Double; ATargetTicks: Integer): Double;
var
  RawStep, Mag, Norm, Nice: Double;
begin
  if (not (ARange > 0.0)) or IsNan(ARange) or IsInfinite(ARange) then
    Exit(1.0);
  RawStep := ARange / Max(2, ATargetTicks);
  Mag := Power(10.0, Floor(Log10(RawStep)));
  Norm := RawStep / Mag;
  if Norm < 1.5 then
    Nice := 1.0
  else if Norm < 3.5 then
    Nice := 2.0
  else if Norm < 7.5 then
    Nice := 5.0
  else
    Nice := 10.0;
  Result := Nice * Mag;
end;

function FormatAxisVal(AVal, AStep: Double): string;
var
  Decimals: Integer;
begin
  if Abs(AVal) < 1e-12 * Max(1e-9, AStep) then
    AVal := 0.0;
  if AStep >= 100.0 then
    Decimals := 0
  else if AStep >= 1.0 then
    Decimals := 1
  else if AStep >= 0.1 then
    Decimals := 2
  else if AStep >= 0.01 then
    Decimals := 3
  else
    Decimals := 4;
  Result := Format('%.*f', [Decimals, AVal], TFormatSettings.Invariant);
end;

function MapX(AX, XMin, XMax: Double; const PR: TRect): Integer;
begin
  if XMax <= XMin then
    Exit(PR.Left);
  Result := PR.Left + Round((AX - XMin) / (XMax - XMin) * PR.Width);
end;

function MapY(AY, YMin, YMax: Double; const PR: TRect; InvertY: Boolean = False): Integer;
begin
  if YMax <= YMin then
    Exit(PR.Bottom);
  if InvertY then
    Result := PR.Top + Round((AY - YMin) / (YMax - YMin) * PR.Height)
  else
    Result := PR.Bottom - Round((AY - YMin) / (YMax - YMin) * PR.Height);
end;

procedure DrawAxesAndGrid(ACanvas: TCanvas; const PR: TRect;
  XMin, XMax, YMin, YMax: Double; const AXTitle, AYTitle, ATitle: string;
  InvertY: Boolean = False);
var
  StepX, StepY, V, StartV: Double;
  Px, Py, Tw, Th: Integer;
  S: string;
begin
  ACanvas.Brush.Color := ColPlotBg;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.FillRect(PR);

  StepX := ComputeNiceStep(XMax - XMin, 6);
  StepY := ComputeNiceStep(YMax - YMin, 5);

  ACanvas.Font.Color := ColText;
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := 9;
  ACanvas.Brush.Style := bsClear;

  StartV := Ceil(XMin / StepX - 1e-9) * StepX;
  V := StartV;
  while V <= XMax + 1e-9 * StepX do
  begin
    Px := MapX(V, XMin, XMax, PR);
    ACanvas.Pen.Color := ColGrid;
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Width := 1;
    ACanvas.MoveTo(Px, PR.Top);
    ACanvas.LineTo(Px, PR.Bottom);
    ACanvas.Pen.Color := ColAxis;
    ACanvas.MoveTo(Px, PR.Bottom);
    ACanvas.LineTo(Px, PR.Bottom + 5);
    S := FormatAxisVal(V, StepX);
    Tw := ACanvas.TextWidth(S);
    ACanvas.TextOut(Px - Tw div 2, PR.Bottom + 7, S);
    V := V + StepX;
  end;

  StartV := Ceil(YMin / StepY - 1e-9) * StepY;
  V := StartV;
  while V <= YMax + 1e-9 * StepY do
  begin
    Py := MapY(V, YMin, YMax, PR, InvertY);
    ACanvas.Pen.Color := ColGrid;
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Width := 1;
    ACanvas.MoveTo(PR.Left, Py);
    ACanvas.LineTo(PR.Right, Py);
    ACanvas.Pen.Color := ColAxis;
    ACanvas.MoveTo(PR.Left - 5, Py);
    ACanvas.LineTo(PR.Left, Py);
    S := FormatAxisVal(V, StepY);
    Tw := ACanvas.TextWidth(S);
    Th := ACanvas.TextHeight(S);
    ACanvas.TextOut(PR.Left - 8 - Tw, Py - Th div 2, S);
    V := V + StepY;
  end;

  ACanvas.Pen.Color := ColAxis;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Width := 1;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(PR.Left, PR.Top, PR.Right + 1, PR.Bottom + 1);

  if ATitle <> '' then
  begin
    ACanvas.Font.Style := [fsBold];
    ACanvas.Font.Size := 11;
    Tw := ACanvas.TextWidth(ATitle);
    ACanvas.TextOut(PR.Left + (PR.Width - Tw) div 2, PR.Top - 28, ATitle);
  end;

  ACanvas.Font.Style := [];
  ACanvas.Font.Size := 9;
  if AXTitle <> '' then
  begin
    Tw := ACanvas.TextWidth(AXTitle);
    ACanvas.TextOut(PR.Left + (PR.Width - Tw) div 2, PR.Bottom + 27, AXTitle);
  end;

  if AYTitle <> '' then
    ACanvas.TextOut(10, PR.Top - 22, AYTitle);
end;

procedure DrawPolylineInRect(ACanvas: TCanvas; const PR: TRect;
  const AX, AY: TDoubleArray; XMin, XMax, YMin, YMax: Double;
  AColor: TColor; AStyle: TPenStyle; AWidth: Integer; InvertY: Boolean = False);
var
  Pts: TArray<TPoint>;
  I, N: Integer;
begin
  N := Min(Length(AX), Length(AY));
  if N < 2 then
    Exit;
  SetLength(Pts, N);
  for I := 0 to N - 1 do
  begin
    Pts[I].X := EnsureRange(MapX(AX[I], XMin, XMax, PR), PR.Left, PR.Right);
    Pts[I].Y := EnsureRange(MapY(AY[I], YMin, YMax, PR, InvertY), PR.Top, PR.Bottom);
  end;
  ACanvas.Pen.Color := AColor;
  ACanvas.Pen.Style := AStyle;
  ACanvas.Pen.Width := AWidth;
  ACanvas.Polyline(Pts);
end;

procedure DrawLegend(ACanvas: TCanvas; AX, AY: Integer;
  const ALabels: TArray<string>; const AColors: TArray<TColor>; const AStyles: TArray<TPenStyle>);
var
  I, MaxW, RowH, BoxW, BoxH, YRow: Integer;
begin
  if Length(ALabels) = 0 then
    Exit;
  ACanvas.Font.Size := 8;
  ACanvas.Font.Style := [];
  MaxW := 0;
  for I := 0 to High(ALabels) do
    MaxW := Max(MaxW, ACanvas.TextWidth(ALabels[I]));
  RowH := 18;
  BoxW := MaxW + 46;
  BoxH := Length(ALabels) * RowH + 10;

  ACanvas.Brush.Color := ColBg;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Pen.Color := $00C0C0C0;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Width := 1;
  ACanvas.Rectangle(AX, AY, AX + BoxW, AY + BoxH);

  ACanvas.Brush.Style := bsClear;
  for I := 0 to High(ALabels) do
  begin
    YRow := AY + 6 + I * RowH;
    ACanvas.Pen.Color := AColors[I];
    ACanvas.Pen.Style := AStyles[I];
    ACanvas.Pen.Width := 2;
    ACanvas.MoveTo(AX + 8, YRow + 7);
    ACanvas.LineTo(AX + 30, YRow + 7);
    ACanvas.Font.Color := ColText;
    ACanvas.TextOut(AX + 36, YRow, ALabels[I]);
  end;
end;

function RenderPressureProfileBitmap(ABundle: TComparisonBundle;
  AWidth, AHeight: Integer): TBitmap;
var
  PR: TRect;
  MaxR, MaxP: Double;
  ResList: array[0..3] of TContactResult;
  Labels: TArray<string>;
  Colors: TArray<TColor>;
  Styles: TArray<TPenStyle>;
  Names: array[0..3] of string;
  CCols: array[0..3] of TColor;
  CStyles: array[0..3] of TPenStyle;
  K, I, Cnt: Integer;
  R: TContactResult;
begin
  Result := CreateCanvasBitmap(AWidth, AHeight);
  try
    PR := Rect(78, 48, Result.Width - 28, Result.Height - 54);
    if ABundle = nil then
    begin
      DrawAxesAndGrid(Result.Canvas, PR, 0, 10, 0, 1, 'r (um)', 'p (GPa)', 'Contact Pressure Profile');
      Exit;
    end;

    ResList[0] := ABundle.HertzSubstrate;
    ResList[1] := ABundle.HertzTopFilm;
    ResList[2] := ABundle.ElasticLayered;
    ResList[3] := ABundle.FemCalculix;
    Names[0] := 'Hertz Substrate';
    Names[1] := 'Hertz Top Film';
    Names[2] := 'Elastic Layered';
    Names[3] := 'CalculiX FEM';
    CCols[0] := ColHertzSub;
    CCols[1] := ColHertzFilm;
    CCols[2] := ColElastic;
    CCols[3] := ColFem;
    CStyles[0] := psDash;
    CStyles[1] := psDot;
    CStyles[2] := psSolid;
    CStyles[3] := psSolid;

    MaxR := 1.0;
    MaxP := 0.1;
    for K := 0 to 3 do
    begin
      R := ResList[K];
      if R = nil then
        Continue;
      if R.ContactRadiusUm > 0.0 then
        MaxR := Max(MaxR, 1.5 * R.ContactRadiusUm);
      for I := 0 to High(R.PGpa) do
        if R.PGpa[I] > MaxP then
          MaxP := R.PGpa[I];
    end;
    MaxP := MaxP * 1.12;

    DrawAxesAndGrid(Result.Canvas, PR, 0.0, MaxR, 0.0, MaxP,
      'Radial coordinate r (um)', 'Pressure p (GPa)',
      'Contact Pressure Profile: ' + ABundle.CaseName);

    SetLength(Labels, 4);
    SetLength(Colors, 4);
    SetLength(Styles, 4);
    Cnt := 0;
    for K := 0 to 3 do
    begin
      R := ResList[K];
      if (R = nil) or (Length(R.RUm) < 2) then
        Continue;
      DrawPolylineInRect(Result.Canvas, PR, R.RUm, R.PGpa, 0.0, MaxR, 0.0, MaxP,
        CCols[K], CStyles[K], 2);
      Labels[Cnt] := Names[K];
      Colors[Cnt] := CCols[K];
      Styles[Cnt] := CStyles[K];
      Inc(Cnt);
    end;
    SetLength(Labels, Cnt);
    SetLength(Colors, Cnt);
    SetLength(Styles, Cnt);
    DrawLegend(Result.Canvas, PR.Right - 175, PR.Top + 10, Labels, Colors, Styles);
  except
    Result.Free;
    raise;
  end;
end;

function SampleMatrixBilinear(const XArr, ZArr: TDoubleArray; const Mat: TDoubleMatrix;
  X, Z: Double): Double;
var
  Ix, Iz, Ix1, Iz1, Nx, Nz: Integer;
  Tx, Tz, V00, V01, V10, V11: Double;
begin
  Nx := Length(XArr);
  Nz := Length(ZArr);
  if (Nx = 0) or (Nz = 0) or (Length(Mat) = 0) then
    Exit(0.0);

  if X <= XArr[0] then
    Ix := 0
  else if X >= XArr[Nx - 1] then
    Ix := Nx - 2
  else
  begin
    Ix := 0;
    while (Ix < Nx - 2) and (X > XArr[Ix + 1]) do
      Inc(Ix);
  end;
  Ix := EnsureRange(Ix, 0, Max(0, Nx - 2));
  Ix1 := Min(Nx - 1, Ix + 1);
  if (Ix1 > Ix) and (XArr[Ix1] > XArr[Ix]) then
    Tx := EnsureRange((X - XArr[Ix]) / (XArr[Ix1] - XArr[Ix]), 0.0, 1.0)
  else
    Tx := 0.0;

  if Z <= ZArr[0] then
    Iz := 0
  else if Z >= ZArr[Nz - 1] then
    Iz := Nz - 2
  else
  begin
    Iz := 0;
    while Iz < Nz - 2 do
    begin
      if ZArr[Iz + 1] <= ZArr[Iz] + 1e-12 then
      begin
        if Z > ZArr[Iz] + 1e-12 then
        begin
          Inc(Iz);
          Continue;
        end
        else
          Break;
      end;
      if Z <= ZArr[Iz + 1] then
        Break;
      Inc(Iz);
    end;
    if (Iz < Nz - 1) and (ZArr[Iz + 1] <= ZArr[Iz] + 1e-12) and (Iz + 2 < Nz) then
      Inc(Iz);
  end;
  Iz := EnsureRange(Iz, 0, Max(0, Nz - 2));
  Iz1 := Min(Nz - 1, Iz + 1);
  if (Iz1 > Iz) and (ZArr[Iz1] > ZArr[Iz] + 1e-12) then
    Tz := EnsureRange((Z - ZArr[Iz]) / (ZArr[Iz1] - ZArr[Iz]), 0.0, 1.0)
  else
    Tz := 0.0;

  V00 := Mat[Iz, Ix];
  V01 := Mat[Iz, Ix1];
  V10 := Mat[Iz1, Ix];
  V11 := Mat[Iz1, Ix1];
  Result := (1.0 - Tz) * ((1.0 - Tx) * V00 + Tx * V01) +
            Tz * ((1.0 - Tx) * V10 + Tx * V11);
end;

function RenderSubsurfaceHeatmapBitmap(ARes: TContactResult; const ACase: TContactCase;
  AField: THeatmapField; AWidth, AHeight: Integer): TBitmap;
var
  PR, CB: TRect;
  Grid: TStressGrid;
  XArr, ZArr: TDoubleArray;
  Mat: TDoubleMatrix;
  Diverging: Boolean;
  FieldName: string;
  XMin, XMax, ZMin, ZMax, VMin, VMax, VAbs, V, T, ZCum: Double;
  Px, Py, I, J, LutIdx, K: Integer;
  RowPtr: PByteArray;
  C: TRgbTriple;
  WMax: Integer;
begin
  EnsureColorLuts;
  Result := CreateCanvasBitmap(AWidth, AHeight);
  try
    PR := Rect(78, 48, Result.Width - 110, Result.Height - 54);
    CB := Rect(PR.Right + 18, PR.Top, PR.Right + 38, PR.Bottom);

    if (ARes = nil) or (ARes.StressGrid = nil) then
    begin
      DrawAxesAndGrid(Result.Canvas, PR, 0, 10, 0, 10, 'r (um)', 'z (um)',
        '2D Subsurface Stress Heatmap (no grid)', True);
      Exit;
    end;

    Grid := ARes.StressGrid;
    Diverging := False;
    XArr := Grid.RUm;
    ZArr := Grid.ZUm;

    case AField of
      hfSigmaRR:
        begin
          Mat := Grid.SigmaRRGpa;
          Diverging := True;
          FieldName := 'Sigma_rr (GPa)';
        end;
      hfTauRZ:
        begin
          Mat := Grid.TauRZGpa;
          Diverging := True;
          FieldName := 'Tau_rz (GPa)';
        end;
      hfPeeq:
        begin
          if Grid.HasPeeq then
            Mat := Grid.Peeq
          else
            Mat := Grid.SigmaVmGpa;
          FieldName := 'PEEQ';
        end;
      hfSlidingSigmaXX:
        begin
          if Grid.HasSliding and (Length(Grid.SlidingPlaneXUm) > 1) and (Length(Grid.SlidingPlaneSigmaXXGpa) > 0) then
          begin
            XArr := Grid.SlidingPlaneXUm;
            Mat := Grid.SlidingPlaneSigmaXXGpa;
            Diverging := True;
            FieldName := 'Sliding Sigma_xx (GPa)';
          end
          else
          begin
            Mat := Grid.SigmaRRGpa;
            Diverging := True;
            FieldName := 'Sigma_rr (GPa)';
          end;
        end;
    else
      Mat := Grid.SigmaVmGpa;
      FieldName := 'von Mises Stress (GPa)';
    end;

    if (Length(XArr) < 2) or (Length(ZArr) < 2) or (Length(Mat) < 2) then
    begin
      DrawAxesAndGrid(Result.Canvas, PR, 0, 10, 0, 10, 'r (um)', 'z (um)', FieldName, True);
      Exit;
    end;

    XMin := XArr[0];
    XMax := XArr[High(XArr)];
    ZMin := ZArr[0];
    ZMax := ZArr[High(ZArr)];

    VMin := Infinity;
    VMax := -Infinity;
    WMax := Min(Length(XArr), Length(Mat[0]));
    for I := 0 to Min(High(ZArr), High(Mat)) do
      for J := 0 to WMax - 1 do
      begin
        if Mat[I, J] < VMin then VMin := Mat[I, J];
        if Mat[I, J] > VMax then VMax := Mat[I, J];
      end;
    if Diverging then
    begin
      VAbs := Max(Max(Abs(VMin), Abs(VMax)), 1e-6);
      VMin := -VAbs;
      VMax := VAbs;
    end
    else
    begin
      if VMax <= VMin then
        VMax := VMin + 1e-6;
    end;

    DrawAxesAndGrid(Result.Canvas, PR, XMin, XMax, ZMin, ZMax,
      IfThen(AField = hfSlidingSigmaXX, 'Sliding x (um)', 'Radial r (um)'),
      'Depth z (um)', Format('%s - %s', [FieldName, ARes.SolverName]), True);

    for Py := PR.Top + 1 to PR.Bottom - 1 do
    begin
      ZCum := ZMin + ((Py - PR.Top) / Max(1, PR.Height)) * (ZMax - ZMin);
      RowPtr := Result.ScanLine[Py];
      for Px := PR.Left + 1 to PR.Right - 1 do
      begin
        V := SampleMatrixBilinear(XArr, ZArr, Mat,
          XMin + ((Px - PR.Left) / Max(1, PR.Width)) * (XMax - XMin), ZCum);
        T := EnsureRange((V - VMin) / Max(1e-12, VMax - VMin), 0.0, 1.0);
        LutIdx := EnsureRange(Round(T * 255.0), 0, 255);
        if Diverging then
          C := CoolwarmLUT[LutIdx]
        else
          C := ViridisLUT[LutIdx];
        RowPtr[3 * Px] := C.B;
        RowPtr[3 * Px + 1] := C.G;
        RowPtr[3 * Px + 2] := C.R;
      end;
    end;

    ZCum := 0.0;
    for K := 0 to High(ACase.Layers) do
    begin
      ZCum := ZCum + ACase.Layers[K].ThicknessUm;
      if (ZCum > ZMin) and (ZCum < ZMax) then
      begin
        Py := MapY(ZCum, ZMin, ZMax, PR, True);
        Result.Canvas.Pen.Color := clWhite;
        Result.Canvas.Pen.Style := psDash;
        Result.Canvas.Pen.Width := 2;
        Result.Canvas.MoveTo(PR.Left + 1, Py);
        Result.Canvas.LineTo(PR.Right - 1, Py);
      end;
    end;

    Result.Canvas.Pen.Color := ColAxis;
    Result.Canvas.Pen.Style := psSolid;
    Result.Canvas.Pen.Width := 1;
    Result.Canvas.Brush.Style := bsClear;
    Result.Canvas.Rectangle(PR.Left, PR.Top, PR.Right + 1, PR.Bottom + 1);

    for Py := CB.Top to CB.Bottom do
    begin
      T := 1.0 - (Py - CB.Top) / Max(1, CB.Height);
      LutIdx := EnsureRange(Round(T * 255.0), 0, 255);
      if Diverging then
        C := CoolwarmLUT[LutIdx]
      else
        C := ViridisLUT[LutIdx];
      RowPtr := Result.ScanLine[Py];
      for Px := CB.Left to CB.Right do
      begin
        RowPtr[3 * Px] := C.B;
        RowPtr[3 * Px + 1] := C.G;
        RowPtr[3 * Px + 2] := C.R;
      end;
    end;
    Result.Canvas.Rectangle(CB.Left, CB.Top, CB.Right + 1, CB.Bottom + 1);

    Result.Canvas.Font.Size := 8;
    Result.Canvas.Font.Color := ColText;
    Result.Canvas.TextOut(CB.Right + 6, CB.Top - 4, Format('%.4g', [VMax], TFormatSettings.Invariant));
    Result.Canvas.TextOut(CB.Right + 6, (CB.Top + CB.Bottom) div 2 - 7,
      Format('%.4g', [0.5 * (VMin + VMax)], TFormatSettings.Invariant));
    Result.Canvas.TextOut(CB.Right + 6, CB.Bottom - 10, Format('%.4g', [VMin], TFormatSettings.Invariant));
  except
    Result.Free;
    raise;
  end;
end;

function RenderCenterlineProfileBitmap(ABundle: TComparisonBundle;
  AWidth, AHeight: Integer): TBitmap;
var
  PR: TRect;
  El, Fem: TContactResult;
  MinS, MaxS, MaxZ, ZCum: Double;
  I, K, Py, Cnt: Integer;
  Labels: TArray<string>;
  Colors: TArray<TColor>;
  Styles: TArray<TPenStyle>;
  procedure ScanMinMax(R: TContactResult);
  var
    J: Integer;
  begin
    if R = nil then
      Exit;
    for J := 0 to High(R.ZCenterlineUm) do
      if R.ZCenterlineUm[J] > MaxZ then
        MaxZ := R.ZCenterlineUm[J];
    for J := 0 to High(R.CenterlineSigmaVmGpa) do
    begin
      if R.CenterlineSigmaVmGpa[J] < MinS then MinS := R.CenterlineSigmaVmGpa[J];
      if R.CenterlineSigmaVmGpa[J] > MaxS then MaxS := R.CenterlineSigmaVmGpa[J];
    end;
    for J := 0 to High(R.CenterlineSigmaRRGpa) do
    begin
      if R.CenterlineSigmaRRGpa[J] < MinS then MinS := R.CenterlineSigmaRRGpa[J];
      if R.CenterlineSigmaRRGpa[J] > MaxS then MaxS := R.CenterlineSigmaRRGpa[J];
    end;
  end;
begin
  Result := CreateCanvasBitmap(AWidth, AHeight);
  try
    PR := Rect(78, 48, Result.Width - 28, Result.Height - 54);
    if ABundle = nil then
    begin
      DrawAxesAndGrid(Result.Canvas, PR, -1, 1, 0, 10, 'Stress (GPa)', 'Depth z (um)', 'Centerline Profile', True);
      Exit;
    end;

    El := ABundle.ElasticLayered;
    Fem := ABundle.FemCalculix;
    MinS := 0.0;
    MaxS := 0.2;
    MaxZ := 1.0;
    ScanMinMax(El);
    ScanMinMax(Fem);
    if MaxS <= MinS then
      MaxS := MinS + 1.0;
    MinS := MinS * 1.1;
    MaxS := MaxS * 1.1;

    DrawAxesAndGrid(Result.Canvas, PR, MinS, MaxS, 0.0, MaxZ,
      'Centerline Stress at r=0 (GPa)', 'Depth z (um)',
      'Centerline Stress Depth Profile: ' + ABundle.CaseName, True);

    if (MinS < 0.0) and (MaxS > 0.0) then
    begin
      I := MapX(0.0, MinS, MaxS, PR);
      Result.Canvas.Pen.Color := $00A0A0A0;
      Result.Canvas.Pen.Style := psDot;
      Result.Canvas.Pen.Width := 1;
      Result.Canvas.MoveTo(I, PR.Top);
      Result.Canvas.LineTo(I, PR.Bottom);
    end;

    ZCum := 0.0;
    for K := 0 to High(ABundle.Layers) do
    begin
      ZCum := ZCum + ABundle.Layers[K].ThicknessUm;
      if ZCum < MaxZ then
      begin
        Py := MapY(ZCum, 0.0, MaxZ, PR, True);
        Result.Canvas.Pen.Color := $00707070;
        Result.Canvas.Pen.Style := psDash;
        Result.Canvas.Pen.Width := 1;
        Result.Canvas.MoveTo(PR.Left, Py);
        Result.Canvas.LineTo(PR.Right, Py);
      end;
    end;

    SetLength(Labels, 4);
    SetLength(Colors, 4);
    SetLength(Styles, 4);
    Cnt := 0;

    if El <> nil then
    begin
      DrawPolylineInRect(Result.Canvas, PR, El.CenterlineSigmaVmGpa, El.ZCenterlineUm,
        MinS, MaxS, 0.0, MaxZ, ColElastic, psSolid, 2, True);
      Labels[Cnt] := 'Elastic sigma_vM'; Colors[Cnt] := ColElastic; Styles[Cnt] := psSolid; Inc(Cnt);
      DrawPolylineInRect(Result.Canvas, PR, El.CenterlineSigmaRRGpa, El.ZCenterlineUm,
        MinS, MaxS, 0.0, MaxZ, ColElasticRR, psDash, 2, True);
      Labels[Cnt] := 'Elastic sigma_rr'; Colors[Cnt] := ColElasticRR; Styles[Cnt] := psDash; Inc(Cnt);
    end;

    if Fem <> nil then
    begin
      DrawPolylineInRect(Result.Canvas, PR, Fem.CenterlineSigmaVmGpa, Fem.ZCenterlineUm,
        MinS, MaxS, 0.0, MaxZ, ColFem, psSolid, 2, True);
      Labels[Cnt] := 'FEM sigma_vM'; Colors[Cnt] := ColFem; Styles[Cnt] := psSolid; Inc(Cnt);
      DrawPolylineInRect(Result.Canvas, PR, Fem.CenterlineSigmaRRGpa, Fem.ZCenterlineUm,
        MinS, MaxS, 0.0, MaxZ, ColFemRR, psDash, 2, True);
      Labels[Cnt] := 'FEM sigma_rr'; Colors[Cnt] := ColFemRR; Styles[Cnt] := psDash; Inc(Cnt);
    end;

    SetLength(Labels, Cnt);
    SetLength(Colors, Cnt);
    SetLength(Styles, Cnt);
    DrawLegend(Result.Canvas, PR.Right - 165, PR.Top + 10, Labels, Colors, Styles);
  except
    Result.Free;
    raise;
  end;
end;

function RenderLoadSweepBitmap(const APoints: TArray<TSweepPoint>;
  AWidth, AHeight: Integer): TBitmap;
var
  Loads, YEl, YFem, YHs, YHf: TDoubleArray;
  I, K, SubW, SubH, Col, Row, Py: Integer;
  XMin, XMax, YMin, YMax: Double;
  PR: TRect;
  AnyFem: Boolean;
  Titles, YTitles: array[0..3] of string;
  Labels: TArray<string>;
  Colors: TArray<TColor>;
  Styles: TArray<TPenStyle>;
begin
  Result := CreateCanvasBitmap(AWidth, AHeight);
  try
    if Length(APoints) = 0 then
    begin
      PR := Rect(78, 48, Result.Width - 28, Result.Height - 54);
      DrawAxesAndGrid(Result.Canvas, PR, 0, 10, 0, 1, 'Load F_N (mN)', 'Metric', 'Load Sweep');
      Exit;
    end;

    SetLength(Loads, Length(APoints));
    SetLength(YEl, Length(APoints));
    SetLength(YFem, Length(APoints));
    SetLength(YHs, Length(APoints));
    SetLength(YHf, Length(APoints));

    XMin := APoints[0].NormalLoadMn;
    XMax := APoints[0].NormalLoadMn;
    AnyFem := False;
    for I := 0 to High(APoints) do
    begin
      Loads[I] := APoints[I].NormalLoadMn;
      if Loads[I] < XMin then XMin := Loads[I];
      if Loads[I] > XMax then XMax := Loads[I];
      if APoints[I].HasFem then AnyFem := True;
    end;
    if XMax <= XMin then
    begin
      XMin := 0.0;
      XMax := XMax + 1.0;
    end;

    Titles[0] := 'Peak Pressure p_max vs F_N'; YTitles[0] := 'p_max (GPa)';
    Titles[1] := 'Mean Pressure p_mean vs F_N'; YTitles[1] := 'p_mean (GPa)';
    Titles[2] := 'Contact Radius a vs F_N'; YTitles[2] := 'a (um)';
    Titles[3] := 'Max Yield Ratio (sigma_vM / sigma_Y)'; YTitles[3] := 'Yield Ratio';

    SubW := Result.Width div 2;
    SubH := Result.Height div 2;

    for Row := 0 to 1 do
      for Col := 0 to 1 do
      begin
        K := Row * 2 + Col;
        PR := Rect(Col * SubW + 68, Row * SubH + 40, (Col + 1) * SubW - 22, (Row + 1) * SubH - 48);
        YMin := 0.0;
        YMax := 0.1;
        for I := 0 to High(APoints) do
        begin
          case K of
            0:
              begin
                YEl[I] := APoints[I].ElasticPMaxGpa;
                YFem[I] := APoints[I].FemPMaxGpa;
                YHs[I] := APoints[I].HertzSubPMaxGpa;
                YHf[I] := APoints[I].HertzFilmPMaxGpa;
                YMax := Max(YMax, Max(Max(YEl[I], YHf[I]), YHs[I]));
              end;
            1:
              begin
                YEl[I] := APoints[I].ElasticPMeanGpa;
                YFem[I] := APoints[I].FemPMeanGpa;
                YMax := Max(YMax, YEl[I]);
              end;
            2:
              begin
                YEl[I] := APoints[I].ElasticRadiusUm;
                YFem[I] := APoints[I].FemRadiusUm;
                YMax := Max(YMax, YEl[I]);
              end;
          else
            YEl[I] := APoints[I].ElasticMaxYieldRatio;
            YFem[I] := APoints[I].FemMaxYieldRatio;
            YMax := Max(YMax, Max(1.2, YEl[I]));
          end;
          if AnyFem and (YFem[I] > YMax) then
            YMax := YFem[I];
        end;
        YMax := YMax * 1.12;

        DrawAxesAndGrid(Result.Canvas, PR, XMin, XMax, YMin, YMax,
          'F_N (mN)', YTitles[K], Titles[K]);

        if K = 0 then
        begin
          DrawPolylineInRect(Result.Canvas, PR, Loads, YHs, XMin, XMax, YMin, YMax, ColHertzSub, psDash, 2);
          DrawPolylineInRect(Result.Canvas, PR, Loads, YHf, XMin, XMax, YMin, YMax, ColHertzFilm, psDot, 2);
        end;
        DrawPolylineInRect(Result.Canvas, PR, Loads, YEl, XMin, XMax, YMin, YMax, ColElastic, psSolid, 2);
        if AnyFem then
          DrawPolylineInRect(Result.Canvas, PR, Loads, YFem, XMin, XMax, YMin, YMax, ColFem, psSolid, 2);

        if K = 3 then
        begin
          Py := MapY(1.0, YMin, YMax, PR);
          Result.Canvas.Pen.Color := ColFem;
          Result.Canvas.Pen.Style := psDash;
          Result.Canvas.Pen.Width := 1;
          Result.Canvas.MoveTo(PR.Left, Py);
          Result.Canvas.LineTo(PR.Right, Py);
        end;

        if K = 0 then
        begin
          if AnyFem then
          begin
            Labels := ['Hertz Sub', 'Hertz Film', 'Elastic', 'FEM'];
            Colors := [ColHertzSub, ColHertzFilm, ColElastic, ColFem];
            Styles := [psDash, psDot, psSolid, psSolid];
          end
          else
          begin
            Labels := ['Hertz Sub', 'Hertz Film', 'Elastic'];
            Colors := [ColHertzSub, ColHertzFilm, ColElastic];
            Styles := [psDash, psDot, psSolid];
          end;
          DrawLegend(Result.Canvas, PR.Right - 135, PR.Top + 6, Labels, Colors, Styles);
        end;
      end;
  except
    Result.Free;
    raise;
  end;
end;

function RenderFemMeshBitmap(AMesh: TFemMesh; const ACase: TContactCase;
  AZoomContactZone: Boolean; AWidth, AHeight: Integer): TBitmap;
const
  LayerColors: array[0..4] of TColor = ($00F0C28C, $00B2DF8A, $00A6CEE3, $00D9B3FF, $0099E6FF);
  SubColor: TColor = $00E8E8E8;
  BallColor: TColor = $00FFD8B0;
var
  PR: TRect;
  XMin, XMax, YMin, YMax, Span, CX, CY, Scale: Double;
  I, Reg: Integer;
  Q: TMeshQuad;
  N1, N2, N3, N4: TMeshNode;
  Pts: array[0..3] of TPoint;
  function ToScreenX(RX: Double): Integer;
  begin
    Result := Round(CX + (RX - XMin) * Scale);
  end;
  function ToScreenY(RY: Double): Integer;
  begin
    Result := Round(CY - (RY - YMax) * Scale);
  end;
begin
  Result := CreateCanvasBitmap(AWidth, AHeight);
  try
    PR := Rect(78, 48, Result.Width - 28, Result.Height - 54);
    if AMesh = nil then
    begin
      DrawAxesAndGrid(Result.Canvas, PR, 0, 10, -10, 5, 'r (um)', 'y (um)', 'FEM Mesh Preview');
      Exit;
    end;

    if AZoomContactZone then
    begin
      XMin := 0.0;
      XMax := Max(AMesh.RFineUm, 2.2 * AMesh.EstRadiusUm);
      YMin := -Max(1.8 * ACase.TotalCoatingThicknessUm, 1.8 * AMesh.EstRadiusUm);
      YMax := 0.6 * XMax;
    end
    else
    begin
      XMin := 0.0;
      XMax := AMesh.RDomUm;
      YMin := -(ACase.TotalCoatingThicknessUm + AMesh.HSubUm);
      YMax := 0.25 * AMesh.RDomUm;
    end;

    Span := Max(XMax - XMin, YMax - YMin);
    if not AZoomContactZone then
    begin
      XMax := XMin + Span;
      YMin := YMax - Span;
    end;

    DrawAxesAndGrid(Result.Canvas, PR, XMin, XMax, YMin, YMax,
      'Radial coordinate r (um)', 'Axial coordinate y (um)',
      IfThen(AZoomContactZone, 'FEM Mesh Preview (Contact Zone Zoom)', 'FEM Mesh Preview (Full Domain)'));

    Scale := Min(PR.Width / Max(1e-9, XMax - XMin), PR.Height / Max(1e-9, YMax - YMin));
    CX := PR.Left;
    CY := PR.Top;

    Result.Canvas.Pen.Color := $00686868;
    Result.Canvas.Pen.Style := psSolid;
    Result.Canvas.Pen.Width := 1;
    Result.Canvas.Brush.Style := bsSolid;

    for I := 0 to High(AMesh.Quads) do
    begin
      Q := AMesh.Quads[I];
      N1 := AMesh.Nodes[Q.N1 - 1];
      N2 := AMesh.Nodes[Q.N2 - 1];
      N3 := AMesh.Nodes[Q.N3 - 1];
      N4 := AMesh.Nodes[Q.N4 - 1];

      if (Max(Max(N1.R, N2.R), Max(N3.R, N4.R)) < XMin) or
         (Min(Min(N1.R, N2.R), Min(N3.R, N4.R)) > XMax) or
         (Max(Max(N1.Y, N2.Y), Max(N3.Y, N4.Y)) < YMin) or
         (Min(Min(N1.Y, N2.Y), Min(N3.Y, N4.Y)) > YMax) then
        Continue;

      if Q.IsBall then
        Result.Canvas.Brush.Color := BallColor
      else
      begin
        Reg := Q.RegionId;
        if Reg < Length(ACase.Layers) then
          Result.Canvas.Brush.Color := LayerColors[Reg mod Length(LayerColors)]
        else
          Result.Canvas.Brush.Color := SubColor;
      end;

      Pts[0] := Point(EnsureRange(ToScreenX(N1.R), PR.Left, PR.Right),
                      EnsureRange(ToScreenY(N1.Y), PR.Top, PR.Bottom));
      Pts[1] := Point(EnsureRange(ToScreenX(N2.R), PR.Left, PR.Right),
                      EnsureRange(ToScreenY(N2.Y), PR.Top, PR.Bottom));
      Pts[2] := Point(EnsureRange(ToScreenX(N3.R), PR.Left, PR.Right),
                      EnsureRange(ToScreenY(N3.Y), PR.Top, PR.Bottom));
      Pts[3] := Point(EnsureRange(ToScreenX(N4.R), PR.Left, PR.Right),
                      EnsureRange(ToScreenY(N4.Y), PR.Top, PR.Bottom));
      Result.Canvas.Polygon(Pts);
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
