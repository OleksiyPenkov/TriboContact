unit Test.ModelsHertz;

interface

uses
  System.SysUtils, System.IOUtils, System.Math, DUnitX.TestFramework,
  TriboContact.Models, TriboContact.Materials, TriboContact.Hertz;

type
  [TestFixture]
  TModelsHertzTests = class
  private
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure UnitConversions_VerifyIdentity;
    [Test]
    procedure YieldFromHardness_MatchesTabor;
    [Test]
    procedure Validation_RejectsInvalidInputs;
    [Test]
    procedure ContactCase_JSONRoundTrip_AndUserUnits;
    [Test]
    procedure MaterialLibrary_LoadsAll24Presets_AndUserOverrides;
    [Test]
    procedure Hertz_DeformableAndRigid_MatchesAnalytical;
    [Test]
    procedure Hertz_SubsurfaceMaxVonMises_DepthAndRatio;
    [Test]
    procedure Hertz_Baselines_YieldWarningTriggered;
  end;

implementation

procedure TModelsHertzTests.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath,
    'tc_m0_' + TPath.GetRandomFileName);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TModelsHertzTests.TearDown;
begin
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TModelsHertzTests.UnitConversions_VerifyIdentity;
var
  StressGpa, AreaUm2, ForceMn: Double;
begin
  Assert.AreEqual(1000.0, MmToUm(1.0), 1e-12);
  Assert.AreEqual(1.0, UmToMm(1000.0), 1e-12);
  Assert.AreEqual(0.5, NmToUm(500.0), 1e-12);
  Assert.AreEqual(500.0, UmToNm(0.5), 1e-12);
  Assert.AreEqual(5000.0, NewtonsToMn(5.0), 1e-12);
  Assert.AreEqual(5.0, MnToNewtons(5000.0), 1e-12);
  Assert.AreEqual(0.25, MpaToGpa(250.0), 1e-12);
  Assert.AreEqual(250.0, GpaToMpa(0.25), 1e-12);

  StressGpa := 1.0;
  AreaUm2 := 1.0;
  ForceMn := StressGpa * AreaUm2;
  Assert.AreEqual(1.0, ForceMn, 1e-15);
end;

procedure TModelsHertzTests.YieldFromHardness_MatchesTabor;
begin
  Assert.AreEqual(1.0, YieldFromHardness(2.8), 1e-12);
  Assert.AreEqual(2.0, YieldFromHardness(6.0, 3.0), 1e-12);
  Assert.WillRaise(
    procedure
    begin
      YieldFromHardness(0.0);
    end,
    EArgumentException);
end;

procedure TModelsHertzTests.Validation_RejectsInvalidInputs;
begin
  Assert.WillRaise(
    procedure
    var
      M: TMaterial;
    begin
      M := TMaterial.Create('BadE', -10.0, 0.3);
      M.Validate;
    end,
    EArgumentException);

  Assert.WillRaise(
    procedure
    var
      M: TMaterial;
    begin
      M := TMaterial.Create('BadNu', 100.0, 0.5);
      M.Validate;
    end,
    EArgumentException);

  Assert.WillRaise(
    procedure
    var
      L: TLayer;
    begin
      L := TLayer.Create(TMaterial.Create('TiN', 450.0, 0.25), 0.0);
      L.Validate;
    end,
    EArgumentException);

  Assert.WillRaise(
    procedure
    var
      B: TBallSpec;
    begin
      B := TBallSpec.Create(-1.0, TMaterial.Create('Ball', 300.0, 0.25, mcBall));
      B.Validate;
    end,
    EArgumentException);

  Assert.WillRaise(
    procedure
    var
      LC: TLoadCase;
    begin
      LC := TLoadCase.Create(100.0, -0.1);
      LC.Validate;
    end,
    EArgumentException);
end;

procedure TModelsHertzTests.ContactCase_JSONRoundTrip_AndUserUnits;
var
  BallMat, LayerMat, SubMat: TMaterial;
  CaseIn, CaseOut: TContactCase;
  JsonPath, UserUnitJson: string;
