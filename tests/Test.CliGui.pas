unit Test.CliGui;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, VCLTee.TeEngine, DUnitX.TestFramework,
  TriboContact.Models, TriboContact.Materials, TriboContact.Hertz,
  TriboContact.FemMesh, TriboContact.Runner, TriboContact.PlotRenderer,
  TriboContact.Export, TriboContact.CliRunner, TriboContact.Worker,
  TriboContact.LayerDialog, TriboContact.MaterialDialog, TriboContact.MainForm;

type
  [TestFixture]
  TCliGuiTests = class
  private
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure PlotRenderer_GeneratesAllFivePlotsAndExportsPngPdf;
    [Test]
    procedure Export_WritesValidJsonAndCsvTables;
    [Test]
    procedure CliRunner_SolveAndSweepExamples_Succeed;
    [Test]
    procedure Gui_MainForm_BindsCaseAndRunsElasticSolve;
    [Test]
    procedure Gui_Dialogs_LayerAndMaterialRoundTrip;
  end;

implementation

procedure TCliGuiTests.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'tc_m5_' + TPath.GetRandomFileName);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TCliGuiTests.TearDown;
begin
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TCliGuiTests.PlotRenderer_GeneratesAllFivePlotsAndExportsPngPdf;
var
  Lib: TMaterialLibrary;
  C: TContactCase;
  Bundle: TComparisonBundle;
  Mesh: TFemMesh;
  SweepPts: TArray<TSweepPoint>;
  Bmp: TBitmap;
  PngPath, PdfPath, PdfText: string;
  PngBytes: TBytes;
begin
  Lib := TMaterialLibrary.Create;
  try
    C := TContactCase.Create('PlotTest',
      TBallSpec.FromDiameterMm(6.0, Lib.GetPreset('Si3N4', mcBall), False),
      [TLayer.Create(Lib.GetPreset('DLC', mcCoating), 1.5)],
      Lib.GetPreset('Glass', mcSubstrate),
      TLoadCase.FromNewtons(2.0, 0.2),
      TSolverConfig.DefaultConfig);
  finally
    Lib.Free;
  end;
  C.Solver.Engine := seElastic;

  Bundle := RunCase(C);
  try
    Bmp := RenderPressureProfileBitmap(Bundle);
    try
      Assert.AreEqual(1000, Bmp.Width);
      Assert.AreEqual(640, Bmp.Height);
      PngPath := TPath.Combine(FTempDir, 'pressure.png');
      PdfPath := TPath.Combine(FTempDir, 'pressure.pdf');
      ExportBitmapPNG(Bmp, PngPath);
      ExportBitmapPDF(Bmp, PdfPath, 'Pressure');
      Assert.IsTrue(TFile.Exists(PngPath));
      Assert.IsTrue(TFile.Exists(PdfPath));
      PngBytes := TFile.ReadAllBytes(PngPath);
      Assert.IsTrue(Length(PngBytes) > 8);
      Assert.AreEqual<Byte>($89, PngBytes[0]);
      Assert.AreEqual<Byte>($50, PngBytes[1]);
      PdfText := TFile.ReadAllText(PdfPath, TEncoding.ASCII);
      Assert.IsTrue(Pos('%PDF-1.4', PdfText) = 1);
      Assert.IsTrue(Pos('xref', PdfText) > 0);
      Assert.IsTrue(Pos('%%EOF', PdfText) > 0);
    finally
      Bmp.Free;
    end;

    Bmp := RenderSubsurfaceHeatmapBitmap(Bundle.ElasticLayered, C, hfSigmaVm);
    try
      Assert.AreEqual(1000, Bmp.Width);
    finally
      Bmp.Free;
    end;

    Bmp := RenderSubsurfaceHeatmapBitmap(Bundle.ElasticLayered, C, hfSlidingSigmaXX);
    try
      Assert.AreEqual(1000, Bmp.Width);
    finally
      Bmp.Free;
    end;

    Bmp := RenderCenterlineProfileBitmap(Bundle);
    try
      Assert.AreEqual(1000, Bmp.Width);
    finally
      Bmp.Free;
    end;

    Mesh := GenerateFemMesh(C, Bundle.ElasticLayered.ContactRadiusUm,
      Bundle.ElasticLayered.PenetrationDepthUm, Bundle.ElasticLayered.MaxYieldRatio);
    try
      Bmp := RenderFemMeshBitmap(Mesh, C, True);
      try
        Assert.AreEqual(1000, Bmp.Width);
      finally
        Bmp.Free;
      end;
    finally
      Mesh.Free;
    end;

    SweepPts := RunLoadSweep(C, [500.0, 1000.0, 2000.0]);
    Bmp := RenderLoadSweepBitmap(SweepPts);
    try
      Assert.AreEqual(1100, Bmp.Width);
      Assert.AreEqual(760, Bmp.Height);
    finally
      Bmp.Free;
    end;
  finally
    Bundle.Free;
  end;
end;

