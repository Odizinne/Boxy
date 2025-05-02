import os
import platform
import subprocess
import threading
from PySide6.QtCore import QObject, Signal, Slot, Property

class SetupManager(QObject):
    # Define the signals
    setupCompleted = Signal(str)  # Emitted when setup is complete with token
    ffmpegInstallInProgressSignal = Signal(bool)
    ffmpegInstalledSignal = Signal(bool)
    ffmpegInstallMessageSignal = Signal(str)
    
    def __init__(self):
        super().__init__()
        self.config_dir = self.get_config_dir()
        self.token_file = os.path.join(self.config_dir, "token.txt")
        self._ffmpeg_install_in_progress = False
        self._ffmpeg_installed = self.check_ffmpeg_installed()
        self._ffmpeg_install_message = ""
        self._os_type = platform.system()
        self._linux_distro = self.get_linux_distro() if self._os_type == "Linux" else ""
        
    def get_config_dir(self):
        """Get platform-specific config directory"""
        system = platform.system()
        
        if system == "Windows":
            config_dir = os.path.join(os.environ.get("APPDATA"), "Boxy")
        elif system == "Darwin":  # macOS
            config_dir = os.path.join(os.path.expanduser("~"), "Library", "Application Support", "Boxy")
        else:  # Linux and other Unix-like
            config_dir = os.path.join(os.path.expanduser("~"), ".config", "Boxy")
            
        # Create directory if it doesn't exist
        if not os.path.exists(config_dir):
            os.makedirs(config_dir)
            
        return config_dir
    
    @Property(str, constant=True)
    def osType(self):
        return self._os_type
        
    @Property(str, constant=True)
    def linuxDistro(self):
        return self._linux_distro
    
    @Property(bool, notify=ffmpegInstallInProgressSignal)
    def ffmpegInstallInProgress(self):
        return self._ffmpeg_install_in_progress
        
    @ffmpegInstallInProgress.setter
    def ffmpegInstallInProgress(self, value):
        if self._ffmpeg_install_in_progress != value:
            self._ffmpeg_install_in_progress = value
            self.ffmpegInstallInProgressSignal.emit(value)
    
    @Property(bool, notify=ffmpegInstalledSignal)
    def ffmpegInstalled(self):
        return self._ffmpeg_installed
        
    @ffmpegInstalled.setter
    def ffmpegInstalled(self, value):
        if self._ffmpeg_installed != value:
            self._ffmpeg_installed = value
            self.ffmpegInstalledSignal.emit(value)
            
    @Property(str, notify=ffmpegInstallMessageSignal)
    def ffmpegInstallMessage(self):
        return self._ffmpeg_install_message
        
    @ffmpegInstallMessage.setter
    def ffmpegInstallMessage(self, value):
        if self._ffmpeg_install_message != value:
            self._ffmpeg_install_message = value
            self.ffmpegInstallMessageSignal.emit(value)
    
    def get_linux_distro(self):
        """Try to determine Linux distribution"""
        try:
            # Check for os-release file
            if os.path.exists("/etc/os-release"):
                with open("/etc/os-release", "r") as f:
                    for line in f:
                        if line.startswith("ID="):
                            distro = line.split("=")[1].strip().strip('"').strip("'").lower()
                            if "ubuntu" in distro:
                                return "Ubuntu"
                            elif "debian" in distro:
                                return "Debian"
                            elif "fedora" in distro:
                                return "Fedora"
                            elif "arch" in distro:
                                return "Arch"
            
            # Check for specific files
            if os.path.exists("/etc/debian_version"):
                return "Debian"
            elif os.path.exists("/etc/fedora-release"):
                return "Fedora"
            elif os.path.exists("/etc/arch-release"):
                return "Arch"
        except:
            pass
        
        return "Unknown"
    
    def check_ffmpeg_installed(self):
        """Check if FFmpeg is installed"""
        try:
            # Try to run ffmpeg -version
            subprocess.run(["ffmpeg", "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            return True
        except:
            return False
    
    @Slot()
    def installFFmpegWindows(self):
        """Install FFmpeg on Windows"""
        if self._ffmpeg_installed or self._ffmpeg_install_in_progress:
            return
            
        self.ffmpegInstallInProgress = True
        self.ffmpegInstallMessage = "Starting download..."
        
        # Run the installation in a separate thread
        threading.Thread(target=self._install_ffmpeg_windows, daemon=True).start()
    
    def _install_ffmpeg_windows(self):
        """Download and install FFmpeg for Windows"""
        import tempfile
        import zipfile
        import urllib.request
        import shutil
        import ctypes
        import sys
        
        ffmpeg_url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
        
        try:
            # Create temp directory
            with tempfile.TemporaryDirectory() as temp_dir:
                # Download file
                self.ffmpegInstallMessage = "Downloading FFmpeg..."
                zip_path = os.path.join(temp_dir, "ffmpeg.zip")
                urllib.request.urlretrieve(ffmpeg_url, zip_path)
                
                # Extract zip
                self.ffmpegInstallMessage = "Extracting files..."
                with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(temp_dir)
                
                # Find bin directory
                bin_dir = None
                for root, dirs, files in os.walk(temp_dir):
                    if "bin" in dirs:
                        bin_dir = os.path.join(root, "bin")
                        break
                
                if not bin_dir:
                    raise Exception("Could not find bin directory in downloaded files")
                
                # Determine install location
                python_dir = os.path.dirname(sys.executable)
                is_admin = ctypes.windll.shell32.IsUserAnAdmin() if hasattr(ctypes.windll, 'shell32') else False
                
                # Check if directory is writable
                is_writable = os.access(python_dir, os.W_OK)
                
                if not is_writable and not is_admin:
                    self.ffmpegInstallMessage = "Python directory is not writable. Installing to user directory..."
                    install_dir = os.path.join(os.path.expanduser("~"), "ffmpeg", "bin")
                    os.makedirs(install_dir, exist_ok=True)
                else:
                    install_dir = python_dir
                
                # Copy files
                self.ffmpegInstallMessage = f"Installing FFmpeg to {install_dir}..."
                for file in os.listdir(bin_dir):
                    if file.endswith(".exe"):
                        shutil.copy2(os.path.join(bin_dir, file), os.path.join(install_dir, file))
                
                # Add to PATH if needed
                if install_dir != python_dir:
                    # Get current PATH
                    path = os.environ.get("PATH", "")
                    
                    # Check if already in PATH
                    if install_dir not in path:
                        # Add to user PATH
                        self.ffmpegInstallMessage = "Adding FFmpeg to user PATH..."
                        subprocess.run(
                            f'setx PATH "{install_dir};{path}"',
                            shell=True, 
                            check=True
                        )
                
                self.ffmpegInstallMessage = "FFmpeg installed successfully!"
                self.ffmpegInstalled = True
        
        except Exception as e:
            self.ffmpegInstallMessage = f"Installation failed: {str(e)}"
            print(f"FFmpeg installation error: {e}")
        finally:
            self.ffmpegInstallInProgress = False
    
    def is_setup_complete(self):
        """Check if token is already set up"""
        if os.path.exists(self.token_file):
            with open(self.token_file, "r") as f:
                token = f.read().strip()
                return token != "" and token != "REPLACE_THIS_WITH_YOUR_BOT_TOKEN"
        return False
    
    @Slot(str)
    def save_token(self, token):
        """Save bot token to file and signal completion"""
        with open(self.token_file, "w") as f:
            f.write(token)
        
        # Emit the token so the main app can use it
        self.setupCompleted.emit(token)
        
    def get_token(self):
        """Get the saved token"""
        if not os.path.exists(self.token_file):
            return None
            
        with open(self.token_file, "r") as f:
            token = f.read().strip()
            if token == "" or token == "REPLACE_THIS_WITH_YOUR_BOT_TOKEN":
                return None
            return token