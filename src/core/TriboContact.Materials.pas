unit TriboContact.Materials;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  TriboContact.Models;

type
  TMaterialLibrary = class
  private
    FMaterials: TList<TMaterial>;
    FBaseFilePath: string;
    FUserFilePath: string;
    procedure AddOrReplaceMaterial(const AMat: TMaterial);
    procedure LoadArrayFromFile(const AFilePath: string);
    procedure SaveUserMaterialsOnly(const AUserList: TList<TMaterial>; const AFilePath: string);
  public
    constructor Create; overload;
    constructor Create(const ABaseFilePath, AUserFilePath: string); overload;
    destructor Destroy; override;
    procedure Reload;
    function Count: Integer;
    function GetByCategory(ACategory: TMaterialCategory): TArray<TMaterial>;
    function TryFind(const AName: string; ACategory: TMaterialCategory;
      out AMat: TMaterial): Boolean; overload;
    function TryFind(const AName: string; out AMat: TMaterial): Boolean; overload;
    function GetPreset(const AName: string; ACategory: TMaterialCategory): TMaterial;
    procedure SaveUserMaterial(const AMat: TMaterial);
    property BaseFilePath: string read FBaseFilePath;
    property UserFilePath: string read FUserFilePath;
  end;

function FindRepoRoot: string;

implementation

uses
  System.IOUtils, System.JSON;

function FindRepoRoot: string;
var
  Dir, Parent: string;
  Depth: Integer;
begin
  Dir := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  if Dir = '' then
    Dir := GetCurrentDir;
  for Depth := 0 to 6 do
  begin
    if TFile.Exists(TPath.Combine(Dir, 'data\materials.json')) or
       TFile.Exists(TPath.Combine(Dir, 'SPEC.md')) then
      Exit(Dir);
    Parent := ExcludeTrailingPathDelimiter(ExtractFilePath(Dir));
    if (Parent = '') or SameText(Parent, Dir) then
      Break;
    Dir := Parent;
  end;
  Result := ExcludeTrailingPathDelimiter(GetCurrentDir);
end;

function DefaultUserDataDir: string;
var
  Root: string;
begin
  Root := FindRepoRoot;
  if TFile.Exists(TPath.Combine(Root, 'SPEC.md')) then
    Result := TPath.Combine(Root, 'data\local')
  else
    Result := TPath.Combine(TPath.GetHomePath, 'TriboContact');
end;

constructor TMaterialLibrary.Create;
var
  Root: string;
begin
  Root := FindRepoRoot;
  Create(TPath.Combine(Root, 'data\materials.json'),
    TPath.Combine(DefaultUserDataDir, 'materials_user.json'));
end;

constructor TMaterialLibrary.Create(const ABaseFilePath, AUserFilePath: string);
begin
  inherited Create;
  FMaterials := TList<TMaterial>.Create;
  FBaseFilePath := ABaseFilePath;
  FUserFilePath := AUserFilePath;
  Reload;
end;

destructor TMaterialLibrary.Destroy;
begin
  FMaterials.Free;
  inherited Destroy;
end;

procedure TMaterialLibrary.AddOrReplaceMaterial(const AMat: TMaterial);
var
  I: Integer;
begin
  for I := 0 to FMaterials.Count - 1 do
  begin
    if (FMaterials[I].Category = AMat.Category) and
       SameText(FMaterials[I].Name, AMat.Name) then
    begin
      FMaterials[I] := AMat.Clone;
      Exit;
    end;
  end;
  FMaterials.Add(AMat.Clone);
end;

procedure TMaterialLibrary.LoadArrayFromFile(const AFilePath: string);
var
  Text: string;
  RootVal, ArrVal, ItemVal: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Mat: TMaterial;
begin
  if not TFile.Exists(AFilePath) then
    Exit;
  Text := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
  RootVal := TJSONObject.ParseJSONValue(Text, False, True);
  if RootVal = nil then
    raise EArgumentException.CreateFmt('Invalid JSON in material library: %s', [AFilePath]);
  try
    if RootVal is TJSONArray then
      Arr := TJSONArray(RootVal)
    else if RootVal is TJSONObject then
    begin
      ArrVal := TJSONObject(RootVal).FindValue('materials');
      if (ArrVal = nil) or not (ArrVal is TJSONArray) then
        raise EArgumentException.CreateFmt('Missing "materials" array in %s', [AFilePath]);
      Arr := TJSONArray(ArrVal);
    end
    else
      raise EArgumentException.CreateFmt('Invalid root JSON type in %s', [AFilePath]);

    for I := 0 to Arr.Count - 1 do
    begin
      ItemVal := Arr.Items[I];
      if not (ItemVal is TJSONObject) then
        raise EArgumentException.Create('Material entry must be a JSON object');
      Mat := TMaterial.FromJSON(TJSONObject(ItemVal));
      AddOrReplaceMaterial(Mat);
    end;
  finally
    RootVal.Free;
  end;
