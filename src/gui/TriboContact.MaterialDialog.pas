unit TriboContact.MaterialDialog;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  RzCommon, RzPanel, RzButton, RzEdit, RzCmboBx,
  TriboContact.Models, TriboContact.Materials;

type
  TfrmMaterialDialog = class(TForm)
    pnlFilter: TRzPanel;
    pnlCenter: TRzPanel;
    pnlBottom: TRzPanel;
    lblCategoryFilter: TLabel;
    cbCategoryFilter: TRzComboBox;
    lvMaterials: TListView;
    gbEditor: TRzGroupBox;
    lblName: TLabel;
    lblCategory: TLabel;
    lblE: TLabel;
    lblNu: TLabel;
    lblSigmaY: TLabel;
    lblEt: TLabel;
    lblHardness: TLabel;
    lblNotes: TLabel;
    edtName: TRzEdit;
    cbCategory: TRzComboBox;
    edtE: TRzEdit;
    edtNu: TRzEdit;
    edtSigmaY: TRzEdit;
    edtEt: TRzEdit;
    edtHardness: TRzEdit;
    edtNotes: TRzEdit;
    btnEstYield: TRzButton;
    btnSaveCustom: TRzButton;
    lblUserPath: TLabel;
    btnClose: TRzButton;
    procedure cbCategoryFilterChange(Sender: TObject);
    procedure lvMaterialsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure btnEstYieldClick(Sender: TObject);
    procedure btnSaveCustomClick(Sender: TObject);
  private
    FLib: TMaterialLibrary;
    FItems: TArray<TMaterial>;
    procedure RefreshList(const ASelectName: string = '');
    procedure LoadMaterialToEditor(const AMat: TMaterial);
    function BuildMaterialFromEditor: TMaterial;
    function ParseRequiredDouble(const AText, AFieldName: string): Double;
    function TryParseOptionalDouble(const AText, AFieldName: string; out AValue: Double): Boolean;
  public
    procedure BindLibrary(ALib: TMaterialLibrary);
    procedure SaveCurrentMaterial;
  end;

implementation

{$R *.dfm}

function TfrmMaterialDialog.ParseRequiredDouble(const AText, AFieldName: string): Double;
begin
  if not TryStrToFloat(Trim(AText), Result, TFormatSettings.Invariant) then
    raise EArgumentException.CreateFmt('Invalid numeric value for %s: %s', [AFieldName, AText]);
end;

