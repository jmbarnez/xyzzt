@echo off
REM =============================================================
REM Run Novus in development mode with a visible console window.
REM - Uses local LÖVE installation in tools folder.
REM - Runs from the project source folder so Lurker hot-reload works.
REM =============================================================

REM Change to the directory where this script lives
pushd "%~dp0"

REM Launch LÖVE pointing at the current folder (the source tree)
"%~dp0tools\love-windows\love.exe" .

REM Keep the console open so you can read/copy any errors or Lurker output
echo.
echo Game has exited. Press any key to close this window.
pause >nul

REM Restore previous directory
popd
