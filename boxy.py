import asyncio
import os
import sys
import threading
import argparse
import concurrent.futures
import discord
from discord.ext import commands
from PySide6.QtCore import QObject, Signal, Slot, QUrl, Property, QTimer
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
import json
import platform
import yt_dlp
from youtube_search import YoutubeSearch
import signal

intents = discord.Intents.default()
intents.message_content = True
intents.voice_states = True


class BotBridge(QObject):
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

    def __init__(self, bot):
        super().__init__()
        self.bot = bot
        self.is_playing = False
        self.current_guild = None
        self.current_channel = None
        self.repeat_mode = False
        self.current_audio_file = None
        self.current_url = None
        self.song_loaded = False
        self._voice_connected = False
        self._channels = []
        self._current_channel = None
        self._servers = []
        self._current_server = None
        self._duration = 0
        self._position = 0
        self._current_thumbnail_url = None
        self._current_channel_name = ""

        self._position_timer = QTimer(self)
        self._position_timer.setInterval(1000)
        self._position_timer.timeout.connect(self._update_position)

        self.startTimerSignal.connect(self._position_timer.start)
        self.stopTimerSignal.connect(self._position_timer.stop)

        self._yt_pool = concurrent.futures.ThreadPoolExecutor(max_workers=2, thread_name_prefix="yt_worker")

    def __del__(self):
        if hasattr(self, "_yt_pool"):
            self._yt_pool.shutdown(wait=False)

    @Slot()
    def stop_playing(self):
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
                if self.current_audio_file and os.path.exists(self.current_audio_file):
                    await delete_file(self.current_audio_file)
                self.current_audio_file = None
                self.current_url = None
                self.downloadStatusChanged.emit("")
                self._current_thumbnail_url = None
                self.thumbnailChanged.emit("")
                self._current_channel_name = ""
                self.channelNameChanged.emit("")

        asyncio.run_coroutine_threadsafe(stop_wrapper(), self.bot.loop)

    @Slot()
    def connect_to_channel(self):
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

    @Slot(result=str)
    def get_playlists_directory(self):
        """Get platform-specific directory for storing playlists"""
        system = platform.system()
        if system == "Windows":
            base_dir = os.path.normpath(os.path.join(os.environ.get("APPDATA"), "Boxy"))
        elif system == "Darwin":  # macOS
            base_dir = os.path.normpath(os.path.join(os.path.expanduser("~"), "Library", "Application Support", "Boxy"))
        else:  # Linux and other Unix-like
            base_dir = os.path.normpath(os.path.join(os.path.expanduser("~"), ".config", "Boxy"))

        # Create directory if it doesn't exist
        if not os.path.exists(base_dir):
            os.makedirs(base_dir)

        return base_dir

    @Slot(str, list)
    def save_playlist(self, name, items):
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
                    print(playlist_data, playlist_name)
        except Exception as e:
            self.playlistSaved.emit(f"Error loading playlist: {str(e)}")

    @Slot(int, str)
    def resolve_title(self, index, user_input):
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

                    async def extract_url_info():
                        print("Resolve operation using thread pool:", id(self._yt_pool))
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

                self.downloadStatusChanged.emit("")

            except Exception as e:
                print(f"Error resolving title: {e}")
                self.titleResolved.emit(index, f"Error: {str(e)}", "", "")
                self.downloadStatusChanged.emit("")

        asyncio.run_coroutine_threadsafe(resolver(), self.bot.loop)

    @Property(str, notify=channelNameChanged)
    def current_channel_name(self):
        return self._current_channel_name

    @current_channel_name.setter
    def current_channel_name(self, name):
        if self._current_channel_name != name:
            self._current_channel_name = name
            self.channelNameChanged.emit(name)

    @Property(str, notify=thumbnailChanged)
    def current_thumbnail_url(self):
        return self._current_thumbnail_url

    @current_thumbnail_url.setter
    def current_thumbnail_url(self, url):
        if self._current_thumbnail_url != url:
            self._current_thumbnail_url = url
            self.thumbnailChanged.emit(url)

    async def cleanup(self):
        if self.bot.voice_client:
            await self.bot.voice_client.disconnect()
            self.bot.voice_client = None
            if self.current_audio_file and os.path.exists(self.current_audio_file):
                await delete_file(self.current_audio_file)

    def _update_position(self):
        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            self._position += 1
            self.positionChanged.emit(self._position)
        else:
            self.stopTimerSignal.emit()
            self._position = 0
            self.positionChanged.emit(0)

    @Property(list, notify=serversChanged)
    def servers(self):
        return self._servers

    @Slot()
    def update_servers(self):
        if self.bot:
            self._servers = [{"name": guild.name, "id": str(guild.id)} for guild in self.bot.guilds]
            print(f"Servers updated: {self._servers}")
            self.serversChanged.emit(self._servers)

    @Slot(str)
    def set_current_server(self, server_id):
        print(f"Setting current server to: {server_id}")
        self._current_server = server_id
        self.currentServerChanged.emit(server_id)
        self.update_channels()

    @Property(list, notify=channelsChanged)
    def channels(self):
        return self._channels

    @Slot()
    def update_channels(self):
        if not self.bot or not self._current_server:
            self._channels = []
        else:
            server = discord.utils.get(self.bot.guilds, id=int(self._current_server))
            if server:
                self._channels = [{"name": channel.name, "id": str(channel.id)} for channel in server.voice_channels]
            else:
                self._channels = []
        print(f"Channels updated: {self._channels}")
        self.channelsChanged.emit(self._channels)

    @Slot(str)
    def set_current_channel(self, channel_id):
        print(f"Setting current channel to: {channel_id}")
        self._current_channel = channel_id
        self.currentChannelChanged.emit(channel_id)

    @Slot()
    def disconnect_voice(self):
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
                if self.current_audio_file and os.path.exists(self.current_audio_file):
                    await delete_file(self.current_audio_file)
                self.current_audio_file = None
                self.current_url = None
                self.downloadStatusChanged.emit("")
                self._current_thumbnail_url = None
                self.thumbnailChanged.emit("")

        asyncio.run_coroutine_threadsafe(disconnect_wrapper(), self.bot.loop)

    @Property(bool, notify=voiceConnectedChanged)
    def voiceConnected(self):
        return self._voice_connected

    @Slot()
    def toggle_playback(self):
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
        print(f"Repeat mode set to: {enabled}")
        self.repeat_mode = enabled
        self.repeatModeChanged.emit(enabled)

    @Slot(float)
    def seek(self, position):
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

            # Stop current playback if any
            if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
                self.bot.voice_client.stop()
                self.stopTimerSignal.emit()
                self._position = 0
                self.positionChanged.emit(0)

            was_repeat = self.repeat_mode
            self.repeat_mode = False
            await self.play_from_gui(url)
            self.repeat_mode = was_repeat

        asyncio.run_coroutine_threadsafe(play_wrapper(), self.bot.loop)

    async def play_from_gui(self, search):
        if not self.bot.voice_client or not self.bot.voice_client.is_connected():
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
            except Exception as e:
                self.downloadStatusChanged.emit(f"Failed to connect: {str(e)}")
                return

        self.downloadStatusChanged.emit("Preparing...")
        audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")

        if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
            self.bot.voice_client.stop()
            self.stopTimerSignal.emit()
            self._position = 0
            self.positionChanged.emit(0)

        if os.path.exists(audio_file):
            await delete_file(audio_file)
            await asyncio.sleep(0.1)

        url = search if search.startswith("http") else get_first_video_url(search)
        if url is None:
            self.downloadStatusChanged.emit("No video found")
            return

        try:
            ydl_opts = {
                "format": "bestaudio/best",
                "outtmpl": audio_file,
                "noplaylist": True,
                "progress_hooks": [self.download_hook],
            }

            self.downloadStatusChanged.emit("Extracting video info...")
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                song_name = info["title"]
                channel_name = info.get("channel", "") or info.get("uploader", "")
                print(channel_name)
                self._duration = info.get("duration", 0)
                self.durationChanged.emit(self._duration)
                self._current_channel_name = channel_name
                self.songChanged.emit(song_name)
                self.channelNameChanged.emit(channel_name)
                self.current_audio_file = audio_file
                self.current_url = search
                self._current_thumbnail_url = info.get("thumbnail") or info.get("thumbnails", [{}])[0].get("url", "")
                self.thumbnailChanged.emit(self._current_thumbnail_url)

        except Exception as e:
            print(f"Download error: {e}")
            self.downloadStatusChanged.emit(f"Error: {str(e)}")
            return

        try:
            if os.path.exists(audio_file):
                self.downloadStatusChanged.emit("Starting playback...")
                if self.bot.voice_client:
                    self._position = 0
                    self.positionChanged.emit(0)

                    self.bot.voice_client.play(
                        discord.FFmpegPCMAudio(audio_file), after=lambda e: self.on_playback_finished(e, audio_file)
                    )

                    self.is_playing = True
                    self.playStateChanged.emit(True)
                    self.downloadStatusChanged.emit("")
                    self.songLoadedChanged.emit(True)
                    self.startTimerSignal.emit()

        except Exception as e:
            print(f"Playback error: {e}")
            self.downloadStatusChanged.emit(f"Playback error: {str(e)}")

    def download_hook(self, d):
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
            asyncio.run_coroutine_threadsafe(delete_file(audio_file), self.bot.loop)

    async def replay_audio(self, audio_file):
        if os.path.exists(audio_file) and audio_file == self.current_audio_file:
            self._position = 0
            self.positionChanged.emit(0)

            self.bot.voice_client.play(
                discord.FFmpegPCMAudio(audio_file), after=lambda e: self.on_playback_finished(e, audio_file)
            )

            self.is_playing = True
            self.playStateChanged.emit(True)
            self.startTimerSignal.emit()


