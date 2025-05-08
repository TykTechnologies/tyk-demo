@echo off
setlocal enabledelayedexpansion

:: -------------------------------
:: Step 1: Check for Docker Desktop
:: -------------------------------
echo ==== Checking for Docker Desktop installation ====
where docker >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Desktop is not installed.
    echo Please install it from https://www.docker.com/products/docker-desktop/
    pause
    exit /b
)

:: -------------------------------
:: Step 2: Check if Docker Desktop is running
:: -------------------------------
echo ==== Checking if Docker Desktop is running ====
powershell -Command "Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue" >nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker Desktop is not running.
    echo Please start Docker Desktop before continuing.
    pause
    exit /b
)

:: -------------------------------
:: Step 3: Check for WSL
:: -------------------------------
echo ==== Checking WSL status ====
wsl --status >nul 2>&1
if errorlevel 1 (
    echo [INFO] WSL is not installed. Installing...
    wsl --install
    echo Please reboot your computer and re-run this script.
    pause
    exit /b
)

wsl --set-default-version 2

:: -------------------------------
:: Step 4: Check for Ubuntu
:: -------------------------------
echo ==== Checking for Ubuntu distro ====
wsl -l -v | findstr /i "Ubuntu" >nul
if errorlevel 1 (
    echo [INFO] Ubuntu not found. Installing via WSL...
    wsl --install -d Ubuntu
    echo Ubuntu installation starting. Please follow on-screen instructions.
    pause
    exit /b
)

:: -------------------------------
:: Step 5: Set Ubuntu as default and run setup
:: -------------------------------
echo ==== Setting Ubuntu as default distro ====
wsl --set-default Ubuntu
if errorlevel 1 (
    echo [ERROR] Failed to set Ubuntu as the default WSL distro.
    pause
    exit /b
)

echo ==== Starting tyk-demo in Ubuntu ====
wsl -e bash -c "
  set -e
  sudo apt update && sudo apt install -y git jq curl

  echo 'Checking Docker Compose availability...'
  docker compose version >/dev/null 2>&1 || { echo >&2 '[ERROR] Docker Compose is not available in WSL. Enable WSL integration for Ubuntu in Docker Desktop → Settings → Resources → WSL Integration.'; exit 1; }

  [ ! -d ~/tyk-demo ] && git clone https://github.com/TykTechnologies/tyk-demo.git ~/tyk-demo
  cd ~/tyk-demo
  chmod +x up.sh
  ./up.sh
"

pause
