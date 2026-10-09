@echo off
setlocal enabledelayedexpansion
title WUControl v2.8 (Extended) - r3ndy.com
color 0A

:: =====================================================
:: Atur ukuran jendela
:: =====================================================
mode con: cols=74 lines=27 >nul 2>&1

:: =====================================================
:: Jalankan sebagai Administrator
:: =====================================================
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: =====================================================
:: Direktori permanen script
:: =====================================================
set "SCRIPT_DIR=C:\Windows\scripts"
set "SCRIPT_FILE=%SCRIPT_DIR%\WUControl.bat"
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%" 2>nul
copy "%~f0" "%SCRIPT_FILE%" /Y >nul 2>&1

:: =====================================================
:: Deteksi OS, arsitektur, build, UBR
:: =====================================================
for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"') do set "OSCaption=%%a"
set "OSArch=32-bit"
if defined ProgramFiles(x86) set "OSArch=64-bit"

for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do set "Build=%%a"
if not defined Build set "Build=19041"

for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR 2^>nul') do set "UBR=%%a"
if not defined UBR set "UBR=0"

set "UBRDec=%UBR%"
echo %UBR% | find "0x" >nul
if %ERRORLEVEL%==0 (
    for /f %%i in ('powershell -NoProfile -Command "[convert]::ToInt32('%UBR%',16)"') do set "UBRDec=%%i"
)
set "OSBuild=%Build%.%UBRDec%"

:: =====================================================
:: Deteksi LTSC / IoT
:: =====================================================
set "OSMode=Non-LTSC"
echo %OSCaption% | findstr /i "LTSC" >nul && set "OSMode=LTSC / IoT"
echo %OSCaption% | findstr /i "IoT" >nul && set "OSMode=LTSC / IoT"

:: =====================================================
:: Jika dipanggil dari Klik Kanan Task Scheduler
:: Arg 1=OFF, Arg2=ON
:: =====================================================
if "%~1"=="1" (
    if /i "%OSMode%"=="LTSC / IoT" goto OFF_TOTAL_QUICK
    goto OFF_QUICK
)
if "%~1"=="2" (
    if /i "%OSMode%"=="LTSC / IoT" goto RESTORE_TOTAL_QUICK
    goto ON_QUICK
)

:: =====================================================
:MENU
cls
:: Deteksi status Windows Update
set "WU_STATUS=OFF"
sc query wuauserv | find /i "RUNNING" >nul && set "WU_STATUS=ON"
if /i "%WU_STATUS%"=="ON" (color 2F) else (color 4F)

:: Header
echo ======================================================
echo        Windows Update Control v2.8 (Extended)
echo ======================================================
echo Nama OS         : %OSCaption%
echo Arsitektur      : %OSArch%
echo OS Build        : %OSBuild%
echo Mode Terdeteksi : %OSMode%
echo Status Update   : %WU_STATUS%
echo ======================================================
echo.
echo [1] Matikan Windows Update    (Non-LTSC)
echo [2] Hidupkan Windows Update   (Non-LTSC)
echo [3] Matikan Windows Update    (LTSC/IoT)
echo [4] Hidupkan Windows Update   (LTSC/IoT)
echo ------------------------------------------------------
echo [5] Pasang Klik Kanan Desktop (Non-LTSC)
echo [6] Pasang Klik Kanan Desktop (LTSC/IoT)

echo [8] Hapus Klik Kanan Desktop  (LTSC/IoT)
echo ------------------------------------------------------
echo [9] Hapus semua WUControl     (Full Uninstall)
echo [0] Cek Pembaruan             (Repair/Updates)
echo [x] Keluar
echo ======================================================
echo.
set /p "menu=Pilih menu (0-9): "

