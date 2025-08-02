import asyncio
from discord.ext import commands


class BoxyBot(commands.Bot):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.voice_client = None
        self.bridge = None
        self._reconnect_task = None
        self._is_manually_disconnected = False

    async def on_ready(self):
        self._is_manually_disconnected = False
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
        if self._is_manually_disconnected:
            return
            
        if self.bridge:
            self.bridge.status = "Disconnected"
        
        # Cancel any existing reconnect task
        if self._reconnect_task and not self._reconnect_task.done():
            self._reconnect_task.cancel()
            
        # Start monitoring for reconnection
        self._reconnect_task = asyncio.create_task(self._monitor_reconnection())
            
    async def _monitor_reconnection(self):
        """Monitor for reconnection and update status accordingly"""
        try:
            # Wait a bit to see if we reconnect automatically
            await asyncio.sleep(2)
            
            # If we're still disconnected after a short wait, show connecting status
            if not self.is_ready() and self.bridge and not self._is_manually_disconnected:
                self.bridge.status = "Connecting..."
                
            # Wait for reconnection or timeout
            reconnect_timeout = 30  # 30 seconds timeout
            start_time = asyncio.get_event_loop().time()
            
            while not self.is_ready() and not self._is_manually_disconnected:
                current_time = asyncio.get_event_loop().time()
                if current_time - start_time > reconnect_timeout:
                    if self.bridge:
                        self.bridge.status = "Connection failed"
                    break
                    
                await asyncio.sleep(1)
                
        except asyncio.CancelledError:
            # Task was cancelled, which is fine
            pass
        except Exception as e:
            print(f"Error in reconnection monitor: {e}")

    async def close(self):
        """Override close to mark as manually disconnected"""
        self._is_manually_disconnected = True
        if self._reconnect_task and not self._reconnect_task.done():
            self._reconnect_task.cancel()
        await super().close()