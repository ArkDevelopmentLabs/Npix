#!/bin/bash

# ========================================
#     NPix Bot - Advanced Launcher
# ========================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions for formatted output
print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}      NPix Bot - Advanced Launcher${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}[$1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "[INFO] $1"
}

# Clear screen and show header
clear
print_header
print_info "Initializing launcher... [$(date '+%Y-%m-%d %H:%M:%S')]"
echo ""

# Move to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1


# Check Python Installation
print_section "SYSTEM CHECK" "Verifying Python installation..."

if ! command -v python3 &> /dev/null; then
    if ! command -v python &> /dev/null; then
        echo ""
        print_error "Python is not installed or not in PATH."
        print_info "ACTION REQUIRED: Install Python 3.10 or higher"
        print_info "  - Ubuntu/Debian: sudo apt install python3 python3-pip"
        print_info "  - macOS: brew install python3"
        print_info "  - Fedora: sudo dnf install python3"
        echo ""
        exit 1
    else
        PYTHON_CMD="python"
    fi
else
    PYTHON_CMD="python3"
fi

# Get Python version
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
print_info "Python $PYTHON_VERSION detected"

# Check Python version (minimum 3.8)
PYTHON_MAJOR=$($PYTHON_CMD -c 'import sys; print(sys.version_info.major)')
PYTHON_MINOR=$($PYTHON_CMD -c 'import sys; print(sys.version_info.minor)')

if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]; }; then
    print_warning "Python $PYTHON_VERSION detected. Python 3.8+ is recommended."
fi
echo ""


# Check pip Installation
print_section "SYSTEM CHECK" "Verifying pip installation..."

if ! $PYTHON_CMD -m pip --version &> /dev/null; then
    echo ""
    print_error "pip is not installed or not functioning properly."
    print_info "ACTION REQUIRED: Install pip for Python 3"
    print_info "  - Ubuntu/Debian: sudo apt install python3-pip"
    print_info "  - macOS: Python 3 from Homebrew includes pip"
    print_info "  - Or run: curl https://bootstrap.pypa.io/get-pip.py | python3"
    echo ""
    exit 1
fi

PIP_VERSION=$($PYTHON_CMD -m pip --version | awk '{print $2}')
print_info "pip $PIP_VERSION is available"
echo ""


# Check Virtual Environment
if [ -d "venv" ] || [ -d ".venv" ]; then
    if [ -d "venv" ]; then
        VENV_DIR="venv"
    else
        VENV_DIR=".venv"
    fi
    
    print_section "VIRTUAL ENV" "Detected virtual environment at $VENV_DIR"
    
    if [ -f "$VENV_DIR/bin/activate" ]; then
        print_info "Activating virtual environment..."
        source "$VENV_DIR/bin/activate"
        print_success "Virtual environment activated"
    else
        print_warning "Virtual environment exists but activation script not found"
    fi
    echo ""
fi


# Check requirements.txt
if [ ! -f "requirements.txt" ]; then
    print_warning "requirements.txt not found in current directory."
    print_info "Skipping dependency installation."
    echo ""
else
    print_section "DEPENDENCY CHECK" "Installing/Updating dependencies..."
    print_info "Reading requirements.txt..."
    
    if $PYTHON_CMD -m pip install -r requirements.txt --quiet --disable-pip-version-check; then
        print_success "All dependencies installed successfully"
    else
        echo ""
        print_error "Failed to install dependencies."
        print_info "ACTION REQUIRED: Check requirements.txt for errors or run manually:"
        print_info "  $PYTHON_CMD -m pip install -r requirements.txt"
        echo ""
        exit 1
    fi
    echo ""
fi


# Check bot file existence
if [ ! -f "src/bot.py" ]; then
    print_error "Bot file not found at src/bot.py"
    print_info "ACTION REQUIRED: Ensure bot.py exists in the src directory."
    echo ""
    exit 1
fi

# Check configuration file

if [ ! -f "src/config.py" ]; then
    print_warning "config.py not found in src directory."
    print_info "Bot may fail to start without proper configuration."
    echo ""
fi


# Create logs directory if not exists
if [ ! -d "logs" ]; then
    mkdir -p logs
    print_info "Created logs directory"
else
    print_info "Log directory verified"
fi
echo ""


# Display System Information
print_section "SYSTEM INFO" "Collecting system information..."
OS_TYPE=$(uname -s)
OS_ARCH=$(uname -m)
HOSTNAME=$(hostname)
print_info "OS: $OS_TYPE $OS_ARCH"
print_info "Hostname: $HOSTNAME"
echo ""


# Display Launch Information
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}         Launch Information${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "[TIMESTAMP]    $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "[PYTHON]       $PYTHON_VERSION"
echo -e "[PIP]          $PIP_VERSION"
echo -e "[WORKING DIR]  $SCRIPT_DIR"
echo -e "[BOT FILE]     src/bot.py"
echo -e "[OS]           $OS_TYPE $OS_ARCH"
echo -e "${CYAN}========================================${NC}"
echo ""


# Launch Bot with Monitoring
print_section "STARTING" "Launching NPix Bot..."
print_info "Press Ctrl+C to stop the bot gracefully"
echo ""
echo "----------------------------------------"
echo "         Bot Output Below"
echo "----------------------------------------"
echo ""

# Run the bot and capture exit code
$PYTHON_CMD src/bot.py
BOT_EXIT_CODE=$?

echo ""
echo "----------------------------------------"
echo "         Bot Process Ended"
echo "----------------------------------------"
echo ""


if [ $BOT_EXIT_CODE -eq 0 ]; then
    print_success "Bot shut down normally"
    print_info "Exit Code: $BOT_EXIT_CODE"
elif [ $BOT_EXIT_CODE -eq 130 ]; then
    print_info "Bot stopped by user (Ctrl+C)"
    print_info "Exit Code: $BOT_EXIT_CODE"
else
    print_error "Bot stopped with error code: $BOT_EXIT_CODE"
    print_info "Check logs directory for error details"
    
    case $BOT_EXIT_CODE in
        1)
            print_info "POSSIBLE CAUSE: General runtime error"
            ;;
        2)
            print_info "POSSIBLE CAUSE: Configuration or permission error"
            ;;
        126)
            print_info "POSSIBLE CAUSE: Permission denied"
            ;;
        127)
            print_info "POSSIBLE CAUSE: Command not found"
            ;;
        *)
            print_info "POSSIBLE CAUSE: Unknown error - Check bot logs"
            ;;
    esac
fi

echo ""
print_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""


if [ -n "$VIRTUAL_ENV" ]; then
    deactivate 2>/dev/null
    print_info "Virtual environment deactivated"
fi

exit $BOT_EXIT_CODE
