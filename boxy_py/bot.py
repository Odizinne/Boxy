import asyncio
import os
import discord
from discord.ext import commands
from boxy_py.utils import get_script_dir, delete_file, get_first_video_url
import yt_dlp

class BoxyBot(commands.Bot):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.voice_client = None
        self.bridge = None

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
                await delete_file(audio_file)
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