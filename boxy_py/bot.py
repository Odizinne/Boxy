import asyncio
from discord.ext import commands


class BoxyBot(commands.Bot):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.voice_client = None
        self.bridge = None

    async def on_ready(self):
        await self.bridge.update_rich_presence()
        if self.bridge:
            self.bridge.status = "Connected"
            self.bridge._voice_connected = False
            self.bridge.voiceConnectedChanged.emit(False)
            await asyncio.sleep(0.5)
            self.bridge.update_servers()

    async def on_voice_state_update(self, member, before, after):
        voice_state = member.guild.voice_client
        if voice_state is None:
            return

        if len(voice_state.channel.members) == 1 and voice_state.channel.members[0].id == self.user.id:
            if self.bridge:
                self.bridge._disconnecting = True
                self.bridge.media_session_active = False
                self.bridge.is_playing = False
                self.bridge.stopTimerSignal.emit()
                self.bridge.position = 0
                self.bridge.song_title = ""
                self.bridge.song_loaded = False
                self.bridge.current_audio_file = None
                self.bridge.current_url = None
                self.bridge.placeholder_status = ""
                self.bridge.thumbnail_url = ""
                self.bridge.channel_name = ""
                self.bridge.voice_connected = False
                self.bridge._disconnecting = False

            await voice_state.disconnect()
            self.voice_client = None