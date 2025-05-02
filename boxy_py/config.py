import os
import platform
from boxy_py.utils import get_script_dir

def get_config_directory():
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

def get_token_path():
    """Get path to the token file"""
    return os.path.join(get_config_directory(), "token.txt")

def get_playlists_directory():
    """Get directory for storing playlists"""
    playlists_dir = os.path.join(get_config_directory(), "playlists")
    
    # Create directory if it doesn't exist
    if not os.path.exists(playlists_dir):
        os.makedirs(playlists_dir)
        
    return playlists_dir