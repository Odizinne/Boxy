import os
import platform

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

def get_cache_directory():
    """Get platform-specific audio cache directory"""
    system = platform.system()
    
    if system == "Windows":
        cache_dir = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Boxy", "audio_files")
    elif system == "Darwin":  # macOS
        cache_dir = os.path.join(os.path.expanduser("~"), "Library", "Caches", "Boxy", "audio_files")
    else:  # Linux and other Unix-like
        cache_dir = os.path.join(os.path.expanduser("~"), ".cache", "Boxy", "audio_files")
        
    # Create directory if it doesn't exist
    if not os.path.exists(cache_dir):
        os.makedirs(cache_dir)
        
    return cache_dir

def migrate_playlists_if_needed():
    """Migrate playlists from config directory to playlist subdirectory"""
    config_dir = get_config_directory()
    playlist_dir = get_playlists_directory()
    
    try:
        for file in os.listdir(config_dir):
            if file.endswith(".json") and file != "metadata.json":
                old_path = os.path.join(config_dir, file)
                new_path = os.path.join(playlist_dir, file)
                
                if not os.path.exists(new_path):
                    import shutil
                    shutil.move(old_path, new_path)
                    print(f"Migrated playlist: {file}")
    except Exception as e:
        print(f"Error during playlist migration: {e}")