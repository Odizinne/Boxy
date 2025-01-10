import asyncio
import os
import sys
import threading
import argparse
import discord
from discord.errors import LoginFailure
from discord.ext import commands
from PySide6.QtCore import QObject, Signal, Slot, QUrl, Property
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
import yt_dlp
from youtube_search import YoutubeSearch

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
    channelsChanged = Signal(list)  # For updating channel list
    currentChannelChanged = Signal(str)  # For updating selected channel
    serversChanged = Signal(list)  # For updating server list
    currentServerChanged = Signal(str)  # For updating selected server

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

    @Property(list, notify=serversChanged)
    def servers(self):
        return self._servers

    @Slot()
    def update_servers(self):
        if self.bot:
            self._servers = [{"name": guild.name, "id": str(guild.id)} for guild in self.bot.guilds]
            print(f"Servers updated: {self._servers}")  # Debug print
            self.serversChanged.emit(self._servers)

    @Slot(str)
    def set_current_server(self, server_id):
        print(f"Setting current server to: {server_id}")  # Debug print
        self._current_server = server_id
        self.currentServerChanged.emit(server_id)
        self.update_channels()  # Update channels for selected server

    @Property(list, notify=channelsChanged)
    def channels(self):
        return self._channels

    @Slot()
    def update_channels(self):
        if not self.bot or not self._current_server:
            self._channels = []
        else:
            # Find the selected server
            server = discord.utils.get(self.bot.guilds, id=int(self._current_server))
            if server:
                self._channels = [{"name": channel.name, "id": str(channel.id)} for channel in server.voice_channels]
            else:
                self._channels = []
        print(f"Channels updated: {self._channels}")  # Debug print
        self.channelsChanged.emit(self._channels)

    @Slot(str)
    def set_current_channel(self, channel_id):
        print(f"Setting current channel to: {channel_id}")  # Debug print
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
                self.playStateChanged.emit(False)
                self.songChanged.emit("")
                self.songLoadedChanged.emit(False)
                self.voiceConnectedChanged.emit(False)
                if self.current_audio_file and os.path.exists(self.current_audio_file):
                    await delete_file(self.current_audio_file)
                self.current_audio_file = None
                self.current_url = None
                self.downloadStatusChanged.emit("")

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
        elif self.bot.voice_client.is_paused():
            self.bot.voice_client.resume()
            self.is_playing = True

        self.playStateChanged.emit(self.is_playing)

    @Slot(bool)
    def set_repeat_mode(self, enabled):
        print(f"Repeat mode set to: {enabled}")
        self.repeat_mode = enabled
        self.repeatModeChanged.emit(enabled)

    @Slot(str)
    def play_url(self, url):
        async def play_wrapper():
            if not self._current_channel or not self._current_server:
                self.downloadStatusChanged.emit("Please select a server and channel first")
                return

            # First disconnect if already connected
            if self.bot.voice_client:
                if self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused():
                    self.bot.voice_client.stop()
                await self.bot.voice_client.disconnect()
                self.bot.voice_client = None
                self.is_playing = False
                self._voice_connected = False
                self.playStateChanged.emit(False)
                self.songChanged.emit("")
                self.songLoadedChanged.emit(False)
                self.voiceConnectedChanged.emit(False)
                if self.current_audio_file and os.path.exists(self.current_audio_file):
                    await delete_file(self.current_audio_file)
                self.current_audio_file = None
                self.current_url = None
                self.downloadStatusChanged.emit("")

            # Attempt new connection
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

            # Start playback
            was_repeat = self.repeat_mode
            self.repeat_mode = False
            await self.play_from_gui(url)
            self.repeat_mode = was_repeat

        asyncio.run_coroutine_threadsafe(play_wrapper(), self.bot.loop)

    async def play_from_gui(self, search):
        # Only check voice connection if we're not already in the right place
        if not self.bot.voice_client or not self.bot.voice_client.is_connected():
            if not self._current_channel or not self._current_server:
                self.downloadStatusChanged.emit("Please select a server and channel first")
                return

            # First disconnect if already connected
            if self.bot.voice_client:
                if self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused():
                    self.bot.voice_client.stop()
                await self.bot.voice_client.disconnect()
                self.bot.voice_client = None
                self.is_playing = False
                self._voice_connected = False
                self.playStateChanged.emit(False)
                self.songChanged.emit("")
                self.songLoadedChanged.emit(False)
                self.voiceConnectedChanged.emit(False)
                if self.current_audio_file and os.path.exists(self.current_audio_file):
                    await delete_file(self.current_audio_file)
                self.current_audio_file = None
                self.current_url = None
                self.downloadStatusChanged.emit("")

            # Attempt new connection
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

        # Continue with download and playback
        self.downloadStatusChanged.emit("Preparing...")
        audio_file = os.path.abspath("downloaded_audio.webm")

        if self.current_url != search:
            if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
                self.bot.voice_client.stop()

            if os.path.exists(audio_file):
                await delete_file(audio_file)
                await asyncio.sleep(0.1)

            self.current_url = search
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
                    self.songChanged.emit(song_name)
                    self.current_audio_file = audio_file

            except Exception as e:
                print(f"Download error: {e}")
                self.downloadStatusChanged.emit(f"Error: {str(e)}")
                return

        try:
            if os.path.exists(audio_file):
                self.downloadStatusChanged.emit("Starting playback...")
                if self.bot.voice_client:
                    self.bot.voice_client.play(
                        discord.FFmpegPCMAudio(audio_file), after=lambda e: self.on_playback_finished(e, audio_file)
                    )
                    self.is_playing = True
                    self.playStateChanged.emit(True)
                    self.downloadStatusChanged.emit("")
                    self.songLoadedChanged.emit(True)

        except Exception as e:
            print(f"Playback error: {e}")
            self.downloadStatusChanged.emit(f"Playback error: {str(e)}")

    def download_hook(self, d):
        if d["status"] == "downloading":
            try:
                # Calculate download progress
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
        if error:
            print(f"An error occurred: {error}")
            return

        if self.repeat_mode and audio_file == self.current_audio_file:  # Only repeat if it's still the current file
            print("Repeating song...")
            asyncio.run_coroutine_threadsafe(self.replay_audio(audio_file), self.bot.loop)
        else:
            # Clean up if we're not repeating or if it's an old file
            asyncio.run_coroutine_threadsafe(delete_file(audio_file), self.bot.loop)

    async def handle_playback_finished(self, error, audio_file):
        if self.repeat_mode:
            # Instead of calling play_from_gui, directly replay the existing file
            await self.replay_audio(audio_file)
        else:
            # Only delete the file if we're not repeating
            await delete_file(audio_file)

    async def replay_audio(self, audio_file):
        if os.path.exists(audio_file) and audio_file == self.current_audio_file:  # Double check it's still current
            self.bot.voice_client.play(
                discord.FFmpegPCMAudio(audio_file), after=lambda e: self.on_playback_finished(e, audio_file)
            )
            self.is_playing = True
            self.playStateChanged.emit(True)

    def download_hook(self, d):
        if d["status"] == "downloading":
            try:
                # Calculate download progress
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

            audio_file = os.path.abspath("downloaded_audio.webm")
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
                audio_file = os.path.abspath("downloaded_audio.webm")
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
    results = YoutubeSearch(keywords, max_results=1).to_dict()
    if results:
        first_result = results[0]
        video_url = f"https://www.youtube.com{first_result['url_suffix']}"
        return video_url
    else:
        return None


def get_token():
    dir_path = os.path.dirname(os.path.realpath(__file__))
    with open(os.path.join(dir_path, "token.txt"), "r") as file:
        return file.read().strip()


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

    # Only create Qt application if token is valid
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    bot = BoxyBot(command_prefix="/", intents=intents)
    bridge = BotBridge(bot)
    bot.bridge = bridge

    engine.rootContext().setContextProperty("botBridge", bridge)

    def bot_runner():
        try:
            bot.run(token)
        except Exception as e:
            print(f"Bot error: {e}")
            app.quit()

    bot_thread = threading.Thread(target=bot_runner, daemon=True)
    bot_thread.start()

    engine.load(QUrl.fromLocalFile("main.qml"))

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


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--nogui", action="store_true", help="Run without GUI")
    args = parser.parse_args()

    print("Starting the bot...")
    if args.nogui:
        run_bot_no_gui()
    else:
        run_bot_with_gui()
