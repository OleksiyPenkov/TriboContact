unit TriboContact.MainForm;

interface

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.Classes, System.Math,
  System.IOUtils, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Grids,
  RzCommon, RzPanel, RzSplit, RzTabs, RzStatus, RzButton, RzEdit, RzCmboBx, RzRadChk,
  VclTee.TeeGDIPlus, VCLTee.TeEngine, VCLTee.Series, VCLTee.TeeProcs, VCLTee.Chart,
  TriboContact.Models, TriboContact.Materials, TriboContact.CcxManager,
  TriboContact.FemMesh, TriboContact.Runner, TriboContact.PlotRenderer,
  TriboContact.Export, TriboContact.Worker;

type
  TfrmMain = class(TForm)
    pnlToolbar: TRzPanel;
    btnOpen: TRzButton;
    btnSave: TRzButton;
    btnSolve: TRzButton;
    btnCancel: TRzButton;
    btnSweep: TRzButton;
    btnMaterials: TRzButton;
    btnExportData: TRzButton;
    btnExportPlots: TRzButton;
    btnSetupCcx: TRzButton;
    btnHelp: TRzButton;
    stsBar: TRzStatusBar;
    stpStatus: TRzStatusPane;
    stpCcx: TRzStatusPane;
    stpRuntime: TRzStatusPane;
    splMain: TRzSplitter;
    scrInputs: TScrollBox;
    gbBall: TRzGroupBox;
    lblCaseName: TLabel;
    lblBallPreset: TLabel;
    lblBallSize: TLabel;
    lblBallE: TLabel;
    lblBallNu: TLabel;
    edtCaseName: TRzEdit;
    cbBallPreset: TRzComboBox;
    edtBallSize: TRzEdit;
    cbBallSizeMode: TRzComboBox;
    edtBallE: TRzEdit;
    edtBallNu: TRzEdit;
    chkBallRigid: TRzCheckBox;
    gbLoad: TRzGroupBox;
    lblNormalLoad: TLabel;
    lblFriction: TLabel;
    edtNormalLoad: TRzEdit;
    cbLoadUnit: TRzComboBox;
    edtFriction: TRzEdit;
    gbLayers: TRzGroupBox;
    lvLayers: TListView;
    pnlLayerBtns: TRzPanel;
    btnLayerAdd: TRzButton;
    btnLayerEdit: TRzButton;
    btnLayerDel: TRzButton;
    btnLayerUp: TRzButton;
    btnLayerDown: TRzButton;
    gbSubstrate: TRzGroupBox;
    lblSubPreset: TLabel;
    lblSubE: TLabel;
    lblSubNu: TLabel;
    lblSubSigmaY: TLabel;
    lblSubEt: TLabel;
    lblSubHardness: TLabel;
    cbSubPreset: TRzComboBox;
    edtSubE: TRzEdit;
    edtSubNu: TRzEdit;
    edtSubSigmaY: TRzEdit;
    btnSubEstYield: TRzButton;
    edtSubEt: TRzEdit;
    edtSubHardness: TRzEdit;
    gbSolver: TRzGroupBox;
    lblEngine: TLabel;
    lblMeshDensity: TLabel;
    lblElementType: TLabel;
    lblNRings: TLabel;
    cbEngine: TRzComboBox;
    cbMeshDensity: TRzComboBox;
    cbElementType: TRzComboBox;
    edtNRings: TRzEdit;
    chkUnloading: TRzCheckBox;
    pnlRight: TRzPanel;
    pnlTopResults: TRzPanel;
    pnlBadge: TRzPanel;
    lblYieldBadge: TLabel;
    pgcTables: TRzPageControl;
    tabSummary: TRzTabSheet;
    grdSummary: TStringGrid;
    tabInterfaces: TRzTabSheet;
    grdInterfaces: TStringGrid;
    pgcPlots: TRzPageControl;
    tabPressure: TRzTabSheet;
    chtPressure: TChart;
    srsPressHertzSub: TLineSeries;
    srsPressHertzFilm: TLineSeries;
    srsPressElastic: TLineSeries;
    srsPressFem: TLineSeries;
    tabHeatmap: TRzTabSheet;
    pnlHeatmapBar: TRzPanel;
    lblHmSolver: TLabel;
    lblHmField: TLabel;
    cbHeatmapSolver: TRzComboBox;
    cbHeatmapField: TRzComboBox;
    btnSaveHeatmap: TRzButton;
    imgHeatmap: TImage;
    tabCenterline: TRzTabSheet;
    chtCenterline: TChart;
    srsClElVm: TLineSeries;
    srsClElRR: TLineSeries;
    srsClFemVm: TLineSeries;
    srsClFemRR: TLineSeries;
    tabSweep: TRzTabSheet;
    pnlSweepBar: TRzPanel;
    lblSweepLoads: TLabel;
    edtSweepLoads: TRzEdit;
    btnRunSweep: TRzButton;
    imgSweep: TImage;
    tabMesh: TRzTabSheet;
    pnlMeshBar: TRzPanel;
    chkMeshZoom: TRzCheckBox;
    btnPreviewMesh: TRzButton;
    imgMesh: TImage;
    tabLog: TRzTabSheet;
    memLog: TRzMemo;
    MainMenu1: TMainMenu;
    mniFile: TMenuItem;
    mniOpenCase: TMenuItem;
    mniSaveCase: TMenuItem;
    mniExamples: TMenuItem;
    mniExTinSteel: TMenuItem;
    mniExDlcGlass: TMenuItem;
    mniExSicPmma: TMenuItem;
    mniSepFile1: TMenuItem;
    mniExportData: TMenuItem;
    mniExportPlots: TMenuItem;
    mniSepFile2: TMenuItem;
    mniExit: TMenuItem;
    mniSolve: TMenuItem;
    mniRunSolve: TMenuItem;
    mniCancel: TMenuItem;
    mniRunSweep: TMenuItem;
    mniPreviewMesh: TMenuItem;
    mniSetupCcx: TMenuItem;
    mniLibrary: TMenuItem;
    mniManageMaterials: TMenuItem;
    mniHelp: TMenuItem;
    mniUserManual: TMenuItem;
    mniSepHelp: TMenuItem;
    mniAbout: TMenuItem;
    dlgOpenCase: TOpenDialog;
    dlgSaveCase: TSaveDialog;
    dlgSelectDir: TFileOpenDialog;
    dlgSaveImage: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnOpenClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure mniExTinSteelClick(Sender: TObject);
    procedure mniExDlcGlassClick(Sender: TObject);
    procedure mniExSicPmmaClick(Sender: TObject);
    procedure btnExportDataClick(Sender: TObject);
    procedure btnExportPlotsClick(Sender: TObject);
    procedure mniExitClick(Sender: TObject);
    procedure btnSolveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnSweepClick(Sender: TObject);
    procedure btnPreviewMeshClick(Sender: TObject);
    procedure btnSetupCcxClick(Sender: TObject);
    procedure btnMaterialsClick(Sender: TObject);
    procedure btnHelpClick(Sender: TObject);
    procedure mniAboutClick(Sender: TObject);
    procedure cbBallPresetChange(Sender: TObject);
    procedure cbBallSizeModeChange(Sender: TObject);
    procedure cbLoadUnitChange(Sender: TObject);
    procedure cbSubPresetChange(Sender: TObject);
    procedure btnSubEstYieldClick(Sender: TObject);
    procedure btnLayerAddClick(Sender: TObject);
    procedure btnLayerEditClick(Sender: TObject);
    procedure btnLayerDelClick(Sender: TObject);
    procedure btnLayerUpClick(Sender: TObject);
    procedure btnLayerDownClick(Sender: TObject);
    procedure cbHeatmapChange(Sender: TObject);
    procedure btnSaveHeatmapClick(Sender: TObject);
    procedure chkMeshZoomClick(Sender: TObject);
  private
    FMatLib: TMaterialLibrary;
    FBallPresets: TArray<TMaterial>;
    FSubPresets: TArray<TMaterial>;
    FLayers: TArray<TLayer>;
    FUpdatingUI: Boolean;
    FPrevBallSizeMode: Integer;
    FPrevLoadUnit: Integer;
    FLastBallMaterial: TMaterial;
    FLastSubHardening: TArray<THardeningPoint>;
    FWorker: TSolverWorkerThread;
    FBundle: TComparisonBundle;
    FLastSolvedCase: TContactCase;
    FHasSolvedCase: Boolean;
    FSweepPoints: TArray<TSweepPoint>;
    FMesh: TFemMesh;
    FMeshCase: TContactCase;
    FHeatmapBmp: TBitmap;
    FSweepBmp: TBitmap;
    FMeshBmp: TBitmap;
    procedure InitGrids;
    procedure PopulatePresetCombos(const ABallName, ASubName: string);
    procedure RefreshLayerListView(ASelectIdx: Integer = -1);
    procedure RefreshCcxStatus;
    procedure SetBusyState(ABusy: Boolean; const AStatusText: string);
    procedure StopActiveWorker;
    procedure AppendLog(const AMsg: string);
    procedure LoadExampleFile(const ARelPath: string);
    procedure UpdateResultsUI;
    procedure UpdateSummaryGrid;
    procedure UpdateInterfaceGrid;
    procedure UpdateYieldBadge;
    procedure UpdateCharts;
    procedure UpdateHeatmap;
    procedure UpdateMeshPreview(AUseCurrentUI: Boolean);
    procedure PopulateSweepImage;
    function ParseSweepLoads: TDoubleArray;
    function ParseRequiredDouble(const AText, AFieldName: string): Double;
    function TryParseOptionalDouble(const AText, AFieldName: string; out AValue: Double): Boolean;
  public
    class function ResolveHelpIndexPath: string;
    function BuildCaseFromUI: TContactCase;
    procedure LoadCaseToUI(const ACase: TContactCase);
    procedure RunSolveSyncForTest;
    property CurrentBundle: TComparisonBundle read FBundle;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  TriboContact.Hertz,
  TriboContact.LayerDialog,
  TriboContact.MaterialDialog;

