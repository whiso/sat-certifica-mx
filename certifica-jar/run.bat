@echo off
rem Windows launcher (scaffold). Prefer launcher.ps1.
setlocal
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
if not exist "%APP%\Certifica-64bits.jar.sha256" (
    echo [launcher] ERROR: hash file not found
    exit /b 1
)

for /f "usebackq tokens=1" %%H in ("%APP%\Certifica-64bits.jar.sha256") do set "EXPECTED=%%H"

set "ACTUAL="
for /f "delims=" %%H in (`certutil -hashfile "%APP%\Certifica-64bits.jar" SHA256 ^| findstr /v ":"`) do call set "ACTUAL=%%ACTUAL%%%%H"
set "ACTUAL=%ACTUAL: =%"

if /i not "%EXPECTED%"=="%ACTUAL%" (
    echo [launcher] ERROR: Hash verification FAILED. Jar corrupt or modified.
    echo [launcher] expected: %EXPECTED%
    echo [launcher] actual:   %ACTUAL%
    exit /b 1
)
echo [launcher] Hash OK

pushd "%APP%"
"%JAVA%" -jar Certifica-64bits.jar %*
set EXIT=%ERRORLEVEL%
popd
exit /b %EXIT%
