#!/bin/bash
# Test script to verify core system structure and configuration

set -e

# Source the common functions
source lib/common.sh

echo "Testing Dashcam Core System..."

# Test 1: Configuration loading
echo "1. Testing configuration loading..."
echo "   Camera: ${CAMERA_WIDTH}x${CAMERA_HEIGHT} @ ${CAMERA_FRAMERATE}fps"
echo "   Rotation: ${CAMERA_ROTATION}°"
echo "   Base path: $BASE_DIR"
echo "   Streaming port: $STREAMING_PORT"
echo "   ✅ Configuration loaded"

# Test 2: Configuration validation
echo "2. Testing configuration validation..."
if validate_config; then
    echo "   ✅ Configuration validation passed"
else
    echo "   ❌ Configuration validation failed"
    exit 1
fi

# Test 3: Directory structure (using temp directory for testing)
echo "3. Testing directory structure..."
ORIGINAL_BASE_DIR="$BASE_DIR"
BASE_DIR="/tmp/dashcam_test_$$"

if ensure_directories; then
    echo "   ✅ Directory structure created"
    
    # Check if directories exist
    for dir in "$BASE_DIR" "$BASE_DIR/$IN_PROGRESS_DIR" "$BASE_DIR/$COMPLETED_DIR"; do
        if [[ -d "$dir" ]]; then
            echo "   ✅ $dir"
        else
            echo "   ❌ $dir missing"
            exit 1
        fi
    done
else
    echo "   ❌ Failed to create directory structure"
    exit 1
fi

# Test 4: Camera lock mechanism
echo "4. Testing camera lock mechanism..."
if acquire_camera_lock "test"; then
    echo "   ✅ Camera lock acquired"
    
    # Test lock status
    status=$(get_camera_status)
    if [[ "$status" =~ ^LOCKED:test: ]]; then
        echo "   ✅ Camera status correct: $status"
    else
        echo "   ❌ Camera status incorrect: $status"
        exit 1
    fi
    
    # Test lock release
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

# Test 5: File management
echo "5. Testing file management..."
# Create a test file
test_file="test_video_$(date +%s).h264"
touch "$BASE_DIR/$IN_PROGRESS_DIR/$test_file"

if move_completed_video "$test_file"; then
    if [[ -f "$BASE_DIR/$COMPLETED_DIR/$test_file" ]]; then
        echo "   ✅ File moved successfully"
    else
        echo "   ❌ File not found in completed directory"
        exit 1
    fi
else
    echo "   ❌ Failed to move file"
    exit 1
fi

# Test 6: System status
echo "6. Testing system status..."
get_system_status
echo "   ✅ System status retrieved"

# Test 7: System initialization
echo "7. Testing system initialization..."
if init_system; then
    echo "   ✅ System initialization successful"
else
    echo "   ❌ System initialization failed"
    exit 1
fi

# Cleanup test directory
rm -rf "$BASE_DIR"
BASE_DIR="$ORIGINAL_BASE_DIR"

echo ""
echo "🎉 All core system tests passed!"
echo ""
echo "Next steps:"
echo "- Run recording service with shell scripts using libcamera-vid"
echo "- Use Python streaming only when recording is not active"
echo "- Create interactive menu system"