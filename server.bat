@echo off
REM Change to the directory where this script lives
pushd "%~dp0"

REM Launch LÖVE in server mode
"%~dp0tools\love-windows\love.exe" . --server

pause
popd
