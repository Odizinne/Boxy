import sys
import os
import threading
import asyncio
import logging
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl

from boxy_py.bot import BoxyBot
from boxy_py.bridge import BotBridge
from boxy_py.setup_manager import SetupManager
from boxy_py.utils import get_script_dir
import discord

from boxy_py.config import migrate_playlists_if_needed


def configure_logging():
    """Configure logging"""
    os.environ["QT_LOGGING_RULES"] = "qt.qpa.*=false"
    discord_player_logger = logging.getLogger('discord.player')
    discord_player_logger.setLevel(logging.WARNING)

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
    
    def cleanup():
        asyncio.run_coroutine_threadsafe(bridge.cleanup(), bot.loop).result()
    
    app.aboutToQuit.connect(cleanup)
    
    engine.rootContext().setContextProperty("botBridge", bridge)
    
    def bot_runner():
        try:
            bot.run(token)
        except Exception as e:
            print(f"Bot error: {e}")
            app.quit()
    
    bot_thread = threading.Thread(target=bot_runner, daemon=True)
    bot_thread.start()
    qml_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qml/Main.qml")

    engine.load(QUrl.fromLocalFile(qml_path))
    
    if not engine.rootObjects():
        print("Error loading main UI")
        sys.exit(1)


if __name__ == "__main__":
    configure_logging()
    
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    icon = os.path.join(get_script_dir(), "boxy-orange.png")
    
    app.setOrganizationName("Odizinne")
    app.setApplicationName("Boxy")
    app.setWindowIcon(QIcon(icon))
    
    setup_manager = SetupManager()

    migrate_playlists_if_needed()
    
    if setup_manager.is_setup_complete():
        token = setup_manager.get_token()
        start_main_app(app, engine, token)
    else:
        engine.rootContext().setContextProperty("setupManager", setup_manager)
        qml_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qml/SetupWindow.qml")
        engine.load(QUrl.fromLocalFile(qml_path))
        
        if not engine.rootObjects():
            print("Error loading setup UI")
            sys.exit(1)
        
        root = engine.rootObjects()[0]
        root.setupFinished.connect(setup_manager.save_token)

        setup_manager.setupCompleted.connect(lambda token: start_main_app(app, engine, token))
    
    sys.exit(app.exec())