function FormatOptFloat(AValue: Double; AHasValue: Boolean): string;
begin
  if AHasValue then
    Result := Format('%.6g', [AValue], TFormatSettings.Invariant)
  else
    Result := '';
end;

function FormatGridFloat(AValue: Double; const AFmt: string = '%.4f'): string;
begin
  if IsNan(AValue) or IsInfinite(AValue) then
    Result := '-'
  else
    Result := Format(AFmt, [AValue], TFormatSettings.Invariant);
end;

function TfrmMain.ParseRequiredDouble(const AText, AFieldName: string): Double;
begin
  if not TryStrToFloat(Trim(AText), Result, TFormatSettings.Invariant) then
    raise EArgumentException.CreateFmt('Invalid numeric value for %s: %s', [AFieldName, AText]);
end;

function TfrmMain.TryParseOptionalDouble(const AText, AFieldName: string;
  out AValue: Double): Boolean;
var
  S: string;
begin
  S := Trim(AText);
  if S = '' then
  begin
    AValue := 0.0;
    Exit(False);
  end;
  if not TryStrToFloat(S, AValue, TFormatSettings.Invariant) then
    raise EArgumentException.CreateFmt('Invalid numeric value for %s: %s', [AFieldName, AText]);
  Result := True;
end;

procedure TfrmMain.InitGrids;
begin
  grdSummary.ColCount := 8;
  grdSummary.RowCount := 5;
  grdSummary.FixedCols := 1;
  grdSummary.FixedRows := 1;
  grdSummary.Cells[0, 0] := 'Solver';
  grdSummary.Cells[1, 0] := 'a (um)';
  grdSummary.Cells[2, 0] := 'delta (um)';
  grdSummary.Cells[3, 0] := 'h_r (um)';
  grdSummary.Cells[4, 0] := 'p_max (GPa)';
  grdSummary.Cells[5, 0] := 'p_mean (GPa)';
  grdSummary.Cells[6, 0] := 'Max s_vM/s_y';
  grdSummary.Cells[7, 0] := 'Max PEEQ';

  grdSummary.Cells[0, 1] := 'Hertz Substrate';
  grdSummary.Cells[0, 2] := 'Hertz Top Film';
  grdSummary.Cells[0, 3] := 'Layered Elastic';
  grdSummary.Cells[0, 4] := 'CalculiX FEM';
  grdSummary.ColWidths[0] := 130;

  grdInterfaces.ColCount := 10;
  grdInterfaces.RowCount := 2;
  grdInterfaces.FixedCols := 0;
  grdInterfaces.FixedRows := 1;
  grdInterfaces.Cells[0, 0] := 'Solver';
  grdInterfaces.Cells[1, 0] := 'If #';
  grdInterfaces.Cells[2, 0] := 'Depth (um)';
  grdInterfaces.Cells[3, 0] := 'Above (z-)';
  grdInterfaces.Cells[4, 0] := 'Below (z+)';
  grdInterfaces.Cells[5, 0] := 's_rr(z-) max';
  grdInterfaces.Cells[6, 0] := 's_rr(z+) max';
  grdInterfaces.Cells[7, 0] := '|tau_rz| max';
  grdInterfaces.Cells[8, 0] := 's_vM(z-) max';
  grdInterfaces.Cells[9, 0] := 's_vM(z+) max';
  grdInterfaces.ColWidths[0] := 110;
  grdInterfaces.ColWidths[1] := 38;
  grdInterfaces.ColWidths[3] := 110;
  grdInterfaces.ColWidths[4] := 110;
end;

procedure TfrmMain.PopulatePresetCombos(const ABallName, ASubName: string);
var
  I, MatchIdx: Integer;
begin
  FUpdatingUI := True;
  try
    FBallPresets := FMatLib.GetByCategory(mcBall);
    cbBallPreset.Items.Clear;
    MatchIdx := -1;
    for I := 0 to High(FBallPresets) do
    begin
      cbBallPreset.Items.Add(FBallPresets[I].Name);
      if SameText(FBallPresets[I].Name, Trim(ABallName)) then
        MatchIdx := I;
    end;
    cbBallPreset.ItemIndex := MatchIdx;

    FSubPresets := FMatLib.GetByCategory(mcSubstrate);
    cbSubPreset.Items.Clear;
    MatchIdx := -1;
    for I := 0 to High(FSubPresets) do
    begin
      cbSubPreset.Items.Add(FSubPresets[I].Name);
      if SameText(FSubPresets[I].Name, Trim(ASubName)) then
        MatchIdx := I;
    end;
    cbSubPreset.ItemIndex := MatchIdx;
  finally
    FUpdatingUI := False;
  end;
end;

procedure TfrmMain.RefreshLayerListView(ASelectIdx: Integer);
var
  I: Integer;
  Item: TListItem;
  L: TLayer;
