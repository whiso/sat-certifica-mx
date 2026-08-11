@echo off
rem Windows launcher (scaffold). Prefer launcher.ps1.
setlocal EnableExtensions
set ROOT=%~dp0..
set APP=%ROOT%\certifica-jar
set CACHE=%ROOT%\.cache

set JAVA=%CERTIFICA_JAVA_HOME%\bin\java.exe
if not defined CERTIFICA_JAVA_HOME set JAVA=%CACHE%\jdk8-x64\bin\java.exe
if not exist "%JAVA%" set JAVA=java

if not exist "%APP%\Certifica-64bits.jar" (
    echo [launcher] ERROR: Certifica-64bits.jar not found
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\dist-src\check-hash.ps1" -AppDir "%APP%"
if errorlevel 1 (
    echo [launcher] ERROR: Hash verification FAILED. Jar corrupt or modified.
    exit /b 1
)

pushd "%APP%"
"%JAVA%" -jar Certifica-64bits.jar %*
set EXIT=%ERRORLEVEL%
popd
exit /b %EXIT%
