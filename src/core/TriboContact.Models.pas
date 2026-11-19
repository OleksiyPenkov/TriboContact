unit TriboContact.Models;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Math;

type
  TMaterialCategory = (mcBall, mcCoating, mcSubstrate);
  TSolverEngineKind = (seElastic, seFem, seBoth);
  TMeshDensity = (mdCoarse, mdStandard, mdFine);
  TElementType = (etCAX4, etCAX4R, etCAX4I);

  TDoubleArray = TArray<Double>;
  TDoubleMatrix = TArray<TArray<Double>>;

  THardeningPoint = record
    TrueStressGpa: Double;
    PlasticStrain: Double;
  end;

  TMaterial = record
    Name: string;
    EGpa: Double;
    Nu: Double;
    HasSigmaY: Boolean;
    SigmaYGpa: Double;
    HasEt: Boolean;
    EtGpa: Double;
    HardeningCurve: TArray<THardeningPoint>;
    HasHardness: Boolean;
    HardnessGpa: Double;
    Category: TMaterialCategory;
    Notes: string;
    class function Create(const AName: string; AEGpa, ANu: Double;
      ACategory: TMaterialCategory = mcCoating): TMaterial; static;
    procedure Validate;
    function EffectiveTangentGpa: Double;
    function Clone: TMaterial;
    function ToJSON: TJSONObject;
    class function FromJSON(AObj: TJSONObject): TMaterial; static;
  end;

  TLayer = record
    Material: TMaterial;
    ThicknessUm: Double;
    class function Create(const AMaterial: TMaterial; AThicknessUm: Double): TLayer; static;
    class function CreateNm(const AMaterial: TMaterial; AThicknessNm: Double): TLayer; static;
    procedure Validate;
    function ToJSON: TJSONObject;
    class function FromJSON(AObj: TJSONObject): TLayer; static;
  end;

  TBallSpec = record
    RadiusUm: Double;
    Material: TMaterial;
    Rigid: Boolean;
    class function Create(ARadiusUm: Double; const AMaterial: TMaterial;
      ARigid: Boolean = False): TBallSpec; static;
    class function FromDiameterMm(ADiameterMm: Double; const AMaterial: TMaterial;
      ARigid: Boolean = False): TBallSpec; static;
    class function FromRadiusMm(ARadiusMm: Double; const AMaterial: TMaterial;
      ARigid: Boolean = False): TBallSpec; static;
    procedure Validate;
    function ToJSON: TJSONObject;
    class function FromJSON(AObj: TJSONObject): TBallSpec; static;
  end;

  TLoadCase = record
    NormalLoadMn: Double;
    FrictionCoeff: Double;
    class function Create(ANormalLoadMn: Double; AFrictionCoeff: Double = 0.0): TLoadCase; static;
    class function FromNewtons(AForceN: Double; AFrictionCoeff: Double = 0.0): TLoadCase; static;
    procedure Validate;
    function ToJSON: TJSONObject;
    class function FromJSON(AObj: TJSONObject): TLoadCase; static;
  end;

  TSolverConfig = record
    Engine: TSolverEngineKind;
    NRings: Integer;
    MeshDensity: TMeshDensity;
    ElementType: TElementType;
    IncludeUnloading: Boolean;
    MaxLoadBrackets: Integer;
    LoadToleranceRel: Double;
    CcxPath: string;
    TimeoutS: Integer;
    WorkDir: string;
    class function DefaultConfig: TSolverConfig; static;
    procedure Validate;
    function ToJSON: TJSONObject;
    class function FromJSON(AObj: TJSONObject): TSolverConfig; static;
  end;

  TContactCase = record
    CaseName: string;
    Ball: TBallSpec;
    Layers: TArray<TLayer>;
    Substrate: TMaterial;
    LoadCase: TLoadCase;
    Solver: TSolverConfig;
    class function Create(const ACaseName: string; const ABall: TBallSpec;
      const ALayers: TArray<TLayer>; const ASubstrate: TMaterial;
      const ALoadCase: TLoadCase; const ASolver: TSolverConfig): TContactCase; static;
    procedure Validate;
    function TotalCoatingThicknessUm: Double;
    function Clone: TContactCase;
    function ToJSON: TJSONObject;
    function ToJSONString(AFormatted: Boolean = True): string;
    class function FromJSON(AObj: TJSONObject): TContactCase; static;
    class function FromJSONString(const AText: string): TContactCase; static;
    class function LoadFromFile(const AFilePath: string): TContactCase; static;
    procedure SaveToFile(const AFilePath: string);
  end;

  TStressGrid = class
  public
    RUm: TDoubleArray;
    ZUm: TDoubleArray;
    SigmaRRGpa: TDoubleMatrix;
    SigmaTTGpa: TDoubleMatrix;
    SigmaZZGpa: TDoubleMatrix;
    TauRZGpa: TDoubleMatrix;
    SigmaVmGpa: TDoubleMatrix;
    HasPeeq: Boolean;
    Peeq: TDoubleMatrix;
    HasSliding: Boolean;
    SlidingSurfaceXUm: TDoubleArray;
    SlidingSurfaceSigmaXXGpa: TDoubleArray;
    SlidingPlaneXUm: TDoubleArray;
    SlidingPlaneSigmaXXGpa: TDoubleMatrix;
    SlidingPlaneTauXZGpa: TDoubleMatrix;
    SlidingPlaneSigmaVmGpa: TDoubleMatrix;
    function ToJSON: TJSONObject;
  end;

  TInterfaceStressSummary = record
    InterfaceIndex: Integer;
    DepthUm: Double;
    AboveLabel: string;
    BelowLabel: string;
    MaxSigmaRRAboveGpa: Double;
    MaxSigmaRRBelowGpa: Double;
    MinSigmaRRAboveGpa: Double;
    MinSigmaRRBelowGpa: Double;
    MaxAbsTauRZGpa: Double;
    MaxSigmaVmAboveGpa: Double;
    MaxSigmaVmBelowGpa: Double;
    HasPeeq: Boolean;
    MaxPeeqAbove: Double;
    MaxPeeqBelow: Double;
    function ToJSON: TJSONObject;
  end;

  TYieldRatioEntry = record
    MaterialLabel: string;
    Ratio: Double;
  end;

  TContactResult = class
  public
    SolverName: string;
    ContactRadiusUm: Double;
    PenetrationDepthUm: Double;
    HasResidualDepth: Boolean;
    ResidualDepthUm: Double;
    PMaxGpa: Double;
    PMeanGpa: Double;
    ActualLoadMn: Double;
    ForceBalanceErrorRel: Double;
    RUm: TDoubleArray;
    PGpa: TDoubleArray;
    ZCenterlineUm: TDoubleArray;
    CenterlineSigmaVmGpa: TDoubleArray;
    CenterlineSigmaRRGpa: TDoubleArray;
    CenterlineSigmaZZGpa: TDoubleArray;
    StressGrid: TStressGrid;
    Interfaces: TArray<TInterfaceStressSummary>;
    LayerYieldRatios: TArray<TYieldRatioEntry>;
    YieldWarning: Boolean;
    HasMaxPeeq: Boolean;
    MaxPeeq: Double;
    RuntimeS: Double;
    Diagnostics: TStringList;
    constructor Create;
    destructor Destroy; override;
    function MaxYieldRatio: Double;
    function ToJSON: TJSONObject;
  end;

  TComparisonBundle = class
  public
    CaseName: string;
    Ball: TBallSpec;
    Layers: TArray<TLayer>;
    Substrate: TMaterial;
    LoadCase: TLoadCase;
    Solver: TSolverConfig;
    HertzSubstrate: TContactResult;
    HertzTopFilm: TContactResult;
    ElasticLayered: TContactResult;
    FemCalculix: TContactResult;
    constructor Create;
    destructor Destroy; override;
    function ToJSON: TJSONObject;
    function ToJSONString(AFormatted: Boolean = True): string;
  end;

