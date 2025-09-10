#!/bin/bash
# Modern recording service using libcamera-vid
# Replaces the old record.sh with modern camera tools and proper resource management

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/camera_manager.sh"

# Global variables
RECORDING_PID=""
SEGMENT_COUNT=0
RECORDING_ACTIVE=false

# Signal handlers for graceful shutdown
cleanup_recording() {
    info "Cleaning up recording session..."
    
    if [[ -n "$RECORDING_PID" ]] && is_process_running "$RECORDING_PID"; then
        info "Stopping active recording process (PID: $RECORDING_PID)"
        terminate_process "$RECORDING_PID"
    fi
    
    release_camera_lock
    RECORDING_ACTIVE=false
    
    info "Recording cleanup complete"
}

signal_handler() {
    info "Received shutdown signal"
    cleanup_recording
    exit 0
}

trap signal_handler SIGTERM SIGINT

# Initialize recording system
init_recording_system() {
    info "Initializing modern recording system"
    
    # Initialize core system
    if ! init_system; then
        error "Failed to initialize core system"
        return 1
    fi
    
    # Initialize camera system
    if ! init_camera_system; then
        error "Failed to initialize camera system"
        return 1
    fi
    
    # Acquire camera lock for recording
    if ! acquire_camera_lock "recording"; then
        error "Cannot acquire camera lock - another process may be using the camera"
        return 1
    fi
    
    info "Recording system initialized successfully"
    return 0
}

# Generate filename with timestamp
generate_filename() {
    local timestamp
    timestamp=$(date +"%d-%m-%Y_%H-%M-%S")
    echo "dashcam-video-${timestamp}.h264"
}

# Record a single video segment
record_segment() {
    local segment_num="$1"
    local filename
    filename=$(generate_filename)
    local output_path="$BASE_DIR/$IN_PROGRESS_DIR/$filename"
    
    info "Recording segment $segment_num: $filename"
    
    # Build libcamera-vid command
    local cmd
    cmd=$(build_libcamera_vid_command "$output_path" "$RECORDING_TIMEOUT")
    
    info "Executing: $cmd"
    
    # Start recording process
    $cmd &
    RECORDING_PID=$!
    
    # Wait for recording to complete
    if wait $RECORDING_PID; then
        info "Segment $segment_num completed successfully"
        
        # Move completed video to completed directory
        if move_completed_video "$filename"; then
            info "Moved $filename to completed directory"
        else
            warn "Failed to move $filename to completed directory"
        fi
        
        # Cleanup old files if we have too many
        cleanup_old_files "$RECORDING_MAX_SEGMENTS"
        
        RECORDING_PID=""
        return 0
    else
        local exit_code=$?
        error "Recording segment $segment_num failed with exit code $exit_code"
        
        # Clean up failed recording file
        if [[ -f "$output_path" ]]; then
            rm -f "$output_path"
            info "Cleaned up failed recording file"
        fi
        
        RECORDING_PID=""
        return 1
    fi
}

# Main recording loop
start_recording_session() {
    info "Starting recording session - will record $RECORDING_MAX_SEGMENTS segments"
    info "Camera settings: ${CAMERA_WIDTH}x${CAMERA_HEIGHT} @ ${CAMERA_FRAMERATE}fps, rotation ${CAMERA_ROTATION}°"
    info "Segment duration: $((RECORDING_TIMEOUT / 1000)) seconds"
    
    RECORDING_ACTIVE=true
    SEGMENT_COUNT=0
    
    # Main recording loop
    for ((i=1; i<=RECORDING_MAX_SEGMENTS; i++)); do
        if ! $RECORDING_ACTIVE; then
            info "Recording session stopped by user"
            break
        fi
        
        info "Starting segment $i of $RECORDING_MAX_SEGMENTS"
        
        if record_segment "$i"; then
            ((SEGMENT_COUNT++))
            
            # Show progress
            local progress=$((i * 100 / RECORDING_MAX_SEGMENTS))
            info "Progress: $progress% ($i/$RECORDING_MAX_SEGMENTS segments)"
            
            # Check disk space periodically
            if [[ $((i % 10)) -eq 0 ]]; then
                local disk_usage
                disk_usage=$(get_disk_usage)
                info "Disk usage: ${disk_usage}%"
                
                if [[ $disk_usage -gt 90 ]]; then
                    warn "Disk usage high (${disk_usage}%), cleaning up old files"
                    cleanup_old_files $((RECORDING_MAX_SEGMENTS / 2))
                fi
            fi
        else
            error "Failed to record segment $i"
            
            # Ask user if they want to continue after failure
            if [[ -t 0 ]]; then  # Only if running interactively
                echo "Recording failed. Continue with next segment? (y/n): "
                read -r continue_recording
                if [[ "$continue_recording" != "y" ]]; then
                    break
                fi
            else
                # Non-interactive mode - stop after 3 consecutive failures
                if [[ $((i % 3)) -eq 0 ]]; then
                    error "Multiple recording failures, stopping session"
                    break
                fi
            fi
        fi
        
        # Small delay between segments
        sleep 1
    done
    
    RECORDING_ACTIVE=false
    info "Recording session completed - recorded $SEGMENT_COUNT segments"
}

