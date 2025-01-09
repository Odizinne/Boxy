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

    @Slot(str)
    def play_url(self, url):
        async def play_wrapper():
            # First ensure we're connected to voice
            if not self.bot.voice_client:
                channel = self.bot.guilds[0].voice_channels[0]
                try:
                    self.bot.voice_client = await channel.connect()
                    self._voice_connected = True
                    self.voiceConnectedChanged.emit(True)
                except Exception as e:
                    self.downloadStatusChanged.emit(f"Failed to connect: {str(e)}")
                    return

            # Rest of your existing play logic
            was_repeat = self.repeat_mode
            self.repeat_mode = False
            await self.play_from_gui(url)
            self.repeat_mode = was_repeat

        asyncio.run_coroutine_threadsafe(play_wrapper(), self.bot.loop)

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

    async def play_from_gui(self, search):
        # Modify the voice connection check to also verify guild connection
        if not self.bot.voice_client or not self.bot.voice_client.is_connected():
            channel = self.bot.guilds[0].voice_channels[0]
            try:
                self.bot.voice_client = await channel.connect()
                self._voice_connected = True
                self.voiceConnectedChanged.emit(True)
            except Exception as e:
                self.downloadStatusChanged.emit(f"Failed to connect: {str(e)}")
                return

        self.downloadStatusChanged.emit("Preparing...")
        audio_file = os.path.abspath("downloaded_audio.webm")

        # Always consider a new search as a fresh start
        if self.current_url != search:
            # Clear current playback state
            if self.bot.voice_client and (self.bot.voice_client.is_playing() or self.bot.voice_client.is_paused()):
                self.bot.voice_client.stop()

            # Clean up old file
            if os.path.exists(audio_file):
                await delete_file(audio_file)
                await asyncio.sleep(0.1)

            # Update current URL before downloading
            self.current_url = search
            url = search if search.startswith("http") else get_first_video_url(search)
            if url is None:
                self.downloadStatusChanged.emit("No video found")
                return

            # Download new file
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

        # Start playback
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
            # Initialize voice state
            self.bridge._voice_connected = False
            self.bridge.voiceConnectedChanged.emit(False)

    async def on_voice_state_update(self, member, before, after):
        voice_state = member.guild.voice_client
        if voice_state is None:
            return
        if len(voice_state.channel.members) == 1:
            await voice_state.disconnect()

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
            delete_file(audio_file)

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
                voice_client.play(discord.FFmpegPCMAudio(audio_file), after=lambda e: delete_file(audio_file))
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
