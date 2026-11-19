unit Test.VVBenchmarks;

interface

uses
  System.SysUtils, System.Math, DUnitX.TestFramework,
  TriboContact.Models, TriboContact.Hertz, TriboContact.ElasticLayered,
  TriboContact.FemCalculix, TriboContact.Runner;

type
  [TestFixture]
  TVVBenchmarksTests = class
  public
    [Test]
    procedure T5_CalculixHomogeneousElasticHertz;
    [Test]
    procedure T6_CrossSolverAgreement_Ef4_And_Ef10;
    [Test]
    procedure T7_ElasticPlasticValidation_YieldTaborUnloadingAndCoated;
    [Test]
    procedure T8_MeshConvergence_StandardVsFine;
  end;

implementation

procedure TVVBenchmarksTests.T5_CalculixHomogeneousElasticHertz;
var
  BallMat, SubMat: TMaterial;
  Cfg: TSolverConfig;
  C: TContactCase;
  HSub, HFilm, FemRes: TContactResult;
  ErrA, ErrDelta, ErrP0: Double;
begin
  BallMat := TMaterial.Create('Rigid', 1000.0, 0.25, mcBall);
  SubMat := TMaterial.Create('Steel200', 200.0, 0.30, mcSubstrate);
  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seFem;
  Cfg.MeshDensity := mdStandard;

  C := TContactCase.Create('T5_Hertz',
    TBallSpec.FromDiameterMm(6.0, BallMat, True),
    [], SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);

  ComputeHertzBaselines(C, HSub, HFilm);
  FemRes := SolveFemCalculix(C);
  try
    ErrA := Abs(FemRes.ContactRadiusUm - HSub.ContactRadiusUm) / HSub.ContactRadiusUm;
    ErrDelta := Abs(FemRes.PenetrationDepthUm - HSub.PenetrationDepthUm) / HSub.PenetrationDepthUm;
    ErrP0 := Abs(FemRes.PMaxGpa - HSub.PMaxGpa) / HSub.PMaxGpa;

    Assert.IsTrue(FemRes.ForceBalanceErrorRel < 0.02,
      Format('T5 force balance err=%g >= 0.02', [FemRes.ForceBalanceErrorRel]));
    Assert.IsTrue(ErrA < 0.02,
      Format('T5 a err=%g (fem=%g, hertz=%g)', [ErrA, FemRes.ContactRadiusUm, HSub.ContactRadiusUm]));
    Assert.IsTrue(ErrDelta < 0.02,
      Format('T5 delta err=%g (fem=%g, hertz=%g)', [ErrDelta, FemRes.PenetrationDepthUm, HSub.PenetrationDepthUm]));
    Assert.IsTrue(ErrP0 < 0.02,
      Format('T5 p0 err=%g (fem=%g, hertz=%g)', [ErrP0, FemRes.PMaxGpa, HSub.PMaxGpa]));
  finally
    FemRes.Free;
    HFilm.Free;
    HSub.Free;
  end;
end;

procedure TVVBenchmarksTests.T6_CrossSolverAgreement_Ef4_And_Ef10;
var
  BallMat, SubMat, FilmMat: TMaterial;
  Cfg: TSolverConfig;
  C: TContactCase;
  HSub, HFilm: TContactResult;
  Bundle: TComparisonBundle;
  A0, Ratio: Double;
  Ratios: TArray<Double>;
  ErrA, ErrDelta, ErrPMax, ErrSrrIf, ErrTauIf: Double;
  El, Fem: TContactResult;
