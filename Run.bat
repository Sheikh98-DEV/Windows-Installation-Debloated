@echo off

:: Gets the absolute path of the script's directory
set script_path=%~dp0
set formated_path=%script_path:~0,-1%

:: Checks if the script is running with admin rights
net session >nul 2>&1

if %ERRORLEVEL% == 0 (
	:: Script IS running as admin -> starting Windows11CleanerBySheikh
	start "Win11 Builder" /max PowerShell.exe -ExecutionPolicy Bypass -File "%script_path%Windows11CleanerBySheikh.ps1" %formated_path%
) else (
	:: Script is NOT running as admin -> aborting
	echo "Administrator rights are REQUIRED for running Win11. The easiest way to do this is:"
	echo "1) Right click on: Run.bat"
	echo "2) Select: Run as administrator"
	pause
)
