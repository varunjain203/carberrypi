#!/bin/bash
# Modern streaming service controller
# Manages the Python streaming service with proper resource management

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/camera_manager.sh"

# Global variables
STREAMING_PID=""
STREAMING_PID_FILE="/tmp/dashcam_streaming.pid"

# Signal handlers
cleanup_streaming() {
    info "Cleaning up streaming session..."
    
    if [[ -n "$STREAMING_PID" ]] && is_process_running "$STREAMING_PID"; then
        info "Stopping streaming process (PID: $STREAMING_PID)"
        terminate_process "$STREAMING_PID"
    fi
    
    # Clean up PID file
    rm -f "$STREAMING_PID_FILE"
    
    release_camera_lock
    info "Streaming cleanup complete"
}

signal_handler() {
    info "Received shutdown signal"
    cleanup_streaming
    exit 0
}

trap signal_handler SIGTERM SIGINT

# Check if streaming is currently active
is_streaming_active() {
    if [[ -f "$STREAMING_PID_FILE" ]]; then
        local pid
        pid=$(cat "$STREAMING_PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && is_process_running "$pid"; then
            STREAMING_PID="$pid"
            return 0
        else
            # Clean up stale PID file
            rm -f "$STREAMING_PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Start streaming service
start_streaming() {
    info "Starting streaming service..."
    
    # Check if already running
    if is_streaming_active; then
        info "Streaming is already active (PID: $STREAMING_PID)"
        return 0
    fi
    
    # Initialize core system
    if ! init_system; then
        error "Failed to initialize core system"
        return 1
    fi
    
    # Acquire camera lock for streaming
    if ! acquire_camera_lock "streaming"; then
        error "Cannot acquire camera lock - recording may be active"
        error "Stop recording first, then try streaming"
        return 1
    fi
    
    # Check if Python streaming script exists
    local stream_script="$SCRIPT_DIR/../src/stream.py"
    if [[ ! -f "$stream_script" ]]; then
        error "Streaming script not found: $stream_script"
        release_camera_lock
        return 1
    fi
    
    # Start Python streaming service
    info "Starting Python streaming service on port $STREAMING_PORT"
    info "Camera: ${CAMERA_WIDTH}x${CAMERA_HEIGHT}, rotation ${CAMERA_ROTATION}°"
    
    python3 "$stream_script" &
    STREAMING_PID=$!
    
    # Save PID to file
    echo "$STREAMING_PID" > "$STREAMING_PID_FILE"
    
    # Wait a moment to see if it starts successfully
    sleep 2
    
    if is_process_running "$STREAMING_PID"; then
        info "Streaming service started successfully (PID: $STREAMING_PID)"
        info "Stream available at:"
        info "  http://localhost:$STREAMING_PORT"
        
        # Try to get local IP addresses
        local ips
        ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -3)
        if [[ -n "$ips" ]]; then
            info "  Network access:"
            while IFS= read -r ip; do
                info "    http://$ip:$STREAMING_PORT"
            done <<< "$ips"
        fi
        
        return 0
    else
        error "Failed to start streaming service"
        rm -f "$STREAMING_PID_FILE"
        release_camera_lock
        return 1
    fi
}

# Stop streaming service
stop_streaming() {
    info "Stopping streaming service..."
    
    if is_streaming_active; then
        info "Terminating streaming process (PID: $STREAMING_PID)"
        
        if terminate_process "$STREAMING_PID"; then
            info "Streaming service stopped successfully"
        else
            warn "Failed to terminate streaming process gracefully"
        fi
        
        rm -f "$STREAMING_PID_FILE"
        release_camera_lock
        STREAMING_PID=""
        return 0
    else
        info "No active streaming service to stop"
        return 0
    fi
}

# Get streaming status
get_streaming_status() {
    if is_streaming_active; then
        echo "ACTIVE:$STREAMING_PID:$STREAMING_PORT"
    else
        echo "INACTIVE"
    fi
}

# Show streaming information
show_streaming_info() {
    info "Streaming Service Information:"
    
    if is_streaming_active; then
        info "  Status: ACTIVE"
        info "  PID: $STREAMING_PID"
        info "  Port: $STREAMING_PORT"
        info "  Camera: ${CAMERA_WIDTH}x${CAMERA_HEIGHT}, rotation ${CAMERA_ROTATION}°"
        
        # Show access URLs
        info "  Access URLs:"
        info "    http://localhost:$STREAMING_PORT"
        
        local ips
        ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -3)
        if [[ -n "$ips" ]]; then
            while IFS= read -r ip; do
                info "    http://$ip:$STREAMING_PORT"
            done <<< "$ips"
        fi
    else
        info "  Status: INACTIVE"
        info "  Port: $STREAMING_PORT (configured)"
        info "  Camera: ${CAMERA_WIDTH}x${CAMERA_HEIGHT}, rotation ${CAMERA_ROTATION}° (configured)"
    fi
    
    # Show camera lock status
    local camera_status
    camera_status=$(get_camera_status)
    info "  Camera lock: $camera_status"
}

