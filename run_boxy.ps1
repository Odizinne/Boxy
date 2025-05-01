# Check if Python is installed
Write-Host "Checking for existing Python installation..."
$python = Get-Command python -ErrorAction SilentlyContinue

if ($python) {
    Write-Host "Python is already installed: $($python.Source)"
} else {
    Write-Host "Python not found. Proceeding to download and install..."

    # Define Python version and installer
    $pythonVersion = "3.13.3"
    $pythonInstaller = "python-$pythonVersion-amd64.exe"
    $downloadUrl = "https://www.python.org/ftp/python/$pythonVersion/$pythonInstaller"

    # Download installer if not already downloaded
    if (-not (Test-Path $pythonInstaller)) {
        Write-Host "Downloading Python $pythonVersion..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $pythonInstaller
    }

    # Install Python silently for current user and add to PATH
    Write-Host "Installing Python $pythonVersion..."
    Start-Process -Wait -FilePath ".\$pythonInstaller" -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0"

    # Add expected install path to PATH for this session
    $defaultInstallPath = "$env:LOCALAPPDATA\Programs\Python\Python313"
    $env:Path += ";$defaultInstallPath;$defaultInstallPath\Scripts"
}

# Install dependencies if requirements.txt exists
if (Test-Path "./requirements.txt") {
    Write-Host "Installing dependencies from requirements.txt..."
    python -m pip install -r requirements.txt
} else {
    Write-Warning "requirements.txt not found. Skipping dependency install."
}

# Run boxy.py in background mode (pythonw, no console)
if (Test-Path "./boxy.py") {
    Write-Host "Launching boxy.py in background mode..."
    Start-Process -FilePath "pythonw" -ArgumentList "boxy.py" -WindowStyle Hidden
} else {
    Write-Warning "Could not find boxy.py in the current directory."
}
