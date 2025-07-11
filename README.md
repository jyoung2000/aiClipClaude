# aiClipClaude - Dockerized ClipsAI with Web GUI

A Docker container that wraps the [ClipsAI](https://github.com/ClipsAI/clipsai) library with a user-friendly web interface. This container automatically converts long videos into clips with optional subtitles.

## Features

- 🎬 **Web-based interface** on port 4444
- 📤 **Drag-and-drop video upload**
- 🎯 **Configurable clip extraction** (1-10 clips per video)
- 📝 **Optional subtitle generation**
- 📊 **Real-time progress tracking**
- 📋 **Live processing logs**
- 🐳 **unRAID compatible** with proper permission handling
- 🖥️ **CPU-only processing** (no GPU required)

## Quick Start

### Using Docker Compose (Recommended)

1. Clone this repository:
```bash
git clone https://github.com/jyoung2000/aiClipClaude.git
cd aiClipClaude
```

2. Build the container:
```bash
docker compose build
```

3. Run the container:
```bash
docker compose up -d
```

4. Access the web interface at `http://localhost:4444`

### Using Docker CLI

```bash
docker build -t aiclip-claude .

docker run -d \
  --name aiClipClaude \
  -p 4444:4444 \
  -e PUID=99 \
  -e PGID=100 \
  -e HUGGINGFACE_TOKEN=your_token_here \
  -v /path/to/input:/input \
  -v /path/to/output:/output \
  -v /path/to/cache:/cache \
  -v /path/to/models:/models \
  aiclip-claude
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 99 | User ID for unRAID compatibility |
| `PGID` | 100 | Group ID for unRAID compatibility |
| `HUGGINGFACE_TOKEN` | - | Optional: HuggingFace token for enhanced features |
| `GRADIO_SERVER_PORT` | 4444 | Web interface port |

### Volume Mounts

| Container Path | Description |
|----------------|-------------|
| `/input` | Directory for source video files |
| `/output` | Directory where processed clips are saved |
| `/cache` | Cache directory for transcriptions |
| `/models` | Directory for ML model storage |

## Usage

1. **Upload Video**: Click or drag a video file to the upload area
2. **Select Clips**: Choose how many clips you want to extract (1-10)
3. **Subtitles**: Check the box if you want subtitles burned into the clips
4. **Process**: Click "Process Video" and monitor the progress
5. **Download**: View generated clips in the gallery and download them

## unRAID Installation

1. In unRAID, go to Docker tab
2. Click "Add Container"
3. Fill in the following:
   - **Name**: aiClipClaude
   - **Repository**: jyoung2000/aiclipClaude (or build locally)
   - **Network Type**: Bridge
   - **Port**: 4444:4444
   - **PUID**: 99
   - **PGID**: 100
   - Add volume mappings as needed

## Building from Source

The container uses a multi-stage build process:

```bash
# Clone the repository
git clone https://github.com/jyoung2000/aiClipClaude.git
cd aiClipClaude

# Build with Docker Compose
docker compose build

# Or build with Docker CLI
docker build -t aiclip-claude .
```

## Technical Details

- **Base Image**: Python 3.11-slim
- **ML Framework**: PyTorch (CPU-only)
- **Transcription**: WhisperX
- **Web Framework**: Gradio
- **Video Processing**: FFmpeg
- **File Permissions**: Handled via gosu for unRAID compatibility

## Troubleshooting

### Permission Issues on unRAID
- Ensure PUID and PGID match your unRAID user
- Default values (99/100) should work for most unRAID setups

### Out of Memory
- Adjust memory limits in docker-compose.yml
- Reduce the number of clips or video resolution

### Slow Processing
- CPU-only processing is slower than GPU
- Consider processing shorter videos or fewer clips

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project follows the same license as ClipsAI.

## Acknowledgments

- [ClipsAI](https://github.com/ClipsAI/clipsai) - The core library this container wraps
- [Gradio](https://gradio.app/) - For the web interface framework