:: =====================================================
:: Normal Menu Mapping
:: =====================================================
if "%menu%"=="x" (
    cls
    color 0F
    echo =====================================================
    echo   Terima kasih telah menggunakan WUControl by R3NDY
    echo =====================================================
    echo.
    timeout /t 3 >nul
    echo Membuka halaman dukungan...
    timeout /t 5 >nul
    start https://www.r3ndy.com/donasi
    exit
)
if "%menu%"=="1" if /i "%OSMode%"=="Non-LTSC" goto OFF
if "%menu%"=="2" if /i "%OSMode%"=="Non-LTSC" goto ON
if "%menu%"=="3" if /i "%OSMode%"=="LTSC / IoT" goto OFF_TOTAL
if "%menu%"=="4" if /i "%OSMode%"=="LTSC / IoT" goto RESTORE_TOTAL
if "%menu%"=="5" if /i "%OSMode%"=="Non-LTSC" goto INSTALL_CONTEXT
if "%menu%"=="6" if /i "%OSMode%"=="LTSC / IoT" goto INSTALL_CONTEXT_LTSC

if "%menu%"=="8" if /i "%OSMode%"=="LTSC / IoT" goto REMOVE_CONTEXT_LTSC
if "%menu%"=="9" goto UNINSTALL
if "%menu%"=="0" goto MENU_CHECK_UPDATE
echo.
echo [PERINGATAN] Menu ini tidak tersedia untuk mode %OSMode%.
timeout /t 5 >nul
goto MENU

:: =====================================================
:: MENU 1 - OFF (Non-LTSC)
:: =====================================================
:OFF
color 4F
echo Menonaktifkan Windows Update...

:: ===== Hentikan layanan terkait =====
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop UsoSvc >nul 2>&1
net stop WaaSMedicSvc >nul 2>&1

:: ===== Reset ACL agar bisa diubah =====
sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset UsoSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset WaaSMedicSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1

:: ===== Nonaktifkan layanan =====
sc config wuauserv start= disabled >nul
sc config bits start= disabled >nul
sc config UsoSvc start= disabled >nul
sc config WaaSMedicSvc start= disabled >nul

:: ===== Kunci Registry WaaSMedicSvc agar tidak Auto-Start =====
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v FailureActions /t REG_BINARY /d 00000000000000000000000003000000140000000000000000000000000000000000000000000000 /f >nul 2>&1

:: ===== Kunci Izin Layanan (Deny Change Config) =====
sc sdset wuauserv D:(D;;CR;;;IU)(D;;CR;;;SU)(A;;CCLCSWLOCRRC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA) >nul 2>&1
sc sdset UsoSvc D:(D;;CR;;;IU)(D;;CR;;;SU)(A;;CCLCSWLOCRRC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA) >nul 2>&1
sc sdset WaaSMedicSvc D:(D;;CR;;;IU)(D;;CR;;;SU)(A;;CCLCSWLOCRRC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA) >nul 2>&1

:: ===== Blok upgrade & Otomatisasi Update =====
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableOSUpgrade /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f >nul

:: ===== Deteksi versi Windows =====
for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"') do set "OSCaption=%%a"

for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion"') do set "DisplayVer=%%a"
if "%DisplayVer%"=="" set "DisplayVer=Unknown"

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersion /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersionInfo /t REG_SZ /d "%DisplayVer%" /f >nul

echo.
echo [OK] Windows Update berhasil dimatikan permanen.
echo [INFO] Versi Windows terkunci di: %DisplayVer%
echo [NAMA OS] %OSCaption%
echo [INFO] Pembaruan versi terbaru tidak akan diinstal otomatis.
timeout /t 5 >nul
if "%~1"=="quick" exit /b
goto MENU

:: =====================================================
:: MENU 2 - ON (Non-LTSC)
:: =====================================================
:ON
color 2F
echo Mengaktifkan Windows Update...

:: ===== Restore Izin Layanan (ACL Original) =====
sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset UsoSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset WaaSMedicSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1

:: ===== Aktifkan kembali layanan terkait =====
sc config wuauserv start= auto >nul
sc config bits start= auto >nul
sc config UsoSvc start= demand >nul
sc config WaaSMedicSvc start= demand >nul

net start wuauserv >nul 2>&1
net start bits >nul 2>&1

:: ===== Izinkan upgrade antar versi =====
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f >nul 2>&1

echo [OK] Windows Update berhasil diaktifkan permanen.
echo [INFO] Pembaruan fitur kini diizinkan kembali.
timeout /t 5 >nul
if "%~1"=="quick" exit /b
goto MENU

