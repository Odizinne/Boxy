#!/usr/bin/env python3

import sys
import os
import argparse
import threading
import asyncio
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl

from bot import BoxyBot
from bridge import BotBridge
from setup_manager import SetupManager
from utils import get_script_dir
import discord

def run_bot_no_gui():
    """Run bot without GUI (command line mode)"""
    from utils import get_token, verify_token
    import asyncio
    
    try:
        token = get_token()

        # Verify token first
        if not asyncio.run(verify_token(token)):
            print("Token was rejected by Discord")
            sys.exit(1)

        # Create and run bot only if token is valid
        intents = discord.Intents.default()
        intents.message_content = True
        intents.voice_states = True
        
        bot = BoxyBot(command_prefix="/", intents=intents)
        bot.run(token)
    except Exception as e:
        print(f"Bot error: {e}")
        sys.exit(1)

def start_main_app(app, engine, token):
    """Start the main application with the token"""
    # Clear any existing objects in the engine
    engine.clearComponentCache()
    for obj in engine.rootObjects():
        obj.deleteLater()
    
    # Initialize the bot
    intents = discord.Intents.default()
    intents.message_content = True
    intents.voice_states = True
    
    bot = BoxyBot(command_prefix="/", intents=intents)
    bridge = BotBridge(bot)
    bot.bridge = bridge
    
    # Connect cleanup on app quit
    def cleanup():
        asyncio.run_coroutine_threadsafe(bridge.cleanup(), bot.loop).result()
    
    app.aboutToQuit.connect(cleanup)
    
    # Register bridge to QML
    engine.rootContext().setContextProperty("botBridge", bridge)
    
    # Start bot in a separate thread
    def bot_runner():
        try:
            bot.run(token)
        except Exception as e:
            print(f"Bot error: {e}")
            app.quit()
    
    bot_thread = threading.Thread(target=bot_runner, daemon=True)
    bot_thread.start()
    
    # Load the main application UI
    qml_path = os.path.join(get_script_dir(), "main.qml")
    engine.load(QUrl.fromLocalFile(qml_path))
    
    if not engine.rootObjects():
        print("Error loading main UI")
        sys.exit(1)

def run_bot():
    """Main entry point for the application"""
    # Create a single QGuiApplication instance
    app = QGuiApplication(sys.argv)
    
    # Create QML engine
    engine = QQmlApplicationEngine()
    
    # Set application info
    app.setOrganizationName("Odizinne")
    app.setApplicationName("Boxy")
    icon = os.path.join(get_script_dir(), "boxy-orange.png")
    app.setWindowIcon(QIcon(icon))
    
    # Create setup manager
    setup_manager = SetupManager()
    
    # Check if setup is needed
    if setup_manager.is_setup_complete():
        # Already set up - go straight to main app
        token = setup_manager.get_token()
        start_main_app(app, engine, token)
    else:
        # Need setup - show setup window first
        engine.rootContext().setContextProperty("setupManager", setup_manager)
        
        # Load setup QML
        qml_path = os.path.join(get_script_dir(), "SetupWindow.qml")
        engine.load(QUrl.fromLocalFile(qml_path))
        
        if not engine.rootObjects():
            print("Error loading setup UI")
            sys.exit(1)
        
        # Connect signals from QML
        root = engine.rootObjects()[0]
        root.setupFinished.connect(setup_manager.save_token)

        setup_manager.setupCompleted.connect(lambda token: start_main_app(app, engine, token))
    
    # Run the application event loop
    sys.exit(app.exec())

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Boxy Discord Bot")
    parser.add_argument("--no-gui", action="store_true", help="Run bot without GUI")
    args = parser.parse_args()
    
    if args.no_gui:
        run_bot_no_gui()
    else:
        print("Starting Boxy GUI")
        run_bot()