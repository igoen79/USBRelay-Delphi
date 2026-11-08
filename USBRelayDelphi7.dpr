program USBRelayDelphi7;

uses
  Forms,
  MainUnit in 'MainUnit.pas';

begin
  Application.Initialize;
  Application.Title := 'USB Relay Controller';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
