import gradio as gr
import os
import sys
import logging
import json
import shutil
from pathlib import Path
from typing import List, Optional, Tuple
import tempfile
from datetime import datetime
import threading
import queue
import time
import subprocess

# Add ClipsAI to path
sys.path.insert(0, '/app/clipsai_source')

# Import ClipsAI modules
try:
    from clipsai import ClipFinder, Transcriber
    from clipsai.media.editor import MediaEditor
except ImportError as e:
    logging.error(f"Failed to import ClipsAI modules: {e}")
    # Try alternative import
    try:
        import clipsai
        ClipFinder = clipsai.ClipFinder
        Transcriber = clipsai.Transcriber
        from clipsai.media.editor import MediaEditor
    except ImportError as e2:
        logging.error(f"Alternative import also failed: {e2}")
        raise

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global variables for progress tracking
progress_queue = queue.Queue()
log_queue = queue.Queue()
current_task = {"status": "idle", "progress": 0, "message": ""}

class VideoProcessor:
    def __init__(self):
        self.media_editor = MediaEditor()
        self.transcriber = Transcriber()
        self.clip_finder = ClipFinder()
        
    def process_video(self, 
                     video_path: str, 
                     num_clips: int, 
                     add_subtitles: bool,
                     output_dir: str,
                     progress_callback=None,
                     log_callback=None) -> List[str]:
        """Process video and generate clips"""
        try:
            # Ensure absolute paths
            video_path = os.path.abspath(video_path)
            output_dir = os.path.abspath(output_dir)
            
            # Create output directory
            os.makedirs(output_dir, exist_ok=True)
            
            # Step 1: Transcribe video
            if progress_callback:
                progress_callback(0.1, "Transcribing video...")
            if log_callback:
                log_callback("Starting transcription process...")
                
            transcription = self.transcriber.transcribe(
                media_file_path=video_path,
                device="cpu",  # Force CPU for compatibility
                compute_type="int8"  # Use int8 for CPU efficiency
            )
            
            if log_callback:
                log_callback(f"Transcription complete.")
            
            # Step 2: Find clips
            if progress_callback:
                progress_callback(0.4, "Finding best clips...")
            if log_callback:
                log_callback(f"Searching for {num_clips} best clips...")
                
            clips = self.clip_finder.find_clips(
                transcription=transcription,
                min_clip_duration=15.0,
                max_clip_duration=120.0
            )
            
            # Sort clips by score and take top N
            clips = sorted(clips, key=lambda x: x.score if hasattr(x, 'score') else 0, reverse=True)[:num_clips]
            
            if log_callback:
                log_callback(f"Found {len(clips)} clips")
            
            # Step 3: Extract and process clips
            output_files = []
            for idx, clip in enumerate(clips):
                if progress_callback:
                    progress = 0.4 + (0.5 * (idx / len(clips)))
                    progress_callback(progress, f"Processing clip {idx + 1}/{len(clips)}")
                
                if log_callback:
                    log_callback(f"Extracting clip {idx + 1}: {clip.start_time:.1f}s - {clip.end_time:.1f}s")
                
                # Generate output filename
                output_filename = f"clip_{idx + 1:03d}.mp4"
                output_path = os.path.join(output_dir, output_filename)
                
                # Extract clip using ffmpeg directly for better control
                cmd = [
                    'ffmpeg', '-i', video_path,
                    '-ss', str(clip.start_time),
                    '-t', str(clip.end_time - clip.start_time),
                    '-c', 'copy',  # Copy codec for faster processing
                    '-avoid_negative_ts', 'make_zero',
                    output_path,
                    '-y'  # Overwrite output
                ]
                
                try:
                    subprocess.run(cmd, check=True, capture_output=True, text=True)
                except subprocess.CalledProcessError as e:
                    if log_callback:
                        log_callback(f"Warning: Fast copy failed, trying re-encode for clip {idx + 1}")
                    # Fallback to re-encoding
                    cmd = [
                        'ffmpeg', '-i', video_path,
                        '-ss', str(clip.start_time),
                        '-t', str(clip.end_time - clip.start_time),
                        '-c:v', 'libx264',
                        '-preset', 'fast',
                        '-crf', '23',
                        '-c:a', 'aac',
                        output_path,
                        '-y'
                    ]
                    subprocess.run(cmd, check=True, capture_output=True, text=True)
                
                # Add subtitles if requested
                if add_subtitles and hasattr(clip, 'transcript') and clip.transcript:
                    if log_callback:
                        log_callback(f"Adding subtitles to clip {idx + 1}")
                    
                    # Create SRT file
                    srt_path = output_path.replace('.mp4', '.srt')
                    self._create_srt_file(clip, srt_path)
                    
                    # Burn subtitles into video
                    temp_output = output_path.replace('.mp4', '_sub.mp4')
                    cmd = [
                        'ffmpeg', '-i', output_path, '-vf',
                        f"subtitles={srt_path}:force_style='FontSize=24,Outline=1'",
                        '-c:a', 'copy',
                        temp_output,
                        '-y'
                    ]
                    
                    try:
                        subprocess.run(cmd, check=True, capture_output=True, text=True)
                        # Replace original with subtitled version
                        os.replace(temp_output, output_path)
                        os.remove(srt_path)
                    except Exception as e:
                        if log_callback:
                            log_callback(f"Warning: Could not add subtitles to clip {idx + 1}: {str(e)}")
                        # Clean up temp files if they exist
                        if os.path.exists(temp_output):
                            os.remove(temp_output)
                        if os.path.exists(srt_path):
                            os.remove(srt_path)
                
                output_files.append(output_path)
                
                if log_callback:
                    log_callback(f"Clip {idx + 1} saved to: {output_filename}")
            
            if progress_callback:
                progress_callback(1.0, "Processing complete!")
            if log_callback:
                log_callback(f"Successfully created {len(output_files)} clips")
                
            return output_files
            
        except Exception as e:
            error_msg = f"Error processing video: {str(e)}"
            logger.error(error_msg, exc_info=True)
            if log_callback:
                log_callback(f"ERROR: {error_msg}")
            raise
    
    def _create_srt_file(self, clip, srt_path: str):
        """Create SRT subtitle file from clip transcript"""
        with open(srt_path, 'w', encoding='utf-8') as f:
            # Adjust timestamps relative to clip start
            clip_start = clip.start_time
            
            for i, segment in enumerate(clip.transcript.segments):
                # Calculate relative timestamps
                start = max(0, segment.start - clip_start)
                end = min(clip.end_time - clip_start, segment.end - clip_start)
                
                if start < end:  # Only write if segment is within clip bounds
                    f.write(f"{i + 1}\n")
                    f.write(f"{self._format_time(start)} --> {self._format_time(end)}\n")
                    f.write(f"{segment.text.strip()}\n\n")
    
    def _format_time(self, seconds: float) -> str:
        """Format time for SRT file"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = seconds % 60
        return f"{hours:02d}:{minutes:02d}:{secs:06.3f}".replace('.', ',')

# Initialize processor
processor = VideoProcessor()

def process_video_async(file_path: str, num_clips: int, add_subtitles: bool):
    """Async wrapper for video processing"""
    global current_task
    
    try:
        current_task = {"status": "processing", "progress": 0, "message": "Starting..."}
        
        # Create unique output directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_dir = f"/output/clips/{timestamp}"
        
        def progress_callback(progress: float, message: str):
            current_task["progress"] = progress
            current_task["message"] = message
            progress_queue.put((progress, message))
        
        def log_callback(message: str):
            log_queue.put(message)
        
        # Process video
        output_files = processor.process_video(
            video_path=file_path,
            num_clips=num_clips,
            add_subtitles=add_subtitles,
            output_dir=output_dir,
            progress_callback=progress_callback,
            log_callback=log_callback
        )
        
        current_task = {
            "status": "complete", 
            "progress": 1.0, 
            "message": "Processing complete!",
            "output_dir": output_dir,
            "files": output_files
        }
        
        return output_dir, output_files
        
    except Exception as e:
        error_msg = str(e)
        current_task = {"status": "error", "progress": 0, "message": f"Error: {error_msg}"}
        log_queue.put(f"ERROR: {error_msg}")
        raise

def create_interface():
    """Create Gradio interface"""
    
    with gr.Blocks(title="ClipsAI Web Interface", theme=gr.themes.Soft()) as interface:
        gr.Markdown(
            """
            # 🎬 ClipsAI Web Interface
            
            Upload a video and automatically extract the best clips!
            
            **Note:** Processing may take several minutes depending on video length.
            """
        )
        
        with gr.Row():
            with gr.Column(scale=1):
                # Input section
                gr.Markdown("### Upload Video")
                video_input = gr.File(
                    label="Video File",
                    file_types=["video"],
                    type="filepath"
                )
                
                num_clips = gr.Slider(
                    minimum=1,
                    maximum=10,
                    value=3,
                    step=1,
                    label="Number of Clips to Extract"
                )
                
                add_subtitles = gr.Checkbox(
                    label="Add Subtitles to Clips",
                    value=True
                )
                
                process_btn = gr.Button("Process Video", variant="primary")
                
            with gr.Column(scale=1):
                # Progress section
                gr.Markdown("### Processing Status")
                status_text = gr.Textbox(
                    label="Status",
                    value="Ready to process",
                    interactive=False
                )
                
                # Logs section
                gr.Markdown("### Processing Logs")
                log_output = gr.Textbox(
                    label="Logs",
                    value="",
                    lines=10,
                    max_lines=20,
                    interactive=False
                )
        
        # Results section
        gr.Markdown("### Results")
        with gr.Row():
            output_dir_text = gr.Textbox(
                label="Output Directory",
                value="",
                interactive=False
            )
            download_btn = gr.Button("Download All Clips", visible=False)
        
        output_gallery = gr.Gallery(
            label="Generated Clips",
            show_label=True,
            elem_id="gallery",
            columns=3,
            rows=2,
            object_fit="contain",
            height="auto"
        )
        
        # Processing logic
        def process_video_handler(video_file, num_clips, add_subtitles):
            if not video_file:
                return "Please upload a video file", "", [], "", gr.update(visible=False)
            
            try:
                # Start processing in background thread
                thread = threading.Thread(
                    target=process_video_async,
                    args=(video_file, num_clips, add_subtitles)
                )
                thread.start()
                
                # Update UI while processing
                logs = []
                while thread.is_alive() or not progress_queue.empty() or not log_queue.empty():
                    # Update progress
                    try:
                        progress, message = progress_queue.get_nowait()
                        yield message, "\n".join(logs), [], "", gr.update(visible=False)
                    except queue.Empty:
                        pass
                    
                    # Update logs
                    try:
                        log_msg = log_queue.get_nowait()
                        logs.append(f"[{datetime.now().strftime('%H:%M:%S')}] {log_msg}")
                        # Keep only last 100 log lines
                        if len(logs) > 100:
                            logs = logs[-100:]
                        yield current_task.get("message", "Processing..."), "\n".join(logs), [], "", gr.update(visible=False)
                    except queue.Empty:
                        pass
                    
                    # Small delay to prevent UI overload
                    time.sleep(0.1)
                
                # Wait for thread to complete
                thread.join()
                
                # Check results
                if current_task["status"] == "complete":
                    output_dir = current_task["output_dir"]
                    output_files = current_task["files"]
                    
                    # Create video previews for gallery
                    video_previews = []
                    for video_path in output_files:
                        video_previews.append(video_path)
                    
                    return (
                        "✅ Processing complete!",
                        "\n".join(logs),
                        video_previews,
                        output_dir,
                        gr.update(visible=True)
                    )
                else:
                    return (
                        f"❌ {current_task.get('message', 'Processing failed')}",
                        "\n".join(logs),
                        [],
                        "",
                        gr.update(visible=False)
                    )
                    
            except Exception as e:
                error_msg = f"Error: {str(e)}"
                logger.error(error_msg, exc_info=True)
                return error_msg, error_msg, [], "", gr.update(visible=False)
        
        # Connect processing
        process_btn.click(
            fn=process_video_handler,
            inputs=[video_input, num_clips, add_subtitles],
            outputs=[status_text, log_output, output_gallery, output_dir_text, download_btn]
        )
        
        # Download handler
        def create_download_zip(output_dir):
            if not output_dir or not os.path.exists(output_dir):
                return None
            
            # Create zip file
            zip_path = f"{output_dir}.zip"
            shutil.make_archive(output_dir, 'zip', output_dir)
            return zip_path
        
        download_btn.click(
            fn=create_download_zip,
            inputs=[output_dir_text],
            outputs=[gr.File(label="Download ZIP")]
        )
    
    return interface

# Main execution
if __name__ == "__main__":
    # Check for required environment variables
    hf_token = os.environ.get("HUGGINGFACE_TOKEN", "")
    if hf_token:
        logger.info("HuggingFace token found")
        os.environ["HF_TOKEN"] = hf_token
    else:
        logger.warning("No HuggingFace token found. Some features may be limited.")
    
    # Create and launch interface
    interface = create_interface()
    interface.launch(
        server_name="0.0.0.0",
        server_port=4444,
        share=False,
        show_error=True
    )