program TriboContactCLI;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TriboContact.Models in 'src\core\TriboContact.Models.pas',
  TriboContact.Materials in 'src\core\TriboContact.Materials.pas',
  TriboContact.Hertz in 'src\core\TriboContact.Hertz.pas',
  TriboContact.SpecialMath in 'src\core\TriboContact.SpecialMath.pas',
  TriboContact.ElasticLayered in 'src\core\TriboContact.ElasticLayered.pas',
  TriboContact.CcxManager in 'src\core\TriboContact.CcxManager.pas',
  TriboContact.FemMesh in 'src\core\TriboContact.FemMesh.pas',
  TriboContact.FemCalculix in 'src\core\TriboContact.FemCalculix.pas',
  TriboContact.Runner in 'src\core\TriboContact.Runner.pas',
  TriboContact.PlotRenderer in 'src\core\TriboContact.PlotRenderer.pas',
  TriboContact.Export in 'src\core\TriboContact.Export.pas',
  TriboContact.CliRunner in 'src\cli\TriboContact.CliRunner.pas';

{$R *.res}

var
  Args: TArray<string>;
  I: Integer;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  SetLength(Args, ParamCount);
  for I := 1 to ParamCount do
    Args[I - 1] := ParamStr(I);

  ExitCode := RunCli(Args,
    procedure(Line: string)
    begin
      Writeln(Line);
    end,
    procedure(ErrLine: string)
    begin
      Writeln(ErrOutput, ErrLine);
    end);
end.
