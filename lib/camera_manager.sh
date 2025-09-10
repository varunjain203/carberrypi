#!/bin/bash
# Camera resource management for the dashcam system
# Ensures only one process can use the camera at a time

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Camera command builders
build_libcamera_vid_command() {
    local output_file="$1"
    local timeout="${2:-$RECORDING_TIMEOUT}"
    
    echo "libcamera-vid" \
         "--timeout" "$timeout" \
         "--width" "$CAMERA_WIDTH" \
         "--height" "$CAMERA_HEIGHT" \
         "--framerate" "$CAMERA_FRAMERATE" \
         "--rotation" "$CAMERA_ROTATION" \
         "--awb" "$CAMERA_AWB" \
         "--sharpness" "$CAMERA_SHARPNESS" \
         "--output" "$output_file"
}

# Test camera availability
test_camera() {
    log_info "Testing camera availability"
    
    if ! acquire_camera_lock "test" 5; then
        log_error "Cannot acquire camera lock for testing"
        return 1
    fi
    
    # Test with a very short recording
    local test_file="/tmp/camera_test_$$.h264"
    local cmd
    cmd=$(build_libcamera_vid_command "$test_file" 1000)  # 1 second test
    
    log_debug "Running camera test: $cmd"
    
    if timeout 10 $cmd >/dev/null 2>&1; then
        log_info "Camera test successful"
        rm -f "$test_file"
        release_camera_lock
        return 0
    else
        log_error "Camera test failed"
        rm -f "$test_file"
        release_camera_lock
        return 1
    fi
}

# Check if libcamera tools are available
check_libcamera_tools() {
    local tools=("libcamera-vid" "libcamera-hello")
    local missing=0
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            ((missing++))
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        log_error "Missing $missing required libcamera tools"
        log_error "Please install libcamera tools: sudo apt install libcamera-apps"
        return 1
    fi
    
    log_info "All required libcamera tools are available"
    return 0
}

# Get camera information
get_camera_info() {
    log_info "Getting camera information"
    
    if ! acquire_camera_lock "info" 5; then
        log_error "Cannot acquire camera lock for info"
        return 1
    fi
    
    # Use libcamera-hello to get camera info
    if command -v libcamera-hello >/dev/null 2>&1; then
        log_info "Camera information:"
        timeout 5 libcamera-hello --list-cameras 2>/dev/null | while IFS= read -r line; do
            log_info "  $line"
        done
    fi
    
    release_camera_lock
    return 0
}

# Monitor camera process
monitor_camera_process() {
    local pid="$1"
    local mode="$2"
    local max_runtime="${3:-0}"  # 0 means no limit
    
    if [[ -z "$pid" ]]; then
        log_error "No PID provided for monitoring"
        return 1
    fi
    
    log_info "Monitoring camera process $pid ($mode)"
    
    local start_time
    start_time=$(date +%s)
    
    while is_process_running "$pid"; do
        sleep 5
        
        # Check runtime limit
        if [[ $max_runtime -gt 0 ]]; then
            local current_time
            current_time=$(date +%s)
            local runtime=$((current_time - start_time))
            
            if [[ $runtime -ge $max_runtime ]]; then
                log_info "Camera process $pid reached runtime limit (${runtime}s)"
                terminate_process "$pid"
                break
            fi
        fi
        
        # Log periodic status
        local runtime=$(($(date +%s) - start_time))
        if [[ $((runtime % 60)) -eq 0 ]] && [[ $runtime -gt 0 ]]; then
            log_debug "Camera process $pid running for ${runtime}s"
        fi
    done
    
    local end_time
    end_time=$(date +%s)
    local total_runtime=$((end_time - start_time))
    
    log_info "Camera process $pid finished after ${total_runtime}s"
    return 0
}

# Kill any existing camera processes
kill_camera_processes() {
    log_info "Checking for existing camera processes"
    
    local processes=("libcamera-vid" "libcamera-hello")
    local killed=0
    
    for process in "${processes[@]}"; do
        local pids
        pids=$(pgrep -f "$process" 2>/dev/null)
        
        if [[ -n "$pids" ]]; then
            log_warn "Found existing $process processes: $pids"
            
            for pid in $pids; do
                if terminate_process "$pid"; then
                    ((killed++))
                fi
            done
        fi
    done
    
    if [[ $killed -gt 0 ]]; then
        log_info "Terminated $killed camera processes"
        sleep 2  # Give time for cleanup
    fi
    
    return 0
}

# Initialize camera system
init_camera_system() {
    log_info "Initializing camera system"
    
    # Check for required tools
    if ! check_libcamera_tools; then
        return 1
    fi
    
    # Kill any existing processes
    kill_camera_processes
    
    # Test camera
    if ! test_camera; then
        log_error "Camera initialization failed"
        return 1
    fi
    
    log_info "Camera system initialized successfully"
    return 0
}

# Main function for standalone execution
main() {
    case "${1:-}" in
        "test")
            test_camera
            ;;
        "info")
            get_camera_info
            ;;
        "init")
            init_camera_system
            ;;
        "kill")
            kill_camera_processes
            ;;
        "status")
            get_camera_status
            ;;
        *)
            echo "Usage: $0 {test|info|init|kill|status}"
            echo "  test   - Test camera functionality"
            echo "  info   - Get camera information"
            echo "  init   - Initialize camera system"
            echo "  kill   - Kill existing camera processes"
            echo "  status - Show camera lock status"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi