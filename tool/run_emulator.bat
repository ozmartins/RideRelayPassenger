@echo off
rem Sobe o emulador Android e roda o app do passageiro nele (build debug).
rem Versao para Windows de tool/run_emulator.sh.
rem
rem Uso: tool\run_emulator.bat [EXEC_ID]
rem   EXEC_ID  identifica a execucao nos logs (ver LOGS.md); padrao "manual".
rem            Use o mesmo valor no app do motorista.
rem Variaveis opcionais:
rem   AVD_NAME     nome do AVD (padrao Pixel_6_API34_2)
rem   ORS_API_KEY  chave do OpenRouteService (sem ela a rota cai no fallback)
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

if not defined AVD_NAME set "AVD_NAME=Pixel_6_API34_2"
set "EXEC_ID=%~1"
if not defined EXEC_ID set "EXEC_ID=manual"

set "SDK=%ANDROID_HOME%"
if not defined SDK set "SDK=%ANDROID_SDK_ROOT%"
if not defined SDK set "SDK=%LOCALAPPDATA%\Android\Sdk"

rem Coloca o SDK no PATH (depois do que ja estiver) para chamar emulator e adb pelo nome.
set "PATH=%PATH%;%SDK%\emulator;%SDK%\platform-tools"

cd /d "%~dp0.."

where emulator >nul 2>&1 || (echo nao encontrei o emulator, defina ANDROID_HOME 1>&2 & exit /b 1)
where adb >nul 2>&1 || (echo nao encontrei o adb, defina ANDROID_HOME 1>&2 & exit /b 1)
where flutter >nul 2>&1 || (echo flutter nao esta no PATH 1>&2 & exit /b 1)

emulator -list-avds | findstr /x /c:"%AVD_NAME%" >nul
if errorlevel 1 (
  echo AVD '%AVD_NAME%' nao existe. Disponiveis: 1>&2
  emulator -list-avds 1>&2
  exit /b 1
)

call :find_serial
if defined SERIAL (
  echo ^>^> %AVD_NAME% ja esta rodando em %SERIAL%
  goto :run
)

echo ^>^> subindo %AVD_NAME%...
if not exist build mkdir build
start "emulador" /min cmd /c "emulator -avd %AVD_NAME% -no-snapshot-save > build\emulator.log 2>&1"
adb start-server >nul 2>&1

for /l %%i in (1,1,120) do if not defined SERIAL (
  call :find_serial
  if not defined SERIAL timeout /t 2 /nobreak >nul
)
if not defined SERIAL (
  echo emulador nao apareceu no adb ^(veja build\emulator.log^) 1>&2
  exit /b 1
)

echo ^>^> aguardando o boot de %SERIAL%...
adb -s %SERIAL% wait-for-device
set "BOOT="
for /l %%i in (1,1,180) do if not "!BOOT!"=="1" (
  call :check_boot
  if not "!BOOT!"=="1" timeout /t 2 /nobreak >nul
)
call :check_boot
if not "!BOOT!"=="1" (
  echo o emulador nao terminou o boot 1>&2
  exit /b 1
)

:run
set "DEFINES=--dart-define=EXEC_ID=%EXEC_ID%"
if defined ORS_API_KEY set "DEFINES=%DEFINES% --dart-define=ORS_API_KEY=%ORS_API_KEY%"

echo ^>^> flutter pub get
call flutter pub get || exit /b 1

echo ^>^> instalando e rodando o app em %SERIAL% ^(EXEC_ID=%EXEC_ID%^)
call flutter run -d %SERIAL% %DEFINES%
exit /b %errorlevel%

rem Procura um emulador ja em execucao com este AVD; define SERIAL (vazio se nao achar).
:find_serial
set "SERIAL="
for /f "tokens=1,2" %%a in ('adb devices ^| findstr /b "emulator-"') do (
  if "%%b"=="device" if not defined SERIAL call :check_avd %%a
)
exit /b 0

:check_avd
set "AVD_FOUND="
for /f "delims=" %%n in ('adb -s %1 emu avd name 2^>nul') do if not defined AVD_FOUND set "AVD_FOUND=%%n"
if "%AVD_FOUND%"=="%AVD_NAME%" set "SERIAL=%1"
exit /b 0

:check_boot
set "BOOT="
for /f "delims=" %%p in ('adb -s %SERIAL% shell getprop sys.boot_completed 2^>nul') do set "BOOT=%%p"
exit /b 0
