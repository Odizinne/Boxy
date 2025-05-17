import sys
import os
import threading
import asyncio
import logging
import argparse
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl, QSettings

from boxy_py.bot import BoxyBot
from boxy_py.bridge import BotBridge
from boxy_py.setup_manager import SetupManager
from boxy_py.utils import verify_token  
from boxy_py.config import migrate_playlists_if_needed

import discord
import rc_main

def configure_logging():
    """Configure logging"""
    os.environ["QT_LOGGING_RULES"] = "qt.qpa.*=false"
    discord_player_logger = logging.getLogger('discord.player')
    discord_player_logger.setLevel(logging.WARNING)

def load_setup_window(app, engine, setup_manager):
    """Load the setup window"""
    engine.clearComponentCache()
    for obj in engine.rootObjects():
        obj.deleteLater()
    
    engine.rootContext().setContextProperty("setupManager", setup_manager)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    qml_path = os.path.join(script_dir, "qml/SetupWindow.qml")
    
    engine.load(QUrl.fromLocalFile(qml_path))
    
    if not engine.rootObjects():
        print("Error loading setup UI")
        sys.exit(1)
    
    root = engine.rootObjects()[0]
    root.setupFinished.connect(setup_manager.save_token)
    setup_manager.setupCompleted.connect(lambda token: start_main_app(app, engine, token))

def start_main_app(app, engine, token):
    """Start the main application with the token"""
    engine.clearComponentCache()
    for obj in engine.rootObjects():
        obj.deleteLater()
    
    intents = discord.Intents.default()
    intents.message_content = True
    intents.voice_states = True
    
    bot = BoxyBot(command_prefix="/", intents=intents)
    bridge = BotBridge(bot)
    bot.bridge = bridge
    bot_started = False
    
    def cleanup():
        settings = QSettings("Odizinne", "Boxy")
        clear_on_exit = settings.value("clearCacheOnExit", False, type=bool)
        if clear_on_exit:
            if hasattr(bridge, 'audio_cache'):
                bridge.audio_cache.clear_all()

        if bot_started:
            try:
                if bot.loop.is_running():
                    asyncio.run_coroutine_threadsafe(bridge.cleanup(), bot.loop)
                else:
                    loop = asyncio.new_event_loop()
                    loop.run_until_complete(asyncio.wait_for(bridge.cleanup(), timeout=2.0))
                    loop.close()
            except asyncio.TimeoutError:
                print("Cleanup timed out")
            except Exception as e:
                print(f"Cleanup error: {e}")
                
        engine.deleteLater()
    
    app.aboutToQuit.connect(cleanup)
    
    engine.rootContext().setContextProperty("botBridge", bridge)
    
    def bot_runner():
        nonlocal bot_started
        try:
            if not asyncio.run(verify_token(token)):
                bridge._valid_token_format = False
                app.quit()
                return

            bot_started = True
            bridge.status = "Connecting..."
            bot.run(token, reconnect=True)

        except Exception as e:
            print(f"Bot error: {e}")
            bridge.status = "Connection Error"
    
    bot_thread = threading.Thread(target=bot_runner, daemon=True)
    bot_thread.start()
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    qml_path = os.path.join(script_dir, "qml/Main.qml")
    engine.load(QUrl.fromLocalFile(qml_path))
    
    if not engine.rootObjects():
        print("Error loading main UI")
        sys.exit(1)


if __name__ == "__main__":
    configure_logging()
    
    parser = argparse.ArgumentParser(description='Boxy Discord Music Bot')
    parser.add_argument('--force-setup', action='store_true', help='Force the setup screen to appear')
    args = parser.parse_args()
    
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    script_dir = os.path.dirname(os.path.abspath(__file__))
    icon = os.path.join(script_dir, "qml/icons/icon.png")
    
    app.setOrganizationName("Odizinne")
    app.setApplicationName("Boxy")
    app.setWindowIcon(QIcon(icon))
    
    setup_manager = SetupManager()
    migrate_playlists_if_needed()
    
    if setup_manager.is_setup_complete() and not args.force_setup:
        token = setup_manager.get_token()
        start_main_app(app, engine, token)
    else:
        load_setup_window(app, engine, setup_manager)
    
    sys.exit(app.exec())