procedure TCliGuiTests.Export_WritesValidJsonAndCsvTables;
var
  Lib: TMaterialLibrary;
  C: TContactCase;
  Bundle: TComparisonBundle;
  SweepPts: TArray<TSweepPoint>;
  JsonPath, JsonText: string;
  Parsed: TJSONValue;
begin
  Lib := TMaterialLibrary.Create;
  try
    C := TContactCase.Create('ExportTest',
      TBallSpec.FromDiameterMm(6.0, Lib.GetPreset('Si3N4', mcBall), False),
      [TLayer.Create(Lib.GetPreset('TiN', mcCoating), 2.0)],
      Lib.GetPreset('304 Steel', mcSubstrate),
      TLoadCase.FromNewtons(5.0, 0.0),
      TSolverConfig.DefaultConfig);
  finally
    Lib.Free;
  end;
  C.Solver.Engine := seElastic;

  Bundle := RunCase(C);
  try
    JsonPath := TPath.Combine(FTempDir, 'bundle.json');
    ExportBundleJSON(Bundle, JsonPath);
    JsonText := TFile.ReadAllText(JsonPath, TEncoding.UTF8);
    Parsed := TJSONObject.ParseJSONValue(JsonText, False, True);
    try
      Assert.IsNotNull(Parsed);
      Assert.IsTrue(Pos('"elastic_layered"', JsonText) > 0);
    finally
      Parsed.Free;
    end;

    ExportBundleCSV(Bundle, FTempDir);
    Assert.IsTrue(TFile.Exists(TPath.Combine(FTempDir, 'summary.csv')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(FTempDir, 'pressure.csv')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(FTempDir, 'centerline.csv')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(FTempDir, 'interfaces.csv')));

    SweepPts := RunLoadSweep(C, [100.0, 500.0]);
    ExportSweepCSV(SweepPts, TPath.Combine(FTempDir, 'sweep.csv'));
    ExportSweepJSON(SweepPts, TPath.Combine(FTempDir, 'sweep.json'));
    Assert.IsTrue(TFile.Exists(TPath.Combine(FTempDir, 'sweep.csv')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(FTempDir, 'sweep.json')));
  finally
    Bundle.Free;
  end;
end;

procedure TCliGuiTests.CliRunner_SolveAndSweepExamples_Succeed;
var
  Root, OutSolve, OutSweep, CasePath: string;
  Rc: Integer;
  OutLines, ErrLines: TStringList;
  Examples: array[0..2] of string;
  I: Integer;
begin
  Root := FindRepoRoot;
  OutLines := TStringList.Create;
  ErrLines := TStringList.Create;
  try
    Examples[0] := TPath.Combine(Root, 'examples\tin_on_steel.json');
    Examples[1] := TPath.Combine(Root, 'examples\dlc_on_glass.json');
    Examples[2] := TPath.Combine(Root, 'examples\hard_film_on_polymer.json');

    for I := 0 to High(Examples) do
    begin
      CasePath := Examples[I];
      Assert.IsTrue(TFile.Exists(CasePath), 'Missing example JSON: ' + CasePath);
      OutSolve := TPath.Combine(FTempDir, Format('ex_%d', [I]));
      OutLines.Clear;
      ErrLines.Clear;
      Rc := RunCli(['solve', CasePath, '--engine', 'elastic', '--out-dir', OutSolve, '--pdf'],
        procedure(S: string) begin OutLines.Add(S); end,
        procedure(S: string) begin ErrLines.Add(S); end);
      Assert.AreEqual(0, Rc, ErrLines.Text);
      Assert.IsTrue(TFile.Exists(TPath.Combine(OutSolve, 'results.json')));
      Assert.IsTrue(TFile.Exists(TPath.Combine(OutSolve, 'summary.csv')));
      Assert.IsTrue(TFile.Exists(TPath.Combine(OutSolve, 'pressure.png')));
      Assert.IsTrue(TFile.Exists(TPath.Combine(OutSolve, 'pressure.pdf')));
    end;

    OutSweep := TPath.Combine(FTempDir, 'sweep_out');
    OutLines.Clear;
    ErrLines.Clear;
    Rc := RunCli(['sweep', Examples[0], '--loads-mn', '500,2000,5000',
      '--engine', 'elastic', '--out-dir', OutSweep],
      procedure(S: string) begin OutLines.Add(S); end,
      procedure(S: string) begin ErrLines.Add(S); end);
    Assert.AreEqual(0, Rc, ErrLines.Text);
    Assert.IsTrue(TFile.Exists(TPath.Combine(OutSweep, 'sweep.csv')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(OutSweep, 'sweep.json')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(OutSweep, 'sweep.png')));
  finally
    ErrLines.Free;
    OutLines.Free;
  end;
end;

procedure TCliGuiTests.Gui_MainForm_BindsCaseAndRunsElasticSolve;
var
  CasePath, HelpIdx, HelpDir, BinDir, RelFile: string;
  C1, C2: TContactCase;
  F: TfrmMain;
  HelpAssets: array[0..8] of string;