begin
  lvLayers.Items.BeginUpdate;
  try
    lvLayers.Items.Clear;
    for I := 0 to High(FLayers) do
    begin
      L := FLayers[I];
      Item := lvLayers.Items.Add;
      Item.Caption := IntToStr(I + 1);
      Item.SubItems.Add(L.Material.Name);
      Item.SubItems.Add(Format('%.5g', [L.ThicknessUm], TFormatSettings.Invariant));
      Item.SubItems.Add(Format('%.5g', [L.Material.EGpa], TFormatSettings.Invariant));
      Item.SubItems.Add(Format('%.4g', [L.Material.Nu], TFormatSettings.Invariant));
      if L.Material.HasSigmaY then
        Item.SubItems.Add(Format('%.5g', [L.Material.SigmaYGpa], TFormatSettings.Invariant))
      else
        Item.SubItems.Add('-');
    end;
    if (ASelectIdx >= 0) and (ASelectIdx < lvLayers.Items.Count) then
      lvLayers.Items[ASelectIdx].Selected := True;
  finally
    lvLayers.Items.EndUpdate;
  end;
end;

procedure TfrmMain.RefreshCcxStatus;
var
  CcxPath: string;
begin
  CcxPath := ResolveCcxPath;
  if CcxPath <> '' then
    stpCcx.Caption := 'CalculiX: ' + ExtractFileName(CcxPath) + ' (' + ExtractFileDir(CcxPath) + ')'
  else
    stpCcx.Caption := 'CalculiX: not installed (run Setup CalculiX)';
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  Root, DefaultEx: string;
  DefaultCase: TContactCase;
begin
  FMatLib := TMaterialLibrary.Create;
  InitGrids;
  pgcTables.ActivePage := tabSummary;
  pgcPlots.ActivePage := tabPressure;

  srsPressHertzSub.LinePen.Style := psDash;
  srsPressHertzFilm.LinePen.Style := psDash;
  srsClElRR.LinePen.Style := psDash;
  srsClFemRR.LinePen.Style := psDash;

  RefreshCcxStatus;

  Root := FindRepoRoot;
  DefaultEx := TPath.Combine(Root, 'examples\tin_on_steel.json');
  if TFile.Exists(DefaultEx) then
    DefaultCase := TContactCase.LoadFromFile(DefaultEx)
  else
  begin
    DefaultCase := TContactCase.Create('TiN 2um on 304 Steel',
      TBallSpec.FromDiameterMm(6.0, FMatLib.GetPreset('Si3N4', mcBall), False),
      [TLayer.Create(FMatLib.GetPreset('TiN', mcCoating), 2.0)],
      FMatLib.GetPreset('304 Steel', mcSubstrate),
      TLoadCase.FromNewtons(5.0, 0.0),
      TSolverConfig.DefaultConfig);
  end;
  LoadCaseToUI(DefaultCase);
end;

procedure TfrmMain.StopActiveWorker;
begin
  if FWorker <> nil then
  begin
    FWorker.RequestCancel;
    FWorker.WaitFor;
    // Drain queued callbacks while the form instance is still intact before destroying objects.
    CheckSynchronize(0);
    FreeAndNil(FWorker);
  end;
  Screen.Cursor := crDefault;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  StopActiveWorker;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  StopActiveWorker;
  Screen.Cursor := crDefault;
  FreeAndNil(FBundle);
  FreeAndNil(FMesh);
  FreeAndNil(FHeatmapBmp);
  FreeAndNil(FSweepBmp);
  FreeAndNil(FMeshBmp);
  FreeAndNil(FMatLib);
end;

procedure TfrmMain.SetBusyState(ABusy: Boolean; const AStatusText: string);
begin
  btnSolve.Enabled := not ABusy;
  btnSweep.Enabled := not ABusy;
  btnRunSweep.Enabled := not ABusy;
  btnSetupCcx.Enabled := not ABusy;
  btnOpen.Enabled := not ABusy;
  btnSave.Enabled := not ABusy;
  btnMaterials.Enabled := not ABusy;
  btnCancel.Enabled := ABusy;

  mniRunSolve.Enabled := not ABusy;
  mniRunSweep.Enabled := not ABusy;
  mniSetupCcx.Enabled := not ABusy;
  mniOpenCase.Enabled := not ABusy;
  mniSaveCase.Enabled := not ABusy;
  mniManageMaterials.Enabled := not ABusy;
  mniCancel.Enabled := ABusy;

  if ABusy then
    Screen.Cursor := crHourGlass
  else
    Screen.Cursor := crDefault;

  stpStatus.Caption := AStatusText;
end;

procedure TfrmMain.AppendLog(const AMsg: string);
begin
  memLog.Lines.Add(AMsg);
end;

procedure TfrmMain.LoadCaseToUI(const ACase: TContactCase);
var
  I: Integer;
begin
  FUpdatingUI := True;
  try
    edtCaseName.Text := ACase.CaseName;
    PopulatePresetCombos(ACase.Ball.Material.Name, ACase.Substrate.Name);

    FLastBallMaterial := ACase.Ball.Material.Clone;
    if ACase.Ball.RadiusUm >= 100.0 then
    begin
      cbBallSizeMode.ItemIndex := 0;
      edtBallSize.Text := Format('%.6g', [2.0 * UmToMm(ACase.Ball.RadiusUm)], TFormatSettings.Invariant);
    end
    else
    begin
      cbBallSizeMode.ItemIndex := 2;
      edtBallSize.Text := Format('%.6g', [ACase.Ball.RadiusUm], TFormatSettings.Invariant);
    end;
    FPrevBallSizeMode := cbBallSizeMode.ItemIndex;
    edtBallE.Text := Format('%.6g', [ACase.Ball.Material.EGpa], TFormatSettings.Invariant);
    edtBallNu.Text := Format('%.6g', [ACase.Ball.Material.Nu], TFormatSettings.Invariant);
    chkBallRigid.Checked := ACase.Ball.Rigid;

    if ACase.LoadCase.NormalLoadMn >= 500.0 then
    begin
      cbLoadUnit.ItemIndex := 0;
      edtNormalLoad.Text := Format('%.6g', [MnToNewtons(ACase.LoadCase.NormalLoadMn)], TFormatSettings.Invariant);
    end
    else
    begin
      cbLoadUnit.ItemIndex := 1;
      edtNormalLoad.Text := Format('%.6g', [ACase.LoadCase.NormalLoadMn], TFormatSettings.Invariant);
    end;
    FPrevLoadUnit := cbLoadUnit.ItemIndex;
    edtFriction.Text := Format('%.6g', [ACase.LoadCase.FrictionCoeff], TFormatSettings.Invariant);

    SetLength(FLayers, Length(ACase.Layers));
    for I := 0 to High(ACase.Layers) do
    begin
      FLayers[I].Material := ACase.Layers[I].Material.Clone;
      FLayers[I].ThicknessUm := ACase.Layers[I].ThicknessUm;
    end;
    RefreshLayerListView(0);

    edtSubE.Text := Format('%.6g', [ACase.Substrate.EGpa], TFormatSettings.Invariant);
    edtSubNu.Text := Format('%.6g', [ACase.Substrate.Nu], TFormatSettings.Invariant);
    edtSubSigmaY.Text := FormatOptFloat(ACase.Substrate.SigmaYGpa, ACase.Substrate.HasSigmaY);
    edtSubEt.Text := FormatOptFloat(ACase.Substrate.EtGpa, ACase.Substrate.HasEt);
    edtSubHardness.Text := FormatOptFloat(ACase.Substrate.HardnessGpa, ACase.Substrate.HasHardness);
    FLastSubHardening := Copy(ACase.Substrate.HardeningCurve);

    case ACase.Solver.Engine of
      seBoth: cbEngine.ItemIndex := 0;
      seElastic: cbEngine.ItemIndex := 1;
      seFem: cbEngine.ItemIndex := 2;
    end;
    case ACase.Solver.MeshDensity of
      mdCoarse: cbMeshDensity.ItemIndex := 0;
      mdStandard: cbMeshDensity.ItemIndex := 1;
      mdFine: cbMeshDensity.ItemIndex := 2;
    end;
    case ACase.Solver.ElementType of
      etCAX4I: cbElementType.ItemIndex := 0;
      etCAX4: cbElementType.ItemIndex := 1;
      etCAX4R: cbElementType.ItemIndex := 2;
    end;
    edtNRings.Text := IntToStr(ACase.Solver.NRings);
    chkUnloading.Checked := ACase.Solver.IncludeUnloading;
  finally
    FUpdatingUI := False;
  end;