begin
  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  LayerMat := TMaterial.Create('TiN', 450.0, 0.25, mcCoating);
  LayerMat.HasSigmaY := True;
  LayerMat.SigmaYGpa := 7.5;
  SubMat := TMaterial.Create('Steel', 200.0, 0.29, mcSubstrate);
  SubMat.HasSigmaY := True;
  SubMat.SigmaYGpa := 0.35;
  SubMat.HasEt := True;
  SubMat.EtGpa := 2.0;

  CaseIn := TContactCase.Create(
    'RoundTrip',
    TBallSpec.FromDiameterMm(6.0, BallMat, False),
    [TLayer.CreateNm(LayerMat, 1500.0)],
    SubMat,
    TLoadCase.FromNewtons(5.0, 0.2),
    TSolverConfig.DefaultConfig);

  JsonPath := TPath.Combine(FTempDir, 'case.json');
  CaseIn.SaveToFile(JsonPath);
  CaseOut := TContactCase.LoadFromFile(JsonPath);

  Assert.AreEqual<string>('RoundTrip', CaseOut.CaseName);
  Assert.AreEqual(3000.0, CaseOut.Ball.RadiusUm, 1e-9);
  Assert.AreEqual<Integer>(1, Length(CaseOut.Layers));
  Assert.AreEqual(1.5, CaseOut.Layers[0].ThicknessUm, 1e-9);
  Assert.AreEqual(5000.0, CaseOut.LoadCase.NormalLoadMn, 1e-9);
  Assert.AreEqual(0.2, CaseOut.LoadCase.FrictionCoeff, 1e-9);
  Assert.AreEqual(0.35, CaseOut.Substrate.SigmaYGpa, 1e-9);
  Assert.AreEqual(2.0, CaseOut.Substrate.EtGpa, 1e-9);

  UserUnitJson := '{' +
    '"case_name":"UserUnits",' +
    '"ball":{"diameter_mm":4.0,"material":{"name":"Steel","E_mpa":210000,"nu":0.3,"category":"ball"}},' +
    '"layers":[{"thickness_nm":500,"material":{"name":"DLC","E_gpa":180,"nu":0.22}}],' +
    '"substrate":{"name":"Al","E_mpa":69000,"nu":0.33,"sigma_y_mpa":276,"category":"substrate"},' +
    '"load_case":{"normal_load_n":2.5,"friction_coeff":0.1}' +
    '}';
  CaseOut := TContactCase.FromJSONString(UserUnitJson);
  Assert.AreEqual(2000.0, CaseOut.Ball.RadiusUm, 1e-9);
  Assert.AreEqual(210.0, CaseOut.Ball.Material.EGpa, 1e-9);
  Assert.AreEqual(0.5, CaseOut.Layers[0].ThicknessUm, 1e-9);
  Assert.AreEqual(69.0, CaseOut.Substrate.EGpa, 1e-9);
  Assert.AreEqual(0.276, CaseOut.Substrate.SigmaYGpa, 1e-9);
  Assert.AreEqual(2500.0, CaseOut.LoadCase.NormalLoadMn, 1e-9);
end;

procedure TModelsHertzTests.MaterialLibrary_LoadsAll24Presets_AndUserOverrides;
var
  Lib: TMaterialLibrary;
  Balls, Coatings, Subs: TArray<TMaterial>;
  CustomMat, FoundMat: TMaterial;
  UserPath: string;
begin
  UserPath := TPath.Combine(FTempDir, 'materials_user.json');
  Lib := TMaterialLibrary.Create(
    TPath.Combine(FindRepoRoot, 'data\materials.json'),
    UserPath);
  try
    Assert.AreEqual<Integer>(24, Lib.Count);
    Balls := Lib.GetByCategory(mcBall);
    Coatings := Lib.GetByCategory(mcCoating);
    Subs := Lib.GetByCategory(mcSubstrate);
    Assert.AreEqual<Integer>(7, Length(Balls));
    Assert.AreEqual<Integer>(9, Length(Coatings));
    Assert.AreEqual<Integer>(8, Length(Subs));

    Assert.AreEqual(450.0, Lib.GetPreset('TiN', mcCoating).EGpa, 1e-9);
    Assert.AreEqual(380.0, Lib.GetPreset('Al2O3', mcBall).EGpa, 1e-9);
    Assert.AreEqual(360.0, Lib.GetPreset('Al2O3', mcCoating).EGpa, 1e-9);
    Assert.AreEqual(3.8, Lib.GetPreset('PEEK', mcSubstrate).EGpa, 1e-9);

    CustomMat := TMaterial.Create('CustomDLC', 220.0, 0.21, mcCoating);
    CustomMat.HasSigmaY := True;
    CustomMat.SigmaYGpa := 6.0;
    Lib.SaveUserMaterial(CustomMat);
  finally
    Lib.Free;
  end;

  Lib := TMaterialLibrary.Create(
    TPath.Combine(FindRepoRoot, 'data\materials.json'),
    UserPath);
  try
    Assert.IsTrue(Lib.TryFind('CustomDLC', mcCoating, FoundMat));
    Assert.AreEqual(220.0, FoundMat.EGpa, 1e-9);
    Assert.AreEqual(6.0, FoundMat.SigmaYGpa, 1e-9);
  finally
    Lib.Free;
  end;
end;

procedure TModelsHertzTests.Hertz_DeformableAndRigid_MatchesAnalytical;
var
  BallMat, SubMat: TMaterial;
  Ball: TBallSpec;
  Load: TLoadCase;
  Res: TContactResult;
  InvEStar, EStar, ExpA, ExpDelta, ExpP0: Double;
