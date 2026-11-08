unit MainUnit;

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls;

type
  PUsbRelayDeviceInfo = ^TUsbRelayDeviceInfo;
  TUsbRelayDeviceInfo = record
    SerialNumber: PChar;
    DeviceType: Word;
    DeviceNumber: Word;
    Next: PUsbRelayDeviceInfo;
  end;

  TUsbRelayInit = function: Integer; cdecl;
  TUsbRelayExit = function: Integer; cdecl;
  TUsbRelayEnumerate = function: PUsbRelayDeviceInfo; cdecl;
  TUsbRelayFreeEnumerate = procedure(Info: PUsbRelayDeviceInfo); cdecl;
  TUsbRelayOpen = function(Info: PUsbRelayDeviceInfo): Integer; cdecl;
  TUsbRelayClose = function(DeviceHandle: Integer): Integer; cdecl;
  TUsbRelayChannel = function(DeviceHandle: Integer): Integer; cdecl;
  TUsbRelayOneChannel = function(DeviceHandle, Channel: Integer): Integer; cdecl;
  TUsbRelayGetStatus = function(DeviceHandle: Integer;
    Status: PCardinal): Integer; cdecl;

  TMainForm = class(TForm)
  private
    FLibrary: HMODULE;
    FInitialized: Boolean;
    FDeviceHandle: Integer;
    FDeviceChannelCount: Integer;
    FDeviceList: PUsbRelayDeviceInfo;
    FInit: TUsbRelayInit;
    FExit: TUsbRelayExit;
    FEnumerate: TUsbRelayEnumerate;
    FFreeEnumerate: TUsbRelayFreeEnumerate;
    FOpenDevice: TUsbRelayOpen;
    FCloseDevice: TUsbRelayClose;
    FOpenAll: TUsbRelayChannel;
    FCloseAll: TUsbRelayChannel;
    FOpenOne: TUsbRelayOneChannel;
    FCloseOne: TUsbRelayOneChannel;
    FGetStatus: TUsbRelayGetStatus;
    FDevices: TComboBox;
    FConnectButton: TButton;
    FRefreshButton: TButton;
    FOpenAllButton: TButton;
    FCloseAllButton: TButton;
    FRelayName: array[1..8] of TLabel;
    FRelayStatus: array[1..8] of TLabel;
    FRelayOpenButton: array[1..8] of TButton;
    FRelayCloseButton: array[1..8] of TButton;
    FLog: TMemo;
    procedure LoadLibraryFunctions;
    procedure ReleaseLibrary;
    procedure FreeDeviceList;
    procedure RefreshDevices;
    function RefreshStatus: Boolean;
    procedure SetConnected(AConnected: Boolean);
    procedure Log(const Text: string);
    procedure ConnectClick(Sender: TObject);
    procedure RefreshClick(Sender: TObject);
    procedure OpenOneClick(Sender: TObject);
    procedure CloseOneClick(Sender: TObject);
    procedure OpenAllClick(Sender: TObject);
    procedure CloseAllClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation

constructor TMainForm.Create(AOwner: TComponent);
var
  LabelControl: TLabel;
  I, Y: Integer;