# Stop recording session
stop_recording_session() {
    if $RECORDING_ACTIVE; then
        info "Stopping recording session..."
        RECORDING_ACTIVE=false
        
        if [[ -n "$RECORDING_PID" ]] && is_process_running "$RECORDING_PID"; then
            terminate_process "$RECORDING_PID"
        fi
        
        info "Recording session stopped"
    else
        info "No active recording session to stop"
    fi
}

# Get recording status
get_recording_status() {
    if $RECORDING_ACTIVE; then
        echo "ACTIVE:$SEGMENT_COUNT:$RECORDING_MAX_SEGMENTS:$RECORDING_PID"
    else
        echo "INACTIVE:$SEGMENT_COUNT:$RECORDING_MAX_SEGMENTS"
    fi
}

# Show recording statistics
show_recording_stats() {
    info "Recording Statistics:"
    info "  Segments recorded: $SEGMENT_COUNT"
    info "  Max segments: $RECORDING_MAX_SEGMENTS"
    info "  Recording active: $RECORDING_ACTIVE"
    
    if [[ -n "$RECORDING_PID" ]]; then
        info "  Active PID: $RECORDING_PID"
    fi
    
    local completed_count
    completed_count=$(get_recording_count)
    info "  Total completed recordings: $completed_count"
    
    local disk_usage
    disk_usage=$(get_disk_usage)
    info "  Disk usage: ${disk_usage}%"
}

# Test recording system
test_recording() {
    info "Testing recording system..."
    
    if ! init_recording_system; then
        error "Recording system initialization failed"
        return 1
    fi
    
    # Record a short test segment (5 seconds)
    local test_filename="test-$(date +%s).h264"
    local test_path="$BASE_DIR/$IN_PROGRESS_DIR/$test_filename"
    
    info "Recording 5-second test segment: $test_filename"
    
    local cmd
    cmd=$(build_libcamera_vid_command "$test_path" 5000)  # 5 seconds
    
    if timeout 10 $cmd; then
        info "Test recording successful"
        
        # Check file size
        if [[ -f "$test_path" ]]; then
            local file_size
            file_size=$(stat -f%z "$test_path" 2>/dev/null || stat -c%s "$test_path" 2>/dev/null)
            info "Test file size: $file_size bytes"
            
            # Move to completed directory
            if move_completed_video "$test_filename"; then
                info "Test file moved to completed directory"
            fi
        fi
        
        cleanup_recording
        return 0
    else
        error "Test recording failed"
        rm -f "$test_path"
        cleanup_recording
        return 1
    fi
}

# Main function
main() {
    case "${1:-start}" in
        "start")
            if ! init_recording_system; then
                error "Failed to initialize recording system"
                exit 1
            fi
            start_recording_session
            cleanup_recording
            ;;
        "stop")
            stop_recording_session
            ;;
        "status")
            get_recording_status
            ;;
        "stats")
            show_recording_stats
            ;;
        "test")
            test_recording
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 {start|stop|status|stats|test|help}"
            echo ""
            echo "Commands:"
            echo "  start  - Start recording session (default)"
            echo "  stop   - Stop active recording session"
            echo "  status - Show recording status"
            echo "  stats  - Show detailed recording statistics"
            echo "  test   - Test recording system with short segment"
            echo "  help   - Show this help message"
            echo ""
            echo "Configuration:"
            echo "  Config file: $CONFIG_FILE"
            echo "  Segments: $RECORDING_MAX_SEGMENTS x $((RECORDING_TIMEOUT/1000))s"
            echo "  Resolution: ${CAMERA_WIDTH}x${CAMERA_HEIGHT} @ ${CAMERA_FRAMERATE}fps"
            echo "  Output: $BASE_DIR"
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