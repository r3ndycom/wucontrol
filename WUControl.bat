@echo off
setlocal enabledelayedexpansion
title WUControl v2.9 (Fixed) - r3ndy.com
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
set "WU_MIGRATION_KEY=HKLM\SOFTWARE\R3NDY\WUControl"
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%" 2>nul

:: Migrasi satu kali: dijalankan saat versi baru pertama kali menggantikan instalasi lama.
reg query "%WU_MIGRATION_KEY%" /v LegacyFullUninstallDone 2>nul | find "0x1" >nul
if not errorlevel 1 goto STARTUP_MIGRATION_DONE
if not exist "%SCRIPT_FILE%" goto STARTUP_MARK_FRESH
findstr /i /c:"WUControl" "%SCRIPT_FILE%" >nul
if errorlevel 1 goto STARTUP_MARK_FRESH
findstr /i /c:"WUControl v2.9 (Fixed)" "%SCRIPT_FILE%" >nul
if not errorlevel 1 goto STARTUP_MARK_FRESH

echo [INFO] Migrasi instalasi WUControl lama terdeteksi.
set "MIGRATION_SOURCE=%~f0"
set "MIGRATION_BACKUP=%TEMP%\WUControl_main_backup_%RANDOM%.bat"
set "MIGRATION_UNINSTALL=%TEMP%\WUControlFullUninstall_%RANDOM%.bat"
set "MIGRATION_MD5=%TEMP%\WUControlFullUninstall_%RANDOM%.md5"
set "MIGRATION_HELPER=%TEMP%\WUControl_migration_%RANDOM%.bat"
copy /y "%~f0" "%MIGRATION_BACKUP%" >nul 2>&1
if errorlevel 1 goto STARTUP_MIGRATION_PREP_ERROR
(
    echo @echo off
    echo setlocal
    echo title Migrasi WUControl
    echo color 0F
    echo set "SCRIPT_FILE=%SCRIPT_FILE%"
    echo set "SOURCE_FILE=%MIGRATION_SOURCE%"
    echo set "BACKUP_FILE=%MIGRATION_BACKUP%"
    echo set "UNINSTALL_FILE=%MIGRATION_UNINSTALL%"
    echo set "MD5_FILE=%MIGRATION_MD5%"
    echo set "UNINSTALL_URL=https://raw.githubusercontent.com/r3ndycom/wucontrol/main/WUControlFullUninstall.bat"
    echo set "MD5_URL=https://raw.githubusercontent.com/r3ndycom/wucontrol/main/WUControlFullUninstall.md5"
    echo set "MIGRATION_KEY=HKLM\SOFTWARE\R3NDY\WUControl"
    echo timeout /t 1 ^>nul
    echo echo =====================================================
    echo echo       WUControl - Migrasi Versi Lama
    echo echo =====================================================
    echo echo [INFO] Mengunduh uninstaller migrasi...
    echo powershell -NoProfile -Command "try{Invoke-WebRequest -Uri '%%UNINSTALL_URL%%' -OutFile '%%UNINSTALL_FILE%%' -UseBasicParsing -TimeoutSec 30}catch{exit 1}" ^>nul 2^>^&1
    echo if not exist "%%UNINSTALL_FILE%%" goto MIGRATION_ERROR
    echo powershell -NoProfile -Command "try{Invoke-WebRequest -Uri '%%MD5_URL%%' -OutFile '%%MD5_FILE%%' -UseBasicParsing -TimeoutSec 15}catch{exit 1}" ^>nul 2^>^&1
    echo if not exist "%%MD5_FILE%%" goto MIGRATION_ERROR
    echo set "EXPECTED_MD5="
    echo set /p "EXPECTED_MD5="^<"%%MD5_FILE%%"
    echo del /f /q "%%MD5_FILE%%" ^>nul 2^>^&1
    echo for /f "delims=" %%%%A in ^('powershell -NoProfile -Command "^(Get-FileHash -LiteralPath '%%UNINSTALL_FILE%%' -Algorithm MD5^).Hash"'^) do set "ACTUAL_MD5=%%%%A"
    echo if not defined EXPECTED_MD5 goto MIGRATION_ERROR
    echo if /i not "%%EXPECTED_MD5%%"=="%%ACTUAL_MD5%%" goto MIGRATION_ERROR
    echo echo [OK] MD5 uninstaller cocok.
    echo echo [INFO] Menjalankan Full Uninstall versi lama...
    echo call "%%UNINSTALL_FILE%%" /auto
    echo if errorlevel 1 goto MIGRATION_ERROR
    echo reg query "%%MIGRATION_KEY%%" /v LegacyFullUninstallDone 2^>nul ^| find "0x1" ^>nul
    echo if errorlevel 1 goto MIGRATION_ERROR
    echo echo.
    echo echo [INFO] Uninstall selesai. Memasang WUControl terbaru dalam 5 detik...
    echo timeout /t 5 ^>nul
    echo if not exist "C:\Windows\scripts" mkdir "C:\Windows\scripts" ^>nul 2^>^&1
    echo copy /y "%%BACKUP_FILE%%" "%%SCRIPT_FILE%%" ^>nul
    echo if errorlevel 1 goto MIGRATION_ERROR
    echo if /i not "%%SOURCE_FILE%%"=="%%SCRIPT_FILE%%" copy /y "%%BACKUP_FILE%%" "%%SOURCE_FILE%%" ^>nul
    echo echo [OK] Migrasi WUControl selesai.
    echo start "" "%%SCRIPT_FILE%%"
    echo del /f /q "%%UNINSTALL_FILE%%" "%%BACKUP_FILE%%" "%%~f0" ^>nul 2^>^&1
    echo exit /b 0
    echo.
    echo :MIGRATION_ERROR
    echo echo.
    echo echo [ERROR] Migrasi gagal. WUControl terbaru belum dijalankan.
    echo echo [INFO] Memulihkan file utama dari salinan sementara...
    echo if exist "%%BACKUP_FILE%%" copy /y "%%BACKUP_FILE%%" "%%SCRIPT_FILE%%" ^>nul
    echo if exist "%%BACKUP_FILE%%" if /i not "%%SOURCE_FILE%%"=="%%SCRIPT_FILE%%" copy /y "%%BACKUP_FILE%%" "%%SOURCE_FILE%%" ^>nul
    echo echo [INFO] Periksa koneksi, file MD5, dan hak Administrator, lalu coba lagi.
    echo pause
    echo exit /b 1
) > "%MIGRATION_HELPER%"
if not exist "%MIGRATION_HELPER%" goto STARTUP_MIGRATION_PREP_ERROR
start "" "%MIGRATION_HELPER%"
exit /b