end;

procedure TMaterialLibrary.Reload;
begin
  FMaterials.Clear;
  if not TFile.Exists(FBaseFilePath) then
    raise EFileNotFoundException.CreateFmt('Base material library not found: %s', [FBaseFilePath]);
  LoadArrayFromFile(FBaseFilePath);
  if (FUserFilePath <> '') and TFile.Exists(FUserFilePath) then
    LoadArrayFromFile(FUserFilePath);
end;

function TMaterialLibrary.Count: Integer;
begin
  Result := FMaterials.Count;
end;

function TMaterialLibrary.GetByCategory(ACategory: TMaterialCategory): TArray<TMaterial>;
var
  List: TList<TMaterial>;
  Mat: TMaterial;
begin
  List := TList<TMaterial>.Create;
  try
    for Mat in FMaterials do
      if Mat.Category = ACategory then
        List.Add(Mat.Clone);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TMaterialLibrary.TryFind(const AName: string; ACategory: TMaterialCategory;
  out AMat: TMaterial): Boolean;
var
  Mat: TMaterial;
begin
  Result := False;
  AMat := Default(TMaterial);
  for Mat in FMaterials do
  begin
    if (Mat.Category = ACategory) and SameText(Mat.Name, Trim(AName)) then
    begin
      AMat := Mat.Clone;
      Exit(True);
    end;
  end;
end;

function TMaterialLibrary.TryFind(const AName: string; out AMat: TMaterial): Boolean;
var
  Mat: TMaterial;
begin
  Result := False;
  AMat := Default(TMaterial);
  for Mat in FMaterials do
  begin
    if SameText(Mat.Name, Trim(AName)) then
    begin
      AMat := Mat.Clone;
      Exit(True);
    end;
  end;
end;

function TMaterialLibrary.GetPreset(const AName: string; ACategory: TMaterialCategory): TMaterial;
begin
  if not TryFind(AName, ACategory, Result) then
    if not TryFind(AName, Result) then
      raise EArgumentException.CreateFmt('Material preset "%s" (%s) not found',
        [AName, MaterialCategoryToStr(ACategory)]);
end;

procedure TMaterialLibrary.SaveUserMaterialsOnly(const AUserList: TList<TMaterial>;
  const AFilePath: string);
var
  Root, Obj: TJSONObject;
  Arr: TJSONArray;
  Dir: string;
  Mat: TMaterial;
begin
  Dir := ExtractFilePath(AFilePath);
  if (Dir <> '') and not TDirectory.Exists(Dir) then
    TDirectory.CreateDirectory(Dir);

  Root := TJSONObject.Create;
  try
    Arr := TJSONArray.Create;
    for Mat in AUserList do
    begin
      Obj := Mat.ToJSON;
      Arr.AddElement(Obj);
    end;
    Root.AddPair('materials', Arr);
    TFile.WriteAllText(AFilePath, Root.Format(2), TEncoding.UTF8);
  finally
    Root.Free;
  end;
end;

procedure TMaterialLibrary.SaveUserMaterial(const AMat: TMaterial);
var
  UserList: TList<TMaterial>;
  Existing: TMaterialLibrary;
  I: Integer;
  Replaced: Boolean;
begin
  AMat.Validate;
  if FUserFilePath = '' then
    raise EArgumentException.Create('User material path is empty');

  UserList := TList<TMaterial>.Create;
  try
    if TFile.Exists(FUserFilePath) then
    begin
      Existing := TMaterialLibrary.Create(FUserFilePath, '');
      try
        for I := 0 to Existing.FMaterials.Count - 1 do
          UserList.Add(Existing.FMaterials[I].Clone);
      finally
        Existing.Free;
      end;
    end;

    Replaced := False;
    for I := 0 to UserList.Count - 1 do
    begin
      if (UserList[I].Category = AMat.Category) and
         SameText(UserList[I].Name, AMat.Name) then
      begin
        UserList[I] := AMat.Clone;
        Replaced := True;
        Break;
      end;
    end;
    if not Replaced then
      UserList.Add(AMat.Clone);

    SaveUserMaterialsOnly(UserList, FUserFilePath);
  finally
    UserList.Free;
  end;

  AddOrReplaceMaterial(AMat);
end;

end.
