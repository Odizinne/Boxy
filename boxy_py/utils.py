import os
import sys
import asyncio
import aiohttp
from youtube_search import YoutubeSearch
from PySide6.QtGui import QImage, QPainter, QPainterPath
from PySide6.QtCore import Qt


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
        
def create_rounded_thumbnail(image_path, size=96, corner_radius=6):
    """
    Process an image to be square with rounded corners.
    
    Args:
        image_path (str): Path to the image file
        size (int): Size of the output square image
        corner_radius (int): Radius of the rounded corners
        
    Returns:
        QImage: Processed image, or None if processing failed
    """
    try:
        # Load the original image
        original = QImage(image_path)
        if original.isNull():
            return None
            
        # Calculate center crop to make it square
        width = original.width()
        height = original.height()
        
        if width > height:
            # Landscape image - crop left and right
            x_offset = (width - height) // 2
            crop_rect = (x_offset, 0, height, height)
        else:
            # Portrait or square image - crop top and bottom
            y_offset = (height - width) // 2
            crop_rect = (0, y_offset, width, width)
            
        # Crop to square
        cropped = original.copy(*crop_rect)
        
        # Scale to desired size
        scaled = cropped.scaled(size, size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        
        # Create rounded version
        rounded = QImage(size, size, QImage.Format_ARGB32)
        rounded.fill(Qt.transparent)
        
        # Create a path with rounded corners
        path = QPainterPath()
        path.addRoundedRect(0, 0, size, size, corner_radius, corner_radius)
        
        # Paint the scaled image onto the transparent image using the rounded path
        painter = QPainter(rounded)
        painter.setClipPath(path)
        painter.drawImage(0, 0, scaled)
        painter.end()
        
        return rounded
        
    except Exception as e:
        print(f"Error processing thumbnail: {e}")
        return None