function MmToUm(AValueMm: Double): Double;
function UmToMm(AValueUm: Double): Double;
function NmToUm(AValueNm: Double): Double;
function UmToNm(AValueUm: Double): Double;
function NewtonsToMn(AValueN: Double): Double;
function MnToNewtons(AValueMn: Double): Double;
function MpaToGpa(AValueMpa: Double): Double;
function GpaToMpa(AValueGpa: Double): Double;
function YieldFromHardness(AHGpa: Double; AConstraintFactor: Double = 2.8): Double;

function MaterialCategoryToStr(ACat: TMaterialCategory): string;
function StrToMaterialCategory(const AStr: string): TMaterialCategory;
function SolverEngineToStr(AEngine: TSolverEngineKind): string;
function StrToSolverEngine(const AStr: string): TSolverEngineKind;
function MeshDensityToStr(ADensity: TMeshDensity): string;
function StrToMeshDensity(const AStr: string): TMeshDensity;
function ElementTypeToStr(AElemType: TElementType): string;
function StrToElementType(const AStr: string): TElementType;

function JsonTryGetDouble(AObj: TJSONObject; const AKey: string; out AValue: Double): Boolean;
function JsonTryGetInt(AObj: TJSONObject; const AKey: string; out AValue: Integer): Boolean;
function JsonTryGetString(AObj: TJSONObject; const AKey: string; out AValue: string): Boolean;
function JsonTryGetBool(AObj: TJSONObject; const AKey: string; out AValue: Boolean): Boolean;
function DoubleArrayToJSON(const AArr: TDoubleArray): TJSONArray;
function DoubleMatrixToJSON(const AMat: TDoubleMatrix): TJSONArray;

implementation

uses
  System.IOUtils, System.Generics.Collections;

function IsFiniteDouble(AValue: Double): Boolean; inline;
begin
  Result := not (IsNan(AValue) or IsInfinite(AValue));
end;

function MmToUm(AValueMm: Double): Double;
begin
  Result := AValueMm * 1000.0;
end;

function UmToMm(AValueUm: Double): Double;
begin
  Result := AValueUm * 0.001;
end;

function NmToUm(AValueNm: Double): Double;
begin
  Result := AValueNm * 0.001;
end;

function UmToNm(AValueUm: Double): Double;
begin
  Result := AValueUm * 1000.0;
end;

function NewtonsToMn(AValueN: Double): Double;
begin
  Result := AValueN * 1000.0;
end;

function MnToNewtons(AValueMn: Double): Double;
begin
  Result := AValueMn * 0.001;
end;

function MpaToGpa(AValueMpa: Double): Double;
begin
  Result := AValueMpa * 0.001;
end;

function GpaToMpa(AValueGpa: Double): Double;
begin
  Result := AValueGpa * 1000.0;
end;

function YieldFromHardness(AHGpa: Double; AConstraintFactor: Double): Double;
begin
  if (not IsFiniteDouble(AHGpa)) or (AHGpa <= 0.0) then
    raise EArgumentException.Create('Hardness must be positive');
  if (not IsFiniteDouble(AConstraintFactor)) or (AConstraintFactor <= 0.0) then
    raise EArgumentException.Create('Constraint factor must be positive');
  Result := AHGpa / AConstraintFactor;
end;

function MaterialCategoryToStr(ACat: TMaterialCategory): string;
begin
  case ACat of
    mcBall: Result := 'ball';
    mcCoating: Result := 'coating';
    mcSubstrate: Result := 'substrate';
  else
    Result := 'coating';
  end;
end;

function StrToMaterialCategory(const AStr: string): TMaterialCategory;
var
  Lower: string;
begin
  Lower := Trim(AStr).ToLower;
  if Lower = 'ball' then
    Result := mcBall
  else if Lower = 'coating' then
    Result := mcCoating
  else if Lower = 'substrate' then
    Result := mcSubstrate
  else
    raise EArgumentException.CreateFmt('Unknown material category: %s', [AStr]);
end;

function SolverEngineToStr(AEngine: TSolverEngineKind): string;
begin
  case AEngine of
    seElastic: Result := 'elastic';
    seFem: Result := 'fem';
    seBoth: Result := 'both';
  else
    Result := 'both';
  end;
