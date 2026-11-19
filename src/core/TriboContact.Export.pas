unit TriboContact.Export;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.IOUtils, System.ZLib,
  Vcl.Graphics, Vcl.Imaging.pngimage,
  TriboContact.Models, TriboContact.Runner, TriboContact.PlotRenderer;

procedure ExportBundleJSON(ABundle: TComparisonBundle; const AFilePath: string);
procedure ExportBundleCSV(ABundle: TComparisonBundle; const AOutDir: string);
procedure ExportSweepCSV(const APoints: TArray<TSweepPoint>; const AFilePath: string);
procedure ExportSweepJSON(const APoints: TArray<TSweepPoint>; const AFilePath: string);
procedure ExportBitmapPNG(ABmp: TBitmap; const AFilePath: string);
procedure ExportBitmapPDF(ABmp: TBitmap; const AFilePath: string; const ATitle: string = '');
procedure ExportBundlePlots(ABundle: TComparisonBundle; const ACase: TContactCase;
  const AOutDir: string; AIncludePdf: Boolean = False);

implementation

uses
  System.JSON;

procedure EnsureParentDir(const AFilePath: string);
var
  Dir: string;
begin
  Dir := ExtractFilePath(AFilePath);
  if (Dir <> '') and not TDirectory.Exists(Dir) then
    TDirectory.CreateDirectory(Dir);
end;

function FmtF(V: Double): string; inline;
begin
  if IsNan(V) or IsInfinite(V) then
    Result := ''
  else
    Result := Format('%.8g', [V], TFormatSettings.Invariant);
end;

