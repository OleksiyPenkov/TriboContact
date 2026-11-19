unit Test.ElasticNormal;

interface

uses
  System.SysUtils, System.Math, DUnitX.TestFramework,
  TriboContact.Models, TriboContact.Hertz, TriboContact.SpecialMath,
  TriboContact.ElasticLayered;

type
  [TestFixture]
  TElasticNormalTests = class
  private
    function MakeHomogeneousCase(ANLayers: Integer; AE, ANu, AThickUm: Double): TContactCase;
  public
    [Test]
    procedure SpecialMath_EllipKE_LegendreRelation;
    [Test]
    procedure SpecialMath_BesselJ012_ZerosAndRecurrence;
    [Test]
    procedure SMM_HomogeneousIdentity_AndHighWavenumberAsymptote;
    [Test]
    procedure T1_HomogeneousLimit_1_2_3Layers;
    [Test]
    procedure T2_ThinAndThickAsymptotes;
    [Test]
    procedure T3_OSullivanKing_LayeredTrendsAndInterfaceJump;
  end;

implementation

function TElasticNormalTests.MakeHomogeneousCase(ANLayers: Integer;
  AE, ANu, AThickUm: Double): TContactCase;
var
  BallMat, LayerMat, SubMat: TMaterial;
  Layers: TArray<TLayer>;
  I: Integer;
  Cfg: TSolverConfig;
begin
  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  LayerMat := TMaterial.Create('HomFilm', AE, ANu, mcCoating);
  SubMat := TMaterial.Create('HomSub', AE, ANu, mcSubstrate);
  SetLength(Layers, ANLayers);
  for I := 0 to ANLayers - 1 do
    Layers[I] := TLayer.Create(LayerMat, AThickUm);
  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seElastic;
  Result := TContactCase.Create('HomTest',
    TBallSpec.FromDiameterMm(6.0, BallMat, False),
    Layers, SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);
end;

procedure TElasticNormalTests.SpecialMath_EllipKE_LegendreRelation;
var
  M, Km, Em, K1m, E1m, RelErr: Double;
  Ms: TArray<Double>;
begin
  Ms := [1e-10, 1e-6, 0.01, 0.25, 0.5, 0.9, 0.999];
  for M in Ms do
  begin
    EllipKE(M, Km, Em);
    EllipKE(1.0 - M, K1m, E1m);
    RelErr := Abs((Em * K1m + E1m * Km - Km * K1m) - 0.5 * Pi);
    Assert.IsTrue(RelErr < 1e-13, Format('Legendre error %g at m=%g', [RelErr, M]));
  end;
  Assert.AreEqual(0.5 * Pi, EllipK(0.0), 1e-15);
  Assert.AreEqual(0.5 * Pi, EllipE(0.0), 1e-15);
  Assert.IsTrue(Abs(EllipE_Minus_OneMinusMK(1e-7) - 0.5 * Pi * 1e-7 * (0.5 + 1e-7 / 16.0)) < 1e-18);
  Assert.IsTrue(Abs(EllipK_Minus_E(1e-7) - 0.5 * Pi * 1e-7 * (0.5 + 3e-7 / 16.0)) < 1e-18);
end;

procedure TElasticNormalTests.SpecialMath_BesselJ012_ZerosAndRecurrence;
var
  J0, J1, J2, X, RecErr: Double;
  Xs: TArray<Double>;
begin
  Assert.AreEqual(1.0, BesselJ0(0.0), 1e-15);
  Assert.AreEqual(0.0, BesselJ1(0.0), 1e-15);
  Assert.AreEqual(0.0, BesselJ2(0.0), 1e-15);
  Assert.AreEqual(0.5, BesselJ1OverX(0.0), 1e-15);
  Assert.IsTrue(Abs(BesselJ0(2.4048255576957729)) < 1e-14);
  Assert.IsTrue(Abs(BesselJ1(3.8317059702075123)) < 1e-14);

  Xs := [1e-9, 1e-4, 0.5, 5.0, 19.9, 20.1, 50.0, 250.0, 500.0];
  for X in Xs do
  begin
    BesselJ012(X, J0, J1, J2);
    RecErr := Abs((2.0 / X) * J1 - (J0 + J2));
    Assert.IsTrue(RecErr < 1e-13, Format('Bessel recurrence error %g at x=%g', [RecErr, X]));
  end;