begin
  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  SubMat := TMaterial.Create('Steel', 200.0, 0.30, mcSubstrate);
  Load := TLoadCase.FromNewtons(5.0, 0.0);

  Ball := TBallSpec.FromDiameterMm(6.0, BallMat, False);
  Res := SolveHertz(Ball, SubMat, Load, 'hertz_test');
  try
    InvEStar := (1.0 - Sqr(0.27)) / 310.0 + (1.0 - Sqr(0.30)) / 200.0;
    EStar := 1.0 / InvEStar;
    ExpA := Power(3.0 * 5000.0 * 3000.0 / (4.0 * EStar), 1.0 / 3.0);
    ExpDelta := Sqr(ExpA) / 3000.0;
    ExpP0 := 3.0 * 5000.0 / (2.0 * Pi * Sqr(ExpA));

    Assert.AreEqual(ExpA, Res.ContactRadiusUm, 1e-9);
    Assert.AreEqual(ExpDelta, Res.PenetrationDepthUm, 1e-9);
    Assert.AreEqual(ExpP0, Res.PMaxGpa, 1e-9);
    Assert.AreEqual((2.0 / 3.0) * ExpP0, Res.PMeanGpa, 1e-9);
    Assert.AreEqual(ExpP0, Res.PGpa[0], 1e-9);
    Assert.AreEqual(0.0, Res.PGpa[High(Res.PGpa)], 1e-12);
  finally
    Res.Free;
  end;

  Ball := TBallSpec.FromDiameterMm(6.0, BallMat, True);
  Res := SolveHertz(Ball, SubMat, Load, 'hertz_rigid');
  try
    EStar := 200.0 / (1.0 - Sqr(0.30));
    ExpA := Power(3.0 * 5000.0 * 3000.0 / (4.0 * EStar), 1.0 / 3.0);
    Assert.AreEqual(ExpA, Res.ContactRadiusUm, 1e-9);
  finally
    Res.Free;
  end;
end;

procedure TModelsHertzTests.Hertz_SubsurfaceMaxVonMises_DepthAndRatio;
var
  BallMat, SubMat: TMaterial;
  Ball: TBallSpec;
  Load: TLoadCase;
  Res: TContactResult;
  I, MaxIdx: Integer;
  MaxSvm, ZOverA: Double;
begin
  BallMat := TMaterial.Create('Rigid', 1000.0, 0.2, mcBall);
  SubMat := TMaterial.Create('Nu03', 200.0, 0.30, mcSubstrate);
  Ball := TBallSpec.FromDiameterMm(6.0, BallMat, True);
  Load := TLoadCase.FromNewtons(10.0, 0.0);

  Res := SolveHertz(Ball, SubMat, Load, 'hertz_vm', 601);
  try
    MaxSvm := -1.0;
    MaxIdx := 0;
    for I := 0 to High(Res.CenterlineSigmaVmGpa) do
    begin
      if Res.CenterlineSigmaVmGpa[I] > MaxSvm then
      begin
        MaxSvm := Res.CenterlineSigmaVmGpa[I];
        MaxIdx := I;
      end;
    end;
    ZOverA := Res.ZCenterlineUm[MaxIdx] / Res.ContactRadiusUm;
    Assert.IsTrue(Abs(ZOverA - 0.48) < 0.02);
    Assert.IsTrue(Abs(MaxSvm / Res.PMaxGpa - 0.62) < 0.015);
    Assert.AreEqual(-Res.PMaxGpa, Res.CenterlineSigmaZZGpa[0], 1e-9);
    Assert.AreEqual(-Res.PMaxGpa * (0.5 + 0.30), Res.CenterlineSigmaRRGpa[0], 1e-9);
  finally
    Res.Free;
  end;
end;

procedure TModelsHertzTests.Hertz_Baselines_YieldWarningTriggered;
var
  BallMat, FilmMat, SubMat: TMaterial;
  CaseData: TContactCase;
  HSub, HFilm: TContactResult;
begin
  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  FilmMat := TMaterial.Create('TiN', 450.0, 0.25, mcCoating);
  FilmMat.HasSigmaY := True;
  FilmMat.SigmaYGpa := 7.5;
  SubMat := TMaterial.Create('304 Steel', 193.0, 0.29, mcSubstrate);
  SubMat.HasSigmaY := True;
  SubMat.SigmaYGpa := 0.29;

  CaseData := TContactCase.Create(
    'YieldCheck',
    TBallSpec.FromDiameterMm(6.0, BallMat),
    [TLayer.Create(FilmMat, 2.0)],
    SubMat,
    TLoadCase.FromNewtons(5.0, 0.0),
    TSolverConfig.DefaultConfig);

  ComputeHertzBaselines(CaseData, HSub, HFilm);
  try
    Assert.AreEqual<string>('hertz_substrate', HSub.SolverName);
    Assert.AreEqual<string>('hertz_top_film', HFilm.SolverName);
    Assert.IsTrue(HSub.YieldWarning);
    Assert.IsTrue(HSub.MaxYieldRatio > 1.0);
  finally
    HFilm.Free;
    HSub.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TModelsHertzTests);

end.
