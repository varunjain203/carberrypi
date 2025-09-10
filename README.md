# 🚗 Modern CarBerry DashCam System 📹

A modernized Raspberry Pi dashcam system using current libcamera tools and proper resource management. This system replaces deprecated `raspivid` commands with modern `libcamera-vid` while maintaining all existing functionality.

## ✨ Features

- **🎬 Continuous Recording**: Automatic 2-minute video segments for up to 6 hours
- **📺 Live Streaming**: MJPEG streaming accessible via web browser  
- **🔒 Resource Management**: Prevents camera conflicts between recording and streaming
- **⚙️ Modern Tools**: Uses libcamera-vid instead of deprecated raspivid
- **🛡️ No Logging**: Clean, simple operation without log files
- **📱 Interactive Menu**: SSH-based menu system for easy control
- **🗂️ File Management**: Automatic organization and cleanup of recordings
- **🌐 Network Access**: Stream accessible from any device on the network
- **📁 Samba Integration**: Access recordings via network file sharing

## 🚀 Quick Start

### 1. Installation

```bash
# Clone the repository
git clone https://github.com/your-username/carberrypi.git
cd carberrypi

# Make scripts executable
chmod +x welcome.sh
chmod +x bin/*.sh
chmod +x test_modern_system.sh

# Test the system
./test_system.sh
```

### 2. First Run

```bash
# Start the interactive menu
./welcome.sh
```

## 📋 System Requirements

- **Raspberry Pi**: 3B+ or newer recommended
- **Camera**: Raspberry Pi Camera Module (v1, v2, or HQ)
- **OS**: Raspberry Pi OS (Bullseye or newer)
- **Storage**: MicroSD card (32GB+ recommended)
- **Dependencies**: 
  - `libcamera-apps` (for recording)
  - `python3-picamera2` (for streaming)

### Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y libcamera-apps python3-picamera2

# Optional: Install Samba for network file sharing
sudo apt install -y samba
```

## 🎮 Usage

### Interactive Menu System

When you SSH into your Raspberry Pi, run `./welcome.sh` to access the modern menu:

```
🚗 Welcome to Modern CarBerry DashCam! 📹
==========================================

📊 System Status:
   Camera: FREE
   Recording: ⭕ INACTIVE
   Streaming: ⭕ INACTIVE
   Storage: 15% used, 42 recordings

Menu Options:
1. 🎬 Start/Stop Recording
2. 📺 Start/Stop Live Streaming
3. 📁 View Completed Recordings
4. ⚙️  System Information
5. 🧪 Test System
6. 🚪 Exit

Choose an option (1-6):
```

### Command Line Usage

You can also control the system directly via command line:

```bash
# Recording commands
./bin/record.sh start    # Start recording session
./bin/record.sh stop     # Stop recording
./bin/record.sh status   # Check recording status
./bin/record.sh test     # Test recording system

# Streaming commands
./bin/stream.sh start    # Start streaming
./bin/stream.sh stop     # Stop streaming
./bin/stream.sh info     # Show streaming info
./bin/stream.sh test     # Test streaming system
```

## ⚙️ Configuration

Edit `config/dashcam.conf` to customize settings:

```bash
# Camera Settings
CAMERA_WIDTH=1280
CAMERA_HEIGHT=720
CAMERA_FRAMERATE=30
CAMERA_ROTATION=90

# Recording Settings
RECORDING_TIMEOUT=120000        # 2 minutes per segment
RECORDING_MAX_SEGMENTS=180      # 6 hours total

# Streaming Settings
STREAMING_PORT=8000

# File Paths
BASE_DIR="/home/pi/carberryshare"
```

## 🔄 Auto-Start on Boot

To automatically start recording when the Pi boots up:

### Method 1: Using rc.local (Simple)

Add to `/etc/rc.local` before `exit 0`:

```bash
# Start dashcam recording on boot
cd /home/pi/carberrypi
./bin/record.sh start &
```

### Method 2: Using systemd (Recommended)

Create a systemd service file:

```bash
sudo nano /etc/systemd/system/dashcam.service
```

Add the following content:

```ini
[Unit]
Description=CarBerry DashCam Recording Service
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/carberrypi
ExecStart=/home/pi/carberrypi/bin/record.sh start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl enable dashcam.service
sudo systemctl start dashcam.service
```
## 📺 Live Streaming

The system provides MJPEG streaming accessible from any web browser:

### Starting a Stream

```bash
# Via menu system
./welcome.sh
# Select option 2