end;

procedure TElasticNormalTests.SMM_HomogeneousIdentity_AndHighWavenumberAsymptote;
var
  C: TContactCase;
  Sys: TSMMSystem;
  GCoated: TMat2x2;
  Xi, Gzz, GHom, RelErr, GTopAsym: Double;
  Xis: TArray<Double>;
  BallMat, LayerMat, SubMat: TMaterial;
begin
  C := MakeHomogeneousCase(3, 180.0, 0.25, 2.5);
  InitSMMSystem(C, Sys);
  Xis := [1e-6, 1e-4, 1e-3, 0.1, 1.0, 10.0, 100.0, 1000.0];
  for Xi in Xis do
  begin
    Gzz := EvaluateCoatedCompliance(Sys, Xi, GCoated);
    GHom := 2.0 * (1.0 - Sqr(0.25)) / (180.0 * Xi);
    RelErr := Abs(Gzz - GHom) / GHom;
    if Xi >= 1e-4 then
      Assert.IsTrue(RelErr < 1e-12, Format('SMM hom mismatch %g at xi=%g', [RelErr, Xi]))
    else
      Assert.IsTrue(RelErr < 1e-9, Format('SMM hom mismatch %g at xi=%g', [RelErr, Xi]));
  end;

  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  LayerMat := TMaterial.Create('TiN', 450.0, 0.25, mcCoating);
  SubMat := TMaterial.Create('Steel', 200.0, 0.30, mcSubstrate);
  C := TContactCase.Create('Asym', TBallSpec.FromDiameterMm(6.0, BallMat),
    [TLayer.Create(LayerMat, 2.0)], SubMat, TLoadCase.FromNewtons(5.0, 0.0),
    TSolverConfig.DefaultConfig);
  InitSMMSystem(C, Sys);
  Xi := 25.0;
  Gzz := EvaluateCoatedCompliance(Sys, Xi, GCoated);
  GTopAsym := 2.0 * (1.0 - Sqr(0.25)) / 450.0;
  RelErr := Abs(Xi * Gzz - GTopAsym) / GTopAsym;
  Assert.IsTrue(RelErr < 1e-10);
end;

procedure TElasticNormalTests.T1_HomogeneousLimit_1_2_3Layers;
var
  N: Integer;
  C: TContactCase;
  HSub, HFilm, Res: TContactResult;
  ErrA, ErrDelta, ErrP0, MaxVmErr, RefVm, DiffVm: Double;
  I: Integer;
begin
  for N := 1 to 3 do
  begin
    C := MakeHomogeneousCase(N, 200.0, 0.30, 5.0);
    ComputeHertzBaselines(C, HSub, HFilm);
    Res := SolveElasticLayered(C);
    try
      ErrA := Abs(Res.ContactRadiusUm - HSub.ContactRadiusUm) / HSub.ContactRadiusUm;
      ErrDelta := Abs(Res.PenetrationDepthUm - HSub.PenetrationDepthUm) / HSub.PenetrationDepthUm;
      ErrP0 := Abs(Res.PMaxGpa - HSub.PMaxGpa) / HSub.PMaxGpa;

      Assert.IsTrue(ErrA < 0.002, Format('T1 (%d layers) a err=%g', [N, ErrA]));
      Assert.IsTrue(ErrDelta < 0.002, Format('T1 (%d layers) delta err=%g', [N, ErrDelta]));
      Assert.IsTrue(ErrP0 < 0.002, Format('T1 (%d layers) p0 err=%g', [N, ErrP0]));

      MaxVmErr := 0.0;
      for I := 0 to High(Res.ZCenterlineUm) do
      begin
        if Res.ZCenterlineUm[I] > 3.0 * HSub.ContactRadiusUm then
          Continue;
        var Zeta := Res.ZCenterlineUm[I] / HSub.ContactRadiusUm;
        var Srr: Double;
        if Zeta <= 0.0 then
          Srr := -HSub.PMaxGpa * (0.5 + 0.30)
        else
          Srr := -HSub.PMaxGpa * ((1.0 + 0.30) * (1.0 - Zeta * ArcTan(1.0 / Zeta)) -
            0.5 / (1.0 + Sqr(Zeta)));
        var Szz := -HSub.PMaxGpa / (1.0 + Sqr(Zeta));
        RefVm := Abs(Szz - Srr);
        DiffVm := Abs(Res.CenterlineSigmaVmGpa[I] - RefVm) / HSub.PMaxGpa;
        if DiffVm > MaxVmErr then
          MaxVmErr := DiffVm;
      end;
      Assert.IsTrue(MaxVmErr < 0.005, Format('T1 (%d layers) vm err=%g', [N, MaxVmErr]));
    finally
      Res.Free;
      HFilm.Free;
      HSub.Free;
    end;
  end;
