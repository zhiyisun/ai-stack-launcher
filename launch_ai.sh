#!/bin/bash

###############################################################################
# AI Stack Launcher (Ollama + OpenWebUI)
###############################################################################
# This script starts Ollama in the background, waits for it to be ready,
# and then launches OpenWebUI in the foreground.
#
# Features:
# - Auto-install Ollama and OpenWebUI if not present
# - Auto-download default models (embeddinggemma, gemma3n)
# - Flexible configuration via environment variables or .env file
# - Comprehensive error handling and health checks
###############################################################################

set -euo pipefail

# --- Configuration (can be overridden via .env or environment variables) ---
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
OPENWEBUI_PORT="${OPENWEBUI_PORT:-3000}"
DEFAULT_EMBEDDING_MODEL="${RAG_EMBEDDING_MODEL:-embeddinggemma}"
DEFAULT_CHAT_MODEL="${DEFAULT_CHAT_MODEL:-gemma3n}"

# --- Required Environment Variables ---
export RAG_EMBEDDING_ENGINE="${RAG_EMBEDDING_ENGINE:-ollama}"
export RAG_EMBEDDING_MODEL="${RAG_EMBEDDING_MODEL:-$DEFAULT_EMBEDDING_MODEL}"
export ENABLE_OPENAI_API="${ENABLE_OPENAI_API:-false}"

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# --- Load .env file if it exists ---
if [ -f ".env" ]; then
    log_info "Loading configuration from .env file..."
    set -a
    source .env
    set +a
fi

# --- Cleanup Function ---
cleanup() {
    echo ""
    log_warning "Shutting down services..."
    if [ -n "${OLLAMA_PID:-}" ]; then
        kill "$OLLAMA_PID" 2>/dev/null || true
        wait "$OLLAMA_PID" 2>/dev/null || true
        log_success "Ollama stopped."
    fi
    # OpenWebUI is running in foreground, so it will stop naturally when script exits
    log_success "Shutdown complete."
    exit 0
}

# Trap Ctrl+C and script termination to cleanup background processes
trap cleanup EXIT INT TERM

# --- Check if command exists ---
command_exists() {
    command -v "$1" &> /dev/null
}

# --- Install Ollama ---
install_ollama() {
    log_info "Installing Ollama..."
    if command_exists curl; then
        curl -fsSL https://ollama.com/install.sh | sh
        if [ $? -eq 0 ]; then
            log_success "Ollama installed successfully."
            return 0
        else
            log_error "Failed to install Ollama."
            return 1
        fi
    else
        log_error "curl is required but not installed. Please install curl first."
        return 1
    fi
}

# --- Install OpenWebUI ---
install_openwebui() {
    log_info "Installing OpenWebUI..."
    
    # Try pipx first (recommended)
    if command_exists pipx; then
        log_info "Installing OpenWebUI via pipx..."
        pipx install open-webui
        if [ $? -eq 0 ]; then
            log_success "OpenWebUI installed successfully via pipx."
            return 0
        else
            log_warning "pipx installation failed, trying pip..."
        fi
    else
        log_info "pipx not found, trying pip..."
    fi
    
    # Fallback to pip
    if command_exists pip3; then
        log_info "Installing OpenWebUI via pip3..."
        pip3 install open-webui
        if [ $? -eq 0 ]; then
            log_success "OpenWebUI installed successfully via pip3."
            return 0
        else
            log_error "Failed to install OpenWebUI via pip3."
            return 1
        fi
    elif command_exists pip; then
        log_info "Installing OpenWebUI via pip..."
        pip install open-webui
        if [ $? -eq 0 ]; then
            log_success "OpenWebUI installed successfully via pip."
            return 0
        else
            log_error "Failed to install OpenWebUI via pip."
            return 1
        fi
    else
        log_error "Neither pipx, pip3, nor pip found. Please install Python pip first."
        return 1
    fi
}

# --- Download Ollama Model ---
download_model() {
    local model_name="$1"
    local model_type="${2:-model}"
    
    log_info "Checking for $model_type: $model_name..."
    
    # Check if model exists
    if ollama list 2>/dev/null | grep -q "^$model_name"; then
        log_success "$model_type '$model_name' is already available."
        return 0
    fi
    
    log_info "Downloading $model_type '$model_name'... (this may take a while)"
    if ollama pull "$model_name"; then
        log_success "$model_type '$model_name' downloaded successfully."
        return 0
    else
        log_error "Failed to download $model_type '$model_name'."
        return 1
    fi
}