# Or directly via command line
./bin/stream.sh start
```

### Accessing the Stream

Once streaming starts, you'll see access URLs:

```
✅ Live stream started successfully!
📺 Stream available at:
   http://localhost:8000
   Network access:
     http://192.168.1.100:8000
     http://10.0.0.50:8000
```

### Stream Features

- **📱 Mobile Friendly**: Responsive web interface
- **🔄 Auto Rotation**: Handles camera rotation in browser
- **🌐 Network Access**: Available to all devices on network
- **⚡ Low Latency**: MJPEG streaming for real-time viewing
- **🔒 Resource Safe**: Automatically stops recording when streaming starts

## 📁 File Organization

The system organizes files in a clean structure:

```
/home/pi/carberryshare/
├── in-progress/          # Currently recording files
├── completed/            # Finished recordings
└── (logs removed)        # No logging in modern system
```

### File Naming Convention

Videos are named with timestamps for easy identification:
```
dashcam-video-21-12-2024_14-30-15.h264
```

### Automatic Cleanup

- **Storage Management**: Automatically removes oldest files when storage is full
- **Segment Limits**: Stops recording after configured number of segments
- **Failed Recording Cleanup**: Removes incomplete files automatically

## 🌐 Network File Sharing (Samba)

Access your recordings from any device on the network using Samba/CIFS.

### Setup Samba

```bash
# Install Samba
sudo apt install -y samba

# Create Samba user
sudo smbpasswd -a pi

# Edit Samba configuration
sudo nano /etc/samba/smb.conf
```

Add this configuration to the end of `/etc/samba/smb.conf`:

```ini
[carberryshare]
    path = /home/pi/carberryshare
    comment = CarBerry DashCam Recordings
    browseable = yes
    read only = no
    writable = yes
    valid users = pi
    create mask = 0644
    directory mask = 0755
```

Restart Samba:

```bash
sudo systemctl restart smbd
sudo systemctl enable smbd
```

### Accessing Files

**Windows**: Open File Explorer, go to `\\your-pi-ip\carberryshare`

**macOS**: Finder → Go → Connect to Server → `smb://your-pi-ip/carberryshare`

**Android**: Install a network file manager app, connect to SMB share

**iOS**: Files app → Connect to Server → `smb://your-pi-ip/carberryshare`

## 🔧 Troubleshooting

### Common Issues

**Camera not detected:**
```bash
# Check camera connection
libcamera-hello --list-cameras

# Test camera
./bin/record.sh test
```

**Permission errors:**
```bash
# Fix permissions
sudo chown -R pi:pi /home/pi/carberrypi
chmod +x welcome.sh bin/*.sh
```

**Port already in use:**
```bash
# Check what's using the port
sudo netstat -tulpn | grep :8000

# Kill process using port
sudo pkill -f "port 8000"
```

**Storage full:**
```bash
# Check disk usage
df -h /home/pi/carberryshare

# Manual cleanup
./bin/record.sh stats
```

### System Status Check

```bash
# Run comprehensive test
./test_system.sh

# Check individual components
./bin/record.sh test
./bin/stream.sh test
```

## 🆕 What's New in Modern Version

### ✅ Improvements

- **Modern Tools**: Uses `libcamera-vid` instead of deprecated `raspivid`
- **Resource Management**: Prevents camera conflicts with file-based locking
- **No Logging**: Cleaner operation without log files
- **Better Error Handling**: Graceful failure recovery
- **Interactive Menu**: Modern, user-friendly interface
- **Configuration Management**: Centralized config file
- **Shell-First Design**: Minimal Python usage (only for streaming)

### 🔄 Migration from Old System

The new system is backward compatible with your existing directory structure:

- **Same paths**: `/home/pi/carberryshare/` structure maintained
- **Same file format**: H.264 video files
- **Same Samba setup**: Network sharing works unchanged
- **Improved reliability**: Better process management and error handling

## 📞 Support

### Getting Help

1. **Run system test**: `./test_system.sh`
2. **Check system status**: Use menu option 4 in `./welcome.sh`
3. **View configuration**: `cat config/dashcam.conf`
4. **Test components individually**: Use `test` commands

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes with `./test_system.sh`
4. Submit a pull request

## 📄 License

This project is open source. Feel free to use, modify, and distribute.

---

**🚗 Happy Dashcamming! 📹**
 
