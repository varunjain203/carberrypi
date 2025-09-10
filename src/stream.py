#!/usr/bin/env python3
"""
Simple streaming server for dashcam when recording is not active.
Uses Picamera2 for MJPEG streaming over HTTP.
"""

import io
import sys
import signal
import socket
import socketserver
from threading import Condition
from http import server
from pathlib import Path

# Add config loading
config_file = Path(__file__).parent.parent / "config" / "dashcam.conf"
config = {}

# Load configuration from shell config file
if config_file.exists():
    with open(config_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key] = value

# Configuration with defaults
STREAMING_PORT = int(config.get('STREAMING_PORT', '8000'))
CAMERA_WIDTH = int(config.get('CAMERA_WIDTH', '1280'))
CAMERA_HEIGHT = int(config.get('CAMERA_HEIGHT', '720'))
CAMERA_ROTATION = int(config.get('CAMERA_ROTATION', '90'))

# HTML page for viewing stream
PAGE = f"""\
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dashcam Stream</title>
<style>
body, html {{
  height: 100%;
  margin: 0;
  background-color: black;
  display: flex;
  justify-content: center;
  align-items: center;
}}
img {{
  max-width: 100%;
  max-height: 100%;
  transform: rotate({CAMERA_ROTATION}deg);
}}
</style>
</head>
<body>
<img src="stream.mjpg" alt="Dashcam Stream">
</body>
</html>
"""

class StreamingOutput:
    def __init__(self):
        self.frame = None
        self.buffer = io.BytesIO()
        self.condition = Condition()

    def write(self, buf):
        if buf.startswith(b'\xff\xd8'):
            # New frame, copy the existing buffer's content and notify all clients
            self.buffer.truncate()
            with self.condition:
                self.frame = self.buffer.getvalue()
                self.condition.notify_all()
            self.buffer.seek(0)
        return self.buffer.write(buf)

class StreamingHandler(server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(301)
            self.send_header('Location', '/index.html')
            self.end_headers()
        elif self.path == '/index.html':
            content = PAGE.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content)
        elif self.path == '/stream.mjpg':
            self.send_response(200)
            self.send_header('Age', 0)
            self.send_header('Cache-Control', 'no-cache, private')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=FRAME')
            self.end_headers()
            try:
                while True:
                    with output.condition:
                        output.condition.wait()
                        frame = output.frame
                    self.wfile.write(b'--FRAME\r\n')
                    self.send_header('Content-Type', 'image/jpeg')
                    self.send_header('Content-Length', len(frame))
                    self.end_headers()
                    self.wfile.write(frame)
                    self.wfile.write(b'\r\n')
            except Exception:
                # Client disconnected
                pass
        else:
            self.send_error(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress HTTP server logs
        pass

class StreamingServer(socketserver.ThreadingMixIn, server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True

def signal_handler(signum, frame):
    print("Shutting down streaming server...")
    if 'picam2' in globals():
        picam2.stop_recording()
        picam2.close()
    sys.exit(0)

def main():
    global output, picam2
    
    # Setup signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    try:
        from picamera2 import Picamera2
        from picamera2 import Preview
        
        # Create camera instance
        picam2 = Picamera2()
        
        # Configure camera
        config = picam2.create_video_configuration(
            main={"size": (CAMERA_WIDTH, CAMERA_HEIGHT)},
            transform={"hflip": False, "vflip": False}
        )
        picam2.configure(config)
        
        # Start preview (required even though we're not using display)
        picam2.start_preview(Preview.NULL)
        
        # Create output stream
        output = StreamingOutput()
        
        # Start recording to stream
        picam2.start_recording(output, format='mjpeg')
        
        # Start HTTP server
        address = ('', STREAMING_PORT)
        httpd = StreamingServer(address, StreamingHandler)
        
        print(f"Streaming server started on port {STREAMING_PORT}")
        print(f"Camera: {CAMERA_WIDTH}x{CAMERA_HEIGHT}, rotation: {CAMERA_ROTATION}°")
        print("Press Ctrl+C to stop")
        
        httpd.serve_forever()
        
    except ImportError:
        print("Error: Picamera2 library not found")
        print("Install with: sudo apt install python3-picamera2")
        sys.exit(1)
    except Exception as e:
        print(f"Error starting streaming server: {e}")
        sys.exit(1)
    finally:
        if 'picam2' in globals():
            picam2.stop_recording()
            picam2.close()

if __name__ == '__main__':
    main()