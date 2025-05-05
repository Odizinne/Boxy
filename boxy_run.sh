#!/bin/bash

# /!\ This is a very generic script that will attempt to use python from your path
# Do not use it if you're using a venv

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

if ! command -v python3 &> /dev/null; then
    echo "Python is not installed. Please install Python 3.13 or higher."
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
PYTHON_MAJOR=$(python3 -c 'import sys; print(sys.version_info[0])')
PYTHON_MINOR=$(python3 -c 'import sys; print(sys.version_info[1])')

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 13 ]); then
    echo "Python 3.13 or higher is required, but version $PYTHON_VERSION is installed."
    echo "Please install Python 3.13 or higher."
    exit 1
fi

if [ ! -f "main.py" ]; then
    echo "main.py not found in the current directory."
    exit 1
fi

echo "Running Boxy with Python $PYTHON_VERSION..."
python3 main.py