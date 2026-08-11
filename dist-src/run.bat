@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%check-hash.ps1"
if errorlevel 1 (
  echo [Certifica] ERROR: la verificacion del jar fallo. Re-descarga el paquete completo.
  pause
  exit /b 1
)

"%ROOT%jre\bin\java.exe" -jar "%ROOT%certifica-jar\Certifica-64bits.jar" %*
endlocal