class BoxyBot(commands.Bot):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.voice_client = None
        self.bridge = None
        # self.loop = asyncio.get_event_loop()

    async def on_ready(self):
        print(f"We have logged in as {self.user}")
        if self.bridge:
            self.bridge.statusChanged.emit("Connected")
            self.bridge._voice_connected = False
            self.bridge.voiceConnectedChanged.emit(False)

            await asyncio.sleep(0.5)
            # First update servers
            self.bridge.update_servers()

    async def on_voice_state_update(self, member, before, after):
        voice_state = member.guild.voice_client
        if voice_state is None:
            return

        if len(voice_state.channel.members) == 1:  # Only bot remains
            # Disconnect from voice
            await voice_state.disconnect()
            self.voice_client = None

            # Update bridge state just like in disconnect_voice
            if self.bridge:
                self.bridge.is_playing = False
                self.bridge._voice_connected = False
                self.bridge.playStateChanged.emit(False)
                self.bridge.songChanged.emit("")
                self.bridge.channelNameChanged.emit("")
                self.bridge.songLoadedChanged.emit(False)
                self.bridge.voiceConnectedChanged.emit(False)

                # Clean up current audio file
                if self.bridge.current_audio_file and os.path.exists(self.bridge.current_audio_file):
                    await delete_file(self.bridge.current_audio_file)
                self.bridge.current_audio_file = None
                self.bridge.current_url = None
                self.bridge.downloadStatusChanged.emit("")

    async def setup_hook(self):
        @self.command(name="play")
        async def play(ctx, *, search):
            if ctx.author.voice is None or ctx.author.voice.channel is None:
                await ctx.send("You need to be in a voice channel to use this command.")
                return

            channel = ctx.author.voice.channel
            if ctx.voice_client is not None:
                voice_client = ctx.voice_client
                if isinstance(voice_client.source, discord.FFmpegPCMAudio):
                    voice_client.source.cleanup()
                voice_client.stop()
            else:
                voice_client = await channel.connect()

            audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
            await delete_file(audio_file)  # Properly await the coroutine

            if not search.startswith("http"):
                await ctx.send("Searching...")
                search = get_first_video_url(search)

            if search is None:
                await ctx.send("You should tell me what you'd like to listen to.")
                return

            ydl_opts = {
                "format": "bestaudio/best",
                "outtmpl": audio_file,
                "noplaylist": True,
            }

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(search, download=True)
                song_name = info["title"]

            if os.path.exists(audio_file):
                # Define an async callback function
                async def after_playing(error):
                    if error:
                        print(f"An error occurred: {error}")
                    await delete_file(audio_file)

                # Convert the async callback to a sync one that runs in the event loop
                def sync_after(error):
                    asyncio.run_coroutine_threadsafe(after_playing(error), self.loop)

                voice_client.play(discord.FFmpegPCMAudio(audio_file), after=sync_after)
                await ctx.send(f"Playing: {song_name}")
            else:
                await ctx.send(f"Ups! Something went wrong. You should tell it to Odizinne.")

            self.voice_client = voice_client

        @self.command(name="stop")
        async def stop(ctx):
            if ctx.voice_client is not None:
                if isinstance(ctx.voice_client.source, discord.FFmpegPCMAudio):
                    ctx.voice_client.source.cleanup()
                ctx.voice_client.stop()
                await ctx.voice_client.disconnect()
                audio_file = os.path.join(get_script_dir(), "downloaded_audio.webm")
                delete_file(audio_file)
                await ctx.send("Stopped playing music and disconnected from the channel.")
                self.voice_client = None
            else:
                await ctx.send("No music is playing.")

        @self.command(name="pause")
        async def pause(ctx):
            if ctx.voice_client is not None and ctx.voice_client.is_playing():
                ctx.voice_client.pause()
                await ctx.send("Paused the music.")
            else:
                await ctx.send("No music is playing.")

        @self.command(name="resume")
        async def resume(ctx):
            if ctx.voice_client is not None and ctx.voice_client.is_paused():
                ctx.voice_client.resume()
                await ctx.send("Resumed the music.")
            else:
                await ctx.send("No music is paused.")


