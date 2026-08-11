@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "APPDIR=%ROOT%certifica-jar"
set "JAR=%APPDIR%\Certifica-32bits.jar"
set "HASHFILE=%APPDIR%\Certifica-32bits.jar.sha256"
set "JAVA=%ROOT%jre\bin\java.exe"

if not exist "%JAR%" (
  echo [Certifica] ERROR: no se encuentra %JAR%
  exit /b 1
)
if not exist "%JAVA%" (
  echo [Certifica] ERROR: no se encuentra el JRE incluido. Re-descarga el paquete completo.
  exit /b 1
)

for /f "usebackq tokens=1" %%a in (`"%HASHFILE%"`) do set "EXPECTED=%%a"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 '%JAR%').Hash.ToLowerInvariant()"`) do set "ACTUAL=%%i"
if /i not "%EXPECTED%"=="%ACTUAL%" (
  echo [Certifica] ERROR: verificacion SHA-256 FALLO. El jar esta corrupto o fue modificado. Re-descarga el paquete.
  exit /b 1
)
echo [Certifica] Integridad verificada (SHA-256 OK)

cd /d "%APPDIR%"
"%JAVA%" -jar Certifica-32bits.jar %*
endlocal
