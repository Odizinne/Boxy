import asyncio
import os
import discord
from discord.ext import commands
from boxy_py.utils import delete_file


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
            self.bridge.update_servers()

    async def on_voice_state_update(self, member, before, after):
        voice_state = member.guild.voice_client
        if voice_state is None:
            return

        if len(voice_state.channel.members) == 1:
            await voice_state.disconnect()
            self.voice_client = None

            if self.bridge:
                self.bridge.is_playing = False
                self.bridge._voice_connected = False
                self.bridge.playStateChanged.emit(False)
                self.bridge.songChanged.emit("")
                self.bridge.channelNameChanged.emit("")
                self.bridge.songLoadedChanged.emit(False)
                self.bridge.voiceConnectedChanged.emit(False)
                if self.bridge.current_audio_file and os.path.exists(self.bridge.current_audio_file):
                    await delete_file(self.bridge.current_audio_file)
                self.bridge.current_audio_file = None
                self.bridge.current_url = None
                self.bridge.downloadStatusChanged.emit("")