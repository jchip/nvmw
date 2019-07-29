@ECHO OFF

SETLOCAL

SET "NODE_EXE=%~dp0\..\node.exe"

IF NOT EXIST "%NODE_EXE%" (
  SET "NODE_EXE=node"
)

"%NODE_EXE%" "%~dp0\..\dist\nvm.js" %1 %2 %3 %4

ENDLOCAL

IF not %ERRORLEVEL% == 0 EXIT /b %ERRORLEVEL%

IF not exist "%TMP%\nvm_env.cmd" EXIT /b 0

IF exist "%TMP%\nvm_envx.cmd" del "%TMP%\nvm_envx.cmd"
ren "%TMP%\nvm_env.cmd" "nvm_envx.cmd"
"%TMP%\nvm_envx.cmd"
del "%TMP%\nvm_envx.cmd"