end;

function TfrmMain.BuildCaseFromUI: TContactCase;
var
  SizeVal, RadiusUm, BallE, BallNu, LoadVal, LoadMn, Fric: Double;
  SubE, SubNu, OptVal: Double;
  BallMat, SubMat: TMaterial;
  Ball: TBallSpec;
  Load: TLoadCase;
  Cfg: TSolverConfig;
  LayersCopy: TArray<TLayer>;
  NRings, I: Integer;
  CaseNameStr, BallName, SubName: string;
begin
  CaseNameStr := Trim(edtCaseName.Text);
  if CaseNameStr = '' then
    CaseNameStr := 'TriboContact Case';

  SizeVal := ParseRequiredDouble(edtBallSize.Text, 'Ball size');
  case cbBallSizeMode.ItemIndex of
    0: RadiusUm := MmToUm(SizeVal) * 0.5;
    1: RadiusUm := MmToUm(SizeVal);
  else
    RadiusUm := SizeVal;
  end;
  BallE := ParseRequiredDouble(edtBallE.Text, 'Ball modulus E (GPa)');
  BallNu := ParseRequiredDouble(edtBallNu.Text, 'Ball Poisson ratio nu');
  if (cbBallPreset.ItemIndex >= 0) and (cbBallPreset.ItemIndex < Length(FBallPresets)) then
    BallName := FBallPresets[cbBallPreset.ItemIndex].Name
  else if FLastBallMaterial.Name <> '' then
    BallName := FLastBallMaterial.Name
  else
    BallName := 'Custom Ball';
  BallMat := FLastBallMaterial.Clone;
  BallMat.Name := BallName;
  BallMat.EGpa := BallE;
  BallMat.Nu := BallNu;
  BallMat.Category := mcBall;
  Ball := TBallSpec.Create(RadiusUm, BallMat, chkBallRigid.Checked);

  LoadVal := ParseRequiredDouble(edtNormalLoad.Text, 'Normal load');
  if cbLoadUnit.ItemIndex = 0 then
    LoadMn := NewtonsToMn(LoadVal)
  else
    LoadMn := LoadVal;
  Fric := ParseRequiredDouble(edtFriction.Text, 'Friction coefficient mu');
  Load := TLoadCase.Create(LoadMn, Fric);

  if (cbSubPreset.ItemIndex >= 0) and (cbSubPreset.ItemIndex < Length(FSubPresets)) then
    SubName := FSubPresets[cbSubPreset.ItemIndex].Name
  else
    SubName := 'Custom Substrate';
  SubE := ParseRequiredDouble(edtSubE.Text, 'Substrate modulus E (GPa)');
  SubNu := ParseRequiredDouble(edtSubNu.Text, 'Substrate Poisson ratio nu');
  SubMat := TMaterial.Create(SubName, SubE, SubNu, mcSubstrate);
  if TryParseOptionalDouble(edtSubSigmaY.Text, 'Substrate yield sigma_y (GPa)', OptVal) then
  begin
    SubMat.HasSigmaY := True;
    SubMat.SigmaYGpa := OptVal;
  end;
  if TryParseOptionalDouble(edtSubEt.Text, 'Substrate tangent E_t (GPa)', OptVal) then
  begin
    SubMat.HasEt := True;
    SubMat.EtGpa := OptVal;
  end;
  if TryParseOptionalDouble(edtSubHardness.Text, 'Substrate hardness H (GPa)', OptVal) then
  begin
    SubMat.HasHardness := True;
    SubMat.HardnessGpa := OptVal;
  end;
  SubMat.HardeningCurve := Copy(FLastSubHardening);

  Cfg := TSolverConfig.DefaultConfig;
  case cbEngine.ItemIndex of
    0: Cfg.Engine := seBoth;
    1: Cfg.Engine := seElastic;
  else
    Cfg.Engine := seFem;
  end;
  case cbMeshDensity.ItemIndex of
    0: Cfg.MeshDensity := mdCoarse;
    1: Cfg.MeshDensity := mdStandard;
  else
    Cfg.MeshDensity := mdFine;
  end;
  case cbElementType.ItemIndex of
    0: Cfg.ElementType := etCAX4I;
    1: Cfg.ElementType := etCAX4;
  else
    Cfg.ElementType := etCAX4R;
  end;
  if not TryStrToInt(Trim(edtNRings.Text), NRings) then
    raise EArgumentException.Create('Elastic Rings must be an integer');
  Cfg.NRings := NRings;
  Cfg.IncludeUnloading := chkUnloading.Checked;

  SetLength(LayersCopy, Length(FLayers));
  for I := 0 to High(FLayers) do
  begin
    LayersCopy[I].Material := FLayers[I].Material.Clone;
    LayersCopy[I].ThicknessUm := FLayers[I].ThicknessUm;
  end;

  Result := TContactCase.Create(CaseNameStr, Ball, LayersCopy, SubMat, Load, Cfg);
  Result.Validate;
end;

procedure TfrmMain.cbBallPresetChange(Sender: TObject);
var
  Idx: Integer;
begin
  if FUpdatingUI then
    Exit;
  Idx := cbBallPreset.ItemIndex;
  if (Idx >= 0) and (Idx < Length(FBallPresets)) then
  begin
    FLastBallMaterial := FBallPresets[Idx].Clone;
    edtBallE.Text := Format('%.6g', [FLastBallMaterial.EGpa], TFormatSettings.Invariant);
    edtBallNu.Text := Format('%.6g', [FLastBallMaterial.Nu], TFormatSettings.Invariant);
  end;
end;

procedure TfrmMain.cbBallSizeModeChange(Sender: TObject);
var
  Val, RadiusUm, NewVal: Double;
begin
  if FUpdatingUI then
    Exit;
  if TryStrToFloat(Trim(edtBallSize.Text), Val, TFormatSettings.Invariant) and (Val > 0.0) then
  begin
    case FPrevBallSizeMode of
      0: RadiusUm := MmToUm(Val) * 0.5;
      1: RadiusUm := MmToUm(Val);
    else
      RadiusUm := Val;
    end;
    case cbBallSizeMode.ItemIndex of
      0: NewVal := 2.0 * UmToMm(RadiusUm);
      1: NewVal := UmToMm(RadiusUm);
    else
      NewVal := RadiusUm;
    end;
    edtBallSize.Text := Format('%.6g', [NewVal], TFormatSettings.Invariant);
  end;
  FPrevBallSizeMode := cbBallSizeMode.ItemIndex;
end;

procedure TfrmMain.cbLoadUnitChange(Sender: TObject);
var
  Val, LoadMn, NewVal: Double;
