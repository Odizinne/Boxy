import asyncio
import os
import concurrent.futures
import json
import discord
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
import yt_dlp
from youtube_search import YoutubeSearch

from boxy_py.utils import delete_file, get_first_video_url, get_script_dir
import boxy_py.config as config
from boxy_py.audio_cache import AudioCache

class BotBridge(QObject):
    # Signal definitions
    statusChanged = Signal(str)
    playStateChanged = Signal(bool)
    songChanged = Signal(str)
    downloadStatusChanged = Signal(str)
    repeatModeChanged = Signal(bool)
    songLoadedChanged = Signal(bool)
    voiceConnectedChanged = Signal(bool)
    channelsChanged = Signal(list)
    currentChannelChanged = Signal(str)
    serversChanged = Signal(list)
    currentServerChanged = Signal(str)
    durationChanged = Signal(float)
    positionChanged = Signal(float)
    startTimerSignal = Signal()
    stopTimerSignal = Signal()
    thumbnailChanged = Signal(str)
    channelNameChanged = Signal(str)
    titleResolved = Signal(int, str, str, str)
    playlistLoaded = Signal(list, str)
    playlistSaved = Signal(str)
    cacheInfoUpdated = Signal(int, int, str)

    def __init__(self, bot):
        super().__init__()
        # Initialize basic properties
        self.bot = bot
        self.is_playing = False
        self.current_guild = None
        self.current_channel = None
        self.repeat_mode = False
        self.current_audio_file = None
        self.current_url = None
        self.song_loaded = False
        self._changing_song = False

        # State properties
        self._voice_connected = False
        self._channels = []
        self._current_channel = None
        self._servers = []
        self._current_server = None
        self._duration = 0
        self._position = 0
        self._current_thumbnail_url = None
        self._current_channel_name = ""

        # Initialize the audio cache
        self.audio_cache = AudioCache()
        
        # Cache settings
        self.max_cache_size_mb = 500
        self.max_cache_age_days = 30

        # Set up position timer
        self._position_timer = QTimer(self)
        self._position_timer.setInterval(1000)
        self._position_timer.timeout.connect(self._update_position)

        # Connect signals
        self.startTimerSignal.connect(self._position_timer.start)
        self.stopTimerSignal.connect(self._position_timer.stop)

        # Create thread pool for YouTube operations
        self._yt_pool = concurrent.futures.ThreadPoolExecutor(max_workers=2, thread_name_prefix="yt_worker")

    def __del__(self):
        """Clean up resources when object is destroyed"""
        if hasattr(self, "_yt_pool"):
            self._yt_pool.shutdown(wait=False)

    #
    # Cache Management Methods
    #
    @Slot(result=dict)
    def get_cache_info(self):
        """Get information about the cache"""
        total_size = 0
        file_count = 0
        
        for file_id, info in self.audio_cache.metadata.items():
            total_size += info.get('file_size', 0)
            file_count += 1
            
        return {
            'total_size': total_size,
            'file_count': file_count,
            'cache_location': self.audio_cache.cache_dir
        }
        
    @Slot(int, int)
    def set_cache_settings(self, max_size_mb, max_age_days):
        """Update cache settings"""
        self.max_cache_size_mb = max_size_mb
        self.max_cache_age_days = max_age_days
        self.audio_cache.cleanup(max_age_days, max_size_mb)
        
        # Update cache info
        cache_info = self.get_cache_info()
        self.cacheInfoUpdated.emit(
            cache_info['total_size'],
            cache_info['file_count'],
            cache_info['cache_location']
        )
        
    @Slot()
    def clear_cache(self):
        """Clear all cache files"""
        try:
            # Delete all files in the cache directory
            for file_id in list(self.audio_cache.metadata.keys()):
                file_path = os.path.join(self.audio_cache.cache_dir, f"{file_id}.webm")
                if os.path.exists(file_path):
                    os.remove(file_path)
            
            # Clear metadata
            self.audio_cache.metadata = {}
            self.audio_cache._save_metadata()
            
            # Update cache info
            cache_info = self.get_cache_info()
            self.cacheInfoUpdated.emit(
                cache_info['total_size'],
                cache_info['file_count'],
                cache_info['cache_location']
            )
            
            return True
        except Exception as e:
            print(f"Error clearing cache: {e}")
            return False

    #
    # Playlist Management Methods
    #
    @Slot(str)
    def delete_playlist(self, filepath):
        """Delete a playlist file"""
        try:
            os.remove(filepath)
            self.playlistSaved.emit("Playlist deleted successfully")
        except Exception as e:
            self.playlistSaved.emit(f"Error deleting playlist: {str(e)}")

    @Slot(result=list)
    def get_playlist_files(self):
        """Get list of playlist files in the playlists directory"""
        playlists_dir = self.get_playlists_directory()
        files = []
        try:
            for file in os.listdir(playlists_dir):
                if file.endswith(".json"):
                    files.append({
                        "name": os.path.splitext(file)[0], 
                        "filePath": os.path.join(playlists_dir, file)
                    })
        except Exception as e:
            print(f"Error reading playlist directory: {e}")
        return files

    @Slot(result=str)
    def get_playlists_directory(self):
        """Get platform-specific directory for storing playlists"""
        return config.get_playlists_directory()

    @Slot(str, list)
    def save_playlist(self, name, items):
        """Save a playlist to file"""
        try:
            playlists_dir = self.get_playlists_directory()
            playlist_file = os.path.join(playlists_dir, f"{name}.json")

            with open(playlist_file, "w", encoding="utf-8") as f:
                json.dump(items, f, ensure_ascii=False, indent=2)

            self.playlistSaved.emit(f"Playlist '{name}' saved successfully")
        except Exception as e:
            self.playlistSaved.emit(f"Error saving playlist: {str(e)}")

    @Slot(str)
    def load_playlist(self, filename):
        """Load a playlist from file"""
        try:
            if filename:
                with open(filename, "r", encoding="utf-8") as f:
                    playlist_data = json.load(f)
                    # Update playlist items to ensure they have channelName field
                    for item in playlist_data:
                        if "channelName" not in item:
                            item["channelName"] = ""
                    playlist_name = os.path.splitext(os.path.basename(filename))[0]
                    self.playlistLoaded.emit(playlist_data, playlist_name)
        except Exception as e:
            self.playlistSaved.emit(f"Error loading playlist: {str(e)}")

    #
    # Playback Control Methods
    #
    @Slot()
    def stop_playing(self):
        """Stop playback and clean up resources"""
        async def stop_wrapper():
            if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
                self.bot.voice_client.stop()
                self.is_playing = False
                self.stopTimerSignal.emit()
                self._position = 0
                self.positionChanged.emit(0)
                self.playStateChanged.emit(False)
                self.songChanged.emit("")
                self.songLoadedChanged.emit(False)
                
                # Only delete the temporary file, not cached files
                temp_audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
                if self.current_audio_file == temp_audio_file and os.path.exists(temp_audio_file):
                    await delete_file(temp_audio_file)
                    
                self.current_audio_file = None
                self.current_url = None
                self.downloadStatusChanged.emit("")
                self._current_thumbnail_url = None
                self.thumbnailChanged.emit("")
                self._current_channel_name = ""
                self.channelNameChanged.emit("")

        asyncio.run_coroutine_threadsafe(stop_wrapper(), self.bot.loop)

    @Slot()
    def toggle_playback(self):
        """Toggle play/pause state"""
        if not self.bot.voice_client:
            return

        if self.bot.voice_client.is_playing():
            self.bot.voice_client.pause()
            self.is_playing = False
            self.stopTimerSignal.emit()
        elif self.bot.voice_client.is_paused():
            self.bot.voice_client.resume()
            self.is_playing = True
            self.startTimerSignal.emit()

        self.playStateChanged.emit(self.is_playing)

    @Slot(bool)
    def set_repeat_mode(self, enabled):
        """Set repeat mode on/off"""
        self.repeat_mode = enabled
        self.repeatModeChanged.emit(enabled)

    @Slot(float)
    def seek(self, position):
        """Seek to position in current audio"""
        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            # Store the current state
            was_playing = self.bot.voice_client.is_playing()

            # Create new audio source with the seek position
            position_ms = int(position * 1000)
            new_source = discord.FFmpegPCMAudio(self.current_audio_file, before_options=f"-ss {position_ms}ms")

            # Save the original after callback
            original_after = getattr(self.bot.voice_client, "_player", None)
            if original_after:
                original_after = original_after.after

            # Create a dummy callback to prevent state changes
            def dummy_callback(error):
                pass

            if hasattr(self.bot.voice_client, "_player") and self.bot.voice_client._player:
                self.bot.voice_client._player.after = dummy_callback

            # Replace the source
            self.bot.voice_client.source = new_source

            # Restore the original callback if it existed
            if hasattr(self.bot.voice_client, "_player") and self.bot.voice_client._player:
                if original_after:
                    self.bot.voice_client._player.after = original_after
                else:
                    self.bot.voice_client._player.after = lambda e: self.on_playback_finished(
                        e, self.current_audio_file
                    )

            # Update position
            self._position = position
            self.positionChanged.emit(position)

            # If it was paused, pause the new source
            if not was_playing:
                self.bot.voice_client.pause()

    @Slot(str)
    def play_url(self, url):
        """Play audio from URL or search term"""
        async def play_wrapper():
            if not self._current_channel or not self._current_server:
                self.downloadStatusChanged.emit("Please select a server and channel first")
                return
    
            selected_server = discord.utils.get(self.bot.guilds, id=int(self._current_server))
            if not selected_server:
                self.downloadStatusChanged.emit("Selected server not found")
                return
    
            selected_channel = discord.utils.get(selected_server.voice_channels, id=int(self._current_channel))
            if not selected_channel:
                self.downloadStatusChanged.emit("Selected channel not found")
                return
    
            # Check if we need to change channels
            need_reconnect = True
            if self.bot.voice_client and self.bot.voice_client.is_connected():
                if self.bot.voice_client.channel.id == int(self._current_channel):
                    need_reconnect = False
                else:
                    # Different channel, need to disconnect first
                    await self.bot.voice_client.disconnect()
                    self.bot.voice_client = None
                    self.is_playing = False
                    self._voice_connected = False
                    self.stopTimerSignal.emit()
                    self._position = 0
                    self.positionChanged.emit(0)
                    self.playStateChanged.emit(False)
                    self.songChanged.emit("")
                    self.songLoadedChanged.emit(False)
                    self.voiceConnectedChanged.emit(False)
    
            if need_reconnect:
                if all(member.bot for member in selected_channel.members):
                    self.downloadStatusChanged.emit("Cannot join empty channel")
                    return
    
                try:
                    self.bot.voice_client = await selected_channel.connect()
                    self._voice_connected = True
                    self.voiceConnectedChanged.emit(True)
                except Exception as e:
                    self.downloadStatusChanged.emit(f"Failed to connect: {str(e)}")
                    return
    
            # IMPORTANT FIX: We need to stop playback and wait for it to completely finish
            # before starting a new playback
            if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
                # First set a flag that we're changing songs - this prevents on_playback_finished
                # from resetting the UI state during the transition
                self._changing_song = True
                
                # Now stop the current playback
                self.bot.voice_client.stop()
                
                # Wait for it to fully stop (important!)
                await asyncio.sleep(0.3)
            else:
                self._changing_song = False
    
            # Now reset the playback state manually since we'll skip that in on_playback_finished
            self.stopTimerSignal.emit()
            self._position = 0
            self.positionChanged.emit(0)
    
            # Save repeat mode state and disable temporarily
            was_repeat = self.repeat_mode
            self.repeat_mode = False
            
            # Play the audio
            await self.play_from_gui(url)
            
            # Restore repeat mode
            self.repeat_mode = was_repeat
            
            # Clear the changing flag
            self._changing_song = False
    
        asyncio.run_coroutine_threadsafe(play_wrapper(), self.bot.loop)

    async def play_from_gui(self, search):
        """Download and play audio from URL or search term"""
        print(f"=========== PLAY_FROM_GUI CALLED ===========")
        print(f"Search/URL: {search}")

        if not self.bot.voice_client or not self.bot.voice_client.is_connected():
            print("Voice client not connected, attempting to connect...")
            if not self._current_channel or not self._current_server:
                self.downloadStatusChanged.emit("Please select a server and channel first")
                print("No server/channel selected")
                return

            selected_server = discord.utils.get(self.bot.guilds, id=int(self._current_server))
            if not selected_server:
                self.downloadStatusChanged.emit("Selected server not found")
                print("Selected server not found")
                return

            selected_channel = discord.utils.get(selected_server.voice_channels, id=int(self._current_channel))
            if not selected_channel:
                self.downloadStatusChanged.emit("Selected channel not found")
                print("Selected channel not found")
                return

            if all(member.bot for member in selected_channel.members):
                self.downloadStatusChanged.emit("Cannot join empty channel")
                print("Cannot join empty channel - only bots present")
                return

            try:
                print(f"Connecting to channel: {selected_channel.name}")
                self.bot.voice_client = await selected_channel.connect()
                self._voice_connected = True
                self.voiceConnectedChanged.emit(True)
                print("Successfully connected to voice channel")
            except Exception as e:
                self.downloadStatusChanged.emit(f"Failed to connect: {str(e)}")
                print(f"Failed to connect: {str(e)}")
                return

        print("Voice connection status OK")
        self.downloadStatusChanged.emit("Preparing...")

        # Define the temporary audio file
        temp_audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
        print(f"Temp audio file path: {temp_audio_file}")

        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            print("Stopping current playback")
            self.bot.voice_client.stop()

        # Reset playback states first to ensure UI elements properly update
        print("Resetting playback states")
        self.stopTimerSignal.emit()
        self._position = 0
        self.positionChanged.emit(0)

        # Clear any existing file
        if os.path.exists(temp_audio_file):
            print("Deleting existing temp file")
            await delete_file(temp_audio_file)
            await asyncio.sleep(0.1)

        url = search if search.startswith("http") else get_first_video_url(search)
        print(f"Resolved URL: {url}")

        if url is None:
            self.downloadStatusChanged.emit("No video found")
            print("No video found")
            return

        # Important: Set song loaded to false during loading to force UI update 
        print("Setting songLoaded to False")
        self.songLoadedChanged.emit(False)

        # Check if the audio is already in cache
        print("Checking cache for URL")
        cached = self.audio_cache.get_cached_file(url)

        if cached:
            print("Found cached file!")
            # Use cached file
            audio_file, info = cached
            print(f"Cached info: {info}")
            song_name = info['title']
            channel_name = info['channel']
            self._duration = info['duration']

            print(f"Setting duration: {self._duration}")
            self.durationChanged.emit(self._duration)

            print(f"Setting channel name: {channel_name}")
            self._current_channel_name = channel_name

            # Explicitly update song info and thumbnail first
            print(f"Setting song name: {song_name}")
            self.songChanged.emit(song_name)  
            self.channelNameChanged.emit(channel_name)

            print(f"Setting current audio file: {audio_file}")
            self.current_audio_file = audio_file
            self.current_url = url

            print(f"Setting thumbnail: {info['thumbnail']}")
            self._current_thumbnail_url = info['thumbnail']
            self.thumbnailChanged.emit(self._current_thumbnail_url)

            self.downloadStatusChanged.emit("Using cached file...")
        else:
            print("No cached file found, downloading...")
            # Download new file
            try:
                ydl_opts = {
                    "format": "bestaudio/best",
                    "outtmpl": temp_audio_file,
                    "noplaylist": True,
                    "progress_hooks": [self.download_hook],
                }

                self.downloadStatusChanged.emit("Extracting video info...")
                print("Extracting video info with yt-dlp")
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    info = ydl.extract_info(url, download=True)
                    song_name = info["title"]
                    channel_name = info.get("channel", "") or info.get("uploader", "")
                    self._duration = info.get("duration", 0)

                    print(f"Downloaded info: title={song_name}, channel={channel_name}, duration={self._duration}")
                    self.durationChanged.emit(self._duration)
                    self._current_channel_name = channel_name

                    # Update song info and thumbnail first
                    print("Emitting song and channel changed signals")
                    self.songChanged.emit(song_name)
                    self.channelNameChanged.emit(channel_name)

                    # Add to cache
                    self.downloadStatusChanged.emit("Caching audio file...")
                    print(f"Adding file to cache: {temp_audio_file}")
                    audio_file = self.audio_cache.add_file(url, temp_audio_file, info)
                    print(f"Cached file path: {audio_file}")
                    self.current_audio_file = audio_file
                    self.current_url = url
                    self._current_thumbnail_url = info.get("thumbnail") or info.get("thumbnails", [{}])[0].get("url", "")
                    print(f"Setting thumbnail: {self._current_thumbnail_url}")
                    self.thumbnailChanged.emit(self._current_thumbnail_url)

            except Exception as e:
                print(f"Download error: {e}")
                self.downloadStatusChanged.emit(f"Error: {str(e)}")
                return

        try:
            print(f"Checking if file exists: {self.current_audio_file}")
            if os.path.exists(self.current_audio_file):
                self.downloadStatusChanged.emit("Starting playback...")
                print("File exists, starting playback")

                if self.bot.voice_client:
                    self._position = 0
                    self.positionChanged.emit(0)

                    print("Creating FFmpegPCMAudio source")
                    source = discord.FFmpegPCMAudio(self.current_audio_file)

                    print("Starting playback with voice client")
                    # Play the audio and ensure the callback is properly connected
                    self.bot.voice_client.play(
                        source, 
                        after=lambda e: self.on_playback_finished(e, self.current_audio_file)
                    )

                    # Critical: Ensure UI state changes happen in the right order
                    # and are always applied regardless of the audio source
                    print("Setting playback state to playing")
                    self.is_playing = True
                    self.playStateChanged.emit(True)
                    self.downloadStatusChanged.emit("")

                    # Use a short delay to make sure the UI updates properly
                    print("Waiting for UI to update")
                    await asyncio.sleep(0.2)

                    # Signal that a song is loaded AFTER all other state is set
                    print("Setting songLoaded to True")
                    self.songLoadedChanged.emit(True)
                    print("Starting position timer")
                    self.startTimerSignal.emit()
            else:
                print(f"Error: Audio file not found at {self.current_audio_file}")
                self.downloadStatusChanged.emit("Error: Audio file not found")

        except Exception as e:
            print(f"Playback error: {e}")
            self.downloadStatusChanged.emit(f"Playback error: {str(e)}")

        print("=========== PLAY_FROM_GUI COMPLETED ===========")

    def download_hook(self, d):
        """Progress hook for youtube-dl"""
        if d["status"] == "downloading":
            try:
                downloaded = d.get("downloaded_bytes", 0)
                total = d.get("total_bytes", 0) or d.get("total_bytes_estimate", 0)
                if total:
                    progress = (downloaded / total) * 100
                    self.downloadStatusChanged.emit(f"Downloading: {progress:.1f}%")
                else:
                    self.downloadStatusChanged.emit("Downloading...")
            except:
                self.downloadStatusChanged.emit("Downloading...")
        elif d["status"] == "finished":
            self.downloadStatusChanged.emit("Download complete, processing...")

    def on_playback_finished(self, error, audio_file):
        """Called when playback finishes"""
        # CRITICAL FIX: Check if we're in the middle of changing songs
        # If so, don't reset UI state to avoid race conditions
        if hasattr(self, '_changing_song') and self._changing_song:
            print("Skipping reset during song change")
            return

        self.stopTimerSignal.emit()
        self._position = 0
        self.positionChanged.emit(0)

        # Reset song state unless we're repeating
        if not (self.repeat_mode and audio_file == self.current_audio_file):
            self.songLoadedChanged.emit(False)
            self.songChanged.emit("")
            self._current_thumbnail_url = ""
            self._current_channel_name = ""
            self.channelNameChanged.emit("")
            self.thumbnailChanged.emit("")

        if error:
            print(f"An error occurred: {error}")
            return

        if self.repeat_mode and audio_file == self.current_audio_file:
            print("Repeating song...")
            asyncio.run_coroutine_threadsafe(self.replay_audio(audio_file), self.bot.loop)
        else:
            # Only delete the temporary file, not cached files
            temp_audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
            if audio_file == temp_audio_file and os.path.exists(temp_audio_file):
                asyncio.run_coroutine_threadsafe(delete_file(audio_file), self.bot.loop)
    
    print("=========== ON_PLAYBACK_FINISHED COMPLETED ===========")

    async def replay_audio(self, audio_file):
        """Replay the current audio file (for repeat mode)"""
        print(f"=========== REPLAY_AUDIO CALLED ===========")
        print(f"Audio file: {audio_file}")

        if os.path.exists(audio_file) and audio_file == self.current_audio_file:
            print("File exists and matches current audio file")
            self._position = 0
            self.positionChanged.emit(0)

            print("Creating FFmpegPCMAudio source for replay")
            source = discord.FFmpegPCMAudio(audio_file)

            print("Starting replay with voice client")
            self.bot.voice_client.play(
                source, 
                after=lambda e: self.on_playback_finished(e, audio_file)
            )

            self.is_playing = True
            self.playStateChanged.emit(True)
            self.startTimerSignal.emit()

            # Make sure to set songLoaded to true again
            print("Setting songLoaded to True for replay")
            self.songLoadedChanged.emit(True)
        else:
            print(f"Cannot replay: File does not exist or doesn't match current audio file")
            print(f"File exists: {os.path.exists(audio_file)}")
            print(f"Current audio file: {self.current_audio_file}")

        print("=========== REPLAY_AUDIO COMPLETED ===========")

    async def cleanup(self):
        """Clean up resources when application exits"""
        if self.bot.voice_client:
            await self.bot.voice_client.disconnect()
            self.bot.voice_client = None
            
            # Only delete the temporary file, not cached files
            temp_audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
            if self.current_audio_file == temp_audio_file and os.path.exists(temp_audio_file):
                await delete_file(temp_audio_file)
        
        # Run cache cleanup
        self.audio_cache.cleanup(self.max_cache_age_days, self.max_cache_size_mb)

    def _update_position(self):
        """Update the position timer"""
        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            self._position += 1
            self.positionChanged.emit(self._position)
        else:
            self.stopTimerSignal.emit()
            self._position = 0
            self.positionChanged.emit(0)

    #
    # YouTube Playlist Handling
    #
    @Slot(str, result="QVariantList")
    def extract_urls_from_playlist(self, playlist_url):
        """Extract video URLs from a YouTube playlist"""
        urls = []

        async def extractor():
            try:
                self.downloadStatusChanged.emit("Extracting playlist info...")

                ydl_opts = {
                    "quiet": True,
                    "no_warnings": True,
                    "extract_flat": "in_playlist",
                    "skip_download": True,
                    "format": None,
                    "playlist_items": "1-100",  # Limit to first 100 items
                }

                async def get_playlist_info():
                    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                        return await asyncio.get_event_loop().run_in_executor(
                            self._yt_pool, lambda: ydl.extract_info(playlist_url, download=False)
                        )

                info = await get_playlist_info()

                if info and "entries" in info:
                    urls.extend([
                        f"https://www.youtube.com/watch?v={entry['id']}"
                        for entry in info["entries"]
                        if entry and "id" in entry
                    ])

            except Exception as e:
                print(f"Error extracting playlist: {e}")
                self.downloadStatusChanged.emit(f"Error extracting playlist: {str(e)}")
            finally:
                self.downloadStatusChanged.emit("")

        future = asyncio.run_coroutine_threadsafe(extractor(), self.bot.loop)
        future.result()
        return urls

    @Slot(int, str)
    def resolve_title(self, index, user_input):
        """Resolve the title and channel for a YouTube URL or search term"""
        async def resolver():
            try:
                self.downloadStatusChanged.emit(f"Resolving title for item {index}...")

                title_ydl_opts = {
                    "quiet": True,
                    "no_warnings": True,
                    "extract_flat": True,
                    "skip_download": True,
                    "format": None,
                }

                if user_input.startswith("http"):
                    # Handle URL directly
                    async def extract_url_info():
                        with yt_dlp.YoutubeDL(title_ydl_opts) as ydl:
                            return await asyncio.get_event_loop().run_in_executor(
                                self._yt_pool, lambda: ydl.extract_info(user_input, download=False, process=False)
                            )

                    info = await extract_url_info()
                    if info:
                        title = info.get("title", "Unknown Title")
                        channel_name = info.get("channel", "") or info.get("uploader", "")
                        self.titleResolved.emit(index, title, user_input, channel_name)
                    else:
                        self.titleResolved.emit(index, "Error fetching title", "", "")
                else:
                    # Handle search term
                    async def perform_search():
                        return await asyncio.get_event_loop().run_in_executor(
                            self._yt_pool, lambda: YoutubeSearch(user_input, max_results=1).to_dict()
                        )

                    results = await perform_search()
                    if results:
                        first_result = results[0]
                        url = f"https://www.youtube.com{first_result['url_suffix']}"

                        async def extract_search_info():
                            with yt_dlp.YoutubeDL(title_ydl_opts) as ydl:
                                return await asyncio.get_event_loop().run_in_executor(
                                    self._yt_pool, lambda: ydl.extract_info(url, download=False, process=False)
                                )

                        info = await extract_search_info()
                        if info:
                            title = info.get("title", "Unknown Title")
                            channel_name = info.get("channel", "") or info.get("uploader", "")
                            self.titleResolved.emit(index, title, url, channel_name)
                        else:
                            self.titleResolved.emit(index, "Error fetching title", "", "")
                    else:
                        self.titleResolved.emit(index, "No video found", "", "")

                self.downloadStatusChanged.emit("")

            except Exception as e:
                print(f"Error resolving title: {e}")
                self.titleResolved.emit(index, f"Error: {str(e)}", "", "")
                self.downloadStatusChanged.emit("")

        asyncio.run_coroutine_threadsafe(resolver(), self.bot.loop)

    #
    # Voice Channel Management
    #
    @Slot()
    def connect_to_channel(self):
        """Connect to the selected voice channel"""
        async def connect_wrapper():
            if not self._current_channel or not self._current_server:
                self.downloadStatusChanged.emit("Please select a server and channel first")
                return

            selected_server = discord.utils.get(self.bot.guilds, id=int(self._current_server))
            if not selected_server:
                self.downloadStatusChanged.emit("Selected server not found")
                return

            selected_channel = discord.utils.get(selected_server.voice_channels, id=int(self._current_channel))
            if not selected_channel:
                self.downloadStatusChanged.emit("Selected channel not found")
                return

            if all(member.bot for member in selected_channel.members):
                self.downloadStatusChanged.emit("Cannot join empty channel")
                return

            try:
                self.bot.voice_client = await selected_channel.connect()
                self._voice_connected = True
                self.voiceConnectedChanged.emit(True)
                self.downloadStatusChanged.emit("")
            except Exception as e:
                self.downloadStatusChanged.emit(f"Failed to connect: {str(e)}")
                return

        asyncio.run_coroutine_threadsafe(connect_wrapper(), self.bot.loop)

    @Slot()
    def disconnect_voice(self):
        """Disconnect from voice channel"""
        async def disconnect_wrapper():
            if self.bot.voice_client:
                await self.bot.voice_client.disconnect()
                self.bot.voice_client = None
                self.is_playing = False
                self._voice_connected = False
                self.stopTimerSignal.emit()
                self._position = 0
                self.positionChanged.emit(0)
                self.playStateChanged.emit(False)
                self.songChanged.emit("")
                self.songLoadedChanged.emit(False)
                self.voiceConnectedChanged.emit(False)
                
                # Only delete the temporary file, not cached files
                temp_audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
                if self.current_audio_file == temp_audio_file and os.path.exists(temp_audio_file):
                    await delete_file(temp_audio_file)
                    
                self.current_audio_file = None
                self.current_url = None
                self.downloadStatusChanged.emit("")
                self._current_thumbnail_url = None
                self.thumbnailChanged.emit("")

