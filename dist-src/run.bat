@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "ROOT=%~dp0"
set "APPDIR=%ROOT%certifica-jar"
set "JAVA=%ROOT%jre\bin\java.exe"

if not exist "%APPDIR%\Certifica-64bits.jar" (
  echo [Certifica] ERROR: no se encuentra certifica-jar\Certifica-64bits.jar
  exit /b 1
)
if not exist "%JAVA%" (
  echo [Certifica] ERROR: no se encuentra el JRE incluido (jre\bin\java.exe). Re-descarga el paquete completo.
  exit /b 1
)

cd /d "%APPDIR%" || exit /b 1

set "EXPECTED="
for /f "usebackq tokens=1" %%a in ("Certifica-64bits.jar.sha256") do set "EXPECTED=%%a"

set "ACTUAL="
for /f "delims=" %%i in ('certutil -hashfile Certifica-64bits.jar SHA256 ^| findstr /v ":"') do set "ACTUAL=!ACTUAL!%%i"
set "ACTUAL=!ACTUAL: =!"

if /i not "!EXPECTED!"=="!ACTUAL!" (
  echo [Certifica] ERROR: verificacion SHA-256 FALLO. El jar esta corrupto o fue modificado. Re-descarga el paquete.
  echo [Certifica] esperado: !EXPECTED!
  echo [Certifica] obtenido: !ACTUAL!
  exit /b 1
)
echo [Certifica] Integridad verificada (SHA-256 OK)

"%JAVA%" -jar Certifica-64bits.jar %*
endlocal
