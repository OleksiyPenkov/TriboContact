program TriboContactTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  TriboContact.Models in '..\src\core\TriboContact.Models.pas',
  TriboContact.Materials in '..\src\core\TriboContact.Materials.pas',
  TriboContact.Hertz in '..\src\core\TriboContact.Hertz.pas',
  TriboContact.SpecialMath in '..\src\core\TriboContact.SpecialMath.pas',
  TriboContact.ElasticLayered in '..\src\core\TriboContact.ElasticLayered.pas',
  TriboContact.CcxManager in '..\src\core\TriboContact.CcxManager.pas',
  TriboContact.FemMesh in '..\src\core\TriboContact.FemMesh.pas',
  TriboContact.FemCalculix in '..\src\core\TriboContact.FemCalculix.pas',
  TriboContact.Runner in '..\src\core\TriboContact.Runner.pas',
  TriboContact.PlotRenderer in '..\src\core\TriboContact.PlotRenderer.pas',
  TriboContact.Export in '..\src\core\TriboContact.Export.pas',
  TriboContact.CliRunner in '..\src\cli\TriboContact.CliRunner.pas',
  TriboContact.Worker in '..\src\gui\TriboContact.Worker.pas',
  TriboContact.LayerDialog in '..\src\gui\TriboContact.LayerDialog.pas' {frmLayerDialog},
  TriboContact.MaterialDialog in '..\src\gui\TriboContact.MaterialDialog.pas' {frmMaterialDialog},
  TriboContact.MainForm in '..\src\gui\TriboContact.MainForm.pas' {frmMain},
  Test.ModelsHertz in 'Test.ModelsHertz.pas',
  Test.ElasticNormal in 'Test.ElasticNormal.pas',
  Test.ElasticSliding in 'Test.ElasticSliding.pas',
  Test.FemMesh in 'Test.FemMesh.pas',
  Test.FemCalculix in 'Test.FemCalculix.pas',
  Test.VVBenchmarks in 'Test.VVBenchmarks.pas',
  Test.CliGui in 'Test.CliGui.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  try
    {$IFDEF TESTINSIGHT}
    TestInsight.DUnitX.RunRegisteredTests;
    Exit;
    {$ENDIF}
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.FailsOnNoAsserts := False;

    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);

    Results := Runner.Execute;
    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_ERRORS;
    end;
  end;
end.