begin
  if FUpdatingUI then
    Exit;
  if TryStrToFloat(Trim(edtNormalLoad.Text), Val, TFormatSettings.Invariant) and (Val > 0.0) then
  begin
    if FPrevLoadUnit = 0 then
      LoadMn := NewtonsToMn(Val)
    else
      LoadMn := Val;
    if cbLoadUnit.ItemIndex = 0 then
      NewVal := MnToNewtons(LoadMn)
    else
      NewVal := LoadMn;
    edtNormalLoad.Text := Format('%.6g', [NewVal], TFormatSettings.Invariant);
  end;
  FPrevLoadUnit := cbLoadUnit.ItemIndex;
end;

procedure TfrmMain.cbSubPresetChange(Sender: TObject);
var
  Idx: Integer;
  M: TMaterial;
begin
  if FUpdatingUI then
    Exit;
  Idx := cbSubPreset.ItemIndex;
  if (Idx >= 0) and (Idx < Length(FSubPresets)) then
  begin
    M := FSubPresets[Idx];
    edtSubE.Text := Format('%.6g', [M.EGpa], TFormatSettings.Invariant);
    edtSubNu.Text := Format('%.6g', [M.Nu], TFormatSettings.Invariant);
    edtSubSigmaY.Text := FormatOptFloat(M.SigmaYGpa, M.HasSigmaY);
    edtSubEt.Text := FormatOptFloat(M.EtGpa, M.HasEt);
    edtSubHardness.Text := FormatOptFloat(M.HardnessGpa, M.HasHardness);
    FLastSubHardening := Copy(M.HardeningCurve);
  end;
end;

procedure TfrmMain.btnSubEstYieldClick(Sender: TObject);
var
  HVal: Double;
begin
  try
    HVal := ParseRequiredDouble(edtSubHardness.Text, 'Substrate hardness H (GPa)');
    edtSubSigmaY.Text := Format('%.6g', [YieldFromHardness(HVal, 2.8)], TFormatSettings.Invariant);
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnLayerAddClick(Sender: TObject);
var
  Dlg: TfrmLayerDialog;
  Dummy: TLayer;
  N: Integer;
begin
  Dummy := Default(TLayer);
  Dlg := TfrmLayerDialog.Create(Self);
  try
    Dlg.Bind(FMatLib, Dummy, False);
    if Dlg.ShowModal = mrOk then
    begin
      N := Length(FLayers);
      SetLength(FLayers, N + 1);
      FLayers[N] := Dlg.BuildLayer;
      RefreshLayerListView(N);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmMain.btnLayerEditClick(Sender: TObject);
var
  Idx: Integer;
  Dlg: TfrmLayerDialog;
begin
  if lvLayers.Selected = nil then
    Exit;
  Idx := lvLayers.Selected.Index;
  if (Idx < 0) or (Idx > High(FLayers)) then
    Exit;
  Dlg := TfrmLayerDialog.Create(Self);
  try
    Dlg.Bind(FMatLib, FLayers[Idx], True);
    if Dlg.ShowModal = mrOk then
    begin
      FLayers[Idx] := Dlg.BuildLayer;
      RefreshLayerListView(Idx);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmMain.btnLayerDelClick(Sender: TObject);
var
  Idx, I: Integer;
begin
  if lvLayers.Selected = nil then
    Exit;
  Idx := lvLayers.Selected.Index;
  if (Idx < 0) or (Idx > High(FLayers)) then
    Exit;
  for I := Idx to High(FLayers) - 1 do
    FLayers[I] := FLayers[I + 1];
  SetLength(FLayers, Length(FLayers) - 1);
  if Idx >= Length(FLayers) then
    Idx := High(FLayers);
  RefreshLayerListView(Idx);
end;

procedure TfrmMain.btnLayerUpClick(Sender: TObject);
var
  Idx: Integer;
  Tmp: TLayer;
begin
  if lvLayers.Selected = nil then
    Exit;
  Idx := lvLayers.Selected.Index;
  if (Idx <= 0) or (Idx > High(FLayers)) then
    Exit;
  Tmp := FLayers[Idx - 1];
  FLayers[Idx - 1] := FLayers[Idx];
  FLayers[Idx] := Tmp;
  RefreshLayerListView(Idx - 1);
end;

procedure TfrmMain.btnLayerDownClick(Sender: TObject);
var
  Idx: Integer;
  Tmp: TLayer;
begin
  if lvLayers.Selected = nil then
    Exit;
  Idx := lvLayers.Selected.Index;
  if (Idx < 0) or (Idx >= High(FLayers)) then
    Exit;
  Tmp := FLayers[Idx + 1];
  FLayers[Idx + 1] := FLayers[Idx];
  FLayers[Idx] := Tmp;
  RefreshLayerListView(Idx + 1);
end;

procedure TfrmMain.LoadExampleFile(const ARelPath: string);
var
  Path: string;
begin
  Path := TPath.Combine(FindRepoRoot, ARelPath);
  if not TFile.Exists(Path) then
  begin
    MessageDlg('Example file not found: ' + Path, mtError, [mbOK], 0);
    Exit;
  end;
  LoadCaseToUI(TContactCase.LoadFromFile(Path));
  stpStatus.Caption := 'Loaded example: ' + ExtractFileName(Path);
end;

procedure TfrmMain.mniExTinSteelClick(Sender: TObject);
begin
  LoadExampleFile('examples\tin_on_steel.json');
end;

procedure TfrmMain.mniExDlcGlassClick(Sender: TObject);
begin
  LoadExampleFile('examples\dlc_on_glass.json');
end;

procedure TfrmMain.mniExSicPmmaClick(Sender: TObject);
begin
  LoadExampleFile('examples\hard_film_on_polymer.json');
end;

procedure TfrmMain.btnOpenClick(Sender: TObject);
var
  InitDir: string;
begin
  InitDir := TPath.Combine(FindRepoRoot, 'examples');
  if TDirectory.Exists(InitDir) then
    dlgOpenCase.InitialDir := InitDir;
  if not dlgOpenCase.Execute then
    Exit;
  try
    LoadCaseToUI(TContactCase.LoadFromFile(dlgOpenCase.FileName));
    stpStatus.Caption := 'Opened: ' + ExtractFileName(dlgOpenCase.FileName);
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnSaveClick(Sender: TObject);
var
  C: TContactCase;
begin
  try
    C := BuildCaseFromUI;
    if dlgSaveCase.Execute then
    begin
      C.SaveToFile(dlgSaveCase.FileName);
      stpStatus.Caption := 'Saved: ' + ExtractFileName(dlgSaveCase.FileName);
    end;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnMaterialsClick(Sender: TObject);
var
  Dlg: TfrmMaterialDialog;
  BallSel, SubSel: string;
begin
  if cbBallPreset.ItemIndex >= 0 then BallSel := cbBallPreset.Text else BallSel := '';
  if cbSubPreset.ItemIndex >= 0 then SubSel := cbSubPreset.Text else SubSel := '';
  Dlg := TfrmMaterialDialog.Create(Self);
  try
    Dlg.BindLibrary(FMatLib);
    Dlg.ShowModal;
    PopulatePresetCombos(BallSel, SubSel);
  finally
    Dlg.Free;
  end;
end;

procedure TfrmMain.btnSolveClick(Sender: TObject);
var
  C: TContactCase;