:STARTUP_MIGRATION_PREP_ERROR
echo [ERROR] Tidak dapat menyiapkan file migrasi WUControl.
echo [INFO] Instalasi tidak dilanjutkan agar file lama tidak tertimpa sebagian.
pause
exit /b 1

:STARTUP_MARK_FRESH
:: Instalasi baru: tidak ada WUControl lama yang perlu dibersihkan.
reg add "%WU_MIGRATION_KEY%" /v LegacyFullUninstallDone /t REG_DWORD /d 1 /f >nul 2>&1

:STARTUP_MIGRATION_DONE
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
set "EditionID="
for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID"') do set "EditionID=%%a"
echo %OSCaption% | findstr /i "LTSC" >nul && set "OSMode=LTSC / IoT"
echo %EditionID% | findstr /i "EnterpriseS IoTEnterpriseS" >nul && set "OSMode=LTSC / IoT"

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
set "WU_STATUS=ON / belum dikunci"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate 2>nul | find "0x1" >nul && set "WU_STATUS=OFF / kebijakan"
sc query wuauserv | find /i "RUNNING" >nul && (
    if /i "%WU_STATUS%"=="OFF / kebijakan" (set "WU_STATUS=KEBIJAKAN OFF / layanan berjalan") else (set "WU_STATUS=LAYANAN BERJALAN")
)
echo %WU_STATUS% | find /i "OFF" >nul
if not errorlevel 1 (color 4F) else (color 2F)

