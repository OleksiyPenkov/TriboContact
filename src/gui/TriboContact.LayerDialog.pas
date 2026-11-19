unit TriboContact.LayerDialog;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  RzCommon, RzPanel, RzButton, RzEdit, RzCmboBx,
  TriboContact.Models, TriboContact.Materials;

type
  TfrmLayerDialog = class(TForm)
    pnlMain: TRzPanel;
    pnlButtons: TRzPanel;
    lblPreset: TLabel;
    lblName: TLabel;
    lblThickness: TLabel;
    lblE: TLabel;
    lblNu: TLabel;
    lblSigmaY: TLabel;
    lblEt: TLabel;
    lblHardness: TLabel;
    cbPreset: TRzComboBox;
    edtName: TRzEdit;
    edtThickness: TRzEdit;
    cbThickUnit: TRzComboBox;
    edtE: TRzEdit;
    edtNu: TRzEdit;
    edtSigmaY: TRzEdit;
    edtEt: TRzEdit;
    edtHardness: TRzEdit;
    btnEstYield: TRzButton;
    btnSavePreset: TRzButton;
    btnOK: TRzButton;
    btnCancel: TRzButton;
    procedure cbPresetChange(Sender: TObject);
    procedure btnEstYieldClick(Sender: TObject);
    procedure btnSavePresetClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FLib: TMaterialLibrary;
    FPresets: TArray<TMaterial>;
    FUpdating: Boolean;
    procedure PopulatePresetList(const ASelectName: string);
    procedure ApplyMaterialFields(const AMat: TMaterial);
    function BuildMaterialFromFields: TMaterial;
    function ParseRequiredDouble(const AText, AFieldName: string): Double;
    function TryParseOptionalDouble(const AText, AFieldName: string; out AValue: Double): Boolean;
  public
    procedure Bind(ALib: TMaterialLibrary; const AInitialLayer: TLayer;
      AHasInitial: Boolean = False);
    function BuildLayer: TLayer;
    procedure EstimateYieldFromHardness;
  end;

implementation

{$R *.dfm}

function FormatOptFloat(AValue: Double; AHasValue: Boolean): string;
begin
  if AHasValue then
    Result := Format('%.6g', [AValue], TFormatSettings.Invariant)
  else
    Result := '';
end;

function TfrmLayerDialog.ParseRequiredDouble(const AText, AFieldName: string): Double;
begin
  if not TryStrToFloat(Trim(AText), Result, TFormatSettings.Invariant) then
    raise EArgumentException.CreateFmt('Invalid numeric value for %s: %s', [AFieldName, AText]);
end;