end;

function StrToSolverEngine(const AStr: string): TSolverEngineKind;
var
  Lower: string;
begin
  Lower := Trim(AStr).ToLower;
  if Lower = 'elastic' then
    Result := seElastic
  else if Lower = 'fem' then
    Result := seFem
  else if Lower = 'both' then
    Result := seBoth
  else
    raise EArgumentException.CreateFmt('Unknown solver engine: %s', [AStr]);
end;

function MeshDensityToStr(ADensity: TMeshDensity): string;
begin
  case ADensity of
    mdCoarse: Result := 'coarse';
    mdStandard: Result := 'standard';
    mdFine: Result := 'fine';
  else
    Result := 'standard';
  end;
end;

function StrToMeshDensity(const AStr: string): TMeshDensity;
var
  Lower: string;
begin
  Lower := Trim(AStr).ToLower;
  if Lower = 'coarse' then
    Result := mdCoarse
  else if Lower = 'standard' then
    Result := mdStandard
  else if Lower = 'fine' then
    Result := mdFine
  else
    raise EArgumentException.CreateFmt('Unknown mesh density: %s', [AStr]);
end;

function ElementTypeToStr(AElemType: TElementType): string;
begin
  case AElemType of
    etCAX4: Result := 'CAX4';
    etCAX4R: Result := 'CAX4R';
    etCAX4I: Result := 'CAX4I';
  else
    Result := 'CAX4';
  end;
end;

function StrToElementType(const AStr: string): TElementType;
var
  Upper: string;
begin
  Upper := Trim(AStr).ToUpper;
  if Upper = 'CAX4' then
    Result := etCAX4
  else if Upper = 'CAX4R' then
    Result := etCAX4R
  else if Upper = 'CAX4I' then
    Result := etCAX4I
  else
    raise EArgumentException.CreateFmt('Unsupported element type: %s', [AStr]);
end;

function JsonTryGetDouble(AObj: TJSONObject; const AKey: string; out AValue: Double): Boolean;
var
  Val: TJSONValue;
begin
  Result := False;
  AValue := 0.0;
  if AObj = nil then
    Exit;
  Val := AObj.FindValue(AKey);
  if (Val = nil) or (Val is TJSONNull) then
    Exit;
  if Val is TJSONNumber then
    Result := TryStrToFloat(Val.Value, AValue, TFormatSettings.Invariant)
  else if Val is TJSONString then
    Result := TryStrToFloat(Trim(Val.Value), AValue, TFormatSettings.Invariant);
end;

function JsonTryGetInt(AObj: TJSONObject; const AKey: string; out AValue: Integer): Boolean;
var
  Val: TJSONValue;
  DVal: Double;
begin
  Result := False;
  AValue := 0;
  if AObj = nil then
    Exit;
  Val := AObj.FindValue(AKey);
  if (Val = nil) or (Val is TJSONNull) then
    Exit;
  if TryStrToInt(Trim(Val.Value), AValue) then
    Result := True
  else if JsonTryGetDouble(AObj, AKey, DVal) and (Abs(DVal - Round(DVal)) < 1e-9) then
  begin
    AValue := Round(DVal);
    Result := True;
  end;
end;

function JsonTryGetString(AObj: TJSONObject; const AKey: string; out AValue: string): Boolean;
var
  Val: TJSONValue;
begin
  Result := False;
  AValue := '';
  if AObj = nil then
    Exit;
  Val := AObj.FindValue(AKey);
  if (Val = nil) or (Val is TJSONNull) then
    Exit;
  AValue := Val.Value;
  Result := True;
end;

function JsonTryGetBool(AObj: TJSONObject; const AKey: string; out AValue: Boolean): Boolean;
var
  Val: TJSONValue;
begin
  Result := False;
  AValue := False;
  if AObj = nil then
    Exit;
  Val := AObj.FindValue(AKey);
  if (Val = nil) or (Val is TJSONNull) then
    Exit;
  if Val is TJSONBool then
  begin
    AValue := SameText(Val.Value, 'true');
    Result := True;
  end
  else if Val is TJSONString then
  begin
    if SameText(Trim(Val.Value), 'true') then
    begin
      AValue := True;
      Result := True;
    end
    else if SameText(Trim(Val.Value), 'false') then
    begin
      AValue := False;
      Result := True;
    end;
  end;
end;

function DoubleArrayToJSON(const AArr: TDoubleArray): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(AArr) do
    Result.AddElement(TJSONNumber.Create(AArr[I]));
end;

function DoubleMatrixToJSON(const AMat: TDoubleMatrix): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(AMat) do
    Result.AddElement(DoubleArrayToJSON(AMat[I]));
end;


class function TMaterial.Create(const AName: string; AEGpa, ANu: Double;
  ACategory: TMaterialCategory): TMaterial;
begin
  Result := Default(TMaterial);
  Result.Name := AName;
  Result.EGpa := AEGpa;
  Result.Nu := ANu;
  Result.Category := ACategory;
end;

procedure TMaterial.Validate;
var
  I: Integer;