begin
  inherited CreateNew(AOwner);

  Caption := 'USB Relay Controller';
  ClientWidth := 390;
  ClientHeight := 465;
  Position := poScreenCenter;
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu, biMinimize];
  OnDestroy := FormDestroy;

  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := Self;
  LabelControl.SetBounds(12, 14, 100, 18);
  LabelControl.Caption := 'Perangkat USB:';

  FDevices := TComboBox.Create(Self);
  FDevices.Parent := Self;
  FDevices.SetBounds(12, 35, 245, 24);
  FDevices.Style := csDropDownList;

  FRefreshButton := TButton.Create(Self);
  FRefreshButton.Parent := Self;
  FRefreshButton.SetBounds(267, 34, 105, 26);
  FRefreshButton.Caption := 'Cari perangkat';
  FRefreshButton.OnClick := RefreshClick;

  FConnectButton := TButton.Create(Self);
  FConnectButton.Parent := Self;
  FConnectButton.SetBounds(12, 69, 105, 27);
  FConnectButton.Caption := 'Buka perangkat';
  FConnectButton.OnClick := ConnectClick;

  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := Self;
  LabelControl.SetBounds(130, 74, 240, 18);
  LabelControl.Caption := 'Hijau = ON, merah = OFF';

  Y := 108;
  for I := 1 to 8 do
  begin
    FRelayName[I] := TLabel.Create(Self);
    FRelayName[I].Parent := Self;
    FRelayName[I].SetBounds(15, Y + 5, 65, 18);
    FRelayName[I].Caption := 'Relay ' + IntToStr(I);

    FRelayOpenButton[I] := TButton.Create(Self);
    FRelayOpenButton[I].Parent := Self;
    FRelayOpenButton[I].SetBounds(92, Y, 75, 25);
    FRelayOpenButton[I].Caption := 'ON';
    FRelayOpenButton[I].Tag := I;
    FRelayOpenButton[I].Enabled := False;
    FRelayOpenButton[I].OnClick := OpenOneClick;

    FRelayStatus[I] := TLabel.Create(Self);
    FRelayStatus[I].Parent := Self;
    FRelayStatus[I].SetBounds(176, Y + 3, 54, 19);
    FRelayStatus[I].Alignment := taCenter;
    FRelayStatus[I].Caption := 'OFF';
    FRelayStatus[I].Font.Color := clMaroon;

    FRelayCloseButton[I] := TButton.Create(Self);
    FRelayCloseButton[I].Parent := Self;
    FRelayCloseButton[I].SetBounds(240, Y, 75, 25);
    FRelayCloseButton[I].Caption := 'OFF';
    FRelayCloseButton[I].Tag := I;
    FRelayCloseButton[I].Enabled := False;
    FRelayCloseButton[I].OnClick := CloseOneClick;

    Y := Y + 30;
  end;

  FOpenAllButton := TButton.Create(Self);
  FOpenAllButton.Parent := Self;
  FOpenAllButton.SetBounds(12, 355, 145, 30);
  FOpenAllButton.Caption := 'Nyalakan semua';
  FOpenAllButton.Enabled := False;
  FOpenAllButton.OnClick := OpenAllClick;

  FCloseAllButton := TButton.Create(Self);
  FCloseAllButton.Parent := Self;
  FCloseAllButton.SetBounds(167, 355, 145, 30);
  FCloseAllButton.Caption := 'Matikan semua';
  FCloseAllButton.Enabled := False;
  FCloseAllButton.OnClick := CloseAllClick;

  FLog := TMemo.Create(Self);
  FLog.Parent := Self;
  FLog.SetBounds(12, 394, 360, 55);
  FLog.ReadOnly := True;
  FLog.ScrollBars := ssVertical;

  FDeviceHandle := 0;
  FDeviceChannelCount := 0;
  FDeviceList := nil;
  LoadLibraryFunctions;
  if FInitialized then
    RefreshDevices;
end;

procedure TMainForm.LoadLibraryFunctions;
begin
  FLibrary := LoadLibrary('usb_relay_device.dll');
  if FLibrary = 0 then
  begin
    Log('DLL tidak ditemukan. Letakkan usb_relay_device.dll di folder EXE.');
    Exit;
  end;

  Pointer(FInit) := GetProcAddress(FLibrary, 'usb_relay_init');
  Pointer(FExit) := GetProcAddress(FLibrary, 'usb_relay_exit');
  Pointer(FEnumerate) := GetProcAddress(FLibrary, 'usb_relay_device_enumerate');
  Pointer(FFreeEnumerate) :=
    GetProcAddress(FLibrary, 'usb_relay_device_free_enumerate');
  Pointer(FOpenDevice) := GetProcAddress(FLibrary, 'usb_relay_device_open');
  Pointer(FCloseDevice) := GetProcAddress(FLibrary, 'usb_relay_device_close');
  Pointer(FOpenAll) :=
    GetProcAddress(FLibrary, 'usb_relay_device_open_all_relay_channel');
  Pointer(FCloseAll) :=
    GetProcAddress(FLibrary, 'usb_relay_device_close_all_relay_channel');
  Pointer(FOpenOne) :=
    GetProcAddress(FLibrary, 'usb_relay_device_open_one_relay_channel');
  Pointer(FCloseOne) :=
    GetProcAddress(FLibrary, 'usb_relay_device_close_one_relay_channel');
  Pointer(FGetStatus) :=
    GetProcAddress(FLibrary, 'usb_relay_device_get_status');

  if (not Assigned(FInit)) or (not Assigned(FExit)) or
     (not Assigned(FEnumerate)) or (not Assigned(FFreeEnumerate)) or
     (not Assigned(FOpenDevice)) or (not Assigned(FCloseDevice)) or
     (not Assigned(FOpenAll)) or (not Assigned(FCloseAll)) or
     (not Assigned(FOpenOne)) or (not Assigned(FCloseOne)) or
     (not Assigned(FGetStatus)) then
  begin
    Log('DLL tidak memiliki ekspor API yang diperlukan.');
    ReleaseLibrary;
    Exit;
  end;

  if FInit() <> 0 then
  begin
    Log('Inisialisasi USB relay gagal.');
    ReleaseLibrary;
    Exit;
  end;

  FInitialized := True;
  Log('DLL USB relay berhasil diinisialisasi.');
