import asyncio
import os
import concurrent.futures
import json
import discord
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, QBuffer, QIODevice, QSettings
import yt_dlp
from youtube_search import YoutubeSearch

from boxy_py.utils import get_first_video_url, create_rounded_thumbnail
import boxy_py.config as config
from boxy_py.audio_cache import AudioCache
from boxy_py.audio_level_source import AudioLevelSource

class BotBridge(QObject):
    statusChanged = Signal(str)
    playStateChanged = Signal(bool)
    songChanged = Signal(str)
    placeholderStatusChanged = Signal(str)
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
    mediaSessionActiveChanged = Signal(bool)
    bulkCurrentChanged = Signal(int)
    bulkTotalChanged = Signal(int)
    audioLevelChanged = Signal(float)
    startAudioLevelTimer = Signal()
    stopAudioLevelTimer = Signal()
    seekingEnabledChanged = Signal(bool)
    resolvingChanged = Signal(bool)
    downloadingChanged = Signal(bool)
    downloadProgressChanged = Signal(float)
    downloadProgressTotalChanged = Signal(float)
    bulkDownloadingChanged = Signal(bool)

    def __init__(self, bot):
        super().__init__()
        self._settings = QSettings("Odizinne", "Boxy")
        self._media_session_active = False
        self._status = "Connecting..."
        self._is_playing = False
        self._song_title = ""
        self._placeholder_status = ""
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
        self._volume = self._settings.value("volume", 0.8, type=float)
        self._bulk_current = 0
        self._bulk_total = 0
        self._audio_level = 0.0
        self._seeking_enabled = True
        self._resolving = False
        self._downloading = False
        self._download_progress = 0.0
        self._download_progress_total = 1.0
        self._bulk_downloading = False

        self.bot = bot
        self.current_audio_file = None
        self.current_url = None
        self._changing_song = False

        self.audio_cache = AudioCache()
        self.max_cache_size_mb = self._settings.value("maxCacheSize", 1024, type=int)

        self._position_timer = QTimer(self)
        self._position_timer.setInterval(1000)
        self._position_timer.timeout.connect(self._update_position)

        self.startTimerSignal.connect(self._position_timer.start)
        self.stopTimerSignal.connect(self._position_timer.stop)

        self._yt_pool = concurrent.futures.ThreadPoolExecutor(max_workers=2, thread_name_prefix="yt_worker")

    def __del__(self):
        """Clean up resources when object is destroyed"""
        if hasattr(self, "_yt_pool"):
            self._yt_pool.shutdown(wait=False)

    def _update_audio_level(self):
        """This is now just a fallback in case the audio source isn't providing levels"""
        if not self.is_playing:
            self.audio_level = 0.0

    @Property(float, notify=downloadProgressChanged)
    def download_progress(self):
        return self._download_progress

    @download_progress.setter
    def download_progress(self, value):
        if self._download_progress != value:
            self._download_progress = value
            self.downloadProgressChanged.emit(value)

    @Property(float, notify=downloadProgressTotalChanged)
    def download_progress_total(self):
        return self._download_progress_total

    @download_progress_total.setter
    def download_progress_total(self, value):
        if self._download_progress_total != value:
            self._download_progress_total = value
            self.downloadProgressTotalChanged.emit(value)

    @Property(float, notify=audioLevelChanged)
    def audio_level(self):
        return self._audio_level
    
    @audio_level.setter
    def audio_level(self, value):
        if abs(self._audio_level - value) > 0.02:  
            self._audio_level = value
            self.audioLevelChanged.emit(value)

    @Property(int, notify=bulkCurrentChanged)
    def bulk_current(self):
        return self._bulk_current
    
    @bulk_current.setter
    def bulk_current(self, value):
        if self._bulk_current != value:
            self._bulk_current = value
            self.bulkCurrentChanged.emit(value)

    @Property(int, notify=bulkTotalChanged)
    def bulk_total(self):
        return self._bulk_total
    
    @bulk_total.setter
    def bulk_total(self, value):
        if self._bulk_total != value:
            self._bulk_total = value
            self.bulkTotalChanged.emit(value)

    @Property(bool, notify=seekingEnabledChanged)
    def seeking_enabled(self):
        return self._seeking_enabled
    
    @seeking_enabled.setter
    def seeking_enabled(self, value):
        if self._seeking_enabled != value:
            self._seeking_enabled = value
            self.seekingEnabledChanged.emit(value)

    @Property(bool, notify=bulkDownloadingChanged)
    def bulk_downloading(self):
        return self._bulk_downloading
    
    @bulk_downloading.setter
    def bulk_downloading(self, value):
        if self._bulk_downloading != value:
            self._bulk_downloading = value
            self.bulkDownloadingChanged.emit(value)

    @Property(bool, notify=resolvingChanged)
    def resolving(self):
        return self._resolving
    
    @resolving.setter
    def resolving(self, value):
        if self._resolving != value:
            self._resolving = value
            self.resolvingChanged.emit(value)

    @Property(bool, notify=downloadingChanged)
    def downloading(self):
        return self._downloading
    
    @downloading.setter
    def downloading(self, value):
        if self._downloading != value:
            self._downloading = value
            self.downloadingChanged.emit(value)

    @Property(bool, notify=mediaSessionActiveChanged)
    def media_session_active(self):
        return self._media_session_active
    
    @media_session_active.setter
    def media_session_active(self, value):
        if self._media_session_active != value:
            self._media_session_active = value
            self.mediaSessionActiveChanged.emit(value)
    
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
    
    @Property(str, notify=placeholderStatusChanged)
    def placeholder_status(self):
        return self._placeholder_status
        
    @placeholder_status.setter
    def placeholder_status(self, value):
        if self._placeholder_status != value:
            self._placeholder_status = value
            self.placeholderStatusChanged.emit(value)
    
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
                if hasattr(self.bot.voice_client.source, 'original') and hasattr(self.bot.voice_client.source.original, 'volume'):
                    self.bot.voice_client.source.original.volume = value
                elif hasattr(self.bot.voice_client.source, 'volume'):
                    self.bot.voice_client.source.volume = value
            self.volumeChanged.emit(value)

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
                    for item in playlist_data:
                        if "channelName" not in item:
                            item["channelName"] = ""
                    playlist_name = os.path.splitext(os.path.basename(filename))[0]
                    self.playlistLoaded.emit(playlist_data, playlist_name)
        except Exception as e:
            self.playlistSaved.emit(f"Error loading playlist: {str(e)}")

    async def _stop_playing_async(self):
        """Async version of stop_playing that can be awaited"""
        self.stopAudioLevelTimer.emit()
        
        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            self.bot.voice_client.stop()
            self.media_session_active = False
            self.is_playing = False
            self.stopTimerSignal.emit()
            self.position = 0
            self.song_title = ""
            self.song_loaded = False
            self.current_audio_file = None
            self.current_url = None
            self.placeholder_status = ""
            self.thumbnail_url = ""
            self.channel_name = ""
            self.audio_level = 0

            if self.bot:
                await self.bot.change_presence(activity=None)

    @Slot()
    def stop_playing(self):
        """Stop playback and clean up resources"""
        asyncio.run_coroutine_threadsafe(self._stop_playing_async(), self.bot.loop)

    @Slot()
    def toggle_playback(self):
        """Toggle play/pause state"""
        asyncio.run_coroutine_threadsafe(self._toggle_playback_async(), self.bot.loop)

    async def _toggle_playback_async(self):
        """Async version of toggle_playback that can be awaited"""
        if not self.bot.voice_client:
            return

        should_be_playing = not (self.bot.voice_client.is_playing())

        if should_be_playing and self.bot.voice_client.is_paused():
            self.bot.voice_client.resume()
            self.is_playing = True
            self.startAudioLevelTimer.emit()
            self.startTimerSignal.emit()
        elif not should_be_playing and self.bot.voice_client.is_playing():
            self.bot.voice_client.pause()
            self.is_playing = False
            self.stopAudioLevelTimer.emit() 
            self.stopTimerSignal.emit()
            self.audio_level = 0

    @Slot(bool)
    def set_repeat_mode(self, enabled):
        """Set repeat mode on/off"""
        self.repeat_mode = enabled

    @Slot(float)
    def seek(self, position):
        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            self.seeking_enabled = False
            was_playing = self.bot.voice_client.is_playing()
            position_ms = int(position * 1000)

            if self._position_timer.isActive():
                self.stopTimerSignal.emit()

            source = discord.FFmpegPCMAudio(
                self.current_audio_file,
                before_options=f"-ss {position_ms}ms"
            )
            volume_transformer = discord.PCMVolumeTransformer(source, volume=self._volume)
            level_analyzer = AudioLevelSource(volume_transformer, self)
            self.bot.voice_client.source = level_analyzer

            self.position = position

            if was_playing:
                self.bot.voice_client.resume()
                self.startTimerSignal.emit()
            else:
                self.bot.voice_client.pause()

            self.seeking_enabled = True

    @Slot(str, result=bool)
    def find_and_join_user(self, user_id):
        """Find a user by ID and join their voice channel if they are in one."""
        if not user_id or not user_id.isdigit():
            return False

        user_id = int(user_id)

        for guild in self.bot.guilds:
            for voice_channel in guild.voice_channels:
                for member in voice_channel.members:
                    if member.id == user_id:
                        server_id = str(guild.id)
                        channel_id = str(voice_channel.id)
                        self.connect_to_channel(server_id, channel_id)
                        return True

        return False

    @Slot(str)
    def play_url(self, url):
        """Play audio from URL or search term"""
        async def play_wrapper():
            self.stopTimerSignal.emit()
            self.position = 0
            self.duration = 0
            if not self._current_channel or not self._current_server:
                default_user_id = self._settings.value("autoJoinUserId", "", type=str)
                if default_user_id and self.find_and_join_user(default_user_id):
                    for _ in range(50): 
                        if self.voice_connected and self.bot.voice_client and self.bot.voice_client.is_connected():
                            break
                        await asyncio.sleep(0.1)
                    if not self.voice_connected:
                        self.issue.emit("Failed to connect to voice channel")
                        return
                else:
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

            if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
                self._changing_song = True
                self.bot.voice_client.stop()
                for _ in range(30):  
                    if not self.bot.voice_client.is_playing() and not self.bot.voice_client.is_paused():
                        break
                    await asyncio.sleep(0.1)
            else:
                self._changing_song = False

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
    
        self.placeholder_status = "Preparing..."
        self.stopTimerSignal.emit()
        self._position = 0
        self._song_loaded = False
    
        url = search if search.startswith("http") else get_first_video_url(search)
        if url is None:
            self.placeholder_status = "No video found"
            return
        
        self.media_session_active = True
    
        cached = self.audio_cache.get_cached_file(url)
        if cached:
            audio_file, info = cached
            await self._play_cached_file(audio_file, info, url)
        else:
            await self._download_and_play_file(url)

    async def _play_cached_file(self, audio_file, info, url):
        """Play a file that's already in the cache"""
        song_name = info['title']
        channel_name = info['channel']
        self.duration = info['duration']
        self.channel_name = channel_name
        self.thumbnail_url = info['thumbnail']

        self.song_title = song_name
        self.placeholder_status = "Using cached file..."

        self.current_audio_file = audio_file
        self.current_url = url

        await self._start_playback(audio_file)

    async def _download_and_play_file(self, url):
        """Download a file and add it to cache before playing"""
        self.downloading = True
        try:
            import tempfile
            temp_dir = tempfile.mkdtemp()
            temp_file = os.path.join(temp_dir, "audio.webm")

            ydl_opts = {
                "format": "bestaudio/best",
                "outtmpl": temp_file,
                "noplaylist": True,
                "progress_hooks": [self.download_hook],
                "quiet": True,
                "no_warnings": True
            }

            self.placeholder_status = "Extracting video info..."

            loop = asyncio.get_event_loop()
            info = await loop.run_in_executor(
                self._yt_pool,
                lambda: self._extract_video_info(url, ydl_opts)
            )

            song_name = info["title"]
            channel_name = info.get("channel", "") or info.get("uploader", "")
            self.duration = info.get("duration", 0)
            self.channel_name = channel_name
            self.thumbnail_url = info.get("thumbnail") or info.get("thumbnails", [{}])[0].get("url", "")
            self.song_title = song_name
            audio_file = self.audio_cache.add_file(url, temp_file, info)

            max_cache_size_mb = self._settings.value("maxCacheSize", 1024, type=int)
            self.audio_cache.cleanup(max_size_mb=max_cache_size_mb)

            cache_info = self.get_cache_info()
            self.cacheInfoUpdated.emit(
                cache_info['total_size'],
                cache_info['file_count'],
                cache_info['cache_location']
            )

            self.current_audio_file = audio_file
            self.current_url = url
            self.downloading = False

            await self._start_playback(audio_file)

            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

        except Exception as e:
            self.placeholder_status = f"Error: {str(e)}"

    async def _start_playback(self, audio_file):
        """Start playing an audio file"""
        try:
            if os.path.exists(audio_file):
                self.placeholder_status = "Starting playback..."
                if self.bot.voice_client:
                    self.position = 0
                    source = discord.FFmpegPCMAudio(audio_file)
                    volume_transformer = discord.PCMVolumeTransformer(source, volume=self._volume)
                    level_analyzer = AudioLevelSource(volume_transformer, self)

                    self.bot.voice_client.play(
                        level_analyzer,
                        after=lambda e: self.on_playback_finished(e, audio_file)
                    )
                    self.is_playing = True
                    self.startAudioLevelTimer.emit()  
                    self.placeholder_status = ""

                    await asyncio.sleep(0.2)

                    self.song_loaded = True
                    self.startTimerSignal.emit()

                    await self.update_rich_presence()
            else:
                self.placeholder_status = "Error: Audio file not found"
        except Exception as e:
            self.placeholder_status = f"Playback error: {str(e)}"

    async def update_rich_presence(self):
        if not self.bot or not self.song_title:
            return

        if self.is_playing and self.song_title:
            activity = discord.Activity(
                type=discord.ActivityType.listening,
                name=self.song_title,
                details=f"by {self.channel_name}" if self.channel_name else None,
                state="via Boxy Music Bot"
            )

            await self.bot.change_presence(activity=activity)
        else:
            await self.bot.change_presence(activity=None)

    def download_hook(self, d):
        """Progress hook for youtube-dl"""
        if d["status"] == "downloading":
            try:
                downloaded = d.get("downloaded_bytes", 0)
                total = d.get("total_bytes", 0) or d.get("total_bytes_estimate", 0)
                if total:
                    progress = (downloaded / total)
                    self.download_progress = progress
                    self.download_progress_total = 1.0
                    self.placeholder_status = f"Downloading: {progress * 100:.1f}%"
                else:
                    self.placeholder_status = "Downloading..."
            except:
                self.placeholder_status = "Downloading..."
                self.download_progress = 0.0
                self.download_progress_total = 1.0
        elif d["status"] == "finished":
            self.placeholder_status = "Download complete, processing..."

    def on_playback_finished(self, error, audio_file):
        """Called when playback finishes"""
        self.stopAudioLevelTimer.emit() 

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

        if not (self.repeat_mode and audio_file == self.current_audio_file):
            asyncio.run_coroutine_threadsafe(self.update_rich_presence(), self.bot.loop)

    async def replay_audio(self, audio_file):
        if os.path.exists(audio_file) and audio_file == self.current_audio_file:
            self.position = 0
            source = discord.FFmpegPCMAudio(audio_file)
            volume_transformer = discord.PCMVolumeTransformer(source, volume=self._volume)
            level_analyzer = AudioLevelSource(volume_transformer, self)

            self.bot.voice_client.play(
                level_analyzer,
                after=lambda e: self.on_playback_finished(e, audio_file)
            )
            self.is_playing = True
            self.startAudioLevelTimer.emit() 
            self.startTimerSignal.emit()
            self.song_loaded = True

    async def cleanup(self):
        """Clean up resources when application exits"""
        self.stopAudioLevelTimer.emit() 
        if self.bot.voice_client:
            await self.bot.voice_client.disconnect()
            self.bot.voice_client = None
    
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
            for guild in self.bot.guilds:
                server_id = str(guild.id)
                result["servers"].append({
                    "name": guild.name,
                    "id": server_id
                })
    
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
                self.placeholder_status = "Extracting playlist info..."
    
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
                self.placeholder_status = f"Error extracting playlist: {str(e)}"
                self.urlsExtractedSignal.emit([])
            finally:
                self.placeholder_status = ""
    
        self._yt_pool.submit(extractor)
    
    @Slot(int, str)
    def resolve_title(self, index, user_input):
        """Resolve the title and channel for a YouTube URL or search term"""
        async def resolver():
            self.resolving = True
            try:
                self.placeholder_status = f"Resolving title for item {index}..."
    
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
    
                self.placeholder_status = ""
    
            except Exception as e:
                self.titleResolved.emit(index, f"Error: {str(e)}", "", "")
                self.placeholder_status = ""

            self.resolving = False
    
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
                self.placeholder_status = ""
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
        self._disconnecting = True
    
        async def disconnect_wrapper():
            try:
                await self._stop_playing_async()
    
                if self.bot.voice_client:
                    await self.bot.voice_client.disconnect()
                    self.bot.voice_client = None
                    self.voice_connected = False
                    self._current_channel = ""
                    self._current_server = ""
    
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
            self.bulk_downloading = True
            cached_count = 0
            non_cached_urls = []
            for i, url in enumerate(urls):
                if self.audio_cache.get_cached_file(url) is not None:
                    cached_count += 1
                else:
                    non_cached_urls.append((i, url))
    
            non_cached_total = len(non_cached_urls)
    
            if non_cached_total == 0:
                self.placeholder_status = "All items already cached"
                self.bulk_downloading = False
                return
    
            self.bulk_current = 0
            self.bulk_total = non_cached_total
            self.placeholder_status = "Downloading playlist items..."
    
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
                        self.bulk_current = downloaded_count
                        max_cache_size_mb = self._settings.value("maxCacheSize", 1024, type=int)
                        self.audio_cache.cleanup(max_size_mb=max_cache_size_mb)
                        cache_info = self.get_cache_info()
                        self.cacheInfoUpdated.emit(
                            cache_info['total_size'],
                            cache_info['file_count'],
                            cache_info['cache_location']
                        )
    
            for url_index, url in non_cached_urls:
                download_tasks.append(download_item(url_index, url))
    
            await asyncio.gather(*download_tasks)
            self.placeholder_status = "Download complete!"
            self.bulk_downloading = False
    
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
            return url  
    
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
                os.unlink(tmp_path) 
    
            except Exception as e:
                print(f"Error downloading image: {e}")
                return ""
        else:
            processed = create_rounded_thumbnail(url, size, corner_radius)
    
        if processed is None:
            return ""
    
        buffer = QBuffer()
        buffer.open(QIODevice.WriteOnly)
        processed.save(buffer, "PNG")
        image_data = buffer.data().toBase64().data().decode("ascii")
    
        return f"data:image/png;base64,{image_data}"
    
    @Slot(str)
    def save_token(self, token):
        """Save the token and restart the application"""
        if not token or token.strip() == "":
            self.placeholder_status = "Invalid token"
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

