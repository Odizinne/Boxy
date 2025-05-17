import discord

class AudioLevelSource(discord.AudioSource):
    def __init__(self, original_source, bridge):
        self.original = original_source
        self.bridge = bridge
        self.last_update_time = 0
        self.update_interval = 0.032
        
    def read(self):
        data = self.original.read()
        
        if data:
            import time
            current_time = time.time()
            if current_time - self.last_update_time >= self.update_interval:
                if len(data) >= 2:
                    import audioop
                    rms = audioop.rms(data, 2)
                    max_rms = 32768 
                    level = min(1.0, rms / (max_rms * 0.5)) 
                    
                    self.bridge.audio_level = level
                    self.last_update_time = current_time
        
        return data

    @property
    def volume(self):
        return getattr(self.original, 'volume', 1.0)
        
    @volume.setter
    def volume(self, value):
        if hasattr(self.original, 'volume'):
            self.original.volume = value
        
    def is_opus(self):
        return getattr(self.original, 'is_opus', lambda: False)()
        
    def cleanup(self):
        if hasattr(self.original, 'cleanup'):
            self.original.cleanup()