begin
  if FWorker <> nil then
    Exit;
  try
    C := BuildCaseFromUI;
  except
    on E: Exception do
    begin
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  memLog.Lines.Clear;
  AppendLog('Starting solve: ' + C.CaseName);
  SetBusyState(True, 'Running simulation...');

  FWorker := TSolverWorkerThread.CreateSolve(C,
    procedure(const AMsg: string)
    begin
      if not (csDestroying in ComponentState) then
        AppendLog(AMsg);
    end,
    procedure(ABundle: TComparisonBundle; const AError: string; ACancelled: Boolean)
    begin
      if csDestroying in ComponentState then
      begin
        ABundle.Free;
        Exit;
      end;
      FreeAndNil(FWorker);
      if ACancelled then
      begin
        ABundle.Free;
        AppendLog('Solve cancelled.');
        SetBusyState(False, 'Cancelled');
        Exit;
      end;
      if AError <> '' then
      begin
        ABundle.Free;
        AppendLog('ERROR: ' + AError);
        SetBusyState(False, 'Error: ' + AError);
        MessageDlg(AError, mtError, [mbOK], 0);
        Exit;
      end;
      FreeAndNil(FBundle);
      FBundle := ABundle;
      FLastSolvedCase := C.Clone;
      FHasSolvedCase := True;
      UpdateResultsUI;
      SetBusyState(False, 'Completed');
    end);
  FWorker.Start;
end;

procedure TfrmMain.RunSolveSyncForTest;
var
  C: TContactCase;
  Bundle: TComparisonBundle;
begin
  StopActiveWorker;
  Screen.Cursor := crHourGlass;
  try
    C := BuildCaseFromUI;
    Bundle := RunCase(C,
      procedure(S: string)
      begin
        AppendLog(S);
      end);
    FreeAndNil(FBundle);
    FBundle := Bundle;
    FLastSolvedCase := C.Clone;
    FHasSolvedCase := True;
    UpdateResultsUI;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmMain.btnCancelClick(Sender: TObject);
begin
  if FWorker <> nil then
  begin
    FWorker.RequestCancel;
    stpStatus.Caption := 'Cancelling...';
  end;
end;

function TfrmMain.ParseSweepLoads: TDoubleArray;
var
  Parts: TArray<string>;
  I: Integer;
  Val: Double;
begin
  Parts := Trim(edtSweepLoads.Text).Split([','], TStringSplitOptions.ExcludeEmpty);
  if Length(Parts) = 0 then
    raise EArgumentException.Create('Enter comma-separated positive loads in mN');
  SetLength(Result, Length(Parts));
  for I := 0 to High(Parts) do
  begin
    if (not TryStrToFloat(Trim(Parts[I]), Val, TFormatSettings.Invariant)) or (Val <= 0.0) then
      raise EArgumentException.CreateFmt('Invalid load value: %s', [Parts[I]]);
    Result[I] := Val;
  end;
end;

procedure TfrmMain.btnSweepClick(Sender: TObject);
var
  C: TContactCase;
  Loads: TDoubleArray;
begin
  if FWorker <> nil then
    Exit;
  try
    C := BuildCaseFromUI;
    Loads := ParseSweepLoads;
  except
    on E: Exception do
    begin
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  pgcPlots.ActivePage := tabSweep;
  memLog.Lines.Clear;
  AppendLog(Format('Starting load sweep (%d loads)...', [Length(Loads)]));
  SetBusyState(True, 'Running load sweep...');

  FWorker := TSolverWorkerThread.CreateSweep(C, Loads,
    procedure(const AMsg: string)
    begin
      if not (csDestroying in ComponentState) then
        AppendLog(AMsg);
    end,
    procedure(const APoints: TArray<TSweepPoint>; const AError: string; ACancelled: Boolean)
    begin
      if csDestroying in ComponentState then
        Exit;
      FreeAndNil(FWorker);
      if ACancelled then
      begin
        AppendLog('Load sweep cancelled.');
        SetBusyState(False, 'Cancelled');
        Exit;
      end;
      if AError <> '' then
      begin
        AppendLog('ERROR: ' + AError);
        SetBusyState(False, 'Error: ' + AError);
        MessageDlg(AError, mtError, [mbOK], 0);
        Exit;
      end;
      FSweepPoints := Copy(APoints);
      PopulateSweepImage;
      SetBusyState(False, Format('Sweep completed (%d loads)', [Length(FSweepPoints)]));
    end);
  FWorker.Start;
end;

procedure TfrmMain.btnSetupCcxClick(Sender: TObject);
begin
  if FWorker <> nil then
    Exit;
  pgcPlots.ActivePage := tabLog;
  AppendLog('Installing / verifying CalculiX...');
  SetBusyState(True, 'Setting up CalculiX...');

  FWorker := TSolverWorkerThread.CreateSetupCcx('',
    procedure(const AMsg: string)
    begin
      if not (csDestroying in ComponentState) then
        AppendLog(AMsg);
    end,
    procedure(const ACcxPath, AError: string)
    begin
      if csDestroying in ComponentState then
        Exit;
      FreeAndNil(FWorker);
      RefreshCcxStatus;
      if AError <> '' then
      begin
        AppendLog('ERROR: ' + AError);
        SetBusyState(False, 'CalculiX setup failed');
        MessageDlg(AError, mtError, [mbOK], 0);
        Exit;
      end;
      AppendLog('CalculiX verified at: ' + ACcxPath);
      SetBusyState(False, 'CalculiX verified');
      MessageDlg('CalculiX is installed and verified:' + sLineBreak + ACcxPath,
        mtInformation, [mbOK], 0);
    end);
  FWorker.Start;
end;

procedure TfrmMain.UpdateSummaryGrid;
var
  ResArr: array[1..4] of TContactResult;
  Row: Integer;
  R: TContactResult;
  TotalRuntime: Double;
begin
  if FBundle = nil then
    Exit;
  ResArr[1] := FBundle.HertzSubstrate;
  ResArr[2] := FBundle.HertzTopFilm;
  ResArr[3] := FBundle.ElasticLayered;
  ResArr[4] := FBundle.FemCalculix;

  TotalRuntime := 0.0;
  for Row := 1 to 4 do
  begin
    R := ResArr[Row];
    if R = nil then
    begin
      grdSummary.Cells[1, Row] := '-';
      grdSummary.Cells[2, Row] := '-';
      grdSummary.Cells[3, Row] := '-';
      grdSummary.Cells[4, Row] := '-';
      grdSummary.Cells[5, Row] := '-';
      grdSummary.Cells[6, Row] := '-';
      grdSummary.Cells[7, Row] := '-';
      Continue;
    end;
    TotalRuntime := TotalRuntime + R.RuntimeS;
    grdSummary.Cells[1, Row] := FormatGridFloat(R.ContactRadiusUm, '%.3f');
    grdSummary.Cells[2, Row] := FormatGridFloat(R.PenetrationDepthUm, '%.4f');
    if R.HasResidualDepth then
      grdSummary.Cells[3, Row] := FormatGridFloat(R.ResidualDepthUm, '%.4f')
    else
      grdSummary.Cells[3, Row] := '-';
    grdSummary.Cells[4, Row] := FormatGridFloat(R.PMaxGpa, '%.4f');
    grdSummary.Cells[5, Row] := FormatGridFloat(R.PMeanGpa, '%.4f');
    grdSummary.Cells[6, Row] := FormatGridFloat(R.MaxYieldRatio, '%.3f');
    if R.HasMaxPeeq then
      grdSummary.Cells[7, Row] := FormatGridFloat(R.MaxPeeq, '%.4g')
    else
      grdSummary.Cells[7, Row] := '-';
  end;
  stpRuntime.Caption := Format('Runtime: %.2f s', [TotalRuntime], TFormatSettings.Invariant);
end;