function TfrmLayerDialog.TryParseOptionalDouble(const AText, AFieldName: string;
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

procedure TfrmLayerDialog.PopulatePresetList(const ASelectName: string);
var
  I, MatchIdx: Integer;
begin
  FUpdating := True;
  try
    cbPreset.Items.Clear;
    if FLib <> nil then
      FPresets := FLib.GetByCategory(mcCoating)
    else
      SetLength(FPresets, 0);

    MatchIdx := -1;
    for I := 0 to High(FPresets) do
    begin
      cbPreset.Items.Add(FPresets[I].Name);
      if SameText(FPresets[I].Name, Trim(ASelectName)) then
        MatchIdx := I;
    end;
    if (MatchIdx < 0) and (cbPreset.Items.Count > 0) then
      MatchIdx := 0;
    cbPreset.ItemIndex := MatchIdx;
  finally
    FUpdating := False;
  end;
end;

procedure TfrmLayerDialog.ApplyMaterialFields(const AMat: TMaterial);
begin
  FUpdating := True;
  try
    edtName.Text := AMat.Name;
    edtE.Text := Format('%.6g', [AMat.EGpa], TFormatSettings.Invariant);
    edtNu.Text := Format('%.6g', [AMat.Nu], TFormatSettings.Invariant);
    edtSigmaY.Text := FormatOptFloat(AMat.SigmaYGpa, AMat.HasSigmaY);
    edtEt.Text := FormatOptFloat(AMat.EtGpa, AMat.HasEt);
    edtHardness.Text := FormatOptFloat(AMat.HardnessGpa, AMat.HasHardness);
  finally
    FUpdating := False;
  end;
end;

function TfrmLayerDialog.BuildMaterialFromFields: TMaterial;
var
  NameStr: string;
  EGpa, Nu, Val: Double;
begin
  NameStr := Trim(edtName.Text);
  if NameStr = '' then
    raise EArgumentException.Create('Material name cannot be empty');
  EGpa := ParseRequiredDouble(edtE.Text, 'Modulus E (GPa)');
  Nu := ParseRequiredDouble(edtNu.Text, 'Poisson ratio nu');

  Result := TMaterial.Create(NameStr, EGpa, Nu, mcCoating);
  if TryParseOptionalDouble(edtSigmaY.Text, 'Yield stress sigma_y (GPa)', Val) then
  begin
    Result.HasSigmaY := True;
    Result.SigmaYGpa := Val;
  end;
  if TryParseOptionalDouble(edtEt.Text, 'Tangent modulus E_t (GPa)', Val) then
  begin
    Result.HasEt := True;
    Result.EtGpa := Val;
  end;
  if TryParseOptionalDouble(edtHardness.Text, 'Hardness H (GPa)', Val) then
  begin
    Result.HasHardness := True;
    Result.HardnessGpa := Val;
  end;
  Result.Validate;
end;

procedure TfrmLayerDialog.Bind(ALib: TMaterialLibrary; const AInitialLayer: TLayer;
  AHasInitial: Boolean);
var
  DefaultMat: TMaterial;
begin
  FLib := ALib;
  if AHasInitial then
  begin
    PopulatePresetList(AInitialLayer.Material.Name);
    ApplyMaterialFields(AInitialLayer.Material);
    edtThickness.Text := Format('%.6g', [AInitialLayer.ThicknessUm], TFormatSettings.Invariant);
    cbThickUnit.ItemIndex := 0;
  end
  else
  begin
    PopulatePresetList('TiN');
    if Length(FPresets) > 0 then
    begin
      if (cbPreset.ItemIndex >= 0) and (cbPreset.ItemIndex < Length(FPresets)) then
        DefaultMat := FPresets[cbPreset.ItemIndex]
      else
        DefaultMat := FPresets[0];
    end
    else
      DefaultMat := TMaterial.Create('Custom Coating', 300.0, 0.25, mcCoating);
    ApplyMaterialFields(DefaultMat);
    edtThickness.Text := '2.0';
    cbThickUnit.ItemIndex := 0;
  end;
end;

function TfrmLayerDialog.BuildLayer: TLayer;
var
  RawThick, ThickUm: Double;
  Mat: TMaterial;
begin
  Mat := BuildMaterialFromFields;
  RawThick := ParseRequiredDouble(edtThickness.Text, 'Thickness');
  if cbThickUnit.ItemIndex = 1 then
    ThickUm := NmToUm(RawThick)
  else
    ThickUm := RawThick;
  Result := TLayer.Create(Mat, ThickUm);
  Result.Validate;
end;

procedure TfrmLayerDialog.EstimateYieldFromHardness;
var
  HVal: Double;
begin
  HVal := ParseRequiredDouble(edtHardness.Text, 'Hardness H (GPa)');
  edtSigmaY.Text := Format('%.6g', [YieldFromHardness(HVal, 2.8)], TFormatSettings.Invariant);
end;

procedure TfrmLayerDialog.cbPresetChange(Sender: TObject);
var
  Idx: Integer;
begin
  if FUpdating then
    Exit;
  Idx := cbPreset.ItemIndex;
  if (Idx >= 0) and (Idx < Length(FPresets)) then
    ApplyMaterialFields(FPresets[Idx]);
end;

procedure TfrmLayerDialog.btnEstYieldClick(Sender: TObject);
begin
  try
    EstimateYieldFromHardness;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmLayerDialog.btnSavePresetClick(Sender: TObject);
var
  Mat: TMaterial;
begin
  if FLib = nil then
    Exit;
  try
    Mat := BuildMaterialFromFields;
    FLib.SaveUserMaterial(Mat);
    PopulatePresetList(Mat.Name);
    MessageDlg(Format('Saved custom coating preset "%s".', [Mat.Name]),
      mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmLayerDialog.btnOKClick(Sender: TObject);
begin
  try
    BuildLayer;
    ModalResult := mrOk;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

end.
