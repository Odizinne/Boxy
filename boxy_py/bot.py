import asyncio
from discord.ext import commands


class BoxyBot(commands.Bot):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.voice_client = None
        self.bridge = None
        self._last_failed_reconnect = 0
        self._reconnect_attempts = 0
        self._max_reconnect_attempts = 10
        self._reconnect_delay = 5  
        self._reconnect_task = None
        self._disconnected = False

    async def on_ready(self):
        self._reconnect_attempts = 0
        self._reconnect_delay = 5
        self._disconnected = False
        await self.bridge.update_rich_presence()
        if self.bridge:
            self.bridge.status = "Connected"
            self.bridge._voice_connected = False
            self.bridge.voiceConnectedChanged.emit(False)
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

    async def on_disconnect(self):
        if self._disconnected:
            return
            
        self._disconnected = True
        
        if self.bridge:
            self.bridge.status = "Disconnected"
        
        if not self._reconnect_task or self._reconnect_task.done():
            self._reconnect_task = asyncio.create_task(self._attempt_reconnect())
            
    async def _attempt_reconnect(self):
        while self._disconnected and self._reconnect_attempts < self._max_reconnect_attempts:
            current_delay = min(self._reconnect_delay * (2 ** min(self._reconnect_attempts, 3)), 60)
            
            if self.bridge:
                self.bridge.status = f"Connecting... (Attempt {self._reconnect_attempts + 1})"
            
            await asyncio.sleep(current_delay)
            
            try:
                if self.bridge:
                    self.bridge.status = "Connecting..."
                
                self._reconnect_attempts += 1
                await asyncio.sleep(5)
                
                if not self.is_closed() and self.is_ready():
                    self._disconnected = False
                    if self.bridge:
                        self.bridge.status = "Connected"  
                    return
                    
            except Exception as e:
                print(f"Reconnection attempt failed: {e}")