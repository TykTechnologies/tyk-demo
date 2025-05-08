# Windows Setup (PowerShell)

1. Open PowerShell as Administrator:

Search for PowerShell in the Start menu.

Right-click on Windows PowerShell and select Run as Administrator.

Run the following command to download and execute the setup script:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/TykTechnologies/tyk-demo/windows/windows/setup-tyk-demo.bat" -OutFile "$env:USERPROFILE\Downloads\setup-tyk-demo.bat"
Start-Process "$env:USERPROFILE\Downloads\setup-tyk-demo.bat"
```

The command will automatically:

- Set up WSL (Windows Subsystem for Linux) if it’s not installed.
- Install Docker Desktop if not already installed.
- Run the necessary setup steps for the Tyk Demo.

Note: Please restart your computer if you are prompted to do so after installing WSL or Docker.