begin
  CasePath := TPath.Combine(FindRepoRoot, 'examples\dlc_on_glass.json');
  C1 := TContactCase.LoadFromFile(CasePath);

  F := TfrmMain.Create(nil);
  try
    F.LoadCaseToUI(C1);
    C2 := F.BuildCaseFromUI;

    Assert.IsTrue(Abs(C2.Ball.RadiusUm - C1.Ball.RadiusUm) < 1e-6);
    Assert.AreEqual<Integer>(1, Length(C2.Layers));
    Assert.IsTrue(Abs(C2.Layers[0].ThicknessUm - C1.Layers[0].ThicknessUm) < 1e-6);
    Assert.IsTrue(Abs(C2.LoadCase.NormalLoadMn - C1.LoadCase.NormalLoadMn) < 1e-6);
    Assert.IsTrue(Abs(C2.LoadCase.FrictionCoeff - C1.LoadCase.FrictionCoeff) < 1e-6);
    Assert.IsTrue(Abs(C2.Substrate.EGpa - C1.Substrate.EGpa) < 1e-6);

    F.cbEngine.ItemIndex := 1;
    F.RunSolveSyncForTest;

    Assert.AreEqual<TCursor>(crDefault, Screen.Cursor);
    Assert.IsNotNull(F.CurrentBundle);
    Assert.IsNotNull(F.CurrentBundle.ElasticLayered);
    Assert.IsTrue(F.grdSummary.Cells[1, 3] <> '');
    Assert.IsTrue(F.grdInterfaces.RowCount >= 2);
    Assert.IsTrue(F.srsPressElastic.Count > 0);
    Assert.IsTrue(F.srsClElVm.Count > 0);
    Assert.IsNotNull(F.imgHeatmap.Picture.Graphic);
    Assert.IsNotNull(F.imgMesh.Picture.Graphic);

    BinDir := ExtractFileDir(ParamStr(0));
    Assert.IsTrue(TFile.Exists(TPath.Combine(BinDir, 'TriboContact.exe')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(BinDir, 'TriboContactCLI.exe')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(BinDir, 'TriboContactTests.exe')));

    HelpIdx := TfrmMain.ResolveHelpIndexPath;
    Assert.IsTrue(HelpIdx <> '');
    Assert.IsTrue(TFile.Exists(HelpIdx));
    HelpDir := ExtractFileDir(HelpIdx);
    HelpAssets[0] := 'index.html';
    HelpAssets[1] := 'getting-started.html';
    HelpAssets[2] := 'physics-hertz.html';
    HelpAssets[3] := 'physics-elastic-layered.html';
    HelpAssets[4] := 'physics-fem-plasticity.html';
    HelpAssets[5] := 'materials-and-units.html';
    HelpAssets[6] := 'verification-and-references.html';
    HelpAssets[7] := 'css\style.css';
    HelpAssets[8] := 'images\logo.png';
    for RelFile in HelpAssets do
      Assert.IsTrue(TFile.Exists(TPath.Combine(HelpDir, RelFile)), 'Missing help asset: ' + RelFile);
  finally
    F.Free;
  end;
end;

procedure TCliGuiTests.Gui_Dialogs_LayerAndMaterialRoundTrip;
var
  Root, UserPath: string;
  Lib: TMaterialLibrary;
  LayerDlg: TfrmLayerDialog;
  MatDlg: TfrmMaterialDialog;
  DummyLayer, OutLayer: TLayer;
  FoundMat: TMaterial;
begin
  Root := FindRepoRoot;
  UserPath := TPath.Combine(FTempDir, 'materials_user.json');
  Lib := TMaterialLibrary.Create(TPath.Combine(Root, 'data\materials.json'), UserPath);
  try
    LayerDlg := TfrmLayerDialog.Create(nil);
    try
      DummyLayer := Default(TLayer);
      LayerDlg.Bind(Lib, DummyLayer, False);
      LayerDlg.edtThickness.Text := '500';
      LayerDlg.cbThickUnit.ItemIndex := 1;
      LayerDlg.edtHardness.Text := '28';
      LayerDlg.EstimateYieldFromHardness;
      OutLayer := LayerDlg.BuildLayer;
      Assert.IsTrue(Abs(OutLayer.ThicknessUm - 0.5) < 1e-9);
      Assert.IsTrue(Abs(OutLayer.Material.SigmaYGpa - 10.0) < 1e-9);
    finally
      LayerDlg.Free;
    end;

    MatDlg := TfrmMaterialDialog.Create(nil);
    try
      MatDlg.BindLibrary(Lib);
      MatDlg.edtName.Text := 'TestCustomCoat';
      MatDlg.cbCategory.ItemIndex := 1;
      MatDlg.edtE.Text := '320';
      MatDlg.edtNu.Text := '0.24';
      MatDlg.SaveCurrentMaterial;
      Assert.IsTrue(TFile.Exists(UserPath));
    finally
      MatDlg.Free;
    end;

    Lib.Reload;
    Assert.IsTrue(Lib.TryFind('TestCustomCoat', mcCoating, FoundMat));
    Assert.IsTrue(Abs(FoundMat.EGpa - 320.0) < 1e-9);
  finally
    Lib.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCliGuiTests);

end.
