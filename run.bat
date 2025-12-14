@echo off
setlocal enabledelayedexpansion
title NPix 
color 0A

REM ========================================
REM     NPix Bot - Advanced Launcher
REM ========================================

cls
echo.
echo ========================================
echo       NPix Bot - Advanced Launcher
echo ========================================
echo.
echo [%date% %time%] Initializing launcher...
echo.

REM Move to repository root
cd /d %~dp0

REM ========================================
REM Check Python Installation
REM ========================================
echo [SYSTEM CHECK] Verifying Python installation...
python --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo.
    echo [ERROR] Python is not installed or not in PATH.
    echo [ACTION REQUIRED] Install Python 3.10 or higher from https://www.python.org
    echo [INFO] Ensure 'Add Python to PATH' is checked during installation.
    echo.
    pause
    exit /b 1
)

REM Get Python version
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo [INFO] Python %PYTHON_VERSION% detected
echo.

REM ========================================
REM Check pip Installation
REM ========================================
echo [SYSTEM CHECK] Verifying pip installation...
pip --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo [ERROR] pip is not installed or not functioning properly.
    echo [ACTION REQUIRED] Reinstall Python with pip enabled.
    echo.
    pause
    exit /b 1
)
echo [INFO] pip is available
echo.

REM ========================================
REM Check requirements.txt
REM ========================================
if not exist "requirements.txt" (
    echo [WARNING] requirements.txt not found in current directory.
    echo [INFO] Skipping dependency installation.
    echo.
) else (
    echo [DEPENDENCY CHECK] Installing/Updating dependencies...
    echo [INFO] Reading requirements.txt...
    pip install -r requirements.txt --quiet --disable-pip-version-check
    IF ERRORLEVEL 1 (
        echo [ERROR] Failed to install dependencies.
        echo [ACTION REQUIRED] Check requirements.txt for errors.
        echo.
        pause
        exit /b 1
    )
    echo [SUCCESS] All dependencies installed successfully
    echo.
)

REM ========================================
REM Check bot file existence
REM ========================================
if not exist "src\bot.py" (
    echo [ERROR] Bot file not found at src\bot.py
    echo [ACTION REQUIRED] Ensure bot.py exists in the src directory.
    echo.
    pause
    exit /b 1
)

REM ========================================
REM Check configuration file
REM ========================================
if not exist "src\config.py" (
    echo [WARNING] config.py not found in src directory.
    echo [INFO] Bot may fail to start without proper configuration.
    echo.
)

REM ========================================
REM Create logs directory if not exists
REM ========================================
if not exist "logs" mkdir logs
echo [INFO] Log directory verified

REM ========================================
REM Display Launch Information
REM ========================================
echo.
echo ========================================
echo          Launch Information
echo ========================================
echo [TIMESTAMP] %date% %time%
echo [PYTHON] %PYTHON_VERSION%
echo [WORKING DIR] %cd%
echo [BOT FILE] src\bot.py
echo ========================================
echo.

REM ========================================
REM Launch Bot with Monitoring
REM ========================================
echo [STARTING] Launching NPix Bot...
echo [INFO] Press Ctrl+C to stop the bot gracefully
echo.
echo ----------------------------------------
echo          Bot Output Below
echo ----------------------------------------
echo.

REM Run the bot and capture exit code
python src\bot.py
set BOT_EXIT_CODE=%ERRORLEVEL%

echo.
echo ----------------------------------------
echo          Bot Process Ended
echo ----------------------------------------
echo.

REM ========================================
REM Handle Exit Status
REM ========================================
if %BOT_EXIT_CODE% EQU 0 (
    echo [INFO] Bot shut down normally
    echo [EXIT CODE] %BOT_EXIT_CODE%
) else (
    echo [ERROR] Bot stopped with error code: %BOT_EXIT_CODE%
    echo [INFO] Check logs directory for error details
    
    if %BOT_EXIT_CODE% EQU 1 (
        echo [POSSIBLE CAUSE] General runtime error
    ) else if %BOT_EXIT_CODE% EQU 2 (
        echo [POSSIBLE CAUSE] Configuration or permission error
    ) else (
        echo [POSSIBLE CAUSE] Unknown error - Check bot logs
    )
)

echo.
echo [TIMESTAMP] %date% %time%
echo [INFO] Press any key to close this window
pause >nul
exit /b %BOT_EXIT_CODE%