:: Header
echo ======================================================
echo        Windows Update Control v2.9 (Fixed)
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

:: =====================================================
:: FUNGSI UMUM - Kontrol layanan Windows Update
:: =====================================================
:WU_DISABLE_SERVICES
echo [INFO] Menghentikan layanan Windows Update...
sc.exe stop wuauserv >nul 2>&1
sc.exe config wuauserv start= disabled >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo [INFO] UsoSvc, WaaSMedicSvc, dan BITS dibiarkan pada konfigurasi Windows.
exit /b

:WU_RESTORE_NONLTSC
sc.exe config wuauserv start= auto >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 2 /f >nul 2>&1
exit /b

:WU_RESTORE_LTSC
sc.exe config wuauserv start= demand >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
exit /b

:: =====================================================
:: MENU 1 - OFF (Non-LTSC)
:: =====================================================
:OFF
color 4F
echo Menonaktifkan Windows Update...
call :WU_DISABLE_SERVICES
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 1 /f >nul 2>&1

for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion"') do set "DisplayVer=%%a"
if "%DisplayVer%"=="" set "DisplayVer=Unknown"
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableOSUpgrade /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersion /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersionInfo /t REG_SZ /d "%DisplayVer%" /f >nul 2>&1

echo.
echo [OK] Kebijakan Automatic Updates telah dinonaktifkan.
echo [INFO] Versi fitur ditargetkan ke: %DisplayVer%
echo [INFO] Halaman Settings mungkin tetap terlihat; akses fitur Check for updates dibatasi kebijakan.
timeout /t 5 >nul
if /i "%~1"=="quick" exit /b
goto MENU

:: =====================================================
:: MENU 2 - ON (Non-LTSC)
:: =====================================================
:ON
color 2F
echo Mengaktifkan Windows Update...
call :WU_RESTORE_NONLTSC
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableOSUpgrade /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersion /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v TargetReleaseVersionInfo /f >nul 2>&1
net start wuauserv >nul 2>&1
net start bits >nul 2>&1
echo [OK] Kebijakan penonaktifan Automatic Updates telah dihapus.
timeout /t 5 >nul
if /i "%~1"=="quick" exit /b
goto MENU

:: =====================================================
:: MENU 3 - OFF_TOTAL (LTSC/IoT)
:: =====================================================
:OFF_TOTAL
color 4F
echo [INFO] Menonaktifkan Automatic Updates (LTSC/IoT)...
call :WU_DISABLE_SERVICES
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 1 /f >nul 2>&1

:: Tugas Windows dipertahankan; kebijakan Automatic Updates mengendalikan pemutakhiran.

echo.
echo [OK] Kebijakan Automatic Updates telah dinonaktifkan.
echo [INFO] Halaman Settings mungkin tetap terlihat; akses fitur Check for updates dibatasi kebijakan.
echo [INFO] Tidak menggunakan blokir IP Microsoft yang tidak lengkap.
timeout /t 5 >nul
if /i "%~1"=="quick" exit /b
goto MENU

:: =====================================================
:: MENU 4 - RESTORE_TOTAL (LTSC/IoT)
:: =====================================================
:RESTORE_TOTAL
color 2F
echo [INFO] Memulihkan Windows Update (LTSC/IoT)...
call :WU_RESTORE_LTSC
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /f >nul 2>&1
netsh advfirewall firewall delete rule name="Block Windows Update" >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\UpdateOrchestrator\Schedule Scan" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WindowsUpdate\Scheduled Start" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WaaSMedic\PerformRemediation" /Enable >nul 2>&1
net start wuauserv >nul 2>&1
net start bits >nul 2>&1
echo.
echo [OK] Kebijakan penonaktifan Automatic Updates telah dihapus.
timeout /t 5 >nul
if /i "%~1"=="quick" exit /b
goto MENU

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

:: =====================================================
:: MENU 9 - UNINSTALL FULL (Restore Windows Update)
:: =====================================================
:UNINSTALL
cls
color 0F
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
goto :EOF