function TfrmMaterialDialog.TryParseOptionalDouble(const AText, AFieldName: string;
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

procedure TfrmMaterialDialog.BindLibrary(ALib: TMaterialLibrary);
begin
  FLib := ALib;
  if FLib <> nil then
    lblUserPath.Caption := 'Custom presets file: ' + FLib.UserFilePath
  else
    lblUserPath.Caption := '';
  RefreshList('');
end;

procedure TfrmMaterialDialog.RefreshList(const ASelectName: string);
var
  Cats: TArray<TMaterialCategory>;
  Cat: TMaterialCategory;
  Arr: TArray<TMaterial>;
  AllList: TArray<TMaterial>;
  N, I, SelectIdx: Integer;
  Item: TListItem;
  M: TMaterial;
begin
  lvMaterials.Items.BeginUpdate;
  try
    lvMaterials.Items.Clear;
    SetLength(FItems, 0);
    if FLib = nil then
      Exit;

    case cbCategoryFilter.ItemIndex of
      1: Cats := [mcBall];
      2: Cats := [mcCoating];
      3: Cats := [mcSubstrate];
    else
      Cats := [mcBall, mcCoating, mcSubstrate];
    end;

    for Cat in Cats do
    begin
      Arr := FLib.GetByCategory(Cat);
      N := Length(AllList);
      SetLength(AllList, N + Length(Arr));
      for I := 0 to High(Arr) do
        AllList[N + I] := Arr[I];
    end;
    FItems := AllList;

    SelectIdx := -1;
    for I := 0 to High(FItems) do
    begin
      M := FItems[I];
      Item := lvMaterials.Items.Add;
      Item.Caption := M.Name;
      Item.SubItems.Add(MaterialCategoryToStr(M.Category));
      Item.SubItems.Add(Format('%.5g', [M.EGpa], TFormatSettings.Invariant));
      Item.SubItems.Add(Format('%.4g', [M.Nu], TFormatSettings.Invariant));
      if M.HasSigmaY then
        Item.SubItems.Add(Format('%.5g', [M.SigmaYGpa], TFormatSettings.Invariant))
      else
        Item.SubItems.Add('-');
      if M.HasHardness then
        Item.SubItems.Add(Format('%.5g', [M.HardnessGpa], TFormatSettings.Invariant))
      else
        Item.SubItems.Add('-');

      if (ASelectName <> '') and SameText(M.Name, Trim(ASelectName)) then
        SelectIdx := I;
    end;

    if (SelectIdx < 0) and (Length(FItems) > 0) then
      SelectIdx := 0;
    if (SelectIdx >= 0) and (SelectIdx < lvMaterials.Items.Count) then
    begin
      lvMaterials.Items[SelectIdx].Selected := True;
      LoadMaterialToEditor(FItems[SelectIdx]);
    end;
  finally
    lvMaterials.Items.EndUpdate;
  end;
end;

procedure TfrmMaterialDialog.LoadMaterialToEditor(const AMat: TMaterial);
begin
  edtName.Text := AMat.Name;
  case AMat.Category of
    mcBall: cbCategory.ItemIndex := 0;
    mcCoating: cbCategory.ItemIndex := 1;
    mcSubstrate: cbCategory.ItemIndex := 2;
  end;
  edtE.Text := Format('%.6g', [AMat.EGpa], TFormatSettings.Invariant);
  edtNu.Text := Format('%.6g', [AMat.Nu], TFormatSettings.Invariant);
  if AMat.HasSigmaY then
    edtSigmaY.Text := Format('%.6g', [AMat.SigmaYGpa], TFormatSettings.Invariant)
  else
    edtSigmaY.Text := '';
  if AMat.HasEt then
    edtEt.Text := Format('%.6g', [AMat.EtGpa], TFormatSettings.Invariant)
  else
    edtEt.Text := '';
  if AMat.HasHardness then
    edtHardness.Text := Format('%.6g', [AMat.HardnessGpa], TFormatSettings.Invariant)
  else
    edtHardness.Text := '';
  edtNotes.Text := AMat.Notes;
end;

function TfrmMaterialDialog.BuildMaterialFromEditor: TMaterial;
var
  NameStr: string;
  Cat: TMaterialCategory;
  EGpa, Nu, Val: Double;
begin
  NameStr := Trim(edtName.Text);
  if NameStr = '' then
    raise EArgumentException.Create('Material name cannot be empty');
  case cbCategory.ItemIndex of
    0: Cat := mcBall;
    1: Cat := mcCoating;
  else
    Cat := mcSubstrate;
  end;
  EGpa := ParseRequiredDouble(edtE.Text, 'Modulus E (GPa)');
  Nu := ParseRequiredDouble(edtNu.Text, 'Poisson ratio nu');

  Result := TMaterial.Create(NameStr, EGpa, Nu, Cat);
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
  Result.Notes := Trim(edtNotes.Text);
  Result.Validate;
end;

procedure TfrmMaterialDialog.SaveCurrentMaterial;
var
  Mat: TMaterial;
begin
  if FLib = nil then
    raise EInvalidOperation.Create('Material library is not bound');
  Mat := BuildMaterialFromEditor;
  FLib.SaveUserMaterial(Mat);
  RefreshList(Mat.Name);
end;

procedure TfrmMaterialDialog.cbCategoryFilterChange(Sender: TObject);
begin
  RefreshList('');
end;

procedure TfrmMaterialDialog.lvMaterialsSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  if Selected and (Item <> nil) and (Item.Index >= 0) and (Item.Index < Length(FItems)) then
    LoadMaterialToEditor(FItems[Item.Index]);
end;

procedure TfrmMaterialDialog.btnEstYieldClick(Sender: TObject);
var
  HVal: Double;
begin
  try
    HVal := ParseRequiredDouble(edtHardness.Text, 'Hardness H (GPa)');
    edtSigmaY.Text := Format('%.6g', [YieldFromHardness(HVal, 2.8)], TFormatSettings.Invariant);
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMaterialDialog.btnSaveCustomClick(Sender: TObject);
begin
  try
    SaveCurrentMaterial;
    MessageDlg('Saved custom material preset to local user library.', mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

end.