async def delete_file(file_path):
    while True:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
            break
        except PermissionError:
            await asyncio.sleep(0.1)


def get_first_video_url(keywords):
    try:
        results = YoutubeSearch(keywords, max_results=1).to_dict()
        if results:
            first_result = results[0]
            video_url = f"https://www.youtube.com{first_result['url_suffix']}"
            return video_url
    except Exception as e:
        print(f"Error searching video: {e}")
    return None


def get_token():
    token_path = os.path.join(get_script_dir(), "token.txt")

    # Check if token.txt exists
    if not os.path.exists(token_path):
        # Create token.txt with placeholder
        with open(token_path, "w") as file:
            file.write("REPLACE_THIS_WITH_YOUR_BOT_TOKEN")
        print("\ntoken.txt has been created.")
        print(
            "Please replace the placeholder text in token.txt with your Discord bot token and restart the application."
        )
        sys.exit(0)

    # Read the token
    with open(token_path, "r") as file:
        token = file.read().strip()

    # Check if token is still the placeholder
    if token == "REPLACE_THIS_WITH_YOUR_BOT_TOKEN":
        print(
            "\nPlease replace the placeholder text in token.txt with your Discord bot token and restart the application."
        )
        sys.exit(0)

    return token


async def verify_token(token):
    """Verify token before starting the GUI"""
    import aiohttp

    async with aiohttp.ClientSession() as session:
        headers = {"Authorization": f"Bot {token}"}

        try:
            async with session.get("https://discord.com/api/v10/users/@me", headers=headers) as response:
                return response.status == 200
        except Exception as e:
            print(f"Error verifying token: {e}")
            return False


