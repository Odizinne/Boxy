import discord
from discord.ext import commands
import yt_dlp
import os
import time

intents = discord.Intents.default()
intents.message_content = True

bot = commands.Bot(command_prefix='/', intents=intents)

@bot.event
async def on_ready():
    print(f'We have logged in as {bot.user}')

@bot.command(name='play')
async def play(ctx, url):
    channel = ctx.author.voice.channel
    if ctx.voice_client is not None:
        voice_client = ctx.voice_client
        if isinstance(voice_client.source, discord.FFmpegPCMAudio):
            voice_client.source._process.kill()
        voice_client.stop()
    else:
        voice_client = await channel.connect()

    audio_file = os.path.abspath('downloaded_audio.webm')

    delete_file(audio_file)

    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': audio_file,
        'noplaylist': True,  # Only download single video, not playlist

    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        song_name = info['title']

    if os.path.exists(audio_file):
        voice_client.play(discord.FFmpegPCMAudio(audio_file), after=lambda e: delete_file(audio_file))
        await ctx.send(f'Playing: {song_name}')
    else:
        await ctx.send(f'Could not find file {audio_file}')

def delete_file(file_path):
    while True:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
            break
        except PermissionError:
            time.sleep(.1)

@bot.command(name='stop')
async def stop(ctx):
    if ctx.voice_client is not None:
        if isinstance(ctx.voice_client.source, discord.FFmpegPCMAudio):
            ctx.voice_client.source._process.kill()
        ctx.voice_client.stop()
        await ctx.voice_client.disconnect()
        audio_file = os.path.abspath('downloaded_audio.webm')
        delete_file(audio_file)
        await ctx.send('Stopped playing music and disconnected from the channel.')
    else:
        await ctx.send('No music is playing.')

@bot.command(name='pause')
async def pause(ctx):
    if ctx.voice_client is not None and ctx.voice_client.is_playing():
        ctx.voice_client.pause()
        await ctx.send('Paused the music.')
    else:
        await ctx.send('No music is playing.')

@bot.command(name='resume')
async def resume(ctx):
    if ctx.voice_client is not None and ctx.voice_client.is_paused():
        ctx.voice_client.resume()
        await ctx.send('Resumed the music.')
    else:
        await ctx.send('No music is paused.')

print("Starting the bot...")
bot.run('YOUR_BOT_TOKEN_HERE')
