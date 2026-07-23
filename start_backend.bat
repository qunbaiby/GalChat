@echo off
setlocal

title GalChat AI Gateway

set "PROJECT_ROOT=%~dp0"
set "GATEWAY_DIR=%PROJECT_ROOT%backend\ai_gateway"
set "PYTHON_EXE=%PROJECT_ROOT%.venv\Scripts\python.exe"
set "GATEWAY_URL=http://127.0.0.1:8787"
set "MASTER_KEY_FILE=%GATEWAY_DIR%\data\.secrets-master-key"
set "ADMIN_TOKEN_FILE=%GATEWAY_DIR%\data\.admin-token"

if not exist "%PYTHON_EXE%" (
    echo [ERROR] Python environment was not found:
    echo         %PYTHON_EXE%
    echo.
    echo Create the project virtual environment and install backend requirements first.
    pause
    exit /b 1
)

set "GALCHAT_ENVIRONMENT=development"
set "GALCHAT_JWT_SECRET=local-development-secret-with-at-least-32-characters"
set "GALCHAT_DEV_TEST_ACCOUNT_ENABLED=true"
if not defined GALCHAT_ADMIN_TOKEN (
    if exist "%ADMIN_TOKEN_FILE%" (
        set /p GALCHAT_ADMIN_TOKEN=<"%ADMIN_TOKEN_FILE%"
    ) else (
        if not exist "%GATEWAY_DIR%\data" mkdir "%GATEWAY_DIR%\data"
        for /f "usebackq delims=" %%T in (`powershell.exe -NoProfile -Command "$bytes = New-Object byte[] 32; $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }; ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()"`) do (
            set "GALCHAT_ADMIN_TOKEN=%%T"
            >"%ADMIN_TOKEN_FILE%" echo %%T
        )
    )
)
if not defined GALCHAT_ADMIN_TOKEN (
    echo [ERROR] Could not create or load the local admin token.
    pause
    exit /b 1
)

powershell.exe -NoProfile -Command "try { $response = Invoke-RestMethod -Uri '%GATEWAY_URL%/health' -TimeoutSec 2; if ($response.status -eq 'ok') { exit 0 } } catch {}; exit 1" >nul 2>&1
if not errorlevel 1 (
    powershell.exe -NoProfile -Command "try { Invoke-RestMethod -Uri '%GATEWAY_URL%/admin/api/overview' -Headers @{ Authorization = 'Bearer %GALCHAT_ADMIN_TOKEN%' } -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Another AI Gateway is already running at %GATEWAY_URL%,
        echo         but it does not accept this launcher's admin token.
        echo         Stop that process and run this tool again.
        pause
        exit /b 1
    )
    echo GalChat AI Gateway is already running at %GATEWAY_URL%.
    echo Admin console: %GATEWAY_URL%/admin
    echo Admin token: %GALCHAT_ADMIN_TOKEN%
    start "" "%GATEWAY_URL%/admin"
    echo You can start the Godot project now.
    pause
    exit /b 0
)
if not defined GALCHAT_SECRETS_MASTER_KEY (
    if exist "%MASTER_KEY_FILE%" (
        set /p GALCHAT_SECRETS_MASTER_KEY=<"%MASTER_KEY_FILE%"
    ) else (
        if not exist "%GATEWAY_DIR%\data" mkdir "%GATEWAY_DIR%\data"
        for /f "usebackq delims=" %%K in (`powershell.exe -NoProfile -Command "$bytes = New-Object byte[] 32; $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }; [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_')"`) do (
            set "GALCHAT_SECRETS_MASTER_KEY=%%K"
            >"%MASTER_KEY_FILE%" echo %%K
        )
    )
)
if not defined GALCHAT_SECRETS_MASTER_KEY (
    echo [ERROR] Could not create or load the provider secrets master key.
    pause
    exit /b 1
)
"%PYTHON_EXE%" -c "import os; from cryptography.fernet import Fernet; Fernet(os.environ['GALCHAT_SECRETS_MASTER_KEY'].encode('ascii'))" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] The provider secrets master key is invalid.
    pause
    exit /b 1
)

cd /d "%GATEWAY_DIR%"

echo Starting GalChat AI Gateway...
echo Address: %GATEWAY_URL%
echo Test account: galchat_test
echo Test password: GalChatTest2026!
echo Admin console: %GATEWAY_URL%/admin
echo Admin token: %GALCHAT_ADMIN_TOKEN%
echo Encrypted provider storage: enabled
echo.
echo Keep this window open while using GalChat.
echo Press Ctrl+C to stop the backend.
echo.

start "" /b powershell.exe -NoProfile -WindowStyle Hidden -Command "$url = '%GATEWAY_URL%'; for ($attempt = 0; $attempt -lt 30; $attempt++) { try { $response = Invoke-RestMethod -Uri ($url + '/health') -TimeoutSec 1; if ($response.status -eq 'ok') { Start-Process ($url + '/admin'); exit 0 } } catch {}; Start-Sleep -Milliseconds 250 }; exit 1"
"%PYTHON_EXE%" -m uvicorn app:app --host 127.0.0.1 --port 8787 --no-access-log

echo.
echo GalChat AI Gateway has stopped.
pause