end;

procedure TElasticNormalTests.T2_ThinAndThickAsymptotes;
var
  BallMat, FilmMat, MildFilmMat, SubMat: TMaterial;
  Ball: TBallSpec;
  Load: TLoadCase;
  Cfg: TSolverConfig;
  HSub, HFilm, ResThin, ResThick, ResThickMild: TContactResult;
  CThin, CThick, CThickMild: TContactCase;
  A0, AFilm0, ErrA, ErrDelta, ErrP0: Double;
begin
  BallMat := TMaterial.Create('RigidBall', 1000.0, 0.25, mcBall);
  FilmMat := TMaterial.Create('StiffFilm', 400.0, 0.25, mcCoating);
  MildFilmMat := TMaterial.Create('MildFilm', 135.0, 0.25, mcCoating);
  SubMat := TMaterial.Create('SoftSub', 100.0, 0.25, mcSubstrate);
  Ball := TBallSpec.FromDiameterMm(6.0, BallMat, True);
  Load := TLoadCase.FromNewtons(5.0, 0.0);
  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seElastic;

  CThin := TContactCase.Create('Thin', Ball, [TLayer.Create(FilmMat, 1.0)], SubMat, Load, Cfg);
  ComputeHertzBaselines(CThin, HSub, HFilm);
  try
    A0 := HSub.ContactRadiusUm;
    AFilm0 := HFilm.ContactRadiusUm;
  finally
    HFilm.Free;
    HSub.Free;
  end;

  CThin := TContactCase.Create('ThinExact', Ball, [TLayer.Create(FilmMat, 0.001 * A0)], SubMat, Load, Cfg);
  ComputeHertzBaselines(CThin, HSub, HFilm);
  ResThin := SolveElasticLayered(CThin);
  try
    ErrA := Abs(ResThin.ContactRadiusUm - HSub.ContactRadiusUm) / HSub.ContactRadiusUm;
    ErrDelta := Abs(ResThin.PenetrationDepthUm - HSub.PenetrationDepthUm) / HSub.PenetrationDepthUm;
    ErrP0 := Abs(ResThin.PMaxGpa - HSub.PMaxGpa) / HSub.PMaxGpa;
    Assert.IsTrue(ErrA < 0.01, Format('T2 thin a err=%g', [ErrA]));
    Assert.IsTrue(ErrDelta < 0.01, Format('T2 thin delta err=%g', [ErrDelta]));
    Assert.IsTrue(ErrP0 < 0.01, Format('T2 thin p0 err=%g', [ErrP0]));
  finally
    ResThin.Free;
    HFilm.Free;
    HSub.Free;
  end;

  CThick := TContactCase.Create('ThickExact', Ball, [TLayer.Create(FilmMat, 20.0 * AFilm0)], SubMat, Load, Cfg);
  ComputeHertzBaselines(CThick, HSub, HFilm);
  ResThick := SolveElasticLayered(CThick);
  try
    ErrA := Abs(ResThick.ContactRadiusUm - HFilm.ContactRadiusUm) / HFilm.ContactRadiusUm;
    ErrP0 := Abs(ResThick.PMaxGpa - HFilm.PMaxGpa) / HFilm.PMaxGpa;
    Assert.IsTrue(ErrA < 0.01, Format('T2 thick a err=%g', [ErrA]));
    Assert.IsTrue(ErrP0 < 0.01, Format('T2 thick p0 err=%g', [ErrP0]));
  finally
    ResThick.Free;
    HFilm.Free;
    HSub.Free;
  end;

  CThickMild := TContactCase.Create('ThickMild', Ball, [TLayer.Create(MildFilmMat, 20.0 * A0)], SubMat, Load, Cfg);
  ComputeHertzBaselines(CThickMild, HSub, HFilm);
  ResThickMild := SolveElasticLayered(CThickMild);
  try
    ErrA := Abs(ResThickMild.ContactRadiusUm - HFilm.ContactRadiusUm) / HFilm.ContactRadiusUm;
    ErrDelta := Abs(ResThickMild.PenetrationDepthUm - HFilm.PenetrationDepthUm) / HFilm.PenetrationDepthUm;
    ErrP0 := Abs(ResThickMild.PMaxGpa - HFilm.PMaxGpa) / HFilm.PMaxGpa;
    Assert.IsTrue(ErrA < 0.01, Format('T2 thick mild a err=%g', [ErrA]));
    Assert.IsTrue(ErrDelta < 0.01, Format('T2 thick mild delta err=%g', [ErrDelta]));
    Assert.IsTrue(ErrP0 < 0.01, Format('T2 thick mild p0 err=%g', [ErrP0]));
  finally
    ResThickMild.Free;
    HFilm.Free;
    HSub.Free;
  end;