begin
  if Trim(Name) = '' then
    raise EArgumentException.Create('Material name cannot be empty');
  if (not IsFiniteDouble(EGpa)) or (EGpa <= 0.0) then
    raise EArgumentException.CreateFmt('Material "%s" E_gpa must be > 0', [Name]);
  if (not IsFiniteDouble(Nu)) or (Nu < 0.0) or (Nu >= 0.5) then
    raise EArgumentException.CreateFmt('Material "%s" nu must be in [0, 0.5)', [Name]);
  if HasSigmaY and ((not IsFiniteDouble(SigmaYGpa)) or (SigmaYGpa <= 0.0)) then
    raise EArgumentException.CreateFmt('Material "%s" sigma_y_gpa must be > 0', [Name]);
  if HasEt and ((not IsFiniteDouble(EtGpa)) or (EtGpa <= 0.0) or (EtGpa >= EGpa)) then
    raise EArgumentException.CreateFmt('Material "%s" E_t_gpa must be in (0, E_gpa)', [Name]);
  if HasHardness and ((not IsFiniteDouble(HardnessGpa)) or (HardnessGpa <= 0.0)) then
    raise EArgumentException.CreateFmt('Material "%s" hardness_gpa must be > 0', [Name]);
  if Length(HardeningCurve) > 0 then
  begin
    for I := 0 to High(HardeningCurve) do
    begin
      if (not IsFiniteDouble(HardeningCurve[I].TrueStressGpa)) or
         (HardeningCurve[I].TrueStressGpa <= 0.0) then
        raise EArgumentException.CreateFmt('Material "%s" hardening stress must be > 0', [Name]);
      if (not IsFiniteDouble(HardeningCurve[I].PlasticStrain)) or
         (HardeningCurve[I].PlasticStrain < 0.0) then
        raise EArgumentException.CreateFmt('Material "%s" hardening strain must be >= 0', [Name]);
      if (I > 0) and (HardeningCurve[I].PlasticStrain <= HardeningCurve[I - 1].PlasticStrain) then
        raise EArgumentException.CreateFmt('Material "%s" hardening plastic strain must increase', [Name]);
      if (I > 0) and (HardeningCurve[I].TrueStressGpa < HardeningCurve[I - 1].TrueStressGpa) then
        raise EArgumentException.CreateFmt('Material "%s" hardening stress must be non-decreasing', [Name]);
    end;
  end;
end;

function TMaterial.EffectiveTangentGpa: Double;
begin
  if HasEt then
    Result := EtGpa
  else
    Result := 0.01 * EGpa;
end;

function TMaterial.Clone: TMaterial;
begin
  Result := Self;
  if Length(HardeningCurve) > 0 then
    Result.HardeningCurve := Copy(HardeningCurve);
end;

function TMaterial.ToJSON: TJSONObject;
var
  Arr, PairArr: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  Result.AddPair('E_gpa', TJSONNumber.Create(EGpa));
  Result.AddPair('nu', TJSONNumber.Create(Nu));
  if HasSigmaY then
    Result.AddPair('sigma_y_gpa', TJSONNumber.Create(SigmaYGpa));
  if HasEt then
    Result.AddPair('E_t_gpa', TJSONNumber.Create(EtGpa));
  if Length(HardeningCurve) > 0 then
  begin
    Arr := TJSONArray.Create;
    for I := 0 to High(HardeningCurve) do
    begin
      PairArr := TJSONArray.Create;
      PairArr.AddElement(TJSONNumber.Create(HardeningCurve[I].TrueStressGpa));
      PairArr.AddElement(TJSONNumber.Create(HardeningCurve[I].PlasticStrain));
      Arr.AddElement(PairArr);
    end;
    Result.AddPair('hardening_curve', Arr);
  end;
  if HasHardness then
    Result.AddPair('hardness_gpa', TJSONNumber.Create(HardnessGpa));
  Result.AddPair('category', MaterialCategoryToStr(Category));
  if Notes <> '' then
    Result.AddPair('notes', Notes);
end;

class function TMaterial.FromJSON(AObj: TJSONObject): TMaterial;
var
  DVal: Double;
  SVal: string;
  ArrVal, PairVal: TJSONValue;
  Arr, Pair: TJSONArray;
  I: Integer;
