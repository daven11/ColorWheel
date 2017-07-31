program ColorWheelTest;

uses
  Forms,
  Unit60 in 'C:\Users\Contrast\Documents\RAD Studio\Projects\Unit60.pas' {Form60};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm60, Form60);
  Application.Run;
end.