begin
  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  SubMat := TMaterial.Create('Sub100', 100.0, 0.28, mcSubstrate);
  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seBoth;
  Cfg.MeshDensity := mdStandard;

  C := TContactCase.Create('Ref', TBallSpec.FromDiameterMm(6.0, BallMat, False),
    [], SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);
  ComputeHertzBaselines(C, HSub, HFilm);
  try
    A0 := HSub.ContactRadiusUm;
  finally
    HFilm.Free;
    HSub.Free;
  end;

  Ratios := [4.0, 10.0];
  for Ratio in Ratios do
  begin
    FilmMat := TMaterial.Create(Format('Film_x%.0f', [Ratio]), Ratio * 100.0, 0.25, mcCoating);
    C := TContactCase.Create(Format('T6_Ef%.0f', [Ratio]),
      TBallSpec.FromDiameterMm(6.0, BallMat, False),
      [TLayer.Create(FilmMat, 0.8 * A0)],
      SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);

    Bundle := RunCase(C);
    try
      El := Bundle.ElasticLayered;
      Fem := Bundle.FemCalculix;
      Assert.IsNotNull(El);
      Assert.IsNotNull(Fem);

      ErrA := Abs(Fem.ContactRadiusUm - El.ContactRadiusUm) / El.ContactRadiusUm;
      ErrDelta := Abs(Fem.PenetrationDepthUm - El.PenetrationDepthUm) / El.PenetrationDepthUm;
      ErrPMax := Abs(Fem.PMaxGpa - El.PMaxGpa) / El.PMaxGpa;
      ErrSrrIf := Abs(Fem.Interfaces[0].MaxSigmaRRAboveGpa - El.Interfaces[0].MaxSigmaRRAboveGpa) /
        Max(Abs(El.Interfaces[0].MaxSigmaRRAboveGpa), 0.1);
      ErrTauIf := Abs(Fem.Interfaces[0].MaxAbsTauRZGpa - El.Interfaces[0].MaxAbsTauRZGpa) /
        Max(Abs(El.Interfaces[0].MaxAbsTauRZGpa), 0.1);

      Assert.IsTrue(ErrA < 0.03, Format('T6 (Ef/Es=%g) a err=%g', [Ratio, ErrA]));
      Assert.IsTrue(ErrDelta < 0.03, Format('T6 (Ef/Es=%g) delta err=%g', [Ratio, ErrDelta]));
      Assert.IsTrue(ErrPMax < 0.03, Format('T6 (Ef/Es=%g) pmax err=%g', [Ratio, ErrPMax]));
      Assert.IsTrue(ErrSrrIf < 0.03,
        Format('T6 (Ef/Es=%g) srr(z1-) err=%g (fem=%g, el=%g)',
          [Ratio, ErrSrrIf, Fem.Interfaces[0].MaxSigmaRRAboveGpa, El.Interfaces[0].MaxSigmaRRAboveGpa]));
      Assert.IsTrue(ErrTauIf < 0.03,
        Format('T6 (Ef/Es=%g) tau_rz(z1) err=%g (fem=%g, el=%g)',
          [Ratio, ErrTauIf, Fem.Interfaces[0].MaxAbsTauRZGpa, El.Interfaces[0].MaxAbsTauRZGpa]));
    finally
      Bundle.Free;
    end;
  end;
end;

procedure TVVBenchmarksTests.T7_ElasticPlasticValidation_YieldTaborUnloadingAndCoated;
var
  BallMat, BallCeramic, SubYield, FilmHard, SubSoft: TMaterial;
  Cfg: TSolverConfig;
  COnset, CDeep, CCoated: TContactCase;
  HSub, HFilm, FemOnset, FemDeep: TContactResult;
  BundleCoated: TComparisonBundle;
  SigmaY, FOnset, P0OverSy, PMeanOverSy: Double;