# --- Check and Install Dependencies ---
check_dependencies() {
    local missing_deps=()
    
    # Check for curl (needed for health checks and installation)
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install them using your package manager."
        return 1
    fi
    
    return 0
}

# --- Check and Setup Ollama ---
setup_ollama() {
    if ! command_exists ollama; then
        log_warning "Ollama is not installed."
        read -p "Do you want to install Ollama now? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! install_ollama; then
                return 1
            fi
        else
            log_error "Ollama is required. Exiting."
            return 1
        fi
    fi
    
    log_success "Ollama is available."
    return 0
}

# --- Check and Setup OpenWebUI ---
setup_openwebui() {
    if ! command_exists open-webui; then
        log_warning "OpenWebUI is not installed."
        read -p "Do you want to install OpenWebUI now? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! install_openwebui; then
                return 1
            fi
        else
            log_error "OpenWebUI is required. Exiting."
            return 1
        fi
    fi
    
    log_success "OpenWebUI is available."
    return 0
}

# --- Setup Models ---
setup_models() {
    log_info "Checking required models..."
    
    local models_ok=true
    
    if ! download_model "$RAG_EMBEDDING_MODEL" "embedding model"; then
        models_ok=false
    fi
    
    if ! download_model "$DEFAULT_CHAT_MODEL" "chat model"; then
        models_ok=false
    fi
    
    if [ "$models_ok" = false ]; then
        log_warning "Some models failed to download. You can still proceed, but functionality may be limited."
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# --- Check Ollama Health ---
check_ollama_health() {
    local host="$1"
    local max_retries="${2:-30}"
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$host/api/tags" 2>/dev/null || echo "000")
        
        if [ "$http_code" = "200" ]; then
            return 0
        fi
        
        sleep 1
        retry_count=$((retry_count + 1))
    done
    
    return 1
}

# --- Main Execution ---
main() {
    echo "=================================================="
    echo "       AI Stack Launcher (Ollama + OpenWebUI)    "
    echo "=================================================="
    echo ""
    
    # Check basic dependencies
    log_info "Checking dependencies..."
    if ! check_dependencies; then
        exit 1
    fi
    
    # Setup Ollama
    log_info "Checking Ollama installation..."
    if ! setup_ollama; then
        exit 1
    fi
    
    # Setup OpenWebUI
    log_info "Checking OpenWebUI installation..."
    if ! setup_openwebui; then
        exit 1
    fi
    
    # Setup models
    log_info "Checking models..."
    if ! setup_models; then
        exit 1
    fi
    
    echo ""
    log_info "Configuration:"
    echo "  - Ollama Host: $OLLAMA_HOST"
    echo "  - OpenWebUI Port: $OPENWEBUI_PORT"
    echo "  - Embedding Model: $RAG_EMBEDDING_MODEL"
    echo "  - Chat Model: $DEFAULT_CHAT_MODEL"
    echo ""
    
    # Start Ollama (Background)
    log_success "Starting Ollama server..."
    if ! ollama serve > /dev/null 2>&1 &; then
        log_error "Failed to start Ollama server."
        exit 1
    fi
    OLLAMA_PID=$!
    
    # Verify Ollama is running
    sleep 2
    if ! kill -0 "$OLLAMA_PID" 2>/dev/null; then
        log_error "Ollama server failed to start."
        exit 1
    fi
    
    # Wait for Ollama to be Ready
    log_info "Waiting for Ollama to be responsive..."
    if check_ollama_health "$OLLAMA_HOST" 30; then
        log_success "Ollama is ready."
    else
        log_error "Ollama failed to start within timeout (30 seconds)."
        exit 1
    fi
    
    # Start OpenWebUI (Foreground)
    log_success "Launching OpenWebUI..."
    echo "--------------------------------------------------"
    log_info "Access UI at: http://localhost:$OPENWEBUI_PORT"
    log_info "Press Ctrl+C to stop all services."
    echo "--------------------------------------------------"
    echo ""
    
    # Launch OpenWebUI in foreground
    exec open-webui serve
}

# Run main function
main "$@"
