@echo off
REM ============================================================================
REM simple_lsp Windows Installer
REM
REM This script installs simple_lsp and the VS Code extension.
REM Run as Administrator for system-wide install, or as normal user for
REM user-only install.
REM ============================================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================
echo   simple_lsp Installer for Windows
echo ============================================
echo.

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% == 0 (
    set "INSTALL_TYPE=system"
    set "INSTALL_DIR=%ProgramFiles%\simple_lsp"
) else (
    set "INSTALL_TYPE=user"
    set "INSTALL_DIR=%USERPROFILE%\.simple_lsp"
)

echo Install type: %INSTALL_TYPE%
echo Install directory: %INSTALL_DIR%
echo.

REM Check for required files
if not exist "%~dp0simple_lsp.exe" (
    echo ERROR: simple_lsp.exe not found in %~dp0
    echo Please ensure you extracted all files from the release archive.
    pause
    exit /b 1
)

REM Create install directory
echo Creating installation directory...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if %errorLevel% neq 0 (
    echo ERROR: Could not create directory %INSTALL_DIR%
    echo Try running as Administrator for system-wide install.
    pause
    exit /b 1
)

REM Copy files
echo Copying files...
copy /Y "%~dp0simple_lsp.exe" "%INSTALL_DIR%\" >nul
if %errorLevel% neq 0 (
    echo ERROR: Could not copy simple_lsp.exe
    pause
    exit /b 1
)

REM Copy extension if present
if exist "%~dp0eiffel-lsp-*.vsix" (
    copy /Y "%~dp0eiffel-lsp-*.vsix" "%INSTALL_DIR%\" >nul
    echo VS Code extension copied to %INSTALL_DIR%
)

REM Set environment variable
echo.
echo Setting SIMPLE_LSP environment variable...
if "%INSTALL_TYPE%"=="system" (
    setx SIMPLE_LSP "%INSTALL_DIR%" /M >nul 2>&1
    if %errorLevel% neq 0 (
        echo WARNING: Could not set system environment variable.
        echo Setting user environment variable instead...
        setx SIMPLE_LSP "%INSTALL_DIR%" >nul
    )
) else (
    setx SIMPLE_LSP "%INSTALL_DIR%" >nul
)

REM Add to PATH (optional)
echo.
set /p ADD_PATH="Add simple_lsp to PATH? (Y/N): "
if /i "%ADD_PATH%"=="Y" (
    if "%INSTALL_TYPE%"=="system" (
        for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%b"
        echo !SYSPATH! | find /i "%INSTALL_DIR%" >nul
        if %errorLevel% neq 0 (
            setx Path "!SYSPATH!;%INSTALL_DIR%" /M >nul 2>&1
            echo Added to system PATH.
        ) else (
            echo Already in PATH.
        )
    ) else (
        for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%b"
        echo !USERPATH! | find /i "%INSTALL_DIR%" >nul
        if %errorLevel% neq 0 (
            setx Path "!USERPATH!;%INSTALL_DIR%" >nul
            echo Added to user PATH.
        ) else (
            echo Already in PATH.
        )
    )
)

REM Install VS Code extension
echo.
set /p INSTALL_EXT="Install VS Code extension now? (Y/N): "
if /i "%INSTALL_EXT%"=="Y" (
    where code >nul 2>&1
    if %errorLevel% == 0 (
        for %%f in ("%INSTALL_DIR%\eiffel-lsp-*.vsix") do (
            echo Installing %%f...
            code --install-extension "%%f"
        )
    ) else (
        echo VS Code command 'code' not found in PATH.
        echo Please install the extension manually:
        echo   1. Open VS Code
        echo   2. Press Ctrl+Shift+P
        echo   3. Type "Extensions: Install from VSIX..."
        echo   4. Select: %INSTALL_DIR%\eiffel-lsp-*.vsix
    )
)

echo.
echo ============================================
echo   Installation Complete!
echo ============================================
echo.
echo simple_lsp installed to: %INSTALL_DIR%
echo.
echo IMPORTANT: You may need to restart VS Code
echo and/or open a new terminal for environment
echo variables to take effect.
echo.
echo To verify installation, open VS Code and:
echo   1. Open any folder with .e files
echo   2. Check Output panel (View ^> Output ^> "Eiffel LSP")
echo.
pause