begin
  BallMat := TMaterial.Create('Rigid', 1000.0, 0.25, mcBall);
  SigmaY := 0.50;
  SubYield := TMaterial.Create('EP_Metal', 200.0, 0.30, mcSubstrate);
  SubYield.HasSigmaY := True;
  SubYield.SigmaYGpa := SigmaY;
  SubYield.HasEt := True;
  SubYield.EtGpa := 0.05;

  var EStar := 200.0 / (1.0 - Sqr(0.30));
  var TargetP0 := 1.65 * SigmaY;
  var RUm := 3000.0;
  FOnset := (Pi * Pi * Pi) * Sqr(RUm) * Power(TargetP0, 3) / (6.0 * Sqr(EStar));

  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seFem;
  Cfg.MeshDensity := mdStandard;
  COnset := TContactCase.Create('T7_Onset',
    TBallSpec.Create(RUm, BallMat, True), [], SubYield,
    TLoadCase.Create(FOnset, 0.0), Cfg);
  ComputeHertzBaselines(COnset, HSub, HFilm);
  FemOnset := SolveFemCalculix(COnset);
  try
    P0OverSy := HSub.PMaxGpa / SigmaY;
    Assert.IsTrue((P0OverSy > 1.5) and (P0OverSy < 1.8));
    Assert.IsTrue(FemOnset.MaxPeeq > 0.0, 'Expected PEEQ > 0 just above 1.6*sigma_y');
    Assert.IsTrue(FemOnset.MaxPeeq < 0.02, 'Expected small initial PEEQ near yield onset');
  finally
    FemOnset.Free;
    HFilm.Free;
    HSub.Free;
  end;

  Cfg.IncludeUnloading := True;
  CDeep := TContactCase.Create('T7_Tabor',
    TBallSpec.FromDiameterMm(1.0, BallMat, True), [], SubYield,
    TLoadCase.FromNewtons(50.0, 0.0), Cfg);
  FemDeep := SolveFemCalculix(CDeep);
  try
    PMeanOverSy := FemDeep.PMeanGpa / SigmaY;
    Assert.IsTrue((PMeanOverSy > 2.4) and (PMeanOverSy < 3.2),
      Format('T7 Tabor p_mean/sigma_y=%g outside [2.4, 3.2]', [PMeanOverSy]));
    Assert.IsTrue(FemDeep.MaxPeeq > 0.02,
      Format('Expected substantial PEEQ > 0.02, got %g', [FemDeep.MaxPeeq]));
    Assert.IsTrue(FemDeep.HasResidualDepth and (FemDeep.ResidualDepthUm > 0.0),
      'Expected unloading residual depth h_r > 0');
  finally
    FemDeep.Free;
  end;

  BallCeramic := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  FilmHard := TMaterial.Create('TiN', 450.0, 0.25, mcCoating);
  SubSoft := TMaterial.Create('Al 6061-T6', 69.0, 0.33, mcSubstrate);
  SubSoft.HasSigmaY := True;
  SubSoft.SigmaYGpa := 0.276;
  SubSoft.HasEt := True;
  SubSoft.EtGpa := 0.70;

  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seBoth;
  Cfg.MeshDensity := mdStandard;
  CCoated := TContactCase.Create('T7_CoatedEP',
    TBallSpec.FromDiameterMm(6.0, BallCeramic, False),
    [TLayer.Create(FilmHard, 10.0)], SubSoft,
    TLoadCase.FromNewtons(10.0, 0.0), Cfg);
  BundleCoated := RunCase(CCoated);
  try
    Assert.IsTrue(BundleCoated.FemCalculix.PMaxGpa < BundleCoated.ElasticLayered.PMaxGpa,
      'Substrate yielding must flatten contact pressure p_max');
    Assert.IsTrue(BundleCoated.FemCalculix.ContactRadiusUm > BundleCoated.ElasticLayered.ContactRadiusUm,
      'Substrate yielding must widen contact radius a');
    Assert.IsTrue(BundleCoated.FemCalculix.Interfaces[0].MaxSigmaRRAboveGpa > 0.0,
      'Expected positive coating interface bending tension');
    Assert.IsTrue(BundleCoated.FemCalculix.Interfaces[0].MaxSigmaRRAboveGpa >
                  BundleCoated.ElasticLayered.Interfaces[0].MaxSigmaRRAboveGpa,
      'Substrate yielding must amplify coating interface bending tensile stress');
    Assert.IsTrue(BundleCoated.FemCalculix.MaxPeeq > 0.0);
  finally
    BundleCoated.Free;
  end;
end;

procedure TVVBenchmarksTests.T8_MeshConvergence_StandardVsFine;
var
  BallMat, FilmMat, SubMat: TMaterial;
  Cfg: TSolverConfig;
  CStd, CFine: TContactCase;
  ResStd, ResFine: TContactResult;
  DiffPMax, DiffA: Double;
begin
  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  FilmMat := TMaterial.Create('TiN', 450.0, 0.25, mcCoating);
  SubMat := TMaterial.Create('Steel', 200.0, 0.30, mcSubstrate);

  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seFem;
  Cfg.MeshDensity := mdStandard;
  CStd := TContactCase.Create('T8_Std', TBallSpec.FromDiameterMm(6.0, BallMat, False),
    [TLayer.Create(FilmMat, 4.0)], SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);

  Cfg.MeshDensity := mdFine;
  CFine := TContactCase.Create('T8_Fine', TBallSpec.FromDiameterMm(6.0, BallMat, False),
    [TLayer.Create(FilmMat, 4.0)], SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);

  ResStd := SolveFemCalculix(CStd);
  ResFine := SolveFemCalculix(CFine);
  try
    DiffPMax := Abs(ResStd.PMaxGpa - ResFine.PMaxGpa) / ResFine.PMaxGpa;
    DiffA := Abs(ResStd.ContactRadiusUm - ResFine.ContactRadiusUm) / ResFine.ContactRadiusUm;
    Assert.IsTrue(DiffPMax < 0.02, Format('T8 pmax diff=%g >= 0.02', [DiffPMax]));
    Assert.IsTrue(DiffA < 0.02, Format('T8 a diff=%g >= 0.02', [DiffA]));
  finally
    ResFine.Free;
    ResStd.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TVVBenchmarksTests);

end.
