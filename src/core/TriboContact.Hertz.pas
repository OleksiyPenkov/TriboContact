unit TriboContact.Hertz;

interface

uses
  System.SysUtils, System.Math, System.Diagnostics,
  TriboContact.Models;

function EffectiveHertzModulusGpa(const ABall: TBallSpec; const ATarget: TMaterial): Double;
function SolveHertz(const ABall: TBallSpec; const ATarget: TMaterial;
  const ALoad: TLoadCase; const ASolverName: string;
  APoints: Integer = 200): TContactResult;
procedure ComputeHertzBaselines(const ACase: TContactCase;
  out AHertzSubstrate, AHertzTopFilm: TContactResult);

implementation

function EffectiveHertzModulusGpa(const ABall: TBallSpec; const ATarget: TMaterial): Double;
var
  InvEStar: Double;
begin
  InvEStar := (1.0 - Sqr(ATarget.Nu)) / ATarget.EGpa;
  if not ABall.Rigid then
    InvEStar := InvEStar + (1.0 - Sqr(ABall.Material.Nu)) / ABall.Material.EGpa;
  Result := 1.0 / InvEStar;
end;

function SolveHertz(const ABall: TBallSpec; const ATarget: TMaterial;
  const ALoad: TLoadCase; const ASolverName: string; APoints: Integer): TContactResult;
var
  Timer: TStopwatch;
  EStar, A, Delta, P0, PMean, RMax, ZMax: Double;
  I: Integer;
  R, Zeta, Srr, Szz, Svm, MaxSvm, Ratio: Double;
  YieldEntry: TYieldRatioEntry;
begin
  ABall.Validate;
  ATarget.Validate;
  ALoad.Validate;
  if APoints < 20 then
    APoints := 20;

  Timer := TStopwatch.StartNew;
  EStar := EffectiveHertzModulusGpa(ABall, ATarget);
  A := Power((3.0 * ALoad.NormalLoadMn * ABall.RadiusUm) / (4.0 * EStar), 1.0 / 3.0);
  Delta := Sqr(A) / ABall.RadiusUm;
  P0 := (3.0 * ALoad.NormalLoadMn) / (2.0 * Pi * Sqr(A));
  PMean := ALoad.NormalLoadMn / (Pi * Sqr(A));

  Result := TContactResult.Create;
  try
    Result.SolverName := ASolverName;
    Result.ContactRadiusUm := A;
    Result.PenetrationDepthUm := Delta;
    Result.PMaxGpa := P0;
    Result.PMeanGpa := PMean;
    Result.ActualLoadMn := ALoad.NormalLoadMn;
    Result.ForceBalanceErrorRel := 0.0;

    RMax := 1.5 * A;
    ZMax := 3.0 * A;
    SetLength(Result.RUm, APoints);
    SetLength(Result.PGpa, APoints);
    for I := 0 to APoints - 1 do
    begin
      R := RMax * (I / (APoints - 1));
      Result.RUm[I] := R;
      if R < A then
        Result.PGpa[I] := P0 * Sqrt(Max(0.0, 1.0 - Sqr(R / A)))
      else
        Result.PGpa[I] := 0.0;
    end;

    SetLength(Result.ZCenterlineUm, APoints);
    SetLength(Result.CenterlineSigmaVmGpa, APoints);
    SetLength(Result.CenterlineSigmaRRGpa, APoints);
    SetLength(Result.CenterlineSigmaZZGpa, APoints);
    MaxSvm := 0.0;

    for I := 0 to APoints - 1 do
    begin
      Result.ZCenterlineUm[I] := ZMax * (I / (APoints - 1));
      Zeta := Result.ZCenterlineUm[I] / A;
      if Zeta <= 0.0 then
      begin
        Srr := -P0 * (0.5 + ATarget.Nu);
        Szz := -P0;
      end
      else
      begin
        Srr := -P0 * ((1.0 + ATarget.Nu) * (1.0 - Zeta * ArcTan(1.0 / Zeta)) -
          0.5 / (1.0 + Sqr(Zeta)));
        Szz := -P0 / (1.0 + Sqr(Zeta));
      end;
      Svm := Abs(Szz - Srr);
      Result.CenterlineSigmaRRGpa[I] := Srr;
      Result.CenterlineSigmaZZGpa[I] := Szz;
      Result.CenterlineSigmaVmGpa[I] := Svm;
      if Svm > MaxSvm then
        MaxSvm := Svm;
    end;

    if ATarget.HasSigmaY then
    begin
      Ratio := MaxSvm / ATarget.SigmaYGpa;
      YieldEntry.MaterialLabel := ATarget.Name;
      YieldEntry.Ratio := Ratio;
      Result.LayerYieldRatios := [YieldEntry];
      Result.YieldWarning := Ratio > 0.95;
    end;

    Timer.Stop;
    Result.RuntimeS := Timer.Elapsed.TotalSeconds;
  except
    Result.Free;
    raise;
  end;
end;

procedure ComputeHertzBaselines(const ACase: TContactCase;
  out AHertzSubstrate, AHertzTopFilm: TContactResult);
var
  TopMaterial: TMaterial;
begin
  ACase.Validate;
  AHertzSubstrate := nil;
  AHertzTopFilm := nil;
  try
    AHertzSubstrate := SolveHertz(ACase.Ball, ACase.Substrate, ACase.LoadCase, 'hertz_substrate');
    if Length(ACase.Layers) > 0 then
      TopMaterial := ACase.Layers[0].Material
    else
      TopMaterial := ACase.Substrate;
    AHertzTopFilm := SolveHertz(ACase.Ball, TopMaterial, ACase.LoadCase, 'hertz_top_film');
  except
    AHertzTopFilm.Free;
    AHertzSubstrate.Free;
    AHertzTopFilm := nil;
    AHertzSubstrate := nil;
    raise;
  end;
end;

end.
