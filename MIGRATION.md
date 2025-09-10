# 🔄 Migration Guide: Old → Modern System

This document explains the migration from the old system to the modern CarBerry DashCam system.

## 📁 File Changes

### ✅ **Kept & Modernized**
- `welcome.sh` → **Modernized** with new menu system
- `/home/pi/carberryshare/` → **Same directory structure**
- Samba configuration → **Same setup**

### 🆕 **New Files**
- `config/dashcam.conf` → Centralized configuration
- `lib/common.sh` → Core system functions
- `lib/camera_manager.sh` → Camera resource management
- `bin/record_modern.sh` → Modern recording service
- `bin/stream_modern.sh` → Streaming service controller
- `src/stream.py` → Modern Python streaming
- `.gitignore` → Security and privacy protection

### ❌ **Deprecated Files** (Safe to Remove)

#### `record.sh` → `bin/record_modern.sh`
**Old (deprecated):**
```bash
raspivid -awb cloud --sharpness 40 --drc medium -vs -t 120000 -w 1280 -h 720 -fps 33 -rot 90
```

**New (modern):**
```bash
libcamera-vid --timeout 120000 --width 1280 --height 720 --framerate 30 --rotation 90 --awb auto --sharpness 1.5
```

#### `carberrystream.py` → `src/stream.py`
**Old:** Hardcoded settings, no configuration integration
**New:** Configuration-driven, better error handling, modern Picamera2 usage

#### `src/__init__.py`
**Old:** Python package marker (not needed in shell-first approach)
**New:** Not needed - using shell scripts as primary interface

## 🚀 Migration Steps

### 1. **Backup Current System**
```bash
# Backup your recordings
cp -r /home/pi/carberryshare /home/pi/carberryshare.backup

# Backup old scripts
mkdir -p ~/old_dashcam_backup
cp record.sh carberrystream.py ~/old_dashcam_backup/
```

### 2. **Test New System**
```bash
# Test the modern system
./test_modern_system.sh

# Test recording
./bin/record_modern.sh test

# Test streaming  
./bin/stream_modern.sh test
```

### 3. **Update Boot Configuration**

**Old rc.local entry:**
```bash
/bin/sh /root/record.sh
```

**New rc.local entry:**
```bash
cd /home/pi/carberrypi
./bin/record_modern.sh start &
```

### 4. **Remove Old Files** (After Testing)
```bash
# Only after confirming new system works
rm record.sh carberrystream.py src/__init__.py
```

## 🔧 Configuration Migration

### Old System (Hardcoded)
- Settings scattered across multiple files
- No centralized configuration
- Manual editing of scripts required

### New System (Configurable)
All settings in `config/dashcam.conf`:
```bash
# Camera Settings
CAMERA_WIDTH=1280
CAMERA_HEIGHT=720
CAMERA_FRAMERATE=30
CAMERA_ROTATION=90

# Recording Settings  
RECORDING_TIMEOUT=120000
RECORDING_MAX_SEGMENTS=180

# Streaming Settings
STREAMING_PORT=8000
```

## 🆘 Rollback Plan

If you need to rollback to the old system:

```bash
# Restore old files
cp ~/old_dashcam_backup/* ./

# Restore old rc.local entry
sudo nano /etc/rc.local
# Change back to: /bin/sh /root/record.sh

# Restart system
sudo reboot
```

## ✅ Verification Checklist

After migration, verify:

- [ ] Recording works: `./bin/record_modern.sh test`
- [ ] Streaming works: `./bin/stream_modern.sh test`  
- [ ] Menu system works: `./welcome.sh`
- [ ] Files are created in correct directories
- [ ] Samba sharing still works
- [ ] Auto-start on boot works (if configured)

## 🎯 Benefits of Migration

### 🔧 **Technical Improvements**
- **Modern tools**: libcamera-vid vs deprecated raspivid
- **Resource management**: No more camera conflicts
- **Better error handling**: Graceful failure recovery
- **Configuration-driven**: Easy customization

### 🛡️ **Security & Privacy**
- **No logging**: Cleaner operation
-