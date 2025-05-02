import os
import sys
import asyncio
import aiohttp
from youtube_search import YoutubeSearch

def get_script_dir():
    """Get the directory of the current script"""
    return os.path.dirname(os.path.abspath(__file__))

async def delete_file(file_path):
    """Delete a file with retry logic for when the file is in use"""
    while True:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
            break
        except PermissionError:
            await asyncio.sleep(0.1)

def get_first_video_url(keywords):
    """Search YouTube and get the URL of the first result"""
    try:
        results = YoutubeSearch(keywords, max_results=1).to_dict()
        if results:
            first_result = results[0]
            video_url = f"https://www.youtube.com{first_result['url_suffix']}"
            return video_url
    except Exception as e:
        print(f"Error searching video: {e}")
    return None

def get_token():
    """Get the bot token from the token file"""
    token_path = os.path.join(get_script_dir(), "token.txt")

    # Check if token.txt exists
    if not os.path.exists(token_path):
        # Create token.txt with placeholder
        with open(token_path, "w") as file:
            file.write("REPLACE_THIS_WITH_YOUR_BOT_TOKEN")
        print("\ntoken.txt has been created.")
        print(
            "Please replace the placeholder text in token.txt with your Discord bot token and restart the application."
        )
        sys.exit(0)

    # Read the token
    with open(token_path, "r") as file:
        token = file.read().strip()

    # Check if token is still the placeholder
    if token == "REPLACE_THIS_WITH_YOUR_BOT_TOKEN":
        print(
            "\nPlease replace the placeholder text in token.txt with your Discord bot token and restart the application."
        )
        sys.exit(0)

    return token

async def verify_token(token):
    """Verify token before starting the GUI"""
    async with aiohttp.ClientSession() as session:
        headers = {"Authorization": f"Bot {token}"}

        try:
            async with session.get("https://discord.com/api/v10/users/@me", headers=headers) as response:
                return response.status == 200
        except Exception as e:
            print(f"Error verifying token: {e}")
            return False