:: =====================================================
:: UNINSTALL untuk Windows Non-LTSC
:: =====================================================
:UNINSTALL_NONLTSC
echo [INFO] Memulihkan layanan Windows Update Non-LTSC...
call :WU_RESTORE_NONLTSC
net start wuauserv >nul 2>&1
net start bits >nul 2>&1
call :COMMON_RESTORE
goto :EOF

:: =====================================================
:: UNINSTALL untuk Windows LTSC / IoT
:: =====================================================
:UNINSTALL_LTSC
echo [INFO] Memulihkan layanan Windows Update LTSC/IoT...
call :WU_RESTORE_LTSC
net start wuauserv >nul 2>&1
net start bits >nul 2>&1
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
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /f >nul 2>&1
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
set "REMOTE_BASE=WUControl"
set "REMOTE_NAME=WUControl.bat"
set "REMOTE_MD5_NAME=WUControl.md5"
set "UNINSTALL_NAME=WUControlFullUninstall.bat"
set "UNINSTALL_MD5_NAME=WUControlFullUninstall.md5"
set "TMP_DL=%TEMP%\WUControl_update_%RANDOM%.tmp"
set "TMP_MD5=%TEMP%\WUControl_remote_%RANDOM%.md5"
set "TMP_UNINSTALL=%TEMP%\WUControlFullUninstall_%RANDOM%.bat"
set "REPL_BAT=%TEMP%\replace_WUControl_%RANDOM%.bat"
set "GITHUB_RAW=https://raw.githubusercontent.com/r3ndycom/wucontrol/main"
set "REMOTE_MD5_URL=%GITHUB_RAW%/%REMOTE_MD5_NAME%"
set "REMOTE_FILE_URL=%GITHUB_RAW%/%REMOTE_NAME%"
set "UNINSTALL_MD5_URL=%GITHUB_RAW%/%UNINSTALL_MD5_NAME%"
set "UNINSTALL_FILE_URL=%GITHUB_RAW%/%UNINSTALL_NAME%"

echo [INFO] Memeriksa koneksi internet...
powershell -NoProfile -Command "$r=$false;try{$r=(iwr 'https://www.google.com' -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200}catch{};if($r){exit 0}else{exit 1}"
if errorlevel 1 (
    color 0C
    echo [ERROR] Tidak ada koneksi internet.
    echo Pastikan koneksi aktif, lalu coba lagi.
    pause
    goto MENU
)
echo [OK] Terhubung ke internet.

echo [INFO] Mengambil MD5 WUControl terbaru...
set "REMOTE_MD5="
powershell -NoProfile -Command "try{Invoke-WebRequest -Uri '%REMOTE_MD5_URL%' -OutFile '%TMP_MD5%' -UseBasicParsing -TimeoutSec 15}catch{exit 1}" >nul 2>&1
if not exist "%TMP_MD5%" goto UPDATE_MD5_ERROR
set /p "REMOTE_MD5="<"%TMP_MD5%"
del /f /q "%TMP_MD5%" >nul 2>&1
if not defined REMOTE_MD5 goto UPDATE_MD5_ERROR

for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%THIS_CMD%' -Algorithm MD5).Hash"') do set "LOCAL_MD5=%%A"
echo Remote MD5 : %REMOTE_MD5%
echo Local  MD5 : %LOCAL_MD5%
if /i "%LOCAL_MD5%"=="%REMOTE_MD5%" (
    color 0A
    echo [OK] Versi WUControl sudah yang terbaru.
    pause
    goto MENU
)

color 0E
echo [INFO] Pembaruan tersedia. Mengunduh WUControl.bat...
powershell -NoProfile -Command "try{Invoke-WebRequest -Uri '%REMOTE_FILE_URL%' -OutFile '%TMP_DL%' -UseBasicParsing -TimeoutSec 30}catch{exit 1}" >nul 2>&1
if not exist "%TMP_DL%" goto UPDATE_DOWNLOAD_ERROR
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%TMP_DL%' -Algorithm MD5).Hash"') do set "DL_MD5=%%A"
if /i not "%DL_MD5%"=="%REMOTE_MD5%" (
    color 0C
    echo [ERROR] MD5 WUControl.bat tidak cocok. Update dibatalkan.
    del /f /q "%TMP_DL%" >nul 2>&1
    pause
    goto MENU
)
echo [OK] MD5 WUControl.bat cocok.

