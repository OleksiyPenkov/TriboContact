unit TriboContact.SpecialMath;

interface

uses
  System.SysUtils, System.Math, TriboContact.Models;

procedure EllipKE(AM: Double; out AK, AE: Double);
function EllipK(AM: Double): Double;
function EllipE(AM: Double): Double;
function EllipE_Minus_OneMinusMK(AM: Double): Double;
function EllipK_Minus_E(AM: Double): Double;

procedure BesselJ012(AX: Double; out AJ0, AJ1, AJ2: Double);
function BesselJ0(AX: Double): Double;
function BesselJ1(AX: Double): Double;
function BesselJ2(AX: Double): Double;
function BesselJ1OverX(AX: Double): Double;

procedure GaussLegendreRule(AN: Integer; out ANodes, AWeights: TDoubleArray);
function OneMinusExpNeg(AX: Double): Double;

implementation

uses
  System.Generics.Collections;

type
  TGLRuleCacheEntry = record
    Nodes: TDoubleArray;
    Weights: TDoubleArray;
  end;

var
  GGLCache: TDictionary<Integer, TGLRuleCacheEntry>;

procedure EllipKE(AM: Double; out AK, AE: Double);
var
  A, B, ANext, BNext, C, Sum, Pow2: Double;
  Iter: Integer;
begin
  if AM <= 0.0 then
  begin
    AK := 0.5 * Pi;
    AE := 0.5 * Pi;
    Exit;
  end;
  if AM >= 1.0 then
  begin
    if AM = 1.0 then
    begin
      AK := Infinity;
      AE := 1.0;
      Exit;
    end;
    raise EArgumentException.CreateFmt('EllipKE argument m must be in [0, 1): %g', [AM]);
  end;

  A := 1.0;
  B := Sqrt(1.0 - AM);
  Sum := 0.5 * AM;
  Pow2 := 1.0;
  for Iter := 1 to 32 do
  begin
    ANext := 0.5 * (A + B);
    BNext := Sqrt(A * B);
    C := 0.5 * (A - B);
    Sum := Sum + Pow2 * C * C;
    Pow2 := 2.0 * Pow2;
    A := ANext;
    B := BNext;
    if Abs(A - B) <= 1e-15 * A then
      Break;
  end;
  AK := 0.5 * Pi / A;
  AE := AK * (1.0 - Sum);
end;

function EllipK(AM: Double): Double;
var
  E: Double;
begin
  EllipKE(AM, Result, E);
end;

function EllipE(AM: Double): Double;
var
  K: Double;
begin
  EllipKE(AM, K, Result);
end;

function EllipE_Minus_OneMinusMK(AM: Double): Double;
var
  K, E: Double;
begin
  if AM < 1e-4 then
  begin
    Result := (0.5 * Pi) * AM * (0.5 + AM * (1.0 / 16.0 +
      AM * (3.0 / 128.0 + AM * (25.0 / 2048.0 + AM * (245.0 / 32768.0)))));
    Exit;
  end;
  EllipKE(AM, K, E);
  Result := E - (1.0 - AM) * K;
end;

function EllipK_Minus_E(AM: Double): Double;
var
  K, E: Double;
begin
  if AM < 1e-4 then
  begin
    Result := (0.5 * Pi) * AM * (0.5 + AM * (3.0 / 16.0 +
      AM * (15.0 / 128.0 + AM * (175.0 / 2048.0 + AM * (2205.0 / 32768.0)))));
    Exit;
  end;
  EllipKE(AM, K, E);
  Result := K - E;
end;

function BesselAsymptotic(ANu: Integer; AX: Double): Double;
var
  Mu4, Term, P, Q, Chi, SignP, SignQ: Double;
  M: Integer;
begin
  Mu4 := 4.0 * ANu * ANu;
  Term := 1.0;
  P := 1.0;
  Q := 0.0;
  SignP := -1.0;
  SignQ := 1.0;
  for M := 1 to 24 do
  begin
    Term := Term * (Mu4 - Sqr(2 * M - 1)) / (8.0 * M * AX);
    if Odd(M) then
    begin
      Q := Q + SignQ * Term;
      SignQ := -SignQ;
    end
    else
    begin
      P := P + SignP * Term;
      SignP := -SignP;
    end;
    if Abs(Term) < 1e-16 then
      Break;
  end;
  Chi := AX - (0.5 * ANu + 0.25) * Pi;
  Result := Sqrt(2.0 / (Pi * AX)) * (P * Cos(Chi) - Q * Sin(Chi));
end;

procedure BesselJ012(AX: Double; out AJ0, AJ1, AJ2: Double);
var
  X, X2, YPrev, YCurr, YNext, Norm, Y0, Y1, Y2: Double;
  N, K: Integer;
  NegSign: Boolean;
