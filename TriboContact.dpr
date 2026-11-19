program TriboContact;

uses
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
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
  TriboContact.Worker in 'src\gui\TriboContact.Worker.pas',
  TriboContact.LayerDialog in 'src\gui\TriboContact.LayerDialog.pas' {frmLayerDialog},
  TriboContact.MaterialDialog in 'src\gui\TriboContact.MaterialDialog.pas' {frmMaterialDialog},
  TriboContact.MainForm in 'src\gui\TriboContact.MainForm.pas' {frmMain};

{$R *.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows10');
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
