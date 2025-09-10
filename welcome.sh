#!/bin/bash

# Modern CarBerry DashCam Menu System
# Uses libcamera-vid and proper resource management

# Get script directory BEFORE sourcing anything
WELCOME_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$WELCOME_SCRIPT_DIR"

# Source common functions
source "./lib/common.sh"

# Service scripts (use paths relative to welcome.sh location)
RECORD_SCRIPT="$WELCOME_SCRIPT_DIR/bin/record.sh"
STREAM_SCRIPT="$WELCOME_SCRIPT_DIR/bin/stream.sh"

# Debug: verify paths exist
if [[ ! -f "$RECORD_SCRIPT" ]]; then
    echo "Error: Record script not found at $RECORD_SCRIPT" >&2
    echo "Welcome script directory: $WELCOME_SCRIPT_DIR" >&2
    echo "Current directory: $(pwd)" >&2
    echo "Directory contents:" >&2
    ls -la "$WELCOME_SCRIPT_DIR/" >&2
    exit 1
fi

if [[ ! -f "$STREAM_SCRIPT" ]]; then
    echo "Error: Stream script not found at $STREAM_SCRIPT" >&2
    echo "Welcome script directory: $WELCOME_SCRIPT_DIR" >&2
    echo "Current directory: $(pwd)" >&2
    echo "Directory contents:" >&2
    ls -la "$WELCOME_SCRIPT_DIR/" >&2
    exit 1
fi

# Initialize system
init_system

# Function to check if recording is active
check_recording() {
    local status
    status=$("$RECORD_SCRIPT" status 2>/dev/null)
    [[ "$status" =~ ^ACTIVE: ]]
}

# Function to check if streaming is active
check_streaming() {
    local status
    status=$("$STREAM_SCRIPT" status 2>/dev/null)
    [[ "$status" =~ ^ACTIVE: ]]
}

# Function to start streaming
start_streaming() {
    echo "Starting modern live stream..."
    if "$STREAM_SCRIPT" start; then
        echo ""
        echo "✅ Live stream started successfully!"
        
        # Get stream URLs
        echo "📺 Stream available at:"
        echo "   http://localhost:$STREAMING_PORT"
        
        # Show network IPs if available
        local ips
        ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -3)
        if [[ -n "$ips" ]]; then
            echo "   Network access:"
            while IFS= read -r ip; do
                echo "     http://$ip:$STREAMING_PORT"
            done <<< "$ips"
        fi
    else
        echo "❌ Failed to start streaming"
        echo "💡 Make sure recording is stopped first"
    fi
}

# Function to stop streaming
stop_streaming() {
    echo "Stopping live streaming..."
    if "$STREAM_SCRIPT" stop; then
        echo "✅ Live stream stopped!"
    else
        echo "❌ Failed to stop streaming"
    fi
}

# Show system status
show_system_status() {
    echo ""
    echo "📊 System Status:"
    
    # Camera status
    local camera_status
    camera_status=$(get_camera_status)
    echo "   Camera: $camera_status"
    
    # Recording status
    if check_recording; then
        local rec_status
        rec_status=$("$RECORD_SCRIPT" status 2>/dev/null)
        echo "   Recording: ✅ ACTIVE ($rec_status)"
    else
        echo "   Recording: ⭕ INACTIVE"
    fi
    
    # Streaming status
    if check_streaming; then
        local stream_status
        stream_status=$("$STREAM_SCRIPT" status 2>/dev/null)
        echo "   Streaming: ✅ ACTIVE ($stream_status)"
    else
        echo "   Streaming: ⭕ INACTIVE"
    fi
    
    # Storage info
    local disk_usage recording_count
    disk_usage=$(get_disk_usage)
    recording_count=$(get_recording_count)
    echo "   Storage: ${disk_usage}% used, $recording_count recordings"
    echo ""
}

