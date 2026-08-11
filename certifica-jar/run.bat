@echo off
rem Windows launcher (scaffold). Prefer launcher.ps1.
setlocal
set ROOT=%~dp0..
set APP=%ROOT%\certifica-jar
set CACHE=%ROOT%\.cache

set JAVA=%CERTIFICA_JAVA_HOME%\bin\java.exe
if not defined CERTIFICA_JAVA_HOME set JAVA=%CACHE%\jdk8-x64\bin\java.exe
if not exist "%JAVA%" set JAVA=java

pushd "%APP%"
"%JAVA%" -jar Certifica-32bits.jar %*
set EXIT=%ERRORLEVEL%
popd
exit /b %EXIT%