end;

procedure TMainForm.ReleaseLibrary;
begin
  if FLibrary <> 0 then
  begin
    FreeLibrary(FLibrary);
    FLibrary := 0;
  end;
end;

procedure TMainForm.FreeDeviceList;
begin
  if (FDeviceList <> nil) and Assigned(FFreeEnumerate) then
  begin
    FFreeEnumerate(FDeviceList);
    FDeviceList := nil;
  end;
end;

procedure TMainForm.RefreshDevices;
var
  Current: PUsbRelayDeviceInfo;
begin
  if not FInitialized then
    Exit;

  FDevices.Items.Clear;
  FreeDeviceList;
  FDeviceList := FEnumerate();
  Current := FDeviceList;
  while Current <> nil do
  begin
    if Current^.SerialNumber <> nil then
      FDevices.Items.AddObject(StrPas(Current^.SerialNumber), TObject(Current));
    Current := Current^.Next;
  end;

  if FDevices.Items.Count > 0 then
  begin
    FDevices.ItemIndex := 0;
    Log(IntToStr(FDevices.Items.Count) + ' perangkat ditemukan.');
  end
  else
    Log('Perangkat USB relay tidak ditemukan.');
end;

function TMainForm.RefreshStatus: Boolean;
var
  Status: Cardinal;
  I: Integer;
begin
  Result := False;
  if FDeviceHandle = 0 then
    Exit;

  Status := 0;
  if FGetStatus(FDeviceHandle, @Status) <> 0 then
  begin
    Log('Gagal membaca status relay.');
    Exit;
  end;

  for I := 1 to 8 do
  begin
    if I <= FDeviceChannelCount then
    begin
      FRelayOpenButton[I].Visible := True;
      FRelayCloseButton[I].Visible := True;
      FRelayStatus[I].Visible := True;
      FRelayName[I].Visible := True;
      FRelayOpenButton[I].Enabled := True;
      FRelayCloseButton[I].Enabled := True;
      if (Status and (Cardinal(1) shl (I - 1))) <> 0 then
      begin
        FRelayStatus[I].Caption := 'ON';
        FRelayStatus[I].Font.Color := clGreen;
      end
      else
      begin
        FRelayStatus[I].Caption := 'OFF';
        FRelayStatus[I].Font.Color := clMaroon;
      end;
    end
    else
    begin
      FRelayOpenButton[I].Visible := False;
      FRelayCloseButton[I].Visible := False;
      FRelayStatus[I].Visible := False;
      FRelayName[I].Visible := False;
      FRelayOpenButton[I].Enabled := False;
      FRelayCloseButton[I].Enabled := False;
    end;
  end;
  Result := True;
end;

procedure TMainForm.SetConnected(AConnected: Boolean);
var
  I: Integer;
