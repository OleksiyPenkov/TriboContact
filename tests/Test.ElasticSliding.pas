unit Test.ElasticSliding;

interface

uses
  System.SysUtils, System.Math, DUnitX.TestFramework,
  TriboContact.Models, TriboContact.Hertz, TriboContact.ElasticLayered;

type
  [TestFixture]
  TElasticSlidingTests = class
  public
    [Test]
    procedure T4_Hamilton1983_HomogeneousSliding_Mu025_Mu050;
    [Test]
    procedure LayeredSliding_HardOnSoft_TrailingTensileAmplification;
  end;

implementation

procedure TElasticSlidingTests.T4_Hamilton1983_HomogeneousSliding_Mu025_Mu050;
var
  BallMat, LayerMat, SubMat: TMaterial;
  Cfg: TSolverConfig;
  Mus: TArray<Double>;
  Mu, Nu, P0, ExpectedTrail, MaxTrail, MinLead, RelErr: Double;
  C: TContactCase;
  Res: TContactResult;
  I, PeakIdx: Integer;
begin
  BallMat := TMaterial.Create('Rigid', 1000.0, 0.25, mcBall);
  Nu := 0.30;
  LayerMat := TMaterial.Create('HomLayer', 200.0, Nu, mcCoating);
  SubMat := TMaterial.Create('HomSub', 200.0, Nu, mcSubstrate);
  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seElastic;

  Mus := [0.25, 0.50];
  for Mu in Mus do
  begin
    C := TContactCase.Create('Hamilton',
      TBallSpec.FromDiameterMm(6.0, BallMat, True),
      [TLayer.Create(LayerMat, 5.0)],
      SubMat,
      TLoadCase.FromNewtons(5.0, Mu),
      Cfg);

    Res := SolveElasticLayered(C);
    try
      Assert.IsNotNull(Res.StressGrid);
      Assert.IsTrue(Res.StressGrid.HasSliding);
      P0 := Res.PMaxGpa;
      ExpectedTrail := P0 * ((1.0 - 2.0 * Nu) / 3.0 + Mu * Pi * (4.0 + Nu) / 8.0);

      MaxTrail := -Infinity;
      MinLead := Infinity;
      PeakIdx := -1;
      for I := 0 to High(Res.StressGrid.SlidingSurfaceSigmaXXGpa) do
      begin
        if Res.StressGrid.SlidingSurfaceSigmaXXGpa[I] > MaxTrail then
        begin
          MaxTrail := Res.StressGrid.SlidingSurfaceSigmaXXGpa[I];
          PeakIdx := I;
        end;
        if Res.StressGrid.SlidingSurfaceSigmaXXGpa[I] < MinLead then
          MinLead := Res.StressGrid.SlidingSurfaceSigmaXXGpa[I];
      end;

      Assert.IsTrue(Res.StressGrid.SlidingSurfaceXUm[PeakIdx] < 0.0,
        'Trailing-edge tensile peak must occur at x < 0');
      Assert.IsTrue(MinLead < 0.0,
        'Leading-edge must be compressive');

      RelErr := Abs(MaxTrail - ExpectedTrail) / ExpectedTrail;
      Assert.IsTrue(RelErr < 0.01,
        Format('T4 Hamilton err=%g (got=%g, expected=%g, x_peak=%g, a=%g, p0=%g) at mu=%g',
          [RelErr, MaxTrail, ExpectedTrail, Res.StressGrid.SlidingSurfaceXUm[PeakIdx],
           Res.ContactRadiusUm, Res.PMaxGpa, Mu]));
    finally
      Res.Free;
    end;
  end;
end;

procedure TElasticSlidingTests.LayeredSliding_HardOnSoft_TrailingTensileAmplification;
var
  BallMat, FilmMat, SubMat: TMaterial;
  Cfg: TSolverConfig;
  HSub, HFilm, ResNorm, ResSlide: TContactResult;
  C: TContactCase;
  A0, MaxSurfNorm, MaxSurfSlide, MaxIfSlide, MaxIfNorm: Double;
  I, Nz, IfRow: Integer;
begin
  BallMat := TMaterial.Create('Rigid', 1000.0, 0.25, mcBall);
  FilmMat := TMaterial.Create('TiN', 400.0, 0.25, mcCoating);
  FilmMat.HasSigmaY := True;
  FilmMat.SigmaYGpa := 7.5;
  SubMat := TMaterial.Create('Steel100', 100.0, 0.25, mcSubstrate);
  SubMat.HasSigmaY := True;
  SubMat.SigmaYGpa := 0.5;
  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seElastic;

  C := TContactCase.Create('Ref', TBallSpec.FromDiameterMm(6.0, BallMat, True),
    [TLayer.Create(FilmMat, 1.0)], SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);
  ComputeHertzBaselines(C, HSub, HFilm);
  try
    A0 := HSub.ContactRadiusUm;
  finally
    HFilm.Free;
    HSub.Free;
  end;

  C := TContactCase.Create('LayeredNorm', TBallSpec.FromDiameterMm(6.0, BallMat, True),
    [TLayer.Create(FilmMat, A0)], SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);
  ResNorm := SolveElasticLayered(C);

  C := TContactCase.Create('LayeredSlide', TBallSpec.FromDiameterMm(6.0, BallMat, True),
    [TLayer.Create(FilmMat, A0)], SubMat, TLoadCase.FromNewtons(5.0, 0.25), Cfg);
  ResSlide := SolveElasticLayered(C);
  try
    Assert.IsTrue(ResSlide.StressGrid.HasSliding);
    MaxSurfNorm := -Infinity;
    for I := 0 to High(ResNorm.StressGrid.SigmaRRGpa[0]) do
      if ResNorm.StressGrid.SigmaRRGpa[0, I] > MaxSurfNorm then
        MaxSurfNorm := ResNorm.StressGrid.SigmaRRGpa[0, I];

    MaxSurfSlide := -Infinity;
    for I := 0 to High(ResSlide.StressGrid.SlidingSurfaceSigmaXXGpa) do
      if ResSlide.StressGrid.SlidingSurfaceSigmaXXGpa[I] > MaxSurfSlide then
        MaxSurfSlide := ResSlide.StressGrid.SlidingSurfaceSigmaXXGpa[I];

    Assert.IsTrue(MaxSurfSlide > MaxSurfNorm,
      Format('Sliding must amplify peak tensile stress: norm=%g slide=%g a=%g',
        [MaxSurfNorm, MaxSurfSlide, ResSlide.ContactRadiusUm]));

    Nz := Length(ResSlide.StressGrid.ZUm);
    IfRow := -1;
    for I := 0 to Nz - 2 do
      if Abs(ResSlide.StressGrid.ZUm[I] - A0) < 1e-9 then
      begin
        IfRow := I;
        Break;
      end;
    Assert.IsTrue(IfRow > 0);
    MaxIfNorm := ResNorm.Interfaces[0].MaxSigmaRRAboveGpa;
    MaxIfSlide := -Infinity;
    for I := 0 to High(ResSlide.StressGrid.SlidingPlaneSigmaXXGpa[IfRow]) do
      if ResSlide.StressGrid.SlidingPlaneSigmaXXGpa[IfRow, I] > MaxIfSlide then
        MaxIfSlide := ResSlide.StressGrid.SlidingPlaneSigmaXXGpa[IfRow, I];
    Assert.IsTrue(MaxIfSlide > MaxIfNorm);
    Assert.IsTrue(ResSlide.MaxYieldRatio >= ResNorm.MaxYieldRatio);
  finally
    ResSlide.Free;
    ResNorm.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TElasticSlidingTests);

end.
