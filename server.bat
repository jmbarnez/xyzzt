@echo off
REM Change to the directory where this script lives
pushd "%~dp0"

REM Launch LÖVE in server mode using lovec.exe (console version)
"%~dp0tools\love-windows\lovec.exe" . --server

pause
popd
