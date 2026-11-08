USB Relay Controller - Delphi 7

Build
1. Open USBRelayDelphi7.dpr in Delphi 7 and build for Win32.
2. Copy usb_relay_device.dll beside the compiled EXE.
3. If Windows reports a missing runtime, install the Microsoft Visual C++ 2008
   (x86) runtime required by this DLL.
4. Connect the relay board, run the EXE, click "Cari perangkat", and open the
   device. The relay controls shown after opening follow the device channel
   count reported by the DLL.

The supplied DLL is a 32-bit Windows DLL; it must be used with the 32-bit
Delphi 7 application. The declarations in MainUnit.pas follow the function
signatures and status convention used by the supplied GuiApp_English.cpp
example: API operations return 0 on success, and get_status writes the relay
bit mask through its second argument.