begin
  Result := Default(TMaterial);
  if AObj = nil then
    raise EArgumentException.Create('Material JSON object is nil');

  if not JsonTryGetString(AObj, 'name', Result.Name) then
    raise EArgumentException.Create('Material missing "name"');

  if JsonTryGetDouble(AObj, 'E_gpa', DVal) then
    Result.EGpa := DVal
  else if JsonTryGetDouble(AObj, 'E_mpa', DVal) then
    Result.EGpa := MpaToGpa(DVal)
  else
    raise EArgumentException.CreateFmt('Material "%s" missing E_gpa', [Result.Name]);

  if not JsonTryGetDouble(AObj, 'nu', Result.Nu) then
    raise EArgumentException.CreateFmt('Material "%s" missing nu', [Result.Name]);

  if JsonTryGetDouble(AObj, 'sigma_y_gpa', DVal) then
  begin
    Result.HasSigmaY := True;
    Result.SigmaYGpa := DVal;
  end
  else if JsonTryGetDouble(AObj, 'sigma_y_mpa', DVal) then
  begin
    Result.HasSigmaY := True;
    Result.SigmaYGpa := MpaToGpa(DVal);
  end;

  if JsonTryGetDouble(AObj, 'E_t_gpa', DVal) then
  begin
    Result.HasEt := True;
    Result.EtGpa := DVal;
  end
  else if JsonTryGetDouble(AObj, 'E_t_mpa', DVal) then
  begin
    Result.HasEt := True;
    Result.EtGpa := MpaToGpa(DVal);
  end;

  if JsonTryGetDouble(AObj, 'hardness_gpa', DVal) then
  begin
    Result.HasHardness := True;
    Result.HardnessGpa := DVal;
  end
  else if JsonTryGetDouble(AObj, 'hardness_mpa', DVal) then
  begin
    Result.HasHardness := True;
    Result.HardnessGpa := MpaToGpa(DVal);
  end;

  if JsonTryGetString(AObj, 'category', SVal) then
    Result.Category := StrToMaterialCategory(SVal)
  else
    Result.Category := mcCoating;

  JsonTryGetString(AObj, 'notes', Result.Notes);

  ArrVal := AObj.FindValue('hardening_curve');
  if (ArrVal <> nil) and (ArrVal is TJSONArray) then
  begin
    Arr := TJSONArray(ArrVal);
    SetLength(Result.HardeningCurve, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      PairVal := Arr.Items[I];
      if not (PairVal is TJSONArray) then
        raise EArgumentException.Create('hardening_curve entries must be 2-element arrays');
      Pair := TJSONArray(PairVal);
      if Pair.Count <> 2 then
        raise EArgumentException.Create('hardening_curve entry must have 2 values');
      if not TryStrToFloat(Pair.Items[0].Value, Result.HardeningCurve[I].TrueStressGpa, TFormatSettings.Invariant) then
        raise EArgumentException.Create('Invalid stress in hardening_curve');
      if not TryStrToFloat(Pair.Items[1].Value, Result.HardeningCurve[I].PlasticStrain, TFormatSettings.Invariant) then
        raise EArgumentException.Create('Invalid strain in hardening_curve');
    end;
  end;

  Result.Validate;
end;


class function TLayer.Create(const AMaterial: TMaterial; AThicknessUm: Double): TLayer;
begin
  Result := Default(TLayer);
  Result.Material := AMaterial.Clone;
  Result.Material.Category := mcCoating;
  Result.ThicknessUm := AThicknessUm;
end;

class function TLayer.CreateNm(const AMaterial: TMaterial; AThicknessNm: Double): TLayer;
begin
  Result := TLayer.Create(AMaterial, NmToUm(AThicknessNm));
end;

procedure TLayer.Validate;
begin
  Material.Validate;
  if (not IsFiniteDouble(ThicknessUm)) or (ThicknessUm <= 0.0) then
    raise EArgumentException.CreateFmt('Layer "%s" thickness_um must be > 0', [Material.Name]);
end;

function TLayer.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('material', Material.ToJSON);
  Result.AddPair('thickness_um', TJSONNumber.Create(ThicknessUm));
end;

class function TLayer.FromJSON(AObj: TJSONObject): TLayer;
var
  MatVal: TJSONValue;
  DVal: Double;
begin
  Result := Default(TLayer);
  if AObj = nil then
    raise EArgumentException.Create('Layer JSON object is nil');
  MatVal := AObj.FindValue('material');
  if (MatVal = nil) or not (MatVal is TJSONObject) then
    raise EArgumentException.Create('Layer missing "material" object');
  Result.Material := TMaterial.FromJSON(TJSONObject(MatVal));

  if JsonTryGetDouble(AObj, 'thickness_um', DVal) then
    Result.ThicknessUm := DVal
  else if JsonTryGetDouble(AObj, 'thickness_nm', DVal) then
    Result.ThicknessUm := NmToUm(DVal)
  else
    raise EArgumentException.Create('Layer missing thickness_um / thickness_nm');

  Result.Validate;
end;


class function TBallSpec.Create(ARadiusUm: Double; const AMaterial: TMaterial;
  ARigid: Boolean): TBallSpec;
begin
  Result := Default(TBallSpec);
  Result.RadiusUm := ARadiusUm;
  Result.Material := AMaterial.Clone;
  Result.Material.Category := mcBall;
  Result.Rigid := ARigid;
end;

class function TBallSpec.FromDiameterMm(ADiameterMm: Double; const AMaterial: TMaterial;
  ARigid: Boolean): TBallSpec;
begin
  Result := TBallSpec.Create(0.5 * MmToUm(ADiameterMm), AMaterial, ARigid);
end;

class function TBallSpec.FromRadiusMm(ARadiusMm: Double; const AMaterial: TMaterial;
  ARigid: Boolean): TBallSpec;
begin
  Result := TBallSpec.Create(MmToUm(ARadiusMm), AMaterial, ARigid);
end;

procedure TBallSpec.Validate;
begin
  if (not IsFiniteDouble(RadiusUm)) or (RadiusUm <= 0.0) then
    raise EArgumentException.Create('Ball radius_um must be > 0');
  Material.Validate;
end;

function TBallSpec.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('radius_um', TJSONNumber.Create(RadiusUm));
  Result.AddPair('material', Material.ToJSON);
  Result.AddPair('rigid', TJSONBool.Create(Rigid));
end;

class function TBallSpec.FromJSON(AObj: TJSONObject): TBallSpec;
var
  MatVal: TJSONValue;
  DVal: Double;
  BVal: Boolean;
begin
  Result := Default(TBallSpec);
  if AObj = nil then
    raise EArgumentException.Create('Ball JSON object is nil');
  if JsonTryGetDouble(AObj, 'radius_um', DVal) then
    Result.RadiusUm := DVal
  else if JsonTryGetDouble(AObj, 'radius_mm', DVal) then
    Result.RadiusUm := MmToUm(DVal)
  else if JsonTryGetDouble(AObj, 'diameter_mm', DVal) then
    Result.RadiusUm := 0.5 * MmToUm(DVal)
  else
    raise EArgumentException.Create('Ball missing radius_um / radius_mm / diameter_mm');

  MatVal := AObj.FindValue('material');
  if (MatVal = nil) or not (MatVal is TJSONObject) then
    raise EArgumentException.Create('Ball missing "material" object');
  Result.Material := TMaterial.FromJSON(TJSONObject(MatVal));

  if JsonTryGetBool(AObj, 'rigid', BVal) then
    Result.Rigid := BVal;

  Result.Validate;
end;


class function TLoadCase.Create(ANormalLoadMn, AFrictionCoeff: Double): TLoadCase;
begin
  Result := Default(TLoadCase);
  Result.NormalLoadMn := ANormalLoadMn;
  Result.FrictionCoeff := AFrictionCoeff;
end;

class function TLoadCase.FromNewtons(AForceN, AFrictionCoeff: Double): TLoadCase;
begin
  Result := TLoadCase.Create(NewtonsToMn(AForceN), AFrictionCoeff);
end;

procedure TLoadCase.Validate;
begin
  if (not IsFiniteDouble(NormalLoadMn)) or (NormalLoadMn <= 0.0) then
    raise EArgumentException.Create('normal_load_mn must be > 0');
  if (not IsFiniteDouble(FrictionCoeff)) or (FrictionCoeff < 0.0) then
    raise EArgumentException.Create('friction_coeff must be >= 0');
end;

function TLoadCase.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('normal_load_mn', TJSONNumber.Create(NormalLoadMn));
  Result.AddPair('friction_coeff', TJSONNumber.Create(FrictionCoeff));
end;

class function TLoadCase.FromJSON(AObj: TJSONObject): TLoadCase;
var
  DVal: Double;
begin
  Result := Default(TLoadCase);
  if AObj = nil then
    raise EArgumentException.Create('LoadCase JSON object is nil');
  if JsonTryGetDouble(AObj, 'normal_load_mn', DVal) then
    Result.NormalLoadMn := DVal
  else if JsonTryGetDouble(AObj, 'normal_load_n', DVal) then
    Result.NormalLoadMn := NewtonsToMn(DVal)
  else
    raise EArgumentException.Create('LoadCase missing normal_load_mn / normal_load_n');

  if JsonTryGetDouble(AObj, 'friction_coeff', DVal) then
    Result.FrictionCoeff := DVal
  else
    Result.FrictionCoeff := 0.0;

  Result.Validate;
end;


class function TSolverConfig.DefaultConfig: TSolverConfig;
begin
  Result := Default(TSolverConfig);
  Result.Engine := seBoth;
  Result.NRings := 160;
  Result.MeshDensity := mdStandard;
  Result.ElementType := etCAX4;
  Result.IncludeUnloading := False;
  Result.MaxLoadBrackets := 3;
  Result.LoadToleranceRel := 0.01;
  Result.CcxPath := '';
  Result.TimeoutS := 300;
  Result.WorkDir := '';
end;

procedure TSolverConfig.Validate;
begin
  if NRings < 20 then
    raise EArgumentException.Create('n_rings must be >= 20');
  if MaxLoadBrackets < 1 then
    raise EArgumentException.Create('max_load_brackets must be >= 1');
  if (not IsFiniteDouble(LoadToleranceRel)) or (LoadToleranceRel <= 0.0) or (LoadToleranceRel >= 0.5) then
    raise EArgumentException.Create('load_tolerance_rel must be in (0, 0.5)');
  if TimeoutS < 5 then
    raise EArgumentException.Create('timeout_s must be >= 5');
end;

function TSolverConfig.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('engine', SolverEngineToStr(Engine));
  Result.AddPair('n_rings', TJSONNumber.Create(NRings));
  Result.AddPair('mesh_density', MeshDensityToStr(MeshDensity));
  Result.AddPair('element_type', ElementTypeToStr(ElementType));
  Result.AddPair('include_unloading', TJSONBool.Create(IncludeUnloading));
  Result.AddPair('max_load_brackets', TJSONNumber.Create(MaxLoadBrackets));
  Result.AddPair('load_tolerance_rel', TJSONNumber.Create(LoadToleranceRel));
  if CcxPath <> '' then
    Result.AddPair('ccx_path', CcxPath);
  Result.AddPair('timeout_s', TJSONNumber.Create(TimeoutS));
  if WorkDir <> '' then
    Result.AddPair('work_dir', WorkDir);
end;

class function TSolverConfig.FromJSON(AObj: TJSONObject): TSolverConfig;
var
  SVal: string;
  IVal: Integer;
  DVal: Double;
  BVal: Boolean;
begin
  Result := TSolverConfig.DefaultConfig;
  if AObj = nil then
    Exit;
  if JsonTryGetString(AObj, 'engine', SVal) then
    Result.Engine := StrToSolverEngine(SVal);
  if JsonTryGetInt(AObj, 'n_rings', IVal) then
    Result.NRings := IVal;
  if JsonTryGetString(AObj, 'mesh_density', SVal) then
    Result.MeshDensity := StrToMeshDensity(SVal);
  if JsonTryGetString(AObj, 'element_type', SVal) then
    Result.ElementType := StrToElementType(SVal);
  if JsonTryGetBool(AObj, 'include_unloading', BVal) then
    Result.IncludeUnloading := BVal;
  if JsonTryGetInt(AObj, 'max_load_brackets', IVal) then
    Result.MaxLoadBrackets := IVal;
  if JsonTryGetDouble(AObj, 'load_tolerance_rel', DVal) then
    Result.LoadToleranceRel := DVal;
  if JsonTryGetString(AObj, 'ccx_path', SVal) then
    Result.CcxPath := SVal;
  if JsonTryGetInt(AObj, 'timeout_s', IVal) then
    Result.TimeoutS := IVal;
  if JsonTryGetString(AObj, 'work_dir', SVal) then
    Result.WorkDir := SVal;
  Result.Validate;
end;


class function TContactCase.Create(const ACaseName: string; const ABall: TBallSpec;
  const ALayers: TArray<TLayer>; const ASubstrate: TMaterial;
  const ALoadCase: TLoadCase; const ASolver: TSolverConfig): TContactCase;
var
  I: Integer;
begin
  Result := Default(TContactCase);
  Result.CaseName := ACaseName;
  Result.Ball := ABall;
  Result.Ball.Material := ABall.Material.Clone;
  SetLength(Result.Layers, Length(ALayers));
  for I := 0 to High(ALayers) do
  begin
    Result.Layers[I] := ALayers[I];
    Result.Layers[I].Material := ALayers[I].Material.Clone;
  end;
  Result.Substrate := ASubstrate.Clone;
  Result.Substrate.Category := mcSubstrate;
  Result.LoadCase := ALoadCase;
  Result.Solver := ASolver;
end;

procedure TContactCase.Validate;
var
  I: Integer;
begin
  Ball.Validate;
  for I := 0 to High(Layers) do
    Layers[I].Validate;
  Substrate.Validate;
  LoadCase.Validate;
  Solver.Validate;
end;

function TContactCase.TotalCoatingThicknessUm: Double;
var
  I: Integer;
begin
  Result := 0.0;
  for I := 0 to High(Layers) do
    Result := Result + Layers[I].ThicknessUm;
end;

function TContactCase.Clone: TContactCase;
begin
  Result := TContactCase.Create(CaseName, Ball, Layers, Substrate, LoadCase, Solver);
end;

function TContactCase.ToJSON: TJSONObject;
var
  Arr: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('case_name', CaseName);
  Result.AddPair('ball', Ball.ToJSON);
  Arr := TJSONArray.Create;
  for I := 0 to High(Layers) do
    Arr.AddElement(Layers[I].ToJSON);
  Result.AddPair('layers', Arr);
  Result.AddPair('substrate', Substrate.ToJSON);
  Result.AddPair('load_case', LoadCase.ToJSON);
  Result.AddPair('solver', Solver.ToJSON);
end;

function TContactCase.ToJSONString(AFormatted: Boolean): string;
var
  Obj: TJSONObject;
begin
  Obj := ToJSON;
  try
    if AFormatted then
      Result := Obj.Format(2)
    else
      Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

class function TContactCase.FromJSON(AObj: TJSONObject): TContactCase;
var
  BallVal, LayersVal, SubVal, LoadVal, SolverVal, ItemVal: TJSONValue;
  LayersArr: TJSONArray;
  I: Integer;
begin
  Result := Default(TContactCase);
  if AObj = nil then
    raise EArgumentException.Create('ContactCase JSON object is nil');
  if not JsonTryGetString(AObj, 'case_name', Result.CaseName) then
    Result.CaseName := 'Unnamed Case';

  BallVal := AObj.FindValue('ball');
  if (BallVal = nil) or not (BallVal is TJSONObject) then
    raise EArgumentException.Create('ContactCase missing "ball" object');
  Result.Ball := TBallSpec.FromJSON(TJSONObject(BallVal));

  LayersVal := AObj.FindValue('layers');
  if (LayersVal <> nil) and (LayersVal is TJSONArray) then
  begin
    LayersArr := TJSONArray(LayersVal);
    SetLength(Result.Layers, LayersArr.Count);
    for I := 0 to LayersArr.Count - 1 do
    begin
      ItemVal := LayersArr.Items[I];
      if not (ItemVal is TJSONObject) then
        raise EArgumentException.Create('Layer array entry must be JSON object');
      Result.Layers[I] := TLayer.FromJSON(TJSONObject(ItemVal));
    end;
  end;

  SubVal := AObj.FindValue('substrate');
  if (SubVal = nil) or not (SubVal is TJSONObject) then
    raise EArgumentException.Create('ContactCase missing "substrate" object');
  Result.Substrate := TMaterial.FromJSON(TJSONObject(SubVal));

  LoadVal := AObj.FindValue('load_case');
  if (LoadVal = nil) or not (LoadVal is TJSONObject) then
    raise EArgumentException.Create('ContactCase missing "load_case" object');
  Result.LoadCase := TLoadCase.FromJSON(TJSONObject(LoadVal));

  SolverVal := AObj.FindValue('solver');
  if (SolverVal <> nil) and (SolverVal is TJSONObject) then
    Result.Solver := TSolverConfig.FromJSON(TJSONObject(SolverVal))
  else
    Result.Solver := TSolverConfig.DefaultConfig;

  Result.Validate;
end;

class function TContactCase.FromJSONString(const AText: string): TContactCase;
var
  Val: TJSONValue;
begin
  Val := TJSONObject.ParseJSONValue(AText, False, True);
  if Val = nil then
    raise EArgumentException.Create('Invalid JSON text for ContactCase');
  try
    if not (Val is TJSONObject) then
      raise EArgumentException.Create('Root JSON value must be an object');
    Result := FromJSON(TJSONObject(Val));
  finally
    Val.Free;
  end;
end;

class function TContactCase.LoadFromFile(const AFilePath: string): TContactCase;
var
  Text: string;
begin
  if not TFile.Exists(AFilePath) then
    raise EFileNotFoundException.CreateFmt('Case file not found: %s', [AFilePath]);
  Text := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
  Result := FromJSONString(Text);
end;

procedure TContactCase.SaveToFile(const AFilePath: string);
var
  Dir: string;
begin
  Dir := ExtractFilePath(AFilePath);
  if (Dir <> '') and not TDirectory.Exists(Dir) then
    TDirectory.CreateDirectory(Dir);
  TFile.WriteAllText(AFilePath, ToJSONString(True), TEncoding.UTF8);
end;


function TStressGrid.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('r_um', DoubleArrayToJSON(RUm));
  Result.AddPair('z_um', DoubleArrayToJSON(ZUm));
  Result.AddPair('sigma_rr_gpa', DoubleMatrixToJSON(SigmaRRGpa));
  Result.AddPair('sigma_tt_gpa', DoubleMatrixToJSON(SigmaTTGpa));
  Result.AddPair('sigma_zz_gpa', DoubleMatrixToJSON(SigmaZZGpa));
  Result.AddPair('tau_rz_gpa', DoubleMatrixToJSON(TauRZGpa));
  Result.AddPair('sigma_vm_gpa', DoubleMatrixToJSON(SigmaVmGpa));
  if HasPeeq then
    Result.AddPair('peeq', DoubleMatrixToJSON(Peeq));
  if HasSliding then
  begin
    Result.AddPair('sliding_surface_x_um', DoubleArrayToJSON(SlidingSurfaceXUm));
    Result.AddPair('sliding_surface_sigma_xx_gpa', DoubleArrayToJSON(SlidingSurfaceSigmaXXGpa));
    Result.AddPair('sliding_plane_x_um', DoubleArrayToJSON(SlidingPlaneXUm));
    Result.AddPair('sliding_plane_sigma_xx_gpa', DoubleMatrixToJSON(SlidingPlaneSigmaXXGpa));
    Result.AddPair('sliding_plane_tau_xz_gpa', DoubleMatrixToJSON(SlidingPlaneTauXZGpa));
    Result.AddPair('sliding_plane_sigma_vm_gpa', DoubleMatrixToJSON(SlidingPlaneSigmaVmGpa));
  end;
end;


function TInterfaceStressSummary.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('interface_index', TJSONNumber.Create(InterfaceIndex));
  Result.AddPair('depth_um', TJSONNumber.Create(DepthUm));
  Result.AddPair('above_label', AboveLabel);
  Result.AddPair('below_label', BelowLabel);
  Result.AddPair('max_sigma_rr_above_gpa', TJSONNumber.Create(MaxSigmaRRAboveGpa));
  Result.AddPair('max_sigma_rr_below_gpa', TJSONNumber.Create(MaxSigmaRRBelowGpa));
  Result.AddPair('min_sigma_rr_above_gpa', TJSONNumber.Create(MinSigmaRRAboveGpa));
  Result.AddPair('min_sigma_rr_below_gpa', TJSONNumber.Create(MinSigmaRRBelowGpa));
  Result.AddPair('max_abs_tau_rz_gpa', TJSONNumber.Create(MaxAbsTauRZGpa));
  Result.AddPair('max_sigma_vm_above_gpa', TJSONNumber.Create(MaxSigmaVmAboveGpa));
  Result.AddPair('max_sigma_vm_below_gpa', TJSONNumber.Create(MaxSigmaVmBelowGpa));
  if HasPeeq then
  begin
    Result.AddPair('max_peeq_above', TJSONNumber.Create(MaxPeeqAbove));
    Result.AddPair('max_peeq_below', TJSONNumber.Create(MaxPeeqBelow));
  end;
end;


constructor TContactResult.Create;
begin
  inherited Create;
  Diagnostics := TStringList.Create;
end;

destructor TContactResult.Destroy;
begin
  StressGrid.Free;
  Diagnostics.Free;
  inherited Destroy;
end;

function TContactResult.MaxYieldRatio: Double;
var
  I: Integer;
begin
  Result := 0.0;
  for I := 0 to High(LayerYieldRatios) do
    if LayerYieldRatios[I].Ratio > Result then
      Result := LayerYieldRatios[I].Ratio;
end;

function TContactResult.ToJSON: TJSONObject;
var
  IfArr, DiagArr: TJSONArray;
  YieldObj: TJSONObject;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('solver_name', SolverName);
  Result.AddPair('contact_radius_um', TJSONNumber.Create(ContactRadiusUm));
  Result.AddPair('penetration_depth_um', TJSONNumber.Create(PenetrationDepthUm));
  if HasResidualDepth then
    Result.AddPair('residual_depth_um', TJSONNumber.Create(ResidualDepthUm))
  else
    Result.AddPair('residual_depth_um', TJSONNull.Create);
  Result.AddPair('p_max_gpa', TJSONNumber.Create(PMaxGpa));
  Result.AddPair('p_mean_gpa', TJSONNumber.Create(PMeanGpa));
  Result.AddPair('actual_load_mn', TJSONNumber.Create(ActualLoadMn));
  Result.AddPair('force_balance_error_rel', TJSONNumber.Create(ForceBalanceErrorRel));
  Result.AddPair('r_um', DoubleArrayToJSON(RUm));
  Result.AddPair('p_gpa', DoubleArrayToJSON(PGpa));
  Result.AddPair('z_centerline_um', DoubleArrayToJSON(ZCenterlineUm));
  Result.AddPair('centerline_sigma_vm_gpa', DoubleArrayToJSON(CenterlineSigmaVmGpa));
  Result.AddPair('centerline_sigma_rr_gpa', DoubleArrayToJSON(CenterlineSigmaRRGpa));
  Result.AddPair('centerline_sigma_zz_gpa', DoubleArrayToJSON(CenterlineSigmaZZGpa));
  if StressGrid <> nil then
    Result.AddPair('stress_grid', StressGrid.ToJSON)
  else
    Result.AddPair('stress_grid', TJSONNull.Create);

  IfArr := TJSONArray.Create;
  for I := 0 to High(Interfaces) do
    IfArr.AddElement(Interfaces[I].ToJSON);
  Result.AddPair('interfaces', IfArr);

  YieldObj := TJSONObject.Create;
  for I := 0 to High(LayerYieldRatios) do
    YieldObj.AddPair(LayerYieldRatios[I].MaterialLabel, TJSONNumber.Create(LayerYieldRatios[I].Ratio));
  Result.AddPair('layer_yield_ratios', YieldObj);
  Result.AddPair('yield_warning', TJSONBool.Create(YieldWarning));
  if HasMaxPeeq then
    Result.AddPair('max_peeq', TJSONNumber.Create(MaxPeeq))
  else
    Result.AddPair('max_peeq', TJSONNull.Create);
  Result.AddPair('runtime_s', TJSONNumber.Create(RuntimeS));

  DiagArr := TJSONArray.Create;
  for I := 0 to Diagnostics.Count - 1 do
    DiagArr.Add(Diagnostics[I]);
  Result.AddPair('diagnostics', DiagArr);
end;


constructor TComparisonBundle.Create;
begin
  inherited Create;
end;

destructor TComparisonBundle.Destroy;
begin
  FemCalculix.Free;
  ElasticLayered.Free;
  HertzTopFilm.Free;
  HertzSubstrate.Free;
  inherited Destroy;
end;

function TComparisonBundle.ToJSON: TJSONObject;
var
  Arr: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('case_name', CaseName);
  Result.AddPair('ball', Ball.ToJSON);
  Arr := TJSONArray.Create;
  for I := 0 to High(Layers) do
    Arr.AddElement(Layers[I].ToJSON);
  Result.AddPair('layers', Arr);
  Result.AddPair('substrate', Substrate.ToJSON);
  Result.AddPair('load_case', LoadCase.ToJSON);
  Result.AddPair('solver', Solver.ToJSON);
  if HertzSubstrate <> nil then
    Result.AddPair('hertz_substrate', HertzSubstrate.ToJSON);
  if HertzTopFilm <> nil then
    Result.AddPair('hertz_top_film', HertzTopFilm.ToJSON);
  if ElasticLayered <> nil then
    Result.AddPair('elastic_layered', ElasticLayered.ToJSON)
  else
    Result.AddPair('elastic_layered', TJSONNull.Create);
  if FemCalculix <> nil then
    Result.AddPair('fem_calculix', FemCalculix.ToJSON)
  else
    Result.AddPair('fem_calculix', TJSONNull.Create);
end;

function TComparisonBundle.ToJSONString(AFormatted: Boolean): string;
var
  Obj: TJSONObject;
begin
  Obj := ToJSON;
  try
    if AFormatted then
      Result := Obj.Format(2)
    else
      Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

end.
