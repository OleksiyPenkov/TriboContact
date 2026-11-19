unit TriboContact.Runner;

interface

uses
  System.SysUtils,
  TriboContact.Models, TriboContact.Hertz, TriboContact.ElasticLayered,
  TriboContact.FemCalculix;

type
  TSweepPoint = record
    NormalLoadMn: Double;
    HertzSubPMaxGpa: Double;
    HertzFilmPMaxGpa: Double;
    ElasticPMaxGpa: Double;
    ElasticPMeanGpa: Double;
    ElasticRadiusUm: Double;
    ElasticMaxYieldRatio: Double;
    HasFem: Boolean;
    FemPMaxGpa: Double;
    FemPMeanGpa: Double;
    FemRadiusUm: Double;
    FemMaxYieldRatio: Double;
    FemMaxPeeq: Double;
  end;

function RunCase(const ACase: TContactCase; const ALogCallback: TProc<string> = nil;
  ACancelFlag: PBoolean = nil): TComparisonBundle;
function RunLoadSweep(const ACase: TContactCase; const ALoadsMn: TDoubleArray;
  const ALogCallback: TProc<string> = nil;
  ACancelFlag: PBoolean = nil): TArray<TSweepPoint>;

implementation

function RunCase(const ACase: TContactCase; const ALogCallback: TProc<string>;
  ACancelFlag: PBoolean): TComparisonBundle;
var
  HSub, HFilm: TContactResult;
  NeedElastic, NeedFem: Boolean;
  ElasticRes, FemRes: TContactResult;
begin
  ACase.Validate;
  Result := TComparisonBundle.Create;
  try
    Result.CaseName := ACase.CaseName;
    Result.Ball := ACase.Ball;
    Result.Layers := Copy(ACase.Layers);
    Result.Substrate := ACase.Substrate.Clone;
    Result.LoadCase := ACase.LoadCase;
    Result.Solver := ACase.Solver;

    ComputeHertzBaselines(ACase, HSub, HFilm);
    Result.HertzSubstrate := HSub;
    Result.HertzTopFilm := HFilm;

    NeedElastic := (ACase.Solver.Engine = seElastic) or (ACase.Solver.Engine = seBoth);
    NeedFem := (ACase.Solver.Engine = seFem) or (ACase.Solver.Engine = seBoth);

    ElasticRes := nil;
    if NeedElastic or NeedFem then
    begin
      if Assigned(ALogCallback) then
        ALogCallback('Running Engine 1 (semi-analytical layered elastic)...');
      ElasticRes := SolveElasticLayered(ACase);
      if NeedElastic then
        Result.ElasticLayered := ElasticRes;
    end;

    try
      if NeedFem then
      begin
        if Assigned(ALogCallback) then
          ALogCallback('Running Engine 2 (CalculiX axisymmetric FEM)...');
        FemRes := SolveFemCalculix(ACase, ALogCallback, ACancelFlag, ElasticRes);
        Result.FemCalculix := FemRes;
      end;
    finally
      if (not NeedElastic) and (ElasticRes <> nil) then
        ElasticRes.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function RunLoadSweep(const ACase: TContactCase; const ALoadsMn: TDoubleArray;
  const ALogCallback: TProc<string>; ACancelFlag: PBoolean): TArray<TSweepPoint>;
var
  I: Integer;
  SubCase: TContactCase;
  Bundle: TComparisonBundle;
  Pt: TSweepPoint;
begin
  SetLength(Result, Length(ALoadsMn));
  for I := 0 to High(ALoadsMn) do
  begin
    if (ACancelFlag <> nil) and ACancelFlag^ then
      Break;
    SubCase := ACase.Clone;
    SubCase.LoadCase.NormalLoadMn := ALoadsMn[I];
    if Assigned(ALogCallback) then
      ALogCallback(Format('Sweep point %d/%d: F_N = %.4g mN',
        [I + 1, Length(ALoadsMn), ALoadsMn[I]], TFormatSettings.Invariant));

    Bundle := RunCase(SubCase, ALogCallback, ACancelFlag);
    try
      Pt := Default(TSweepPoint);
      Pt.NormalLoadMn := ALoadsMn[I];
      Pt.HertzSubPMaxGpa := Bundle.HertzSubstrate.PMaxGpa;
      Pt.HertzFilmPMaxGpa := Bundle.HertzTopFilm.PMaxGpa;
      if Bundle.ElasticLayered <> nil then
      begin
        Pt.ElasticPMaxGpa := Bundle.ElasticLayered.PMaxGpa;
        Pt.ElasticPMeanGpa := Bundle.ElasticLayered.PMeanGpa;
        Pt.ElasticRadiusUm := Bundle.ElasticLayered.ContactRadiusUm;
        Pt.ElasticMaxYieldRatio := Bundle.ElasticLayered.MaxYieldRatio;
      end;
      if Bundle.FemCalculix <> nil then
      begin
        Pt.HasFem := True;
        Pt.FemPMaxGpa := Bundle.FemCalculix.PMaxGpa;
        Pt.FemPMeanGpa := Bundle.FemCalculix.PMeanGpa;
        Pt.FemRadiusUm := Bundle.FemCalculix.ContactRadiusUm;
        Pt.FemMaxYieldRatio := Bundle.FemCalculix.MaxYieldRatio;
        Pt.FemMaxPeeq := Bundle.FemCalculix.MaxPeeq;
      end;
      Result[I] := Pt;
    finally
      Bundle.Free;
    end;
  end;
end;

end.
