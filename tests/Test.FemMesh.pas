unit Test.FemMesh;

interface

uses
  System.SysUtils, System.IOUtils, System.Math, DUnitX.TestFramework,
  TriboContact.Models, TriboContact.Materials, TriboContact.Hertz,
  TriboContact.CcxManager, TriboContact.FemMesh;

type
  [TestFixture]
  TFemMeshTests = class
  public
    [Test]
    procedure CcxManager_SetupAndSmokeTest_Passes;
    [Test]
    procedure CcxManager_DetectCax4FaceLabels_ValidatesSurfaceContact;
    [Test]
    procedure FemMesh_PresetsAndLayers_PassAllQualityChecks;
    [Test]
    procedure FemMesh_RigidAndDeformable_ConformAndScale;
  end;

implementation

procedure TFemMeshTests.CcxManager_SetupAndSmokeTest_Passes;
var
  CcxExe, Diag: string;
begin
  CcxExe := ResolveCcxPath('');
  if CcxExe = '' then
    CcxExe := SetupCcx('');
  Assert.IsTrue(TFile.Exists(CcxExe), 'ccx.exe must exist after SetupCcx');
  Assert.IsTrue(SmokeTestCcx(CcxExe, Diag), '1-element smoke test failed: ' + Diag);
end;

procedure TFemMeshTests.CcxManager_DetectCax4FaceLabels_ValidatesSurfaceContact;
var
  CcxExe, TopFace, BotFace, Diag: string;
begin
  CcxExe := ResolveCcxPath('');
  if CcxExe = '' then
    CcxExe := SetupCcx('');
  Assert.IsTrue(DetectCax4FaceLabels(CcxExe, TopFace, BotFace, Diag),
    '2-element contact probe failed: ' + Diag);
  Assert.AreEqual<string>('S3', TopFace);
  Assert.AreEqual<string>('S1', BotFace);
end;

procedure TFemMeshTests.FemMesh_PresetsAndLayers_PassAllQualityChecks;
var
  Lib: TMaterialLibrary;
  BallMat, SubMat, L1Mat, L2Mat, L3Mat: TMaterial;
  Layers: TArray<TLayer>;
  Densities: TArray<TMeshDensity>;
  D: TMeshDensity;
  NCount: Integer;
  Cfg: TSolverConfig;
  C: TContactCase;
  HSub, HFilm: TContactResult;
  Mesh: TFemMesh;
  Report: string;
  CountInA, I: Integer;
begin
  Lib := TMaterialLibrary.Create;
  try
    BallMat := Lib.GetPreset('Si3N4', mcBall);
    SubMat := Lib.GetPreset('304 Steel', mcSubstrate);
    L1Mat := Lib.GetPreset('TiN', mcCoating);
    L2Mat := Lib.GetPreset('CrN', mcCoating);
    L3Mat := Lib.GetPreset('Al2O3', mcCoating);
  finally
    Lib.Free;
  end;

  Densities := [mdCoarse, mdStandard, mdFine];
  for NCount := 1 to 3 do
  begin
    case NCount of
      1: Layers := [TLayer.Create(L1Mat, 2.0)];
      2: Layers := [TLayer.Create(L1Mat, 1.0), TLayer.Create(L2Mat, 1.5)];
      3: Layers := [TLayer.Create(L1Mat, 0.8), TLayer.Create(L2Mat, 1.0), TLayer.Create(L3Mat, 1.2)];
    end;

    for D in Densities do
    begin
      Cfg := TSolverConfig.DefaultConfig;
      Cfg.MeshDensity := D;
      C := TContactCase.Create('MeshTest',
        TBallSpec.FromDiameterMm(6.0, BallMat, False),
        Layers, SubMat, TLoadCase.FromNewtons(5.0, 0.0), Cfg);

      ComputeHertzBaselines(C, HSub, HFilm);
      try
        Mesh := GenerateFemMesh(C, HSub.ContactRadiusUm, HSub.PenetrationDepthUm, HSub.MaxYieldRatio);
        try
          Assert.IsTrue(ValidateFemMesh(Mesh, C, Report), Report);
          Assert.IsTrue(Mesh.RDomUm >= 20.0 * Mesh.EstRadiusUm);
          Assert.IsTrue(Mesh.HSubUm >= 20.0 * C.TotalCoatingThicknessUm);
          Assert.IsTrue(Mesh.MaxContactZoneAspectRatio <= 10.0);

          CountInA := 0;
          for I := 0 to High(Mesh.SpecRCoords) - 1 do
            if Mesh.SpecRCoords[I + 1] <= Mesh.EstRadiusUm + 1e-6 then
              Inc(CountInA);
          Assert.IsTrue(CountInA >= Mesh.NrAcrossA - 1);
        finally
          Mesh.Free;
        end;
      finally
        HFilm.Free;
        HSub.Free;
      end;
    end;
  end;
end;

procedure TFemMeshTests.FemMesh_RigidAndDeformable_ConformAndScale;
var
  BallMat, FilmMat, SubMat: TMaterial;
  Cfg: TSolverConfig;
  C: TContactCase;
  MeshDef, MeshRig: TFemMesh;
  Report: string;
begin
  BallMat := TMaterial.Create('WC', 620.0, 0.22, mcBall);
  FilmMat := TMaterial.Create('TiN', 450.0, 0.25, mcCoating);
  SubMat := TMaterial.Create('Glass', 72.0, 0.22, mcSubstrate);
  Cfg := TSolverConfig.DefaultConfig;

  C := TContactCase.Create('Def', TBallSpec.FromDiameterMm(4.0, BallMat, False),
    [TLayer.Create(FilmMat, 1.5)], SubMat, TLoadCase.FromNewtons(2.0, 0.0), Cfg);
  MeshDef := GenerateFemMesh(C, 25.0, 0.3, 0.5);
  try
    Assert.IsTrue(ValidateFemMesh(MeshDef, C, Report), Report);
    Assert.IsFalse(MeshDef.RigidBall);
    Assert.IsTrue(Length(MeshDef.BallElSet) > 40);
  finally
    MeshDef.Free;
  end;

  C := TContactCase.Create('Rig', TBallSpec.FromDiameterMm(4.0, BallMat, True),
    [TLayer.Create(FilmMat, 1.5)], SubMat, TLoadCase.FromNewtons(2.0, 0.0), Cfg);
  MeshRig := GenerateFemMesh(C, 25.0, 0.3, 0.5);
  try
    Assert.IsTrue(ValidateFemMesh(MeshRig, C, Report), Report);
    Assert.IsTrue(MeshRig.RigidBall);
  finally
    MeshRig.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFemMeshTests);

end.
