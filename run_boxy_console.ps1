# Define necessary paths
$boxyZipUrl = "https://github.com/Odizinne/Boxy/archive/refs/heads/main.zip"
$boxyExtractPath = "$env:LOCALAPPDATA\Programs\Boxy-main"  # Correct path for Boxy-main directory
$pythonInstaller = "python-3.13.3-amd64.exe"
$pythonVersion = "3.13.3"
$pythonPath = "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"
$desktopShortcutName = "Boxy.lnk"
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path -Path $desktopPath -ChildPath $desktopShortcutName

# Function to download and extract Boxy repository
function Download-And-Extract-Boxy {
    Write-Host "Downloading Boxy repository from GitHub..."
    $zipFilePath = "$env:TEMP\Boxy-main.zip"

    # Download the ZIP file
    Invoke-WebRequest -Uri $boxyZipUrl -OutFile $zipFilePath

    Write-Host "Extracting Boxy repository..."
    # Extract the ZIP file to the desired path
    Expand-Archive -Path $zipFilePath -DestinationPath $env:LOCALAPPDATA\Programs -Force

    # Clean up the ZIP file
    Remove-Item -Path $zipFilePath -Force
}

# Check if Boxy repository is already downloaded
if (-not (Test-Path $boxyExtractPath)) {
    # If Boxy is not found, download and extract it
    Download-And-Extract-Boxy
} else {
    Write-Host "Boxy repository already exists at $boxyExtractPath"
}

# Change directory to the Boxy repository
Set-Location -Path $boxyExtractPath

# Check if Python is installed
Write-Host "Checking for existing Python installation..."
$python = Get-Command python -ErrorAction SilentlyContinue

if ($python) {
    Write-Host "Python is already installed: $($python.Source)"
} else {
    Write-Host "Python not found. Proceeding to download and install..."

    # Define Python installer URL
    $downloadUrl = "https://www.python.org/ftp/python/$pythonVersion/$pythonInstaller"

    # Download installer if not already downloaded
    if (-not (Test-Path $pythonInstaller)) {
        Write-Host "Downloading Python $pythonVersion..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $pythonInstaller
    }

    # Install Python silently for the current user and add to PATH
    Write-Host "Installing Python $pythonVersion..."
    Write-Host "This may take a moment..."
    Start-Process -FilePath ".\$pythonInstaller" -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0" -Wait

    # Add expected install path to PATH for this session
    $defaultInstallPath = "$env:LOCALAPPDATA\Programs\Python\Python313"
    $env:Path += ";$defaultInstallPath;$defaultInstallPath\Scripts"

    # Remove the installer after installation
    if (Test-Path $pythonInstaller) {
        Write-Host "Removing Python installer..."
        Remove-Item $pythonInstaller -Force
    }
}

# Install dependencies if requirements.txt exists
if (Test-Path "$boxyExtractPath\requirements.txt") {
    Write-Host "Installing dependencies from requirements.txt..."
    & $pythonPath -m pip install -r "$boxyExtractPath\requirements.txt"
} else {
    Write-Warning "requirements.txt not found. Skipping dependency install."
}

# Get the absolute path of the current working directory
$currentDir = Get-Location

Write-Host "Creating desktop shortcut..."

# Create WScript Shell COM object
$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)

# Set the target of the shortcut
$shortcut.TargetPath = $pythonPath
$shortcut.Arguments = "`"$currentDir\boxy.py`""
$shortcut.WorkingDirectory = $currentDir.Path  # Set working directory to current location
$shortcut.IconLocation = "$pythonPath,0" # Optional: set Python icon for the shortcut
$shortcut.Save()

# Create a second desktop shortcut for running without a console
$pythonwPath = "$env:LOCALAPPDATA\Programs\Python\Python313\pythonw.exe"
$shortcutNameNoConsole = "Boxy (No console).lnk"
$shortcutPathNoConsole = Join-Path -Path $desktopPath -ChildPath $shortcutNameNoConsole

Write-Host "Creating 'Boxy (No console)' desktop shortcut..."

$shortcutNoConsole = $wshShell.CreateShortcut($shortcutPathNoConsole)
$shortcutNoConsole.TargetPath = $pythonwPath
$shortcutNoConsole.Arguments = "`"$currentDir\boxy.py`""
$shortcutNoConsole.WorkingDirectory = $currentDir.Path
$shortcutNoConsole.IconLocation = "$pythonwPath,0"
$shortcutNoConsole.Save()

Write-Host "Desktop shortcuts created successfully at $shortcutPath"


# Run boxy.py with visible console (normal python) after prompt
if (Test-Path "$boxyExtractPath\boxy.py") {
    Write-Host "Launching boxy.py in console mode..."
    Start-Process -FilePath $pythonPath -ArgumentList "$currentDir\boxy.py" -WindowStyle Normal
    Write-Host "You can safely close this window."
} else {
    Write-Warning "Could not find boxy.py in the current directory."
}

