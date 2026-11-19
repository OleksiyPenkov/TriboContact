unit Test.FemCalculix;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Math, DUnitX.TestFramework,
  TriboContact.Models, TriboContact.Hertz, TriboContact.FemMesh,
  TriboContact.FemCalculix, TriboContact.Runner;

type
  [TestFixture]
  TFemCalculixTests = class
  private
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure InpGenerator_EmitsUnitsPlasticityAndContactCards;
    [Test]
    procedure FrdParser_HandlesAdjacentNegativeExponents;
    [Test]
    procedure PressureForceIntegral_MatchesAnalyticalEllipsoid;
    [Test]
    procedure Runner_ProducesAllBaselines;
  end;

implementation

procedure TFemCalculixTests.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'tc_m4_' + TPath.GetRandomFileName);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TFemCalculixTests.TearDown;
begin
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TFemCalculixTests.InpGenerator_EmitsUnitsPlasticityAndContactCards;
var
  BallMat, FilmMat, SubMat: TMaterial;
  C: TContactCase;
  Mesh: TFemMesh;
  InpText, ActualEl: string;
begin
  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  FilmMat := TMaterial.Create('TiN', 450.0, 0.25, mcCoating);
  SubMat := TMaterial.Create('Steel', 200.0, 0.30, mcSubstrate);
  SubMat.HasSigmaY := True;
  SubMat.SigmaYGpa := 0.35;
  SubMat.HasEt := True;
  SubMat.EtGpa := 2.0;

  C := TContactCase.Create('InpCheck', TBallSpec.FromDiameterMm(6.0, BallMat),
    [TLayer.Create(FilmMat, 2.0)], SubMat, TLoadCase.FromNewtons(5.0, 0.0),
    TSolverConfig.DefaultConfig);

  Mesh := GenerateFemMesh(C, 35.0, 0.4, 1.5);
  try
    InpText := GenerateCalculixInp(C, Mesh, 0.4, 1.0, True, ActualEl);
    Assert.AreEqual<string>('CAX4', ActualEl);
    Assert.IsTrue(Pos('*ELEMENT, TYPE=CAX4', InpText) > 0);
    Assert.IsTrue(Pos('TYPE=SURFACE TO SURFACE', InpText) > 0);
    Assert.IsTrue(Pos('PRESSURE-OVERCLOSURE=LINEAR', InpText) > 0);
    Assert.IsTrue(Pos('*PLASTIC', InpText) > 0);
    Assert.IsTrue(Pos('OUTPUT=2D', InpText) > 0);
    Assert.IsTrue(Pos('AMP_UNLOAD', InpText) > 0);
  finally
    Mesh.Free;
  end;
end;

procedure TFemCalculixTests.FrdParser_HandlesAdjacentNegativeExponents;
var
  FrdPath: string;
  Lines: TStringList;
  Frd: TFrdData;
begin
  FrdPath := TPath.Combine(FTempDir, 'sample.frd');
  Lines := TStringList.Create;
  try
    Lines.Add('  100CL  101 1.000000000           2                     0    1           1');
    Lines.Add(' -4  DISP        4    1');
    Lines.Add(' -1         1-1.23456E-02-2.34567E-01 0.00000E+00');
    Lines.Add(' -3');
    Lines.Add('  100CL  102 1.000000000           2                     0    1           1');
    Lines.Add(' -4  CONTACT     6    1');
    Lines.Add(' -1         1 0.00000E+00 0.00000E+00 0.00000E+00 2.50000E+00 0.00000E+00 0.00000E+00');
    Lines.Add(' -3');
    Lines.SaveToFile(FrdPath, TEncoding.ASCII);
  finally
    Lines.Free;
  end;

  Frd := ParseFrdFile(FrdPath, 2);
  Assert.IsTrue(Frd.HasDisp);
  Assert.IsTrue(Frd.HasContact);
  Assert.AreEqual(-0.0123456, Frd.DispX[1], 1e-10);
  Assert.AreEqual(-0.234567, Frd.DispY[1], 1e-10);
  Assert.AreEqual(2.5, Frd.CPress[1], 1e-10);
end;

procedure TFemCalculixTests.PressureForceIntegral_MatchesAnalyticalEllipsoid;
var
  R, P: TDoubleArray;
  I, N: Integer;
  A, P0, FExpected, FCalc: Double;
begin
  N := 400;
  A := 30.0;
  P0 := 2.0;
  SetLength(R, N + 1);
  SetLength(P, N + 1);
  for I := 0 to N do
  begin
    R[I] := A * (I / N);
    P[I] := P0 * Sqrt(Max(0.0, 1.0 - Sqr(R[I] / A)));
  end;
  FExpected := (2.0 / 3.0) * Pi * Sqr(A) * P0;
  FCalc := ComputeAxisymmetricPressureForce(R, P);
  Assert.IsTrue(Abs(FCalc - FExpected) / FExpected < 1e-3);
end;

procedure TFemCalculixTests.Runner_ProducesAllBaselines;
var
  BallMat, FilmMat, SubMat: TMaterial;
  Cfg: TSolverConfig;
  C: TContactCase;
  Bundle: TComparisonBundle;
begin
  BallMat := TMaterial.Create('Si3N4', 310.0, 0.27, mcBall);
  FilmMat := TMaterial.Create('TiN', 450.0, 0.25, mcCoating);
  SubMat := TMaterial.Create('Steel', 200.0, 0.30, mcSubstrate);
  Cfg := TSolverConfig.DefaultConfig;
  Cfg.Engine := seElastic;

  C := TContactCase.Create('RunnerCheck', TBallSpec.FromDiameterMm(6.0, BallMat),
    [TLayer.Create(FilmMat, 2.0)], SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);

  Bundle := RunCase(C);
  try
    Assert.IsNotNull(Bundle.HertzSubstrate);
    Assert.IsNotNull(Bundle.HertzTopFilm);
    Assert.IsNotNull(Bundle.ElasticLayered);
    Assert.IsNull(Bundle.FemCalculix);
  finally
    Bundle.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFemCalculixTests);

end.