def run_bot_with_gui():
    try:
        token = get_token()
    except Exception as e:
        print(f"Error reading token: {e}")
        sys.exit(1)

    # Verify token before creating any Qt components
    if not asyncio.run(verify_token(token)):
        print("Token was rejected by Discord")
        sys.exit(1)

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    def signal_handler(signum, frame):
        print("\nCtrl+C received. Cleaning up...")
        app.quit()

    signal.signal(signal.SIGINT, signal_handler)

    bot = BoxyBot(command_prefix="/", intents=intents)
    bridge = BotBridge(bot)
    bot.bridge = bridge

    def cleanup():
        asyncio.run_coroutine_threadsafe(bridge.cleanup(), bot.loop).result()

    icon = os.path.join(get_script_dir(), "boxy-orange.png")
    app.setWindowIcon(QIcon(icon))
    app.aboutToQuit.connect(cleanup)

    engine.rootContext().setContextProperty("botBridge", bridge)

    def bot_runner():
        try:
            bot.run(token)
        except Exception as e:
            print(f"Bot error: {e}")
            app.quit()

    bot_thread = threading.Thread(target=bot_runner, daemon=True)
    bot_thread.start()

    qml_path = os.path.join(get_script_dir(), "main.qml")
    engine.load(QUrl.fromLocalFile(qml_path))

    if not engine.rootObjects():
        sys.exit(1)

    sys.exit(app.exec())


def run_bot_no_gui():
    try:
        token = get_token()

        # Verify token first
        if not asyncio.run(verify_token(token)):
            print("Token was rejected by Discord")
            sys.exit(1)

        # Create and run bot only if token is valid
        bot = BoxyBot(command_prefix="/", intents=intents)
        # Don't get event loop here since it will be created by bot.run()
        bot.run(token)
    except Exception as e:
        print(f"Bot error: {e}")
        sys.exit(1)


def get_script_dir():
    return os.path.dirname(os.path.abspath(__file__))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--nogui", action="store_true", help="Run without GUI")
    args = parser.parse_args()

    print("Starting the bot...")
    if args.nogui:
        run_bot_no_gui()
    else:
        run_bot_with_gui()
