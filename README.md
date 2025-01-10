# Boxy
yt-dlp discord music bot

## Requierments

- Python 3.13
- Install dependencies: `pip install -r requirements.txt`
- ffmpeg added to path:
  
  Windows: download ffmpeg binaries [here](https://github.com/BtbN/FFmpeg-Builds/releases) and add it to path / next to python executable

  Ubuntu: `sudo apt install ffmpeg`

  Fedora: `sudo dnf in ffmpeg`

  Arch: `sudo pacman -S ffmpeg`

You have to create an application from [discord dev portal](https://discord.com/developers/docs/intro).

## Setup

from boxy.py directory:

`python3 boxy.py` or `python3 boxy.py --nogui`

On first run `token.txt` will be created. Replace placeholder with your bot token from your application.

You can then create an oAuth2 link.

Give it the bot scope.

Under permissions setions, check the following:
- Send messages
- Read message history
- Connect
- Speak
- View channels

You can then invite boxy in your server.

## Usage 

### No gui mode

Discord commands:
- `/play YOUTUBE_URL / KEYWORDS`<br/>
- `/stop`<br/>
- `/pause`<br/>
- `/resume`

### Gui mode

Wait for boxy to connect.

Select server / channel where boxy should join, paste url or type search to textinput and press enter.
