import io
import picamera
import logging
import http.server
import socketserver
import socket
from threading import Condition

# HTML page template for video streaming
PAGE = """\
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body, html {
  height: 100%;
  margin: 5;
}

.bg {
  /* The image used */
  background-image: url("stream.mjpg");

  /* Full height */
  height: 100%; 

  /* Center and scale the image nicely */
  background-position: center;
  background-repeat: no-repeat;
  background-size: cover;
}
</style>
</head>
<body>

<div class="bg"></div>

</body>
</html>
"""

class StreamingOutput(object):
    def __init__(self):
        self.frame = None
        self.buffer = io.BytesIO()
        self.condition = Condition()

    def write(self, buf):
        if buf.startswith(b'\xff\xd8'):  # Check for the start of a JPEG frame
            # New frame, copy the existing buffer's content and notify all
            # clients it's available
            self.buffer.truncate()
            with self.condition:
                self.frame = self.buffer.getvalue()
                self.condition.notify_all()
            self.buffer.seek(0)
        return self.buffer.write(buf)

class StreamingHandler(http.server.BaseHTTPRequestHandler):
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
                        output.condition.wait()  # Wait for new frame
                        frame = output.frame
                    self.wfile.write(b'--FRAME\r\n')
                    self.send_header('Content-Type', 'image/jpeg')
                    self.send_header('Content-Length', len(frame))
                    self.end_headers()
                    self.wfile.write(frame)
                    self.wfile.write(b'\r\n')
            except Exception as e:
                logging.warning('Removed streaming client %s: %s', self.client_address, str(e))
        else:
            self.send_error(404)
            self.end_headers()

class StreamingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True
    address_family = socket.AF_INET  # Change to IPv4 if you don't need IPv6

# Set up the camera and stream video
with picamera.PICamera(resolution='1280x720', framerate=40) as camera:
    output = StreamingOutput()
    camera.rotation = 90  # Rotate image if needed
    # camera.iso = 400      # Enable if you need manual ISO control
    # camera.shutter_speed = 6000000  # Enable if you need manual shutter speed

    camera.start_recording(output, format='mjpeg')  # Start recording

    try:
        # Set up the HTTP server and bind it to address
        address = ('', 8000)  # Listen on port 8000
        httpd = StreamingServer(address, StreamingHandler)  # Rename variable to avoid conflict with the module name
        logging.info("Starting HTTP server for streaming at http://localhost:8000")
        httpd.serve_forever()  # Start serving the HTTP requests
    except Exception as e:
        logging.error("Error starting the server: %s", str(e))
    finally:
        camera.stop_recording()  # Stop recording when finished
        logging.info("Camera recording stopped.")