# Test streaming system
test_streaming() {
    info "Testing streaming system..."
    
    # Check Python and required modules
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python3 not found"
        return 1
    fi
    
    # Test import of required modules
    if ! python3 -c "from picamera2 import Picamera2" 2>/dev/null; then
        error "Picamera2 module not available"
        error "Install with: sudo apt install python3-picamera2"
        return 1
    fi
    
    info "Python dependencies OK"
    
    # Test camera availability
    if ! init_camera_system; then
        error "Camera system test failed"
        return 1
    fi
    
    info "Camera system test passed"
    
    # Test port availability
    if netstat -tuln 2>/dev/null | grep -q ":$STREAMING_PORT "; then
        warn "Port $STREAMING_PORT is already in use"
        return 1
    fi
    
    info "Port $STREAMING_PORT is available"
    info "Streaming system test passed"
    return 0
}

# Monitor streaming service
monitor_streaming() {
    if ! is_streaming_active; then
        error "No active streaming service to monitor"
        return 1
    fi
    
    info "Monitoring streaming service (PID: $STREAMING_PID)"
    info "Press Ctrl+C to stop monitoring"
    
    local start_time
    start_time=$(date +%s)
    
    while is_process_running "$STREAMING_PID"; do
        sleep 10
        
        local runtime=$(($(date +%s) - start_time))
        local hours=$((runtime / 3600))
        local minutes=$(((runtime % 3600) / 60))
        local seconds=$((runtime % 60))
        
        info "Streaming active for ${hours}h ${minutes}m ${seconds}s"
        
        # Check if port is still listening
        if ! netstat -tuln 2>/dev/null | grep -q ":$STREAMING_PORT "; then
            warn "Streaming port $STREAMING_PORT is no longer listening"
        fi
    done
    
    warn "Streaming process has stopped"
    cleanup_streaming
}

# Main function
main() {
    case "${1:-help}" in
        "start")
            start_streaming
            ;;
        "stop")
            stop_streaming
            ;;
        "restart")
            stop_streaming
            sleep 2
            start_streaming
            ;;
        "status")
            get_streaming_status
            ;;
        "info")
            show_streaming_info
            ;;
        "test")
            test_streaming
            ;;
        "monitor")
            monitor_streaming
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 {start|stop|restart|status|info|test|monitor|help}"
            echo ""
            echo "Commands:"
            echo "  start   - Start streaming service"
            echo "  stop    - Stop streaming service"
            echo "  restart - Restart streaming service"
            echo "  status  - Show streaming status"
            echo "  info    - Show detailed streaming information"
            echo "  test    - Test streaming system dependencies"
            echo "  monitor - Monitor active streaming service"
            echo "  help    - Show this help message"
            echo ""
            echo "Configuration:"
            echo "  Config file: $CONFIG_FILE"
            echo "  Port: $STREAMING_PORT"
            echo "  Resolution: ${CAMERA_WIDTH}x${CAMERA_HEIGHT}"
            echo "  Rotation: ${CAMERA_ROTATION}°"
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"