(
    echo @echo off
    echo setlocal
    echo title Migrasi dan Pembaruan WUControl
    echo color 0F
    echo set "THIS_CMD=%THIS_CMD%"
    echo set "SCRIPT_FILE=C:\Windows\scripts\WUControl.bat"
    echo set "TMP_DL=%TMP_DL%"
    echo set "TMP_UNINSTALL=%TMP_UNINSTALL%"
    echo set "UNINSTALL_URL=%UNINSTALL_FILE_URL%"
    echo set "UNINSTALL_MD5_URL=%UNINSTALL_MD5_URL%"
    echo set "UNINSTALL_MD5_FILE=%%TEMP%%\WUControlFullUninstall_%%RANDOM%%.md5"
    echo set "WU_MIGRATION_KEY=HKLM\SOFTWARE\R3NDY\WUControl"
    echo timeout /t 1 ^>nul
    echo echo =====================================================
    echo echo       WUControl - Proses Pembaruan
    echo echo =====================================================
    echo reg query "%%WU_MIGRATION_KEY%%" /v LegacyFullUninstallDone 2^>nul ^| find "0x1" ^>nul
    echo if not errorlevel 1 goto INSTALL_NEW
    echo if not exist "%%SCRIPT_FILE%%" goto DOWNLOAD_LEGACY_UNINSTALL
    echo findstr /i /c:"WUControl v2.9 (Fixed)" "%%SCRIPT_FILE%%" ^>nul
    echo if not errorlevel 1 goto MARK_MIGRATION_DONE
    echo.
    echo :DOWNLOAD_LEGACY_UNINSTALL
    echo echo [INFO] Mengunduh WUControlFullUninstall.bat...
    echo powershell -NoProfile -Command "try{Invoke-WebRequest -Uri '%%UNINSTALL_URL%%' -OutFile '%%TMP_UNINSTALL%%' -UseBasicParsing -TimeoutSec 30}catch{exit 1}" ^>nul 2^>^&1
    echo if not exist "%%TMP_UNINSTALL%%" goto LEGACY_DOWNLOAD_ERROR
    echo powershell -NoProfile -Command "try{Invoke-WebRequest -Uri '%%UNINSTALL_MD5_URL%%' -OutFile '%%UNINSTALL_MD5_FILE%%' -UseBasicParsing -TimeoutSec 15}catch{exit 1}" ^>nul 2^>^&1
    echo if not exist "%%UNINSTALL_MD5_FILE%%" goto LEGACY_MD5_ERROR
    echo set "UNINSTALL_MD5="
    echo set /p "UNINSTALL_MD5="^<"%%UNINSTALL_MD5_FILE%%"
    echo del /f /q "%%UNINSTALL_MD5_FILE%%" ^>nul 2^>^&1
    echo if not defined UNINSTALL_MD5 goto LEGACY_MD5_ERROR
    echo for /f "delims=" %%%%A in ^('powershell -NoProfile -Command "^(Get-FileHash -LiteralPath '%%TMP_UNINSTALL%%' -Algorithm MD5^).Hash"'^) do set "UNINSTALL_DL_MD5=%%%%A"
    echo if /i not "%%UNINSTALL_DL_MD5%%"=="%%UNINSTALL_MD5%%" goto LEGACY_MD5_ERROR
    echo echo [OK] MD5 WUControlFullUninstall.bat cocok.
    echo echo [INFO] Menjalankan Full Uninstall versi lama satu kali...
    echo call "%%TMP_UNINSTALL%%" /auto
    echo if errorlevel 1 goto LEGACY_RUN_ERROR
    echo reg query "%%WU_MIGRATION_KEY%%" /v LegacyFullUninstallDone 2^>nul ^| find "0x1" ^>nul
    echo if errorlevel 1 goto LEGACY_RUN_ERROR
    echo del /f /q "%%TMP_UNINSTALL%%" ^>nul 2^>^&1
    echo goto INSTALL_NEW
    echo.
    echo :MARK_MIGRATION_DONE
    echo echo [INFO] WUControl v2.9 terdeteksi. Full Uninstall versi lama dilewati.
    echo reg add "%%WU_MIGRATION_KEY%%" /v LegacyFullUninstallDone /t REG_DWORD /d 1 /f ^>nul 2^>^&1
    echo if errorlevel 1 goto LEGACY_RUN_ERROR
    echo goto INSTALL_NEW
    echo.
    echo :INSTALL_NEW
    echo echo.
    echo echo [INFO] Full Uninstall lama selesai atau tidak diperlukan.
    echo echo [INFO] Pemasangan WUControl terbaru dimulai dalam 5 detik...
    echo timeout /t 5 ^>nul
    echo if not exist "C:\Windows\scripts" mkdir "C:\Windows\scripts" ^>nul 2^>^&1
    echo echo [INFO] Memasang WUControl.bat terbaru...
    echo copy /y "%%TMP_DL%%" "%%SCRIPT_FILE%%" ^>nul
    echo if errorlevel 1 goto INSTALL_ERROR
    echo copy /y "%%TMP_DL%%" "%%THIS_CMD%%" ^>nul
    echo if errorlevel 1 goto INSTALL_ERROR
    echo del /f /q "%%TMP_DL%%" ^>nul 2^>^&1
    echo echo.
    echo echo [OK] WUControl berhasil diperbarui.
    echo echo [INFO] Membuka WUControl terbaru...
    echo start "" "%%SCRIPT_FILE%%"
    echo del /f /q "%%TMP_UNINSTALL%%" ^>nul 2^>^&1
    echo del /f /q "%%~f0" ^>nul 2^>^&1
    echo exit /b 0
    echo.
    echo :LEGACY_DOWNLOAD_ERROR
    echo echo [ERROR] Gagal mengunduh WUControlFullUninstall.bat.
    echo goto SAFE_ABORT
    echo :LEGACY_MD5_ERROR
    echo echo [ERROR] MD5 WUControlFullUninstall.bat tidak tersedia atau tidak cocok.
    echo goto SAFE_ABORT
    echo :LEGACY_RUN_ERROR
    echo echo [ERROR] Full Uninstall versi lama gagal atau marker tidak ditemukan.
    echo goto SAFE_ABORT
    echo :SAFE_ABORT
    echo echo [INFO] Update dihentikan. WUControl terbaru tidak dipasang.
    echo echo [INFO] File unduhan utama disimpan di: "%%TMP_DL%%"
    echo pause
    echo exit /b 1
    echo.
    echo :INSTALL_ERROR
    echo echo [ERROR] Gagal memasang WUControl.bat terbaru.
    echo echo [INFO] File unduhan disimpan di: "%%TMP_DL%%"
    echo pause
    echo exit /b 1
) > "%REPL_BAT%"

if not exist "%REPL_BAT%" goto UPDATE_HELPER_ERROR
echo.
echo [INFO] File pembaruan dan pemeriksaan MD5 telah disiapkan.
echo [INFO] Full Uninstall lama hanya dijalankan satu kali.
echo [INFO] Proses pembaruan dimulai dalam 5 detik...
timeout /t 5 >nul
start "" "%REPL_BAT%"
exit /b

:UPDATE_MD5_ERROR
color 0C
echo [ERROR] Gagal mengambil MD5 WUControl dari GitHub.
echo URL: %REMOTE_MD5_URL%
pause
goto MENU

:UPDATE_DOWNLOAD_ERROR
color 0C
echo [ERROR] Gagal mengunduh WUControl.bat.
echo URL: %REMOTE_FILE_URL%
pause
goto MENU

:UPDATE_HELPER_ERROR
color 0C
echo [ERROR] Gagal membuat proses pengganti update.
del /f /q "%TMP_DL%" >nul 2>&1
pause
goto MENU

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