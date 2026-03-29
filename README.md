# AI Stack Launcher (Ollama + OpenWebUI)

A convenient bash script that automatically sets up and launches a local AI stack consisting of [Ollama](https://ollama.com/) and [OpenWebUI](https://openwebui.com/).

## Features

- **Auto-installation**: Automatically installs Ollama and OpenWebUI if not present
- **Model Management**: Downloads default models (`embeddinggemma` and `gemma3n`) if missing
- **Flexible Configuration**: Configure via environment variables or `.env` file
- **Health Checks**: Comprehensive health checks for all services
- **Graceful Shutdown**: Proper cleanup on Ctrl+C or script termination
- **Color-coded Output**: Easy-to-read status messages

## Prerequisites

- Linux or macOS
- `curl` (for health checks and installation)
- Python 3.8+ with `pip` or `pipx` (for OpenWebUI)

## Quick Start

```bash
# Make the script executable
chmod +x launch_ai.sh

# Run the launcher
./launch_ai.sh
```

The script will:
1. Check for required dependencies
2. Prompt to install Ollama if not found
3. Prompt to install OpenWebUI if not found
4. Download required models (`embeddinggemma` and `gemma3n`)
5. Start Ollama server in the background
6. Launch OpenWebUI in the foreground

Once running, access the UI at: **http://localhost:3000**

## Configuration

### Environment Variables

You can configure the launcher using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `127.0.0.1:11434` | Ollama server host and port |
| `OPENWEBUI_PORT` | `3000` | OpenWebUI listening port |
| `RAG_EMBEDDING_ENGINE` | `ollama` | Embedding engine to use |
| `RAG_EMBEDDING_MODEL` | `embeddinggemma` | Model for embeddings |
| `DEFAULT_CHAT_MODEL` | `gemma3n` | Default chat/completion model |
| `ENABLE_OPENAI_API` | `false` | Enable OpenAI API compatibility |

### Using a `.env` File

Create a `.env` file in the same directory to persist your configuration:

```bash
# .env file
OLLAMA_HOST=127.0.0.1:11434
OPENWEBUI_PORT=3000
RAG_EMBEDDING_MODEL=all-minilm
DEFAULT_CHAT_MODEL=llama3.2
ENABLE_OPENAI_API=false
```

The script will automatically load settings from `.env` on startup.

### Command-line Override

You can also set environment variables inline:

```bash
OPENWEBUI_PORT=8080 DEFAULT_CHAT_MODEL=llama3.2 ./launch_ai.sh
```

## Manual Installation

If you prefer to install components manually before running the script:

### Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Install OpenWebUI

**Using pipx (recommended):**
```bash
pipx install open-webui
```

**Using pip:**
```bash
pip install open-webui
```

### Download Models

```bash
ollama pull embeddinggemma
ollama pull gemma3n
```

## Troubleshooting

### Ollama fails to start

- Check if port 11434 is already in use: `lsof -i :11434`
- Ensure you have sufficient permissions
- Try restarting: `ollama serve`

### OpenWebUI fails to install

- Ensure Python 3.8+ is installed: `python3 --version`
- Upgrade pip: `pip install --upgrade pip`
- Consider using pipx for better isolation: `pipx install open-webui`

### Model download fails

- Check your internet connection
- Verify Ollama is running: `ollama list`
- Try manual download: `ollama pull <model-name>`

### Port already in use

Change the port via environment variable:
```bash
OPENWEBUI_PORT=8080 ./launch_ai.sh
```

## Project Structure

```
.
├── launch_ai.sh      # Main launcher script
├── .env              # Configuration file (optional, not tracked)
├── .gitignore        # Git ignore rules
└── README.md         # This file
```

## Security Notes

- The `.env` file may contain sensitive configuration and is included in `.gitignore`
- The `.webui_secret_key` file is automatically ignored by git
- Never commit secret keys or credentials to version control

## License

This launcher script is provided as-is for convenience. Ollama and OpenWebUI are separate projects with their own licenses.

## Useful Links

- [Ollama Documentation](https://ollama.com/help)
- [OpenWebUI Documentation](https://docs.openwebui.com/)
- [Ollama Model Library](https://ollama.com/library)
