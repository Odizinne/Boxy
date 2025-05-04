import os
import json
import hashlib
import platform
import time
import shutil
from typing import Dict, Optional, Tuple

class AudioCache:
    """
    Manages caching of downloaded audio files to avoid redundant downloads.
    """
    def __init__(self, cache_dir=None):
        """
        Initialize the audio cache system.
        
        Args:
            cache_dir: Optional custom cache directory path
        """
        if cache_dir is None:
            # Use %localappdata%/Boxy/audio_files on Windows, 
            # or equivalent on other platforms
            if platform.system() == "Windows":
                cache_dir = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Boxy", "audio_files")
            elif platform.system() == "Darwin":  # macOS
                cache_dir = os.path.join(os.path.expanduser("~"), "Library", "Caches", "Boxy", "audio_files")
            else:  # Linux and other Unix-like
                cache_dir = os.path.join(os.path.expanduser("~"), ".cache", "Boxy", "audio_files")
        
        self.cache_dir = cache_dir
        self.metadata_file = os.path.join(self.cache_dir, "metadata.json")
        self.metadata = {}
        self._ensure_cache_dir()
        self._load_metadata()
        
    def _ensure_cache_dir(self):
        """Create cache directory if it doesn't exist"""
        if not os.path.exists(self.cache_dir):
            os.makedirs(self.cache_dir, exist_ok=True)
    
    def _load_metadata(self):
        """Load metadata from the JSON file"""
        if os.path.exists(self.metadata_file):
            try:
                with open(self.metadata_file, 'r', encoding='utf-8') as f:
                    self.metadata = json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                print(f"Error loading metadata: {e}")
                # Create a new metadata file if corrupted
                self.metadata = {}
                self._save_metadata()
        else:
            self.metadata = {}
            self._save_metadata()
    
    def _save_metadata(self):
        """Save metadata to the JSON file"""
        try:
            with open(self.metadata_file, 'w', encoding='utf-8') as f:
                json.dump(self.metadata, f, ensure_ascii=False, indent=2)
        except IOError as e:
            print(f"Error saving metadata: {e}")
    
    def _generate_file_id(self, url: str) -> str:
        """
        Generate a unique ID for a URL.
        
        Args:
            url: The video URL
            
        Returns:
            A unique ID string based on the URL
        """
        return hashlib.md5(url.encode('utf-8')).hexdigest()
    
    def get_cached_file(self, url: str) -> Optional[Tuple[str, Dict]]:
        """
        Check if a URL is already cached.
        
        Args:
            url: The video URL
            
        Returns:
            Tuple of (file_path, metadata) if cached, None otherwise
        """
        file_id = self._generate_file_id(url)
        
        if file_id in self.metadata:
            info = self.metadata[file_id]
            file_path = os.path.join(self.cache_dir, f"{file_id}.webm")
            
            # Check if the file actually exists
            if os.path.exists(file_path):
                # Update last access time
                info['last_accessed'] = time.time()
                self._save_metadata()
                return file_path, info
            
            # File referenced in metadata but doesn't exist
            del self.metadata[file_id]
            self._save_metadata()
            
        return None
    
    def add_file(self, url: str, temp_file_path: str, info: Dict) -> str:
        """
        Add a file to the cache.
        
        Args:
            url: The video URL
            temp_file_path: Path to the temporary downloaded file
            info: Dictionary containing video metadata (title, duration, etc.)
            
        Returns:
            Path to the cached file
        """
        file_id = self._generate_file_id(url)
        cached_file_path = os.path.join(self.cache_dir, f"{file_id}.webm")
        
        # Copy the file to the cache
        shutil.copy2(temp_file_path, cached_file_path)
        
        # Record metadata
        file_size = os.path.getsize(cached_file_path)
        self.metadata[file_id] = {
            'url': url,
            'title': info.get('title', 'Unknown'),
            'duration': info.get('duration', 0),
            'thumbnail': info.get('thumbnail', ''),
            'channel': info.get('channel', '') or info.get('uploader', ''),
            'file_size': file_size,
            'date_added': time.time(),
            'last_accessed': time.time()
        }
        self._save_metadata()
        
        return cached_file_path
    
    def cleanup(self, max_size_mb=1024):
        """
        Clean up old cache files to stay within size limits.
        This is called during normal operation, not on exit.

        Args:
            max_age_days: Maximum age of files in days
            max_size_mb: Maximum total cache size in MB
        """
        if not self.metadata:
            return

        # Check total cache size
        total_size = sum(info.get('file_size', 0) for info in self.metadata.values())
        max_size_bytes = max_size_mb * 1024 * 1024

        # Only cleanup if we exceed the size limit
        if total_size <= max_size_bytes:
            return

        # Sort files by last access time (oldest first)
        items = sorted(self.metadata.items(), key=lambda x: x[1].get('last_accessed', 0))

        # Delete files until we're under the max size
        for file_id, info in items:
            file_path = os.path.join(self.cache_dir, f"{file_id}.webm")

            # Try to delete the file
            if os.path.exists(file_path):
                try:
                    os.remove(file_path)
                    total_size -= info.get('file_size', 0)
                    del self.metadata[file_id]

                    # Check if we're now under the limit
                    if total_size <= max_size_bytes:
                        break

                except PermissionError:
                    # File is probably in use (playing), skip it
                    continue
                except OSError as e:
                    print(f"Error deleting cache file {file_path}: {e}")
            else:
                # File is missing, remove from metadata
                del self.metadata[file_id]

        self._save_metadata()

    def clear_all(self):
        """
        Clear ALL cache files. Used when closing the application.
        This is different from cleanup() which only removes old files to maintain size limits.
        """
        try:
            # Get all files in the cache directory
            for filename in os.listdir(self.cache_dir):
                file_path = os.path.join(self.cache_dir, filename)
                
                # Skip the metadata file
                if filename == "metadata.json":
                    continue
                    
                # Try to delete the file
                try:
                    if os.path.isfile(file_path):
                        os.remove(file_path)
                except PermissionError:
                    # File is in use (possibly playing), skip it
                    continue
                except OSError as e:
                    print(f"Error deleting cache file {file_path}: {e}")
            
            # Clear metadata
            self.metadata = {}
            self._save_metadata()
            
        except Exception as e:
            print(f"Error clearing cache: {e}")