begin
  FDevices.Enabled := not AConnected;
  FRefreshButton.Enabled := not AConnected;
  if AConnected then
    FConnectButton.Caption := 'Tutup perangkat'
  else
    FConnectButton.Caption := 'Buka perangkat';
  FOpenAllButton.Enabled := AConnected;
  FCloseAllButton.Enabled := AConnected;
  for I := 1 to 8 do
  begin
    FRelayOpenButton[I].Enabled := AConnected and
      (I <= FDeviceChannelCount);
    FRelayCloseButton[I].Enabled := AConnected and
      (I <= FDeviceChannelCount);
    FRelayOpenButton[I].Visible := not AConnected or
      (I <= FDeviceChannelCount);
    FRelayCloseButton[I].Visible := not AConnected or
      (I <= FDeviceChannelCount);
    FRelayName[I].Visible := not AConnected or
      (I <= FDeviceChannelCount);
    FRelayStatus[I].Visible := not AConnected or
      (I <= FDeviceChannelCount);
    if not AConnected then
    begin
      FRelayStatus[I].Caption := 'OFF';
      FRelayStatus[I].Font.Color := clMaroon;
    end;
  end;
end;

procedure TMainForm.Log(const Text: string);
begin
  if FLog <> nil then
    FLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + Text);
end;

procedure TMainForm.ConnectClick(Sender: TObject);
var
  DeviceInfo: PUsbRelayDeviceInfo;
  DeviceSerial: string;
begin
  if FDeviceHandle <> 0 then
  begin
    if FCloseDevice(FDeviceHandle) = 0 then
      Log('Perangkat ditutup.')
    else
      Log('DLL melaporkan kegagalan saat menutup perangkat.');
    FDeviceHandle := 0;
    FDeviceChannelCount := 0;
    SetConnected(False);
    Exit;
  end;

  if FDevices.ItemIndex < 0 then
  begin
    Log('Pilih perangkat terlebih dahulu.');
    Exit;
  end;

  DeviceInfo := PUsbRelayDeviceInfo(
    FDevices.Items.Objects[FDevices.ItemIndex]);
  DeviceSerial := FDevices.Items[FDevices.ItemIndex];
  FDeviceHandle := FOpenDevice(DeviceInfo);
  if FDeviceHandle = 0 then
  begin
    Log('Gagal membuka perangkat ' + DeviceSerial + '.');
    Exit;
  end;

  FDeviceChannelCount := DeviceInfo^.DeviceType;
  if FDeviceChannelCount > 8 then
    FDeviceChannelCount := 8;
  SetConnected(True);
  if not RefreshStatus then
  begin
    FCloseDevice(FDeviceHandle);
    FDeviceHandle := 0;
    FDeviceChannelCount := 0;
    SetConnected(False);
    Log('Pembacaan status gagal; koneksi perangkat dibatalkan.');
    Exit;
  end;
  Log('Terhubung ke perangkat ' + DeviceSerial + '.');
end;

procedure TMainForm.RefreshClick(Sender: TObject);
begin
  RefreshDevices;
end;

procedure TMainForm.OpenOneClick(Sender: TObject);
var
  Channel: Integer;
begin
  Channel := TButton(Sender).Tag;
  if FOpenOne(FDeviceHandle, Channel) = 0 then
  begin
    Log('Relay ' + IntToStr(Channel) + ' dinyalakan.');
    RefreshStatus;
  end
  else
    Log('Gagal menyalakan relay ' + IntToStr(Channel) + '.');
end;

procedure TMainForm.CloseOneClick(Sender: TObject);
var
  Channel: Integer;
begin
  Channel := TButton(Sender).Tag;
  if FCloseOne(FDeviceHandle, Channel) = 0 then
  begin
    Log('Relay ' + IntToStr(Channel) + ' dimatikan.');
    RefreshStatus;
  end
  else
    Log('Gagal mematikan relay ' + IntToStr(Channel) + '.');
end;

procedure TMainForm.OpenAllClick(Sender: TObject);
begin
  if FOpenAll(FDeviceHandle) = 0 then
  begin
    Log('Semua relay dinyalakan.');
    RefreshStatus;
  end
  else
    Log('Gagal menyalakan semua relay.');
end;

procedure TMainForm.CloseAllClick(Sender: TObject);
begin
  if FCloseAll(FDeviceHandle) = 0 then
  begin
    Log('Semua relay dimatikan.');
    RefreshStatus;
  end
  else
    Log('Gagal mematikan semua relay.');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if FDeviceHandle <> 0 then
  begin
    FCloseDevice(FDeviceHandle);
    FDeviceHandle := 0;
  end;
  FreeDeviceList;
  if FInitialized then
  begin
    FExit();
    FInitialized := False;
  end;
  ReleaseLibrary;
end;

end.