procedure TfrmMain.UpdateInterfaceGrid;
var
  TotalRows, Row, K: Integer;
  procedure FillRows(const ASolverLabel: string; AR: TContactResult);
  var
    J: Integer;
    IfS: TInterfaceStressSummary;
  begin
    if AR = nil then
      Exit;
    for J := 0 to High(AR.Interfaces) do
    begin
      IfS := AR.Interfaces[J];
      grdInterfaces.Cells[0, Row] := ASolverLabel;
      grdInterfaces.Cells[1, Row] := IntToStr(IfS.InterfaceIndex);
      grdInterfaces.Cells[2, Row] := FormatGridFloat(IfS.DepthUm, '%.4g');
      grdInterfaces.Cells[3, Row] := IfS.AboveLabel;
      grdInterfaces.Cells[4, Row] := IfS.BelowLabel;
      grdInterfaces.Cells[5, Row] := FormatGridFloat(IfS.MaxSigmaRRAboveGpa, '%.4f');
      grdInterfaces.Cells[6, Row] := FormatGridFloat(IfS.MaxSigmaRRBelowGpa, '%.4f');
      grdInterfaces.Cells[7, Row] := FormatGridFloat(IfS.MaxAbsTauRZGpa, '%.4f');
      grdInterfaces.Cells[8, Row] := FormatGridFloat(IfS.MaxSigmaVmAboveGpa, '%.4f');
      grdInterfaces.Cells[9, Row] := FormatGridFloat(IfS.MaxSigmaVmBelowGpa, '%.4f');
      Inc(Row);
    end;
  end;
begin
  if FBundle = nil then
    Exit;
  TotalRows := 0;
  if FBundle.ElasticLayered <> nil then
    TotalRows := TotalRows + Length(FBundle.ElasticLayered.Interfaces);
  if FBundle.FemCalculix <> nil then
    TotalRows := TotalRows + Length(FBundle.FemCalculix.Interfaces);

  if TotalRows = 0 then
  begin
    grdInterfaces.RowCount := 2;
    for K := 0 to grdInterfaces.ColCount - 1 do
      grdInterfaces.Cells[K, 1] := '-';
    Exit;
  end;

  grdInterfaces.RowCount := TotalRows + 1;
  Row := 1;
  FillRows('Layered Elastic', FBundle.ElasticLayered);
  FillRows('CalculiX FEM', FBundle.FemCalculix);
end;

procedure TfrmMain.UpdateYieldBadge;
var
  Ratio, Peeq: Double;
  Warn, HavePeeq: Boolean;
begin
  if FBundle = nil then
    Exit;
  Ratio := 0.0;
  Warn := False;
  HavePeeq := False;
  Peeq := 0.0;

  if FBundle.FemCalculix <> nil then
  begin
    Ratio := System.Math.Max(Ratio, FBundle.FemCalculix.MaxYieldRatio);
    Warn := Warn or FBundle.FemCalculix.YieldWarning;
    HavePeeq := FBundle.FemCalculix.HasMaxPeeq;
    Peeq := FBundle.FemCalculix.MaxPeeq;
  end
  else if FBundle.ElasticLayered <> nil then
  begin
    Ratio := System.Math.Max(Ratio, FBundle.ElasticLayered.MaxYieldRatio);
    Warn := Warn or FBundle.ElasticLayered.YieldWarning;
  end
  else if FBundle.HertzSubstrate <> nil then
  begin
    Ratio := FBundle.HertzSubstrate.MaxYieldRatio;
    Warn := FBundle.HertzSubstrate.YieldWarning;
  end;

  if Warn or (HavePeeq and (Peeq > 1e-4)) then
  begin
    lblYieldBadge.Font.Color := clMaroon;
    if HavePeeq then
      lblYieldBadge.Caption := Format('Yield Status: PLASTIC / YIELD ONSET (max s_vM/s_y = %.3f, max PEEQ = %.4g)',
        [Ratio, Peeq], TFormatSettings.Invariant)
    else
      lblYieldBadge.Caption := Format('Yield Status: YIELD ONSET WARNING (max s_vM/s_y = %.3f > 0.95)',
        [Ratio], TFormatSettings.Invariant);
  end
  else
  begin
    lblYieldBadge.Font.Color := clGreen;
    lblYieldBadge.Caption := Format('Yield Status: ELASTIC REGIME (max s_vM/s_y = %.3f)',
      [Ratio], TFormatSettings.Invariant);
  end;
end;

procedure TfrmMain.UpdateCharts;
  procedure FillSeries(ASeries: TLineSeries; const AX, AY: TDoubleArray);
  var
    I, N: Integer;
  begin
    ASeries.Clear;
    N := Min(Length(AX), Length(AY));
    for I := 0 to N - 1 do
      ASeries.AddXY(AX[I], AY[I]);
  end;
begin
  srsPressHertzSub.Clear;
  srsPressHertzFilm.Clear;
  srsPressElastic.Clear;
  srsPressFem.Clear;
  srsClElVm.Clear;
  srsClElRR.Clear;
  srsClFemVm.Clear;
  srsClFemRR.Clear;

  if FBundle = nil then
    Exit;

  if FBundle.HertzSubstrate <> nil then
    FillSeries(srsPressHertzSub, FBundle.HertzSubstrate.RUm, FBundle.HertzSubstrate.PGpa);
  if FBundle.HertzTopFilm <> nil then
    FillSeries(srsPressHertzFilm, FBundle.HertzTopFilm.RUm, FBundle.HertzTopFilm.PGpa);
  if FBundle.ElasticLayered <> nil then
  begin
    FillSeries(srsPressElastic, FBundle.ElasticLayered.RUm, FBundle.ElasticLayered.PGpa);
    FillSeries(srsClElVm, FBundle.ElasticLayered.CenterlineSigmaVmGpa, FBundle.ElasticLayered.ZCenterlineUm);
    FillSeries(srsClElRR, FBundle.ElasticLayered.CenterlineSigmaRRGpa, FBundle.ElasticLayered.ZCenterlineUm);
  end;
  if FBundle.FemCalculix <> nil then
  begin
    FillSeries(srsPressFem, FBundle.FemCalculix.RUm, FBundle.FemCalculix.PGpa);
    FillSeries(srsClFemVm, FBundle.FemCalculix.CenterlineSigmaVmGpa, FBundle.FemCalculix.ZCenterlineUm);
    FillSeries(srsClFemRR, FBundle.FemCalculix.CenterlineSigmaRRGpa, FBundle.FemCalculix.ZCenterlineUm);
  end;
end;

procedure TfrmMain.UpdateHeatmap;
var
  Res: TContactResult;
  Field: THeatmapField;
begin
  if (FBundle = nil) or not FHasSolvedCase then
    Exit;

  if cbHeatmapSolver.ItemIndex = 1 then
    Res := FBundle.FemCalculix
  else
    Res := FBundle.ElasticLayered;
  if Res = nil then
  begin
    if FBundle.ElasticLayered <> nil then
      Res := FBundle.ElasticLayered
    else
      Res := FBundle.FemCalculix;
  end;
  if (Res = nil) or (Res.StressGrid = nil) then
  begin
    FreeAndNil(FHeatmapBmp);
    imgHeatmap.Picture.Assign(nil);
    Exit;
  end;

  case cbHeatmapField.ItemIndex of
    0: Field := hfSigmaVm;
    1: Field := hfSigmaRR;
    2: Field := hfTauRZ;
    3: Field := hfPeeq;
  else
    Field := hfSlidingSigmaXX;
  end;
  if (Field = hfPeeq) and not Res.StressGrid.HasPeeq then
    Field := hfSigmaVm;
  if (Field = hfSlidingSigmaXX) and not Res.StressGrid.HasSliding then
    Field := hfSigmaVm;

  FreeAndNil(FHeatmapBmp);
  FHeatmapBmp := RenderSubsurfaceHeatmapBitmap(Res, FLastSolvedCase, Field);
  imgHeatmap.Picture.Bitmap.Assign(FHeatmapBmp);
