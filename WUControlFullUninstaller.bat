@echo off
setlocal EnableExtensions
 title WUControl Full Uninstaller - Legacy Migration
color 0F

:: Hanya boleh dipanggil oleh updater dengan parameter /auto.
if /i not "%~1"=="/auto" (
    echo [ERROR] File ini khusus untuk migrasi otomatis WUControl versi lama.
    echo Jalankan pembaruan melalui menu [0] pada WUControl.
    exit /b 2
)

:: Pastikan berjalan sebagai Administrator.
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Hak Administrator tidak tersedia.
    exit /b 3
)

:: Deteksi OS, arsitektur, build, UBR.
set "OSCaption="
set "EditionID="
set "OSArch=32-bit"
set "Build=Unknown"
set "UBR=0"
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"') do set "OSCaption=%%A"
if defined ProgramFiles(x86) set "OSArch=64-bit"
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do set "Build=%%A"
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR 2^>nul') do set "UBR=%%A"
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID"') do set "EditionID=%%A"
set "UBRDec=%UBR%"
echo %UBR% | find "0x" >nul
if not errorlevel 1 for /f %%A in ('powershell -NoProfile -Command "[convert]::ToInt32('%UBR%',16)"') do set "UBRDec=%%A"
set "OSBuild=%Build%.%UBRDec%"

set "OSMode=Non-LTSC"
echo %OSCaption% | findstr /i "LTSC" >nul && set "OSMode=LTSC / IoT"
echo %EditionID% | findstr /i "EnterpriseS IoTEnterpriseS" >nul && set "OSMode=LTSC / IoT"

echo.
echo =====================================================
echo  Menghapus semua WUControl (Full) dan memulihkan
echo  layanan Windows Update ke konfigurasi layanan standar.
echo =====================================================
echo.
echo Nama OS     : %OSCaption%
echo Arsitektur  : %OSArch%
echo Build       : %OSBuild%
echo.
echo [INFO] Mendeteksi jenis edisi Windows...
if /i "%OSMode%"=="LTSC / IoT" (
    call :UNINSTALL_LTSC
) else (
    call :UNINSTALL_NONLTSC
)
if errorlevel 1 exit /b 10

:: Marker ditulis hanya setelah rangkaian uninstall selesai.
reg add "HKLM\SOFTWARE\R3NDY\WUControl" /v LegacyFullUninstallDone /t REG_DWORD /d 1 /f >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Gagal menyimpan penanda migrasi di Registry.
    exit /b 11
)
reg query "HKLM\SOFTWARE\R3NDY\WUControl" /v LegacyFullUninstallDone 2>nul | find "0x1" >nul
if errorlevel 1 (
    echo [ERROR] Verifikasi penanda migrasi gagal.
    exit /b 12
)
echo.
echo [OK] Windows Update telah dipulihkan sepenuhnya.
echo.
exit /b 0

:UNINSTALL_NONLTSC
echo [INFO] Memulihkan layanan Windows Update Non-LTSC...
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
exit /b %errorlevel%

:UNINSTALL_LTSC
 echo [INFO] Memulihkan layanan Windows Update LTSC/IoT...
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
exit /b %errorlevel%

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
        if exist "%TARGET_FILE%" (
            echo [ERROR] File WUControl.bat lama gagal dihapus.
            exit /b 1
        )
        echo [OK] File WUControl.bat lama telah dihapus.
    )
)
exit /b 0