:: =====================================================
:: MENU 3 - OFF_TOTAL (LTSC/IoT)
:: =====================================================
:OFF_TOTAL
color 4F
echo [INFO] Menonaktifkan layanan Windows Update (LTSC/IoT - OFF Total)...
net stop wuauserv >nul 2>&1
net stop usosvc >nul 2>&1
net stop WaaSMedicSvc >nul 2>&1
net stop bits >nul 2>&1

echo [INFO] Menerapkan penguncian izin layanan...
:: Reset ACL ke standar dulu agar perubahan sc config diterima
sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset UsoSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset WaaSMedicSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1

echo [INFO] Menonaktifkan layanan services...
sc config wuauserv start= disabled >nul
sc config usosvc start= disabled >nul
sc config WaaSMedicSvc start= disabled >nul
sc config bits start= disabled >nul

:: Kunci Registry WaaSMedicSvc
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v FailureActions /t REG_BINARY /d 00000000000000000000000003000000140000000000000000000000000000000000000000000000 /f >nul 2>&1

:: Kunci Izin Layanan agar tidak dapat dimodifikasi oleh sistem
sc sdset wuauserv D:(D;;CR;;;IU)(D;;CR;;;SU)(A;;CCLCSWLOCRRC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA) >nul 2>&1
sc sdset UsoSvc D:(D;;CR;;;IU)(D;;CR;;;SU)(A;;CCLCSWLOCRRC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA) >nul 2>&1
sc sdset WaaSMedicSvc D:(D;;CR;;;IU)(D;;CR;;;SU)(A;;CCLCSWLOCRRC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA) >nul 2>&1

echo [INFO] Menerapkan Kebijakan Group Policy...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f >nul

echo [INFO] Menerapkan blokir firewall untuk server pembaruan...
netsh advfirewall firewall add rule name="Block Windows Update" dir=out action=block remoteip=13.107.4.50,13.107.5.50,20.190.160.0/20,40.126.32.0/20 enable=yes >nul 2>&1

echo [INFO] Menonaktifkan tugas terjadwal...
schtasks /Change /TN "Microsoft\Windows\UpdateOrchestrator\Schedule Scan" /Disable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WindowsUpdate\Scheduled Start" /Disable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WaaSMedic\PerformRemediation" /Disable >nul 2>&1

echo [OK] Windows Update berhasil dinonaktifkan.
echo [INFO] Pembaruan dihentikan hingga diaktifkan kembali.
timeout /t 5 >nul
if "%~1"=="quick" exit /b
goto MENU

:: =====================================================
:: MENU 4 - RESTORE_TOTAL (LTSC/IoT)
:: =====================================================
:RESTORE_TOTAL
color 2F
echo [INFO] Mengembalikan semua fungsi Update (LTSC/IoT)...

:: Restore Izin Layanan
sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset UsoSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset WaaSMedicSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1

sc config wuauserv start= demand >nul
sc config usosvc start= demand >nul
sc config WaaSMedicSvc start= demand >nul
sc config bits start= demand >nul

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f >nul 2>&1

net start wuauserv >nul 2>&1
net start usosvc >nul 2>&1

echo [INFO] Menghapus aturan firewall...
netsh advfirewall firewall delete rule name="Block Windows Update" >nul 2>&1

echo [INFO] Mengaktifkan tugas terjadwal...
schtasks /Change /TN "Microsoft\Windows\UpdateOrchestrator\Schedule Scan" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WindowsUpdate\Scheduled Start" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WaaSMedic\PerformRemediation" /Enable >nul 2>&1

echo.
echo [OK] Windows Update berhasil dipulihkan.
timeout /t 5 >nul
if "%~1"=="quick" exit /b
goto MENU

:: =====================================================
:: MENU 5 - INSTALL_CONTEXT (Klik Kanan Non-LTSC)
:: =====================================================
:INSTALL_CONTEXT
cls
echo Memasang Klik Kanan Desktop (Non-LTSC - Bypass UAC)...
echo.

set "SCRIPT_DIR=C:\Windows\scripts"
set "SCRIPT_FILE=%SCRIPT_DIR%\WUControl.bat"
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"
copy "%~f0" "%SCRIPT_FILE%" /Y >nul

schtasks /delete /tn "WUControl_OFF" /f >nul 2>&1
schtasks /delete /tn "WUControl_ON" /f >nul 2>&1