function CsvEscape(const S: string): string;
begin
  if (Pos(',', S) > 0) or (Pos('"', S) > 0) or (Pos(#10, S) > 0) or (Pos(#13, S) > 0) then
    Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := S;
end;

procedure ExportBundleJSON(ABundle: TComparisonBundle; const AFilePath: string);
begin
  if ABundle = nil then
    raise EArgumentNilException.Create('Bundle cannot be nil');
  EnsureParentDir(AFilePath);
  TFile.WriteAllText(AFilePath, ABundle.ToJSONString(True), TEncoding.UTF8);
end;

procedure ExportBundleCSV(ABundle: TComparisonBundle; const AOutDir: string);
var
  SL: TStringList;
  K, I, MaxRows: Integer;
  ResArr: array[0..3] of TContactResult;
  Labels: array[0..3] of string;
  R: TContactResult;
  LineStr: string;
  procedure AppendSummary(const ASolver: string; AR: TContactResult);
  var
    HrStr, PeeqStr: string;
  begin
    if AR = nil then
      Exit;
    if AR.HasResidualDepth then HrStr := FmtF(AR.ResidualDepthUm) else HrStr := '';
    if AR.HasMaxPeeq then PeeqStr := FmtF(AR.MaxPeeq) else PeeqStr := '';
    SL.Add(Format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s',
      [CsvEscape(ASolver), FmtF(AR.ContactRadiusUm), FmtF(AR.PenetrationDepthUm),
       HrStr, FmtF(AR.PMaxGpa), FmtF(AR.PMeanGpa), FmtF(AR.ActualLoadMn),
       FmtF(AR.ForceBalanceErrorRel), FmtF(AR.MaxYieldRatio),
       BoolToStr(AR.YieldWarning, True), PeeqStr]));
  end;
  procedure AppendIfs(const ASolver: string; AR: TContactResult);
  var
    J: Integer;
    IfS: TInterfaceStressSummary;
    Pa, Pb: string;
  begin
    if AR = nil then
      Exit;
    for J := 0 to High(AR.Interfaces) do
    begin
      IfS := AR.Interfaces[J];
      if IfS.HasPeeq then
      begin
        Pa := FmtF(IfS.MaxPeeqAbove);
        Pb := FmtF(IfS.MaxPeeqBelow);
      end
      else
      begin
        Pa := '';
        Pb := '';
      end;
      SL.Add(Format('%s,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s',
        [CsvEscape(ASolver), IfS.InterfaceIndex, FmtF(IfS.DepthUm),
         CsvEscape(IfS.AboveLabel), CsvEscape(IfS.BelowLabel),
         FmtF(IfS.MaxSigmaRRAboveGpa), FmtF(IfS.MaxSigmaRRBelowGpa),
         FmtF(IfS.MinSigmaRRAboveGpa), FmtF(IfS.MinSigmaRRBelowGpa),
         FmtF(IfS.MaxAbsTauRZGpa), FmtF(IfS.MaxSigmaVmAboveGpa),
         FmtF(IfS.MaxSigmaVmBelowGpa), Pa, Pb]));
    end;
  end;
begin
  if ABundle = nil then
    raise EArgumentNilException.Create('Bundle cannot be nil');
  TDirectory.CreateDirectory(AOutDir);

  ResArr[0] := ABundle.HertzSubstrate; Labels[0] := 'hertz_substrate';
  ResArr[1] := ABundle.HertzTopFilm;   Labels[1] := 'hertz_top_film';
  ResArr[2] := ABundle.ElasticLayered; Labels[2] := 'elastic_layered';
  ResArr[3] := ABundle.FemCalculix;    Labels[3] := 'fem_calculix';

  SL := TStringList.Create;
  try
    SL.Add('solver,contact_radius_um,penetration_depth_um,residual_depth_um,p_max_gpa,p_mean_gpa,actual_load_mn,force_balance_err_rel,max_yield_ratio,yield_warning,max_peeq');
    for K := 0 to 3 do
      AppendSummary(Labels[K], ResArr[K]);
    SL.SaveToFile(TPath.Combine(AOutDir, 'summary.csv'), TEncoding.UTF8);

    SL.Clear;
    SL.Add('r_hertz_sub_um,p_hertz_sub_gpa,r_hertz_film_um,p_hertz_film_gpa,r_elastic_um,p_elastic_gpa,r_fem_um,p_fem_gpa');
    MaxRows := 0;
    for K := 0 to 3 do
      if ResArr[K] <> nil then
        MaxRows := Max(MaxRows, Length(ResArr[K].RUm));
    for I := 0 to MaxRows - 1 do
    begin
      LineStr := '';
      for K := 0 to 3 do
      begin
        R := ResArr[K];
        if (R <> nil) and (I <= High(R.RUm)) and (I <= High(R.PGpa)) then
          LineStr := LineStr + FmtF(R.RUm[I]) + ',' + FmtF(R.PGpa[I])
        else
          LineStr := LineStr + ',';
        if K < 3 then
          LineStr := LineStr + ',';
      end;
      SL.Add(LineStr);
    end;
    SL.SaveToFile(TPath.Combine(AOutDir, 'pressure.csv'), TEncoding.UTF8);

    SL.Clear;
    SL.Add('z_elastic_um,svm_elastic_gpa,srr_elastic_gpa,szz_elastic_gpa,z_fem_um,svm_fem_gpa,srr_fem_gpa,szz_fem_gpa');
    MaxRows := 0;
    if ABundle.ElasticLayered <> nil then
      MaxRows := Max(MaxRows, Length(ABundle.ElasticLayered.ZCenterlineUm));
    if ABundle.FemCalculix <> nil then
      MaxRows := Max(MaxRows, Length(ABundle.FemCalculix.ZCenterlineUm));
    for I := 0 to MaxRows - 1 do
    begin
      LineStr := '';
      R := ABundle.ElasticLayered;
      if (R <> nil) and (I <= High(R.ZCenterlineUm)) then
        LineStr := LineStr + Format('%s,%s,%s,%s,',
          [FmtF(R.ZCenterlineUm[I]), FmtF(R.CenterlineSigmaVmGpa[I]),
           FmtF(R.CenterlineSigmaRRGpa[I]), FmtF(R.CenterlineSigmaZZGpa[I])])
      else
        LineStr := LineStr + ',,,,';
      R := ABundle.FemCalculix;
      if (R <> nil) and (I <= High(R.ZCenterlineUm)) then
        LineStr := LineStr + Format('%s,%s,%s,%s',
          [FmtF(R.ZCenterlineUm[I]), FmtF(R.CenterlineSigmaVmGpa[I]),
           FmtF(R.CenterlineSigmaRRGpa[I]), FmtF(R.CenterlineSigmaZZGpa[I])])
      else
        LineStr := LineStr + ',,,';
      SL.Add(LineStr);
    end;
    SL.SaveToFile(TPath.Combine(AOutDir, 'centerline.csv'), TEncoding.UTF8);

    SL.Clear;
    SL.Add('solver,interface_index,depth_um,above_label,below_label,max_srr_above_gpa,max_srr_below_gpa,min_srr_above_gpa,min_srr_below_gpa,max_abs_tau_rz_gpa,max_svm_above_gpa,max_svm_below_gpa,max_peeq_above,max_peeq_below');
    AppendIfs('elastic_layered', ABundle.ElasticLayered);
    AppendIfs('fem_calculix', ABundle.FemCalculix);
    SL.SaveToFile(TPath.Combine(AOutDir, 'interfaces.csv'), TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

procedure ExportSweepCSV(const APoints: TArray<TSweepPoint>; const AFilePath: string);
var
  SL: TStringList;
  I: Integer;
  Pt: TSweepPoint;
begin
  EnsureParentDir(AFilePath);
  SL := TStringList.Create;
  try
    SL.Add('normal_load_mn,hertz_sub_pmax_gpa,hertz_film_pmax_gpa,elastic_pmax_gpa,elastic_pmean_gpa,elastic_radius_um,elastic_max_yield_ratio,fem_pmax_gpa,fem_pmean_gpa,fem_radius_um,fem_max_yield_ratio,fem_max_peeq');
    for I := 0 to High(APoints) do
    begin
      Pt := APoints[I];
      if Pt.HasFem then
        SL.Add(Format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s',
          [FmtF(Pt.NormalLoadMn), FmtF(Pt.HertzSubPMaxGpa), FmtF(Pt.HertzFilmPMaxGpa),
           FmtF(Pt.ElasticPMaxGpa), FmtF(Pt.ElasticPMeanGpa), FmtF(Pt.ElasticRadiusUm),
           FmtF(Pt.ElasticMaxYieldRatio), FmtF(Pt.FemPMaxGpa), FmtF(Pt.FemPMeanGpa),
           FmtF(Pt.FemRadiusUm), FmtF(Pt.FemMaxYieldRatio), FmtF(Pt.FemMaxPeeq)]))
      else
        SL.Add(Format('%s,%s,%s,%s,%s,%s,%s,,,,,',
          [FmtF(Pt.NormalLoadMn), FmtF(Pt.HertzSubPMaxGpa), FmtF(Pt.HertzFilmPMaxGpa),
           FmtF(Pt.ElasticPMaxGpa), FmtF(Pt.ElasticPMeanGpa), FmtF(Pt.ElasticRadiusUm),
           FmtF(Pt.ElasticMaxYieldRatio)]));
    end;
    SL.SaveToFile(AFilePath, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

procedure ExportSweepJSON(const APoints: TArray<TSweepPoint>; const AFilePath: string);
var
  Root, Obj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Pt: TSweepPoint;
begin
  EnsureParentDir(AFilePath);
  Root := TJSONObject.Create;
  try
    Arr := TJSONArray.Create;
    for I := 0 to High(APoints) do
    begin
      Pt := APoints[I];
      Obj := TJSONObject.Create;
      Obj.AddPair('normal_load_mn', TJSONNumber.Create(Pt.NormalLoadMn));
      Obj.AddPair('hertz_sub_pmax_gpa', TJSONNumber.Create(Pt.HertzSubPMaxGpa));
      Obj.AddPair('hertz_film_pmax_gpa', TJSONNumber.Create(Pt.HertzFilmPMaxGpa));
      Obj.AddPair('elastic_pmax_gpa', TJSONNumber.Create(Pt.ElasticPMaxGpa));
      Obj.AddPair('elastic_pmean_gpa', TJSONNumber.Create(Pt.ElasticPMeanGpa));
      Obj.AddPair('elastic_radius_um', TJSONNumber.Create(Pt.ElasticRadiusUm));
      Obj.AddPair('elastic_max_yield_ratio', TJSONNumber.Create(Pt.ElasticMaxYieldRatio));
      Obj.AddPair('has_fem', TJSONBool.Create(Pt.HasFem));
      if Pt.HasFem then
      begin
        Obj.AddPair('fem_pmax_gpa', TJSONNumber.Create(Pt.FemPMaxGpa));
        Obj.AddPair('fem_pmean_gpa', TJSONNumber.Create(Pt.FemPMeanGpa));
        Obj.AddPair('fem_radius_um', TJSONNumber.Create(Pt.FemRadiusUm));
        Obj.AddPair('fem_max_yield_ratio', TJSONNumber.Create(Pt.FemMaxYieldRatio));
        Obj.AddPair('fem_max_peeq', TJSONNumber.Create(Pt.FemMaxPeeq));
      end;
      Arr.AddElement(Obj);
    end;
    Root.AddPair('sweep', Arr);
    TFile.WriteAllText(AFilePath, Root.Format(2), TEncoding.UTF8);
  finally
    Root.Free;
  end;
end;

procedure ExportBitmapPNG(ABmp: TBitmap; const AFilePath: string);
var
  Png: TPngImage;
begin
  if ABmp = nil then
    raise EArgumentNilException.Create('Bitmap cannot be nil');
  EnsureParentDir(AFilePath);
  Png := TPngImage.Create;
  try
    Png.Assign(ABmp);
    Png.SaveToFile(AFilePath);
  finally
    Png.Free;
  end;
end;

procedure WriteAsciiStr(AStream: TStream; const S: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.ASCII.GetBytes(S);
  if Length(Bytes) > 0 then
    AStream.WriteBuffer(Bytes[0], Length(Bytes));
end;

procedure ExportBitmapPDF(ABmp: TBitmap; const AFilePath: string; const ATitle: string);
var
  WorkBmp: TBitmap;
  RawRgb: TBytes;
  ZippedStream: TMemoryStream;
  ZStream: TZCompressionStream;
  FS: TFileStream;
  W, H, X, Y, Off: Integer;
  RowPtr: PByteArray;
  Offsets: array[1..6] of Int64;
  PageW, PageH: Double;
  ContentCmd, SafeTitle: string;
  XrefOffset: Int64;
  I: Integer;
begin
  if ABmp = nil then
    raise EArgumentNilException.Create('Bitmap cannot be nil');
  EnsureParentDir(AFilePath);

  WorkBmp := TBitmap.Create;
  try
    WorkBmp.PixelFormat := pf24bit;
    WorkBmp.SetSize(ABmp.Width, ABmp.Height);
    WorkBmp.Canvas.Draw(0, 0, ABmp);
    W := WorkBmp.Width;
    H := WorkBmp.Height;

    SetLength(RawRgb, W * H * 3);
    Off := 0;
    for Y := 0 to H - 1 do
    begin
      RowPtr := WorkBmp.ScanLine[Y];
      for X := 0 to W - 1 do
      begin
        RawRgb[Off] := RowPtr[3 * X + 2];
        RawRgb[Off + 1] := RowPtr[3 * X + 1];
        RawRgb[Off + 2] := RowPtr[3 * X];
        Inc(Off, 3);
      end;
    end;
  finally
    WorkBmp.Free;
  end;

  ZippedStream := TMemoryStream.Create;
  try
    ZStream := TZCompressionStream.Create(ZippedStream);
    try
      if Length(RawRgb) > 0 then
        ZStream.WriteBuffer(RawRgb[0], Length(RawRgb));
    finally
      ZStream.Free;
    end;

    PageW := 792.0;
    PageH := PageW * (H / Max(1, W));
    ContentCmd := Format('q %.2f 0 0 %.2f 0 0 cm /Im1 Do Q', [PageW, PageH], TFormatSettings.Invariant);

    FS := TFileStream.Create(AFilePath, fmCreate);
    try
      WriteAsciiStr(FS, '%PDF-1.4'#10);

      Offsets[1] := FS.Position;
      WriteAsciiStr(FS, '1 0 obj'#10'<< /Type /Catalog /Pages 2 0 R >>'#10'endobj'#10);

      Offsets[2] := FS.Position;
      WriteAsciiStr(FS, '2 0 obj'#10'<< /Type /Pages /Kids [3 0 R] /Count 1 >>'#10'endobj'#10);

      Offsets[3] := FS.Position;
      WriteAsciiStr(FS, Format('3 0 obj'#10'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] /Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>'#10'endobj'#10,
        [PageW, PageH], TFormatSettings.Invariant));

      Offsets[4] := FS.Position;
      WriteAsciiStr(FS, Format('4 0 obj'#10'<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length %d >>'#10'stream'#10,
        [W, H, ZippedStream.Size]));
      if ZippedStream.Size > 0 then
        FS.WriteBuffer(ZippedStream.Memory^, ZippedStream.Size);
      WriteAsciiStr(FS, #10'endstream'#10'endobj'#10);

      Offsets[5] := FS.Position;
      WriteAsciiStr(FS, Format('5 0 obj'#10'<< /Length %d >>'#10'stream'#10'%s'#10'endstream'#10'endobj'#10,
        [Length(ContentCmd), ContentCmd]));

      SafeTitle := StringReplace(StringReplace(ATitle, '\', '\\', [rfReplaceAll]), ')', '\)', [rfReplaceAll]);
      SafeTitle := StringReplace(SafeTitle, '(', '\(', [rfReplaceAll]);
      Offsets[6] := FS.Position;
      WriteAsciiStr(FS, Format('6 0 obj'#10'<< /Title (%s) /Producer (TriboContact) >>'#10'endobj'#10, [SafeTitle]));

      XrefOffset := FS.Position;
      WriteAsciiStr(FS, 'xref'#10'0 7'#10'0000000000 65535 f '#13#10);
      for I := 1 to 6 do
        WriteAsciiStr(FS, Format('%010d 00000 n '#13#10, [Offsets[I]]));

      WriteAsciiStr(FS, Format('trailer'#10'<< /Size 7 /Root 1 0 R /Info 6 0 R >>'#10'startxref'#10'%d'#10'%%%%EOF'#10, [XrefOffset]));
    finally
      FS.Free;
    end;
  finally
    ZippedStream.Free;
  end;
end;

procedure ExportBundlePlots(ABundle: TComparisonBundle; const ACase: TContactCase;
  const AOutDir: string; AIncludePdf: Boolean);
var
  Bmp: TBitmap;
  procedure SaveBoth(const ABaseName: string; B: TBitmap);
  begin
    try
      ExportBitmapPNG(B, TPath.Combine(AOutDir, ABaseName + '.png'));
      if AIncludePdf then
        ExportBitmapPDF(B, TPath.Combine(AOutDir, ABaseName + '.pdf'), ABaseName);
    finally
      B.Free;
    end;
  end;
begin
  if ABundle = nil then
    raise EArgumentNilException.Create('Bundle cannot be nil');
  TDirectory.CreateDirectory(AOutDir);

  Bmp := RenderPressureProfileBitmap(ABundle);
  SaveBoth('pressure', Bmp);

  Bmp := RenderCenterlineProfileBitmap(ABundle);
  SaveBoth('centerline', Bmp);

  if ABundle.ElasticLayered <> nil then
  begin
    Bmp := RenderSubsurfaceHeatmapBitmap(ABundle.ElasticLayered, ACase, hfSigmaVm);
    SaveBoth('heatmap_elastic_svm', Bmp);
    if (ABundle.ElasticLayered.StressGrid <> nil) and ABundle.ElasticLayered.StressGrid.HasSliding then
    begin
      Bmp := RenderSubsurfaceHeatmapBitmap(ABundle.ElasticLayered, ACase, hfSlidingSigmaXX);
      SaveBoth('heatmap_elastic_sliding_sxx', Bmp);
    end;
  end;

  if ABundle.FemCalculix <> nil then
  begin
    Bmp := RenderSubsurfaceHeatmapBitmap(ABundle.FemCalculix, ACase, hfSigmaVm);
    SaveBoth('heatmap_fem_svm', Bmp);
    Bmp := RenderSubsurfaceHeatmapBitmap(ABundle.FemCalculix, ACase, hfPeeq);
    SaveBoth('heatmap_fem_peeq', Bmp);
  end;
end;

end.
