import discord
from discord.ext import commands
import yt_dlp
import os
import time
from youtube_search import YoutubeSearch

intents = discord.Intents.default()
intents.message_content = True
intents.voice_states = True

class BoxyBot(commands.Bot):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.voice_client = None

    async def on_ready(self):
        print(f'We have logged in as {self.user}')

boxy = BoxyBot(command_prefix='/', intents=intents)

@boxy.event
async def on_voice_state_update(member, before, after):
    voice_state = member.guild.voice_client
    if voice_state is None:
        return 

    if len(voice_state.channel.members) == 1:
        await voice_state.disconnect()

@boxy.command(name='play')
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

    audio_file = os.path.abspath('downloaded_audio.webm')

    delete_file(audio_file)

    if not search.startswith('http'):
        await ctx.send('Searching...')
        search = get_first_video_url(search)

    if search is None:
        await ctx.send("You should tell me what you'd like to listen to.")
        return

    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': audio_file,
        'noplaylist': True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(search, download=True)
        song_name = info['title']

    if os.path.exists(audio_file):
        voice_client.play(discord.FFmpegPCMAudio(audio_file), after=lambda e: delete_file(audio_file))
        await ctx.send(f'Playing: {song_name}')
    else:
        await ctx.send(f'Ups! Something went wrong. You should tell it to Odizinne.')

    boxy.voice_client = voice_client
    
def delete_file(file_path):
    while True:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
            break
        except PermissionError:
            time.sleep(.1)

def get_first_video_url(keywords):
    results = YoutubeSearch(keywords, max_results=1).to_dict()
    if results:
        first_result = results[0]
        video_url = f"https://www.youtube.com{first_result['url_suffix']}"
        return video_url
    else:
        return None

@boxy.command(name='stop')
async def stop(ctx):
    if ctx.voice_client is not None:
        if isinstance(ctx.voice_client.source, discord.FFmpegPCMAudio):
            ctx.voice_client.source.cleanup()
        ctx.voice_client.stop()
        await ctx.voice_client.disconnect()
        audio_file = os.path.abspath('downloaded_audio.webm')
        delete_file(audio_file)
        await ctx.send('Stopped playing music and disconnected from the channel.')
        boxy.voice_client = None
    else:
        await ctx.send('No music is playing.')

@boxy.command(name='pause')
async def pause(ctx):
    if ctx.voice_client is not None and ctx.voice_client.is_playing():
        ctx.voice_client.pause()
        await ctx.send('Paused the music.')
    else:
        await ctx.send('No music is playing.')

@boxy.command(name='resume')
async def resume(ctx):
    if ctx.voice_client is not None and ctx.voice_client.is_paused():
        ctx.voice_client.resume()
        await ctx.send('Resumed the music.')
    else:
        await ctx.send('No music is paused.')

def get_token():
    dir_path = os.path.dirname(os.path.realpath(__file__))
    with open(os.path.join(dir_path, 'token.txt'), 'r') as file:
        return file.read().strip()

print("Starting the bot...")
boxy.run(get_token())