schtasks /create /tn "WUControl_OFF" /tr "\"%SCRIPT_FILE%\" 1" /sc once /st 00:00 /rl highest /f >nul
schtasks /create /tn "WUControl_ON"  /tr "\"%SCRIPT_FILE%\" 2" /sc once /st 00:00 /rl highest /f >nul

reg add "HKCR\Directory\Background\shell\WindowsUpdateOFF" /v "" /d "Windows Update OFF" /f >nul
reg add "HKCR\Directory\Background\shell\WindowsUpdateOFF\command" /v "" /d "schtasks /run /tn WUControl_OFF" /f >nul

reg add "HKCR\Directory\Background\shell\WindowsUpdateON" /v "" /d "Windows Update ON" /f >nul
reg add "HKCR\Directory\Background\shell\WindowsUpdateON\command" /v "" /d "schtasks /run /tn WUControl_ON" /f >nul

echo Klik kanan desktop berhasil dipasang!
echo (Windows Update OFF/ON dapat dijalankan langsung tanpa membuka menu)
timeout /t 5 >nul
exit /b

:: =====================================================
:: MENU 6 - INSTALL_CONTEXT_LTSC (Klik Kanan LTSC/IoT)
:: =====================================================
:INSTALL_CONTEXT_LTSC
cls
echo Memasang Klik Kanan Desktop (LTSC/IoT - Bypass UAC)...
echo.

if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%" 2>nul
copy "%~f0" "%SCRIPT_FILE%" /Y >nul

schtasks /delete /tn "WUControl_OFF" /f >nul 2>&1
schtasks /delete /tn "WUControl_ON" /f >nul 2>&1

schtasks /create /tn "WUControl_OFF" /tr "\"%SCRIPT_FILE%\" 1" /sc once /st 00:00 /rl highest /f >nul 2>&1
schtasks /create /tn "WUControl_ON"  /tr "\"%SCRIPT_FILE%\" 2" /sc once /st 00:00 /rl highest /f >nul 2>&1

reg add "HKCR\Directory\Background\shell\WindowsUpdateOFF" /v "" /d "Windows Update OFF" /f >nul
reg add "HKCR\Directory\Background\shell\WindowsUpdateOFF\command" /v "" /d "schtasks /run /tn WUControl_OFF" /f >nul
reg add "HKCR\Directory\Background\shell\WindowsUpdateON" /v "" /d "Windows Update ON" /f >nul
reg add "HKCR\Directory\Background\shell\WindowsUpdateON\command" /v "" /d "schtasks /run /tn WUControl_ON" /f >nul

echo Klik kanan desktop LTSC/IoT berhasil dipasang!
echo (Windows Update OFF/ON dapat dijalankan langsung tanpa membuka menu)
timeout /t 5 >nul
exit /b

:: =====================================================
:: MENU 8 - REMOVE_CONTEXT_LTSC
:: =====================================================
:REMOVE_CONTEXT_LTSC
cls
echo Menghapus Klik Kanan Desktop (LTSC/IoT)...
reg delete "HKCR\Directory\Background\shell\WindowsUpdateOFF" /f >nul
reg delete "HKCR\Directory\Background\shell\WindowsUpdateON" /f >nul
schtasks /delete /tn "WUControl_OFF" /f >nul 2>&1
schtasks /delete /tn "WUControl_ON" /f >nul 2>&1
timeout /t 5 >nul
exit /b

:: =====================================================
:: MENU 9 - UNINSTALL FULL (Restore Windows Update)
:: =====================================================
:UNINSTALL
cls
color 0F
echo.
echo =====================================================
echo  Menghapus semua WUControl (Full) dan memulihkan
echo  layanan Windows Update ke kondisi awal sistem.
echo =====================================================
echo.
echo Nama OS     : %OSCaption%
echo Arsitektur  : %OSArch%
echo Build       : %OSBuild%
echo.

echo [INFO] Mendeteksi jenis edisi Windows...
echo %OSCaption% | find /I "LTSC" >nul
if %errorlevel%==0 (
    call :UNINSTALL_LTSC
) else (
    call :UNINSTALL_NONLTSC
)
goto :EOF