begin
  if AX < 0.0 then
  begin
    X := -AX;
    NegSign := True;
  end
  else
  begin
    X := AX;
    NegSign := False;
  end;

  if X < 1e-8 then
  begin
    X2 := X * X;
    AJ0 := 1.0 - 0.25 * X2 + (1.0 / 64.0) * X2 * X2;
    AJ1 := 0.5 * X * (1.0 - 0.125 * X2);
    AJ2 := 0.125 * X2 * (1.0 - (1.0 / 12.0) * X2);
  end
  else if X <= 20.0 then
  begin
    N := Ceil(X) + 54;
    if Odd(N) then
      Inc(N);
    YNext := 0.0;
    YCurr := 1e-250;
    Y0 := 0.0;
    Y1 := 0.0;
    Y2 := 0.0;
    Norm := 0.0;

    for K := N downto 1 do
    begin
      YPrev := (2.0 * K / X) * YCurr - YNext;
      YNext := YCurr;
      YCurr := YPrev;
      if K = 3 then
        Y2 := YPrev
      else if K = 2 then
        Y1 := YPrev
      else if K = 1 then
        Y0 := YPrev;

      if ((K - 1) > 0) and not Odd(K - 1) then
        Norm := Norm + 2.0 * YPrev;

      if Abs(YCurr) > 1e150 then
      begin
        YCurr := YCurr * 1e-150;
        YNext := YNext * 1e-150;
        Y2 := Y2 * 1e-150;
        Y1 := Y1 * 1e-150;
        Y0 := Y0 * 1e-150;
        Norm := Norm * 1e-150;
      end;
    end;
    Norm := Norm + Y0;
    AJ0 := Y0 / Norm;
    AJ1 := Y1 / Norm;
    AJ2 := Y2 / Norm;
  end
  else
  begin
    AJ0 := BesselAsymptotic(0, X);
    AJ1 := BesselAsymptotic(1, X);
    AJ2 := (2.0 / X) * AJ1 - AJ0;
  end;

  if NegSign then
    AJ1 := -AJ1;
end;

function BesselJ0(AX: Double): Double;
var
  J1, J2: Double;
begin
  BesselJ012(AX, Result, J1, J2);
end;

function BesselJ1(AX: Double): Double;
var
  J0, J2: Double;
begin
  BesselJ012(AX, J0, Result, J2);
end;

function BesselJ2(AX: Double): Double;
var
  J0, J1: Double;
begin
  BesselJ012(AX, J0, J1, Result);
end;

function BesselJ1OverX(AX: Double): Double;
var
  J0, J1, J2: Double;
begin
  if Abs(AX) < 1e-8 then
    Result := 0.5 - (1.0 / 16.0) * AX * AX
  else
  begin
    BesselJ012(AX, J0, J1, J2);
    Result := J1 / AX;
  end;
end;

procedure GaussLegendreRule(AN: Integer; out ANodes, AWeights: TDoubleArray);
var
  Entry: TGLRuleCacheEntry;
  M, I, J, Iter: Integer;
  Z, Z1, P1, P2, P3, PP: Double;
begin
  if AN < 1 then
    raise EArgumentException.Create('Gauss-Legendre order must be >= 1');

  if GGLCache.TryGetValue(AN, Entry) then
  begin
    ANodes := Entry.Nodes;
    AWeights := Entry.Weights;
    Exit;
  end;

  SetLength(Entry.Nodes, AN);
  SetLength(Entry.Weights, AN);
  M := (AN + 1) div 2;
  for I := 0 to M - 1 do
  begin
    Z := Cos(Pi * (I + 0.75) / (AN + 0.5));
    for Iter := 1 to 40 do
    begin
      P1 := 1.0;
      P2 := 0.0;
      for J := 1 to AN do
      begin
        P3 := P2;
        P2 := P1;
        P1 := ((2.0 * J - 1.0) * Z * P2 - (J - 1.0) * P3) / J;
      end;
      PP := AN * (Z * P1 - P2) / (Z * Z - 1.0);
      Z1 := Z;
      Z := Z1 - P1 / PP;
      if Abs(Z - Z1) <= 1e-15 then
        Break;
    end;
    Entry.Nodes[I] := -Z;
    Entry.Nodes[AN - 1 - I] := Z;
    Entry.Weights[I] := 2.0 / ((1.0 - Z * Z) * PP * PP);
    Entry.Weights[AN - 1 - I] := Entry.Weights[I];
  end;

  GGLCache.AddOrSetValue(AN, Entry);
  ANodes := Entry.Nodes;
  AWeights := Entry.Weights;
end;

function OneMinusExpNeg(AX: Double): Double;
begin
  if Abs(AX) < 1e-3 then
    Result := AX * (1.0 - AX * (0.5 - AX * ((1.0 / 6.0) -
      AX * ((1.0 / 24.0) - AX * ((1.0 / 120.0) - AX / 720.0)))))
  else
    Result := 1.0 - Exp(-AX);
end;

initialization
  GGLCache := TDictionary<Integer, TGLRuleCacheEntry>.Create;

finalization
  GGLCache.Free;

end.
