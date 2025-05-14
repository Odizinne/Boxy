import asyncio
import os
import concurrent.futures
import json
import discord
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, QBuffer, QIODevice, QSettings
import yt_dlp
from youtube_search import YoutubeSearch

from boxy_py.utils import delete_file, get_first_video_url, get_script_dir, create_rounded_thumbnail
import boxy_py.config as config
from boxy_py.audio_cache import AudioCache

class BotBridge(QObject):
    # Core signals - these are still needed for properties
    statusChanged = Signal(str)
    playStateChanged = Signal(bool)
    songChanged = Signal(str)
    downloadStatusChanged = Signal(str)
    issue = Signal(str)
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
    batchDownloadProgressChanged = Signal(int, int, str)
    validTokenFormatChanged = Signal(bool)
    urlsExtractedSignal = Signal(list)
    itemDownloadStarted = Signal(str, int)
    itemDownloadCompleted = Signal(str, int)
    volumeChanged = Signal(float)

    def __init__(self, bot):
        super().__init__()
        # Initialize state properties
        self._status = "Disconnected"
        self._is_playing = False
        self._song_title = ""
        self._download_status = ""
        self._repeat_mode = False
        self._song_loaded = False
        self._voice_connected = False
        self._channels = []
        self._current_channel = None
        self._servers = []
        self._current_server = None
        self._duration = 0
        self._position = 0
        self._current_thumbnail_url = ""
        self._current_channel_name = ""
        self._valid_token_format = True
        self._disconnecting = False
        self._volume = 0.8

        # Initialize basic properties
        self.bot = bot
        self.current_guild = None
        self.current_channel = None
        self.current_audio_file = None
        self.current_url = None
        self._changing_song = False

        # Initialize the audio cache
        self.audio_cache = AudioCache()

        # Cache settings
        self.max_cache_size_mb = 500
        self.max_cache_age_days = 30

        # Set up position timer
        self._position_timer = QTimer(self)
        self._position_timer.setInterval(1000)
        self._position_timer.timeout.connect(self._update_position)

        self._settings = QSettings("Odizinne", "Boxy")
        self._volume = self._settings.value("volume", 0.8, type=float)

        # Connect signals
        self.startTimerSignal.connect(self._position_timer.start)
        self.stopTimerSignal.connect(self._position_timer.stop)

        # Create thread pool for YouTube operations
        self._yt_pool = concurrent.futures.ThreadPoolExecutor(max_workers=2, thread_name_prefix="yt_worker")

    def __del__(self):
        """Clean up resources when object is destroyed"""
        if hasattr(self, "_yt_pool"):
            self._yt_pool.shutdown(wait=False)

    # Property Definitions
    @Property(str, notify=statusChanged)
    def status(self):
        return self._status
        
    @status.setter
    def status(self, value):
        if self._status != value:
            self._status = value
            self.statusChanged.emit(value)
    
    @Property(bool, notify=playStateChanged)
    def is_playing(self):
        return self._is_playing
        
    @is_playing.setter
    def is_playing(self, value):
        if self._is_playing != value:
            self._is_playing = value
            self.playStateChanged.emit(value)
    
    @Property(str, notify=songChanged)
    def song_title(self):
        return self._song_title
        
    @song_title.setter
    def song_title(self, value):
        if self._song_title != value:
            self._song_title = value
            self.songChanged.emit(value)
    
    @Property(str, notify=downloadStatusChanged)
    def download_status(self):
        return self._download_status
        
    @download_status.setter
    def download_status(self, value):
        if self._download_status != value:
            self._download_status = value
            self.downloadStatusChanged.emit(value)
    
    @Property(bool, notify=repeatModeChanged)
    def repeat_mode(self):
        return self._repeat_mode
        
    @repeat_mode.setter
    def repeat_mode(self, value):
        if self._repeat_mode != value:
            self._repeat_mode = value
            self.repeatModeChanged.emit(value)
    
    @Property(bool, notify=songLoadedChanged)
    def song_loaded(self):
        return self._song_loaded
        
    @song_loaded.setter
    def song_loaded(self, value):
        if self._song_loaded != value:
            self._song_loaded = value
            self.songLoadedChanged.emit(value)
    
    @Property(bool, notify=voiceConnectedChanged)
    def voice_connected(self):
        return self._voice_connected
        
    @voice_connected.setter
    def voice_connected(self, value):
        if self._voice_connected != value:
            self._voice_connected = value
            self.voiceConnectedChanged.emit(value)
    
    @Property(list, notify=channelsChanged)
    def channels(self):
        return self._channels
        
    @channels.setter
    def channels(self, value):
        if self._channels != value:
            self._channels = value
            self.channelsChanged.emit(value)
    
    @Property(str, notify=currentChannelChanged)
    def current_channel(self):
        return self._current_channel
        
    @current_channel.setter
    def current_channel(self, value):
        if self._current_channel != value:
            self._current_channel = value
            self.currentChannelChanged.emit(value)
    
    @Property(list, notify=serversChanged)
    def servers(self):
        return self._servers
        
    @servers.setter
    def servers(self, value):
        if self._servers != value:
            self._servers = value
            self.serversChanged.emit(value)
    
    @Property(str, notify=currentServerChanged)
    def current_server(self):
        return self._current_server
        
    @current_server.setter
    def current_server(self, value):
        if self._current_server != value:
            self._current_server = value
            self.currentServerChanged.emit(value)
    
    @Property(float, notify=durationChanged)
    def duration(self):
        return self._duration
        
    @duration.setter
    def duration(self, value):
        if self._duration != value:
            self._duration = value
            self.durationChanged.emit(value)
    
    @Property(float, notify=positionChanged)
    def position(self):
        return self._position
        
    @position.setter
    def position(self, value):
        if self._position != value:
            self._position = value
            self.positionChanged.emit(value)
    
    @Property(str, notify=thumbnailChanged)
    def thumbnail_url(self):
        return self._current_thumbnail_url
        
    @thumbnail_url.setter
    def thumbnail_url(self, value):
        if self._current_thumbnail_url != value:
            self._current_thumbnail_url = value
            self.thumbnailChanged.emit(value)
    
    @Property(str, notify=channelNameChanged)
    def channel_name(self):
        return self._current_channel_name
        
    @channel_name.setter
    def channel_name(self, value):
        if self._current_channel_name != value:
            self._current_channel_name = value
            self.channelNameChanged.emit(value)
    
    @Property(bool, notify=validTokenFormatChanged)
    def valid_token_format(self):
        return self._valid_token_format
        
    @valid_token_format.setter
    def valid_token_format(self, value):
        if self._valid_token_format != value:
            self._valid_token_format = value
            self.validTokenFormatChanged.emit(value)
    
    @Property(bool)
    def disconnecting(self):
        return self._disconnecting
    
    @Property(float, notify=volumeChanged)
    def volume(self):
        return self._volume
    
    @volume.setter
    def volume(self, value):
        if 0.0 <= value <= 1.0 and self._volume != value:
            self._volume = value
            if self.bot.voice_client and self.bot.voice_client.source:
                self.bot.voice_client.source.volume = value
            self.volumeChanged.emit(value)

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
        """Update cache settings and cleanup old files"""
        self.max_cache_size_mb = max_size_mb
        self.max_cache_age_days = max_age_days
        self.audio_cache.cleanup(max_size_mb)

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
            self.audio_cache.clear_all()

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

    @Slot()
    def stop_playing(self):
        """Stop playback and clean up resources"""
        async def stop_wrapper():
            if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
                self.bot.voice_client.stop()
                self.is_playing = False
                self.stopTimerSignal.emit()
                self.position = 0
                self.song_title = ""
                self.song_loaded = False
                self.current_audio_file = None
                self.current_url = None
                self.download_status = ""
                self.thumbnail_url = ""
                self.channel_name = ""

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

    @Slot(bool)
    def set_repeat_mode(self, enabled):
        """Set repeat mode on/off"""
        self.repeat_mode = enabled

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
            self.position = position

            # If it was paused, pause the new source
            if not was_playing:
                self.bot.voice_client.pause()

    @Slot(str)
    def play_url(self, url):
        """Play audio from URL or search term"""
        async def play_wrapper():
            if not self._current_channel or not self._current_server:
                self.issue.emit("Please connect to a channel first")
                return
    
            selected_server = discord.utils.get(self.bot.guilds, id=int(self._current_server))
            if not selected_server:
                self.issue.emit("Selected server not found")
                return
    
            selected_channel = discord.utils.get(selected_server.voice_channels, id=int(self._current_channel))
            if not selected_channel:
                self.issue.emit("Selected channel not found")
                return
    
            if not self.bot.voice_client or not self.bot.voice_client.is_connected():
                self.issue.emit("Not connected to voice channel")
                return
                
            if self.bot.voice_client.channel.id != int(self._current_channel):
                self.issue.emit("Connected to a different channel")
                return
    
            if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
                self._changing_song = True
                self.bot.voice_client.stop()
                await asyncio.sleep(0.3)
            else:
                self._changing_song = False
    
            self.stopTimerSignal.emit()
            self._position = 0
    
            was_repeat = self.repeat_mode
            self.repeat_mode = False
    
            await self.play_from_gui(url)
    
            self.repeat_mode = was_repeat
    
            self._changing_song = False
    
        asyncio.run_coroutine_threadsafe(play_wrapper(), self.bot.loop)
    
    async def play_from_gui(self, search):
        """Download and play audio from URL or search term"""
        if not self.bot.voice_client or not self.bot.voice_client.is_connected():
            self.issue.emit("Not connected to voice channel")
            return
    
        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            self.bot.voice_client.stop()
    
        self._download_status = "Preparing..."
        self.stopTimerSignal.emit()
        self._position = 0
        self._song_loaded = False
    
        url = search if search.startswith("http") else get_first_video_url(search)
        if url is None:
            self._download_status = "No video found"
            return
    
        cached = self.audio_cache.get_cached_file(url)
        if cached:
            audio_file, info = cached
            await self._play_cached_file(audio_file, info, url)
        else:
            await self._download_and_play_file(url)

    async def _play_cached_file(self, audio_file, info, url):
        """Play a file that's already in the cache"""
        # Update metadata
        song_name = info['title']
        channel_name = info['channel']
        self.duration = info['duration']
        self.channel_name = channel_name
        self.thumbnail_url = info['thumbnail']

        # Update UI
        self.song_title = song_name
        self.download_status = "Using cached file..."

        # Store current file/URL
        self.current_audio_file = audio_file
        self.current_url = url

        # Start playback
        await self._start_playback(audio_file)

    async def _download_and_play_file(self, url):
        """Download a file and add it to cache before playing"""
        try:
            # Create a temporary directory for download
            import tempfile
            temp_dir = tempfile.mkdtemp()
            temp_file = os.path.join(temp_dir, "audio.webm")

            # Configure downloader
            ydl_opts = {
                "format": "bestaudio/best",
                "outtmpl": temp_file,
                "noplaylist": True,
                "progress_hooks": [self.download_hook],
                "quiet": True,
                "no_warnings": True
            }

            self.download_status = "Extracting video info..."

            # Run yt_dlp in thread pool to prevent blocking
            loop = asyncio.get_event_loop()
            info = await loop.run_in_executor(
                self._yt_pool,
                lambda: self._extract_video_info(url, ydl_opts)
            )

            # Update metadata
            song_name = info["title"]
            channel_name = info.get("channel", "") or info.get("uploader", "")
            self.duration = info.get("duration", 0)
            self.channel_name = channel_name
            self.thumbnail_url = info.get("thumbnail") or info.get("thumbnails", [{}])[0].get("url", "")

            # Update UI
            self.song_title = song_name

            # Add to cache
            self.download_status = "Caching audio file..."
            audio_file = self.audio_cache.add_file(url, temp_file, info)

            # Clean up cache
            max_cache_size_mb = self._settings.value("maxCacheSize", 1024, type=int)
            self.audio_cache.cleanup(max_size_mb=max_cache_size_mb)

            # Store current file/URL
            self.current_audio_file = audio_file
            self.current_url = url

            # Start playback
            await self._start_playback(audio_file)

            # Clean up temp directory
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

        except Exception as e:
            self.download_status = f"Error: {str(e)}"

    async def _start_playback(self, audio_file):
        """Start playing an audio file"""
        try:
            if os.path.exists(audio_file):
                self.download_status = "Starting playback..."
                if self.bot.voice_client:
                    self.position = 0
                    source = discord.FFmpegPCMAudio(audio_file)
                    volume_transformer = discord.PCMVolumeTransformer(source, volume=self._volume)
                    self.bot.voice_client.play(
                        volume_transformer,
                        after=lambda e: self.on_playback_finished(e, audio_file)
                    )
                    self.is_playing = True
                    self.download_status = ""

                    await asyncio.sleep(0.2)

                    self.song_loaded = True
                    self.startTimerSignal.emit()
            else:
                self.download_status = "Error: Audio file not found"
        except Exception as e:
            self.download_status = f"Playback error: {str(e)}"

    def download_hook(self, d):
        """Progress hook for youtube-dl"""
        if d["status"] == "downloading":
            try:
                downloaded = d.get("downloaded_bytes", 0)
                total = d.get("total_bytes", 0) or d.get("total_bytes_estimate", 0)
                if total:
                    progress = (downloaded / total) * 100
                    self.download_status = f"Downloading: {progress:.1f}%"
                else:
                    self.download_status = "Downloading..."
            except:
                self.download_status = "Downloading..."
        elif d["status"] == "finished":
            self.download_status = "Download complete, processing..."

    def on_playback_finished(self, error, audio_file):
        """Called when playback finishes"""

        if hasattr(self, '_changing_song') and self._changing_song:
            return

        self.stopTimerSignal.emit()
        self.position = 0

        if not (self.repeat_mode and audio_file == self.current_audio_file):
            self.song_loaded = False
            self.song_title = ""
            self.thumbnail_url = ""
            self.channel_name = ""

        if error:
            return

        if self.repeat_mode and audio_file == self.current_audio_file:
            asyncio.run_coroutine_threadsafe(self.replay_audio(audio_file), self.bot.loop)
        else:
            temp_audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
            if audio_file == temp_audio_file and os.path.exists(temp_audio_file):
                asyncio.run_coroutine_threadsafe(delete_file(audio_file), self.bot.loop)

    async def replay_audio(self, audio_file):
        if os.path.exists(audio_file) and audio_file == self.current_audio_file:
            self.position = 0
            source = discord.FFmpegPCMAudio(audio_file)
            self.bot.voice_client.play(
                source,
                after=lambda e: self.on_playback_finished(e, audio_file)
            )
            self.is_playing = True
            self.startTimerSignal.emit()
            self.song_loaded = True

    async def cleanup(self):
        """Clean up resources when application exits"""
        if self.bot.voice_client:
            await self.bot.voice_client.disconnect()
            self.bot.voice_client = None
            temp_audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
            if self.current_audio_file == temp_audio_file and os.path.exists(temp_audio_file):
                await delete_file(temp_audio_file)

        # Note: We don't clear cache here - that's handled by main.py checking settings
        # Just cleanup active resources

    def _update_position(self):
        """Update the position timer"""
        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            self.position = self._position + 1
        else:
            self.stopTimerSignal.emit()
            self.position = 0

    @Slot(result="QVariantMap")
    def get_servers_with_channels(self):
        """Get complete hierarchical structure of servers and their channels"""
        result = {
            "servers": [],
            "channels": {}
        }
        if self.bot:
            # Get all servers
            for guild in self.bot.guilds:
                server_id = str(guild.id)
                result["servers"].append({
                    "name": guild.name,
                    "id": server_id
                })

                # Get channels for this server
                channels = []
                for channel in guild.voice_channels:
                    channels.append({
                        "name": channel.name,
                        "id": str(channel.id)
                    })

                result["channels"][server_id] = channels

        return result

    @Slot(str)
    def extract_urls_from_playlist(self, playlist_url):
        """Extract video URLs from a YouTube playlist (non-blocking)"""
        def extractor():
            try:
                self.download_status = "Extracting playlist info..."

                urls = []
                ydl_opts = {
                    "quiet": True,
                    "no_warnings": True,
                    "extract_flat": "in_playlist",
                    "skip_download": True,
                    "format": None,
                    "playlist_items": "1-100",
                }

                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    info = ydl.extract_info(playlist_url, download=False)

                    if info and "entries" in info:
                        urls.extend([
                            f"https://www.youtube.com/watch?v={entry['id']}"
                            for entry in info["entries"]
                            if entry and "id" in entry
                        ])

                self.urlsExtractedSignal.emit(urls)

            except Exception as e:
                self.download_status = f"Error extracting playlist: {str(e)}"
                self.urlsExtractedSignal.emit([])
            finally:
                self.download_status = ""

        self._yt_pool.submit(extractor)

    @Slot(int, str)
    def resolve_title(self, index, user_input):
        """Resolve the title and channel for a YouTube URL or search term"""
        async def resolver():
            try:
                self.download_status = f"Resolving title for item {index}..."

                title_ydl_opts = {
                    "quiet": True,
                    "no_warnings": True,
                    "extract_flat": True,
                    "skip_download": True,
                    "format": None,
                }

                if user_input.startswith("http"):
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

                self.download_status = ""

            except Exception as e:
                self.titleResolved.emit(index, f"Error: {str(e)}", "", "")
                self.download_status = ""

        asyncio.run_coroutine_threadsafe(resolver(), self.bot.loop)

    @Slot(str, str)
    def connect_to_channel(self, server_id, channel_id):
        """Connect to the specified voice channel"""
        async def connect_wrapper():
            if not server_id or not channel_id:
                print("Error: connect_to_channel called with missing server_id or channel_id")
                return

            self.current_server = server_id
            self.current_channel = channel_id

            selected_server = discord.utils.get(self.bot.guilds, id=int(server_id))
            if not selected_server:
                self.issue.emit("Selected server not found")
                return

            selected_channel = discord.utils.get(selected_server.voice_channels, id=int(channel_id))
            if not selected_channel:
                self.issue.emit("Selected channel not found")
                return

            if all(member.bot for member in selected_channel.members):
                self.issue.emit("Cannot join empty channel")
                return

            if self.bot.voice_client and self.bot.voice_client.is_connected():
                if self.bot.voice_client.channel.id == int(channel_id):
                    return
                else:
                    await self.bot.voice_client.disconnect()
                    self.bot.voice_client = None
                    self._reset_playback_state()

            try:
                self.bot.voice_client = await selected_channel.connect()
                self.voice_connected = True
                self.download_status = ""
            except Exception as e:
                self.issue.emit(f"Failed to connect: {str(e)}")

        asyncio.run_coroutine_threadsafe(connect_wrapper(), self.bot.loop)

    def _reset_playback_state(self):
        """Reset all playback-related states"""
        self.is_playing = False
        self.song_loaded = False
        self.stopTimerSignal.emit()
        self.position = 0
        self.song_title = ""
        self.thumbnail_url = ""
        self.channel_name = ""
        self.voice_connected = False

    @Slot()
    def disconnect_voice(self):
        """Disconnect from voice channel"""
        self._disconnecting = True  # Set flag immediately

        async def disconnect_wrapper():
            try:
                self.stop_playing()

                if self.bot.voice_client:
                    await self.bot.voice_client.disconnect()
                    self.bot.voice_client = None
                    self._voice_connected = False

                    await asyncio.sleep(0.2)
            finally:
                self._disconnecting = False

        asyncio.run_coroutine_threadsafe(disconnect_wrapper(), self.bot.loop)

    @Slot(result=str)
    def get_invitation_link(self):
        """Generate an OAuth2 invitation link for the bot with specified permissions"""
        if self.bot and self.bot.user:
            client_id = str(self.bot.user.id)
            permissions = 3212288  # read message history, view channels, speak, connect
            return f"https://discord.com/api/oauth2/authorize?client_id={client_id}&permissions={permissions}&scope=bot"
        else:
            self.issue.emit("Bot is not connected yet")
            return ""

    @Slot()
    def update_servers(self):
        """Update the list of available servers"""
        if self.bot:
            self.servers = [{"name": guild.name, "id": str(guild.id)} for guild in self.bot.guilds]

    @Slot()
    def update_channels(self):
        """Update the list of available voice channels"""
        if not self.bot or not self.current_server:
            self.channels = []
        else:
            server = discord.utils.get(self.bot.guilds, id=int(self.current_server))
            if server:
                self.channels = [{"name": channel.name, "id": str(channel.id)} for channel in server.voice_channels]
            else:
                self.channels = []

    @Slot(result=str)
    def get_cache_directory(self):
        """Get the audio cache directory path"""
        return self.audio_cache.cache_dir

    @Slot("QVariantList")
    def download_all_playlist_items(self, urls):
        """Download all playlist items to cache with parallel processing based on user settings"""
        async def downloader():
            cached_count = 0
            non_cached_urls = []
            for i, url in enumerate(urls):
                if self.audio_cache.get_cached_file(url) is not None:
                    cached_count += 1
                else:
                    non_cached_urls.append((i, url))

            non_cached_total = len(non_cached_urls)

            if non_cached_total == 0:
                self.download_status = "All items already cached"
                return

            self.batchDownloadProgressChanged.emit(0, non_cached_total, "Downloading playlist items...")

            max_parallel_downloads = self._settings.value("maxParallelDownloads", 3, type=int)
            downloaded_count = 0
            semaphore = asyncio.Semaphore(max_parallel_downloads)
            download_tasks = []

            async def download_item(url_index, url):
                nonlocal downloaded_count
                idx, current_url = url_index, url

                async with semaphore:
                    try:
                        self.itemDownloadStarted.emit(current_url, idx)

                        import tempfile
                        temp_dir = tempfile.mkdtemp()
                        temp_path = os.path.join(temp_dir, "audio.webm")

                        ydl_opts = {
                            "format": "bestaudio/best",
                            "outtmpl": temp_path,
                            "noplaylist": True,
                            "quiet": True,
                            "no_warnings": True
                        }

                        loop = asyncio.get_event_loop()
                        info = await loop.run_in_executor(
                            self._yt_pool,
                            lambda: self._extract_video_info(current_url, ydl_opts)
                        )

                        if os.path.exists(temp_path) and os.path.getsize(temp_path) > 0:
                            cached_path = self.audio_cache.add_file(current_url, temp_path, info)
                        else:
                            print(f"Error: Downloaded file is missing or empty: {temp_path}")

                        import shutil
                        shutil.rmtree(temp_dir, ignore_errors=True)

                    except Exception as e:
                        print(f"Error downloading {current_url}: {str(e)}")
                    finally:
                        self.itemDownloadCompleted.emit(current_url, idx)
                        downloaded_count += 1
                        self.batchDownloadProgressChanged.emit(
                            downloaded_count, non_cached_total,
                            "Downloading playlist items..."
                        )

            for url_index, url in non_cached_urls:
                download_tasks.append(download_item(url_index, url))

            await asyncio.gather(*download_tasks)

            self.batchDownloadProgressChanged.emit(
                non_cached_total, non_cached_total, "Download complete!"
            )

            max_cache_size_mb = self._settings.value("maxCacheSize", 1024, type=int)
            self.audio_cache.cleanup(max_size_mb=max_cache_size_mb)

        asyncio.run_coroutine_threadsafe(downloader(), self.bot.loop)

    def _extract_video_info(self, url, ydl_opts):
        """Helper method to run yt_dlp in thread pool"""
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            return ydl.extract_info(url, download=True)

    @Slot(str, int, int, result=str)
    def process_thumbnail(self, url, size=96, corner_radius=6):
        """
        Process a thumbnail image to be square with rounded corners.
        Returns a data URL for use in QML.

        Args:
            url (str): URL or path of the image
            size (int): Size of the output square image
            corner_radius (int): Radius of the rounded corners

        Returns:
            str: Data URL containing the processed image
        """
        if not url or url.startswith("data:"):
            return url  # Already a data URL or empty

        # For remote URLs, download the image to a temporary file
        if url.startswith("http"):
            import tempfile
            import requests

            try:
                response = requests.get(url, timeout=5)
                if response.status_code != 200:
                    return ""

                with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
                    tmp.write(response.content)
                    tmp_path = tmp.name

                processed = create_rounded_thumbnail(tmp_path, size, corner_radius)
                os.unlink(tmp_path)  # Delete temp file

            except Exception as e:
                print(f"Error downloading image: {e}")
                return ""
        else:
            # Local file
            processed = create_rounded_thumbnail(url, size, corner_radius)

        if processed is None:
            return ""

        # Convert to data URL
        buffer = QBuffer()
        buffer.open(QIODevice.WriteOnly)
        processed.save(buffer, "PNG")
        image_data = buffer.data().toBase64().data().decode("ascii")

        return f"data:image/png;base64,{image_data}"
    
    @Slot(str)
    def save_token(self, token):
        """Save the token and restart the application"""
        if not token or token.strip() == "":
            self.download_status = "Invalid token"
            return

        token_path = config.get_token_path()
        with open(token_path, "w") as f:
            f.write(token.strip())

        QTimer.singleShot(0, self.restart_application)

    @Slot()
    def restart_application(self):
        """Restart the application"""
        import sys
        import os

        python = sys.executable
        script = os.path.abspath(sys.argv[0])
        args = sys.argv[1:]

        os.execl(python, python, script, *args)
        
    @Slot(result=str)
    def get_token(self):
        """Get the current token from the token file"""
        token_path = config.get_token_path()
        if os.path.exists(token_path):
            with open(token_path, "r") as f:
                return f.read().strip()
        return ""
        
    @Slot(float)
    def set_volume(self, value):
        """Slot for setting volume from QML"""
        self.volume = value