:: =====================================================
:: UNINSTALL untuk Windows Non-LTSC
:: =====================================================
:UNINSTALL_NONLTSC
echo [INFO] Mode Non-LTSC terdeteksi, memulihkan layanan default...

sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset UsoSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset WaaSMedicSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1

sc config wuauserv start= auto >nul 2>&1
sc config bits start= auto >nul 2>&1
sc config usosvc start= demand >nul 2>&1
sc config WaaSMedicSvc start= demand >nul 2>&1

net start wuauserv >nul 2>&1
net start bits >nul 2>&1
net start usosvc >nul 2>&1
net start WaaSMedicSvc >nul 2>&1

call :COMMON_RESTORE
goto :EOF


:: =====================================================
:: UNINSTALL untuk Windows LTSC / IoT
:: =====================================================
:UNINSTALL_LTSC
echo [INFO] Mode LTSC/IoT terdeteksi, memulihkan layanan dengan mode demand...

sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset UsoSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1
sc sdset WaaSMedicSvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU) >nul 2>&1

sc config wuauserv start= demand >nul 2>&1
sc config bits start= demand >nul 2>&1
sc config usosvc start= demand >nul 2>&1
sc config WaaSMedicSvc start= demand >nul 2>&1

net start wuauserv >nul 2>&1
net start bits >nul 2>&1
net start usosvc >nul 2>&1
net start WaaSMedicSvc >nul 2>&1

call :COMMON_RESTORE
goto :EOF


:: =====================================================
:: FUNGSI UMUM: Restore Registry, Task, Context Menu, Cache
:: =====================================================
:COMMON_RESTORE
echo [INFO] Menghapus aturan firewall...
netsh advfirewall firewall delete rule name="Block Windows Update" >nul 2>&1

echo [INFO] Menghapus konfigurasi kebijakan Windows Update...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableOSUpgrade /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersion /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersionInfo /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1

echo [INFO] Memulihkan Task Scheduler...
schtasks /delete /tn "WUControl_OFF" /f >nul 2>&1
schtasks /delete /tn "WUControl_ON" /f >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\UpdateOrchestrator\Schedule Scan" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WindowsUpdate\Scheduled Start" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WaaSMedic\PerformRemediation" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\Servicing\StartComponentCleanup" /Enable >nul 2>&1

echo [INFO] Menghapus menu klik kanan WUControl...
reg delete "HKCR\Directory\Background\shell\WindowsUpdateOFF" /f >nul 2>&1
reg delete "HKCR\Directory\Background\shell\WindowsUpdateON" /f >nul 2>&1
reg delete "HKCR\Directory\Background\shell\WUControl" /f >nul 2>&1

echo [INFO] Membersihkan cache pembaruan...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
rmdir /s /q "%windir%\SoftwareDistribution" >nul 2>&1
rmdir /s /q "%windir%\System32\catroot2" >nul 2>&1
net start wuauserv >nul 2>&1
net start bits >nul 2>&1

echo [INFO] Menghapus file WUControl utama (jika tidak aktif)...
set "TARGET_FILE=C:\Windows\scripts\WUControl.bat"
if exist "%TARGET_FILE%" (
    if /I "%~f0"=="%TARGET_FILE%" (
        echo [SKIP] File ini sedang aktif, tidak dihapus.
    ) else (
        del /f /q "%TARGET_FILE%" >nul 2>&1
        echo [OK] File WUControl.bat telah dihapus.
    )
)

echo.
echo [OK] Windows Update telah dipulihkan sepenuhnya.
echo.
pause
goto MENU

:: =====================================================
:: MENU 0 - CEK PEMBARUAN (Universal)
:: =====================================================
:MENU_CHECK_UPDATE
cls
color 0F
echo =====================================================
echo              [CEK PEMBARUAN / REPAIR]
echo =====================================================
echo.

set "THIS_CMD=%~f0"
set "TMP_NAME=WUControl"
set "REMOTE_NAME=%TMP_NAME%.bat"
set "REMOTE_BASE=%TMP_NAME%"
set "TMP_DL=%TEMP%\%REMOTE_BASE%_update.tmp"
set "REPL_BAT=%TEMP%\replace_%REMOTE_BASE%_%RANDOM%.bat"