end;

procedure TfrmMain.UpdateMeshPreview(AUseCurrentUI: Boolean);
var
  C: TContactCase;
  EstA, EstDelta, EstRatio: Double;
  HSub, HFilm: TContactResult;
begin
  if AUseCurrentUI or not FHasSolvedCase then
    C := BuildCaseFromUI
  else
    C := FLastSolvedCase.Clone;

  if (FBundle <> nil) and (FBundle.ElasticLayered <> nil) then
  begin
    EstA := FBundle.ElasticLayered.ContactRadiusUm;
    EstDelta := FBundle.ElasticLayered.PenetrationDepthUm;
    EstRatio := FBundle.ElasticLayered.MaxYieldRatio;
  end
  else
  begin
    ComputeHertzBaselines(C, HSub, HFilm);
    try
      EstA := System.Math.Max(HSub.ContactRadiusUm, HFilm.ContactRadiusUm);
      EstDelta := System.Math.Max(HSub.PenetrationDepthUm, HFilm.PenetrationDepthUm);
      EstRatio := System.Math.Max(HSub.MaxYieldRatio, HFilm.MaxYieldRatio);
    finally
      HFilm.Free;
      HSub.Free;
    end;
  end;

  FreeAndNil(FMesh);
  FMesh := GenerateFemMesh(C, EstA, EstDelta, EstRatio);
  FMeshCase := C;

  FreeAndNil(FMeshBmp);
  FMeshBmp := RenderFemMeshBitmap(FMesh, FMeshCase, chkMeshZoom.Checked);
  imgMesh.Picture.Bitmap.Assign(FMeshBmp);
end;

procedure TfrmMain.PopulateSweepImage;
begin
  FreeAndNil(FSweepBmp);
  FSweepBmp := RenderLoadSweepBitmap(FSweepPoints);
  imgSweep.Picture.Bitmap.Assign(FSweepBmp);
end;

procedure TfrmMain.UpdateResultsUI;
begin
  if FBundle = nil then
    Exit;
  if (FBundle.FemCalculix <> nil) and (FBundle.ElasticLayered = nil) then
    cbHeatmapSolver.ItemIndex := 1
  else if FBundle.ElasticLayered <> nil then
    cbHeatmapSolver.ItemIndex := 0;

  UpdateSummaryGrid;
  UpdateInterfaceGrid;
  UpdateYieldBadge;
  UpdateCharts;
  UpdateHeatmap;
  UpdateMeshPreview(False);
end;

procedure TfrmMain.cbHeatmapChange(Sender: TObject);
begin
  UpdateHeatmap;
end;

procedure TfrmMain.btnSaveHeatmapClick(Sender: TObject);
var
  Ext: string;
begin
  if FHeatmapBmp = nil then
  begin
    MessageDlg('No heatmap has been rendered yet.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not dlgSaveImage.Execute then
    Exit;
  Ext := LowerCase(ExtractFileExt(dlgSaveImage.FileName));
  if Ext = '.pdf' then
    ExportBitmapPDF(FHeatmapBmp, dlgSaveImage.FileName, 'Subsurface Stress Heatmap')
  else
    ExportBitmapPNG(FHeatmapBmp, dlgSaveImage.FileName);
  stpStatus.Caption := 'Saved heatmap: ' + dlgSaveImage.FileName;
end;

procedure TfrmMain.btnPreviewMeshClick(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  try
    try
      UpdateMeshPreview(True);
      pgcPlots.ActivePage := tabMesh;
      if FMesh <> nil then
        stpStatus.Caption := Format('Mesh preview: %d nodes, %d quads, dr_min=%.3g um',
          [Length(FMesh.Nodes), Length(FMesh.Quads), FMesh.DrMinUm], TFormatSettings.Invariant);
    except
      on E: Exception do
        MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmMain.chkMeshZoomClick(Sender: TObject);
begin
  if FMesh = nil then
    Exit;
  FreeAndNil(FMeshBmp);
  FMeshBmp := RenderFemMeshBitmap(FMesh, FMeshCase, chkMeshZoom.Checked);
  imgMesh.Picture.Bitmap.Assign(FMeshBmp);
end;

procedure TfrmMain.btnExportDataClick(Sender: TObject);
var
  OutDir: string;
begin
  if FBundle = nil then
  begin
    MessageDlg('Run a solve first before exporting data.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not dlgSelectDir.Execute then
    Exit;
  OutDir := dlgSelectDir.FileName;
  Screen.Cursor := crHourGlass;
  try
    ExportBundleJSON(FBundle, TPath.Combine(OutDir, 'results.json'));
    ExportBundleCSV(FBundle, OutDir);
    if Length(FSweepPoints) > 0 then
    begin
      ExportSweepCSV(FSweepPoints, TPath.Combine(OutDir, 'sweep.csv'));
      ExportSweepJSON(FSweepPoints, TPath.Combine(OutDir, 'sweep.json'));
    end;
    stpStatus.Caption := 'Exported data to: ' + OutDir;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmMain.btnExportPlotsClick(Sender: TObject);
var
  OutDir: string;
  C: TContactCase;
begin
  if FBundle = nil then
  begin
    MessageDlg('Run a solve first before exporting plots.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not dlgSelectDir.Execute then
    Exit;
  OutDir := dlgSelectDir.FileName;
  Screen.Cursor := crHourGlass;
  try
    if FHasSolvedCase then
      C := FLastSolvedCase
    else
      C := BuildCaseFromUI;
    ExportBundlePlots(FBundle, C, OutDir, True);
    if Length(FSweepPoints) > 0 then
    begin
      if FSweepBmp = nil then
        PopulateSweepImage;
      ExportBitmapPNG(FSweepBmp, TPath.Combine(OutDir, 'sweep.png'));
      ExportBitmapPDF(FSweepBmp, TPath.Combine(OutDir, 'sweep.pdf'), 'Load Sweep');
    end;
    stpStatus.Caption := 'Exported PNG + PDF plots to: ' + OutDir;
  finally
    Screen.Cursor := crDefault;
  end;
end;

class function TfrmMain.ResolveHelpIndexPath: string;
var
  ExeCandidate, RepoCandidate: string;
begin
  ExeCandidate := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Help\index.html');
  if TFile.Exists(ExeCandidate) then
    Exit(ExeCandidate);
  RepoCandidate := TPath.Combine(FindRepoRoot, 'Help\index.html');
  if TFile.Exists(RepoCandidate) then
    Exit(RepoCandidate);
  Result := '';
end;

procedure TfrmMain.btnHelpClick(Sender: TObject);
var
  HelpPath: string;
begin
  HelpPath := ResolveHelpIndexPath;
  if HelpPath = '' then
  begin
    MessageDlg('Help manual not found (Help\index.html).', mtError, [mbOK], 0);
    Exit;
  end;
  ShellExecuteW(Handle, 'open', PWideChar(HelpPath), nil,
    PWideChar(ExtractFileDir(HelpPath)), SW_SHOWNORMAL);
end;

procedure TfrmMain.mniExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.mniAboutClick(Sender: TObject);
begin
  MessageDlg(
    'TriboContact - Layered Contact Mechanics Solver' + sLineBreak +
    'Engine 1: Semi-analytical SMM + Polonsky-Keer CG + Hamilton/O''Sullivan-King' + sLineBreak +
    'Engine 2: Automated CalculiX Axisymmetric Elastic-Plastic FEM' + sLineBreak +
    'Internal units: um, GPa, mN.',
    mtInformation, [mbOK], 0);
end;

end.
