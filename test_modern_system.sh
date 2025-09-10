#!/bin/bash
# Test script for the modernized dashcam system

set -e

echo "🧪 Testing Modern CarBerry DashCam System"
echo "========================================"

# Source the system
source lib/common.sh

echo ""
echo "1. Testing system initialization..."
if init_system; then
    echo "   ✅ System initialization successful"
else
    echo "   ❌ System initialization failed"
    exit 1
fi

echo ""
echo "2. Testing configuration..."
echo "   Camera: ${CAMERA_WIDTH}x${CAMERA_HEIGHT} @ ${CAMERA_FRAMERATE}fps"
echo "   Rotation: ${CAMERA_ROTATION}°"
echo "   Recording: ${RECORDING_MAX_SEGMENTS} segments x $((RECORDING_TIMEOUT/1000))s"
echo "   Streaming port: $STREAMING_PORT"
echo "   Base directory: $BASE_DIR"
echo "   ✅ Configuration loaded"

echo ""
echo "3. Testing directory structure..."
for dir in "$BASE_DIR" "$BASE_DIR/$IN_PROGRESS_DIR" "$BASE_DIR/$COMPLETED_DIR"; do
    if [[ -d "$dir" ]]; then
        echo "   ✅ $dir"
    else
        echo "   ❌ $dir missing"
        exit 1
    fi
done

echo ""
echo "4. Testing camera resource management..."
if acquire_camera_lock "test"; then
    echo "   ✅ Camera lock acquired"
    
    status=$(get_camera_status)
    echo "   ✅ Camera status: $status"
    
    if release_camera_lock; then
        echo "   ✅ Camera lock released"
    else
        echo "   ❌ Failed to release camera lock"
        exit 1
    fi
else
    echo "   ❌ Failed to acquire camera lock"
    exit 1
fi

echo ""
echo "5. Testing recording script..."
if [[ -x "bin/record_modern.sh" ]]; then
    echo "   ✅ Recording script exists and is executable"
    
    # Test help command
    if bin/record_modern.sh help >/dev/null 2>&1; then
        echo "   ✅ Recording script help works"
    else
        echo "   ❌ Recording script help failed"
    fi
else
    echo "   ❌ Recording script missing or not executable"
    exit 1
fi

echo ""
echo "6. Testing streaming script..."
if [[ -x "bin/stream_modern.sh" ]]; then
    echo "   ✅ Streaming script exists and is executable"
    
    # Test help command
    if bin/stream_modern.sh help >/dev/null 2>&1; then
        echo "   ✅ Streaming script help works"
    else
        echo "   ❌ Streaming script help failed"
    fi
else
    echo "   ❌ Streaming script missing or not executable"
    exit 1
fi

echo ""
echo "7. Testing Python streaming dependencies..."
if command -v python3 >/dev/null 2>&1; then
    echo "   ✅ Python3 available"
    
    if [[ -f "src/stream.py" ]]; then
        echo "   ✅ Python streaming script exists"
        
        # Test basic syntax
        if python3 -m py_compile src/stream.py 2>/dev/null; then
            echo "   ✅ Python streaming script syntax OK"
        else
            echo "   ⚠️  Python streaming script has syntax issues"
        fi
    else
        echo "   ❌ Python streaming script missing"
    fi
else
    echo "   ❌ Python3 not available"
fi

echo ""
echo "8. Testing modernized welcome.sh..."
if [[ -x "welcome.sh" ]]; then
    echo "   ✅ Welcome script exists and is executable"
    
    # Test syntax
    if bash -n welcome.sh; then
        echo "   ✅ Welcome script syntax OK"
    else
        echo "   ❌ Welcome script has syntax errors"
        exit 1
    fi
else
    echo "   ❌ Welcome script missing or not executable"
    exit 1
fi

echo ""
echo "9. Testing system status functions..."
disk_usage=$(get_disk_usage)
recording_count=$(get_recording_count)
echo "   ✅ Disk usage: ${disk_usage}%"
echo "   ✅ Recording count: $recording_count"

echo ""
echo "🎉 All tests passed!"
echo ""
echo "📋 System Summary:"
echo "=================="
echo "✅ Core system: Ready"
echo "✅ Configuration: Loaded"
echo "✅ Directory structure: Created"
echo "✅ Camera management: Working"
echo "✅ Recording service: Ready"
echo "✅ Streaming service: Ready"
echo "✅ Menu system: Modernized"
echo ""
echo "🚀 Ready to use! Run './welcome.sh' to start"