echo [INFO] Memeriksa koneksi internet...
powershell -NoProfile -Command ^
  "$r=$false;try{$r=(iwr 'https://www.google.com' -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200}catch{};if($r){exit 0}else{exit 1}"

if errorlevel 1 (
    color 0C
    echo [ERROR] Tidak ada koneksi internet.
    echo Pastikan koneksi aktif, lalu coba lagi.
    pause
    goto MENU
) else (
    echo [OK] Terhubung ke internet.
)

set "REMOTE_MD5_URL=https://raw.githubusercontent.com/r3ndycom/wucontrol/main/%REMOTE_BASE%.md5"
set "REMOTE_FILE_URL=https://raw.githubusercontent.com/r3ndycom/wucontrol/main/%REMOTE_NAME%"

echo [INFO] Mengambil hash MD5 versi terbaru dari server...
set "REMOTE_MD5="
for /f "delims=" %%A in ('
    powershell -NoProfile -Command ^
    "$ErrorActionPreference='SilentlyContinue';" ^
    "try {" ^
    "  $resp = Invoke-RestMethod -Uri '%REMOTE_MD5_URL%' -UseBasicParsing;" ^
    "  if ($resp) { $resp.Trim() } else { '' }" ^
    "} catch {" ^
    "  Write-Host '[PS ERROR] ' + $_.Exception.Message;" ^
    "  ''" ^
    "}"
') do (
    echo %%A | findstr /i "[PS ERROR]" >nul
    if errorlevel 1 (set "REMOTE_MD5=%%A") else (echo %%A)
)

if "%REMOTE_MD5%"=="" (
    color 0C
    echo [ERROR] Gagal mengambil MD5 dari server:
    echo    %REMOTE_MD5_URL%
    echo.
    pause
    goto MENU
)
echo Remote MD5 : %REMOTE_MD5%

for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-FileHash -Path '%THIS_CMD%' -Algorithm MD5).Hash"') do set "LOCAL_MD5=%%A"
echo Local  MD5 : %LOCAL_MD5%

if /i "%LOCAL_MD5%"=="%REMOTE_MD5%" (
    color 0A
    echo [OK] Versi skrip sudah yang terbaru.
    pause
    goto MENU
)

color 0E
echo [INFO] Pembaruan tersedia! Mengunduh versi terbaru...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%REMOTE_FILE_URL%' -OutFile '%TMP_DL%' -UseBasicParsing" >nul 2>&1

if not exist "%TMP_DL%" (
    color 0C
    echo [ERROR] Gagal mengunduh file pembaruan dari:
    echo    %REMOTE_FILE_URL%
    pause
    goto MENU
)

for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm MD5 -Path '%TMP_DL%').Hash"') do set "DL_MD5=%%A"
echo Download MD5: %DL_MD5%

if /i not "%DL_MD5%"=="%REMOTE_MD5%" (
    color 0C
    echo [ERROR] Hash file unduhan tidak cocok. Update dibatalkan.
    del /f /q "%TMP_DL%" >nul 2>&1
    pause
    goto MENU
)

(
    echo @echo off
    echo title Memperbarui %REMOTE_NAME%...
    echo timeout /t 1 ^>nul
    echo echo [INFO] Memperbarui file skrip di lokasi: "%THIS_CMD%"
    echo copy /y "%TMP_DL%" "%THIS_CMD%" ^>nul 2^>^&1
    echo del /f /q "%TMP_DL%" ^>nul 2^>^&1
    echo echo [OK] Pembaruan selesai. Menjalankan ulang skrip baru...
    echo start "" "%THIS_CMD%"
    echo exit
) > "%REPL_BAT%"

echo.
echo [INFO] File pengganti telah disiapkan.
echo [INFO] Proses update akan dimulai dalam 5 detik...
timeout /t 5 >nul

start "" "%REPL_BAT%"
exit /b

:: =====================================================
:: MODE CEPAT UNTUK TASK SCHEDULER / QUICK
:: =====================================================
:OFF_QUICK
call :OFF quick
exit /b

:ON_QUICK
call :ON quick
exit /b

:OFF_TOTAL_QUICK
call :OFF_TOTAL quick
exit /b

:RESTORE_TOTAL_QUICK
call :RESTORE_TOTAL quick
exit /b