#
    # Server and Channel Management
    #
    @Property(list, notify=serversChanged)
    def servers(self):
        """Get list of available servers"""
        return self._servers

    @Slot()
    def update_servers(self):
        """Update the list of available servers"""
        if self.bot:
            self._servers = [{"name": guild.name, "id": str(guild.id)} for guild in self.bot.guilds]
            self.serversChanged.emit(self._servers)

    @Slot(str)
    def set_current_server(self, server_id):
        """Set the current server"""
        self._current_server = server_id
        self.currentServerChanged.emit(server_id)
        self.update_channels()

    @Property(list, notify=channelsChanged)
    def channels(self):
        """Get list of available voice channels"""
        return self._channels

    @Slot()
    def update_channels(self):
        """Update the list of available voice channels"""
        if not self.bot or not self._current_server:
            self._channels = []
        else:
            server = discord.utils.get(self.bot.guilds, id=int(self._current_server))
            if server:
                self._channels = [{"name": channel.name, "id": str(channel.id)} for channel in server.voice_channels]
            else:
                self._channels = []
        self.channelsChanged.emit(self._channels)

    @Slot(str)
    def set_current_channel(self, channel_id):
        """Set the current voice channel"""
        self._current_channel = channel_id
        self.currentChannelChanged.emit(channel_id)

    #
    # Property Getters/Setters
    #
    @Property(str, notify=channelNameChanged)
    def current_channel_name(self):
        """Get the name of the current YouTube channel"""
        return self._current_channel_name

    @current_channel_name.setter
    def current_channel_name(self, name):
        """Set the name of the current YouTube channel"""
        if self._current_channel_name != name:
            self._current_channel_name = name
            self.channelNameChanged.emit(name)

    @Property(str, notify=thumbnailChanged)
    def current_thumbnail_url(self):
        """Get the URL of the current thumbnail"""
        return self._current_thumbnail_url

    @current_thumbnail_url.setter
    def current_thumbnail_url(self, url):
        """Set the URL of the current thumbnail"""
        if self._current_thumbnail_url != url:
            self._current_thumbnail_url = url
            self.thumbnailChanged.emit(url)

    @Property(bool, notify=voiceConnectedChanged)
    def voiceConnected(self):
        """Get whether connected to a voice channel"""
        return self._voice_connected