# Main menu loop
while true; do
    clear
    echo "🚗 Welcome to Modern CarBerry DashCam! 📹"
    echo "=========================================="
    
    show_system_status
    
    echo "Menu Options:"
    echo "1. 🎬 Start/Stop Recording"
    echo "2. 📺 Start/Stop Live Streaming"
    echo "3. 📁 View Completed Recordings"
    echo "4. ⚙️  System Information"
    echo "5. 🧪 Test System"
    echo "6. 🚪 Exit"
    echo ""
    read -p "Choose an option (1-6): " choice

    case $choice in
        1)
            echo ""
            if check_recording; then
                echo "🎬 Recording is currently ACTIVE"
                echo "Do you want to stop it? (y/n): "
                read -r stop_recording
                if [[ "$stop_recording" == "y" ]]; then
                    echo "Stopping recording..."
                    if "$RECORD_SCRIPT" stop; then
                        echo "✅ Recording stopped!"
                    else
                        echo "❌ Failed to stop recording"
                    fi
                fi
            else
                echo "🎬 Starting recording session..."
                echo "This will record $RECORDING_MAX_SEGMENTS segments of $((RECORDING_TIMEOUT/1000)) seconds each"
                echo "Press Ctrl+C to stop early"
                echo ""
                "$RECORD_SCRIPT" start
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        
        2)
            echo ""
            if check_streaming; then
                echo "📺 Streaming is currently ACTIVE"
                echo "Do you want to stop it? (y/n): "
                read -r stop_stream
                if [[ "$stop_stream" == "y" ]]; then
                    stop_streaming
                fi
            else
                start_streaming
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        
        3)
            echo ""
            echo "📁 Completed Recordings:"
            echo "======================="
            if [[ -d "$BASE_DIR/$COMPLETED_DIR" ]]; then
                local file_count
                file_count=$(find "$BASE_DIR/$COMPLETED_DIR" -name "*.h264" | wc -l)
                
                if [[ $file_count -gt 0 ]]; then
                    echo "Found $file_count recordings:"
                    echo ""
                    ls -lrth "$BASE_DIR/$COMPLETED_DIR"/*.h264 2>/dev/null | tail -20
                    
                    if [[ $file_count -gt 20 ]]; then
                        echo ""
                        echo "... (showing last 20 files, $file_count total)"
                    fi
                else
                    echo "No recordings found."
                fi
            else
                echo "Recordings directory not found."
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        
        4)
            echo ""
            echo "⚙️  System Information:"
            echo "======================"
            echo "Config file: $CONFIG_FILE"
            echo "Camera: ${CAMERA_WIDTH}x${CAMERA_HEIGHT} @ ${CAMERA_FRAMERATE}fps"
            echo "Rotation: ${CAMERA_ROTATION}°"
            echo "Recording: ${RECORDING_MAX_SEGMENTS} segments x $((RECORDING_TIMEOUT/1000))s"
            echo "Streaming port: $STREAMING_PORT"
            echo "Base directory: $BASE_DIR"
            echo ""
            get_system_status
            echo ""
            read -p "Press Enter to continue..."
            ;;
        
        5)
            echo ""
            echo "🧪 Testing System Components:"
            echo "============================"
            
            echo "Testing recording system..."
            if "$RECORD_SCRIPT" test; then
                echo "✅ Recording system test passed"
            else
                echo "❌ Recording system test failed"
            fi
            
            echo ""
            echo "Testing streaming system..."
            if "$STREAM_SCRIPT" test; then
                echo "✅ Streaming system test passed"
            else
                echo "❌ Streaming system test failed"
            fi
            
            echo ""
            read -p "Press Enter to continue..."
            ;;
        
        6)
            echo ""
            echo "🚪 Exiting CarBerry DashCam..."
            
            # Clean shutdown
            if check_recording; then
                echo "Stopping active recording..."
                "$RECORD_SCRIPT" stop
            fi
            
            if check_streaming; then
                echo "Stopping active streaming..."
                "$STREAM_SCRIPT" stop
            fi
            
            echo "Goodbye! 👋"
            exit 0
            ;;
        
        *)
            echo ""
            echo "❌ Invalid choice. Please select 1-6."
            sleep 2
            ;;
    esac
done