end;

procedure TElasticNormalTests.T3_OSullivanKing_LayeredTrendsAndInterfaceJump;
var
  BallMat, SubMat, FilmMat: TMaterial;
  Ball: TBallSpec;
  Load: TLoadCase;
  Cfg: TSolverConfig;
  A0, EfRatio, HOverA, JumpRatio: Double;
  HSub, HFilm, Res: TContactResult;
  C: TContactCase;
  EfList, HList: TArray<Double>;
  PMaxPrev: Double;
  Jump: Double;
begin
  BallMat := TMaterial.Create('Rigid', 1000.0, 0.25, mcBall);
  SubMat := TMaterial.Create('Sub100', 100.0, 0.30, mcSubstrate);
  Ball := TBallSpec.FromDiameterMm(6.0, BallMat, True);
  Load := TLoadCase.FromNewtons(5.0, 0.0);
  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seElastic;

  C := TContactCase.Create('Ref', Ball, [TLayer.Create(SubMat, 1.0)], SubMat, Load, Cfg);
  ComputeHertzBaselines(C, HSub, HFilm);
  try
    A0 := HSub.ContactRadiusUm;
  finally
    HFilm.Free;
    HSub.Free;
  end;

  EfList := [0.5, 2.0, 4.0];
  HList := [0.5, 1.0, 2.0];

  for HOverA in HList do
  begin
    PMaxPrev := 0.0;
    for EfRatio in EfList do
    begin
      FilmMat := TMaterial.Create('Film', EfRatio * 100.0, 0.30, mcCoating);
      C := TContactCase.Create('OK88', Ball, [TLayer.Create(FilmMat, HOverA * A0)], SubMat, Load, Cfg);
      ComputeHertzBaselines(C, HSub, HFilm);
      Res := SolveElasticLayered(C);
      try
        Assert.IsTrue(Res.ForceBalanceErrorRel < 1e-6);
        if EfRatio > 1.0 then
        begin
          Assert.IsTrue(Res.PMaxGpa > HSub.PMaxGpa);
          Assert.IsTrue(Res.ContactRadiusUm < HSub.ContactRadiusUm);
          Assert.IsTrue(Res.PenetrationDepthUm < HSub.PenetrationDepthUm);
          // Stiff film on softer substrate carries tensile bending stress at bottom of film (z1-).
          Assert.IsTrue(Res.Interfaces[0].MaxSigmaRRAboveGpa > 0.0,
            Format('Expected tensile bending at interface for Ef/Es=%g, h/a=%g, got %g',
              [EfRatio, HOverA, Res.Interfaces[0].MaxSigmaRRAboveGpa]));
          Jump := Abs(Res.Interfaces[0].MaxSigmaRRAboveGpa - Res.Interfaces[0].MaxSigmaRRBelowGpa);
          JumpRatio := Jump / Max(Abs(Res.Interfaces[0].MaxSigmaRRAboveGpa), 1e-9);
          Assert.IsTrue(JumpRatio > 0.25);
        end
        else
        begin
          Assert.IsTrue(Res.PMaxGpa < HSub.PMaxGpa);
          Assert.IsTrue(Res.ContactRadiusUm > HSub.ContactRadiusUm);
        end;
        Assert.IsTrue(Res.PMaxGpa > PMaxPrev);
        PMaxPrev := Res.PMaxGpa;
      finally
        Res.Free;
        HFilm.Free;
        HSub.Free;
      end;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TElasticNormalTests);

end.
