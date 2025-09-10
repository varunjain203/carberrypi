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
    
    # Detect which camera tool is available
    local camera_cmd=""
    if command -v "rpicam-vid" >/dev/null 2>&1; then
        camera_cmd="rpicam-vid"
    elif command -v "libcamera-vid" >/dev/null 2>&1; then
        camera_cmd="libcamera-vid"
    else
        error "No camera recording tool found (rpicam-vid or libcamera-vid)"
        return 1
    fi
    
    echo "$camera_cmd" \
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
    info "Testing camera availability"
    
    if ! acquire_camera_lock "test" 5; then
        error "Cannot acquire camera lock for testing"
        return 1
    fi
    
    # Test with a very short recording
    local test_file="/tmp/camera_test_$$.h264"
    local cmd
    cmd=$(build_libcamera_vid_command "$test_file" 1000)  # 1 second test
    
    # Running camera test (debug info removed as requested)
    
    if timeout 10 $cmd >/dev/null 2>&1; then
        info "Camera test successful"
        rm -f "$test_file"
        release_camera_lock
        return 0
    else
        error "Camera test failed"
        rm -f "$test_file"
        release_camera_lock
        return 1
    fi
}

# Check if libcamera tools are available
check_libcamera_tools() {
    # Check for both old and new camera tool names
    local old_tools=("libcamera-vid" "libcamera-hello")
    local new_tools=("rpicam-vid" "rpicam-hello")
    local missing=0
    local found_tools=()
    
    # Try new tools first (rpicam-*)
    for tool in "${new_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            found_tools+=("$tool")
        fi
    done
    
    # If new tools not found, try old tools (libcamera-*)
    if [[ ${#found_tools[@]} -eq 0 ]]; then
        for tool in "${old_tools[@]}"; do
            if command -v "$tool" >/dev/null 2>&1; then
                found_tools+=("$tool")
            fi
        done
    fi
    
    # Check if we found the required tools
    if [[ ${#found_tools[@]} -lt 2 ]]; then
        error "Camera tools not found. Tried:"
        for tool in "${new_tools[@]}" "${old_tools[@]}"; do
            error "  - $tool"
        done
        error "Please install camera tools:"
        error "  sudo apt install rpicam-apps  # For newer Raspberry Pi OS"
        error "  sudo apt install libcamera-apps  # For older versions"
        return 1
    fi
    
    info "Found camera tools: ${found_tools[*]}"
    
    if [[ $missing -gt 0 ]]; then
        error "Missing $missing required libcamera tools"
        error "Please install libcamera tools: sudo apt install libcamera-apps"
        return 1
    fi
    
    info "All required libcamera tools are available"
    return 0
}

# Get camera information
get_camera_info() {
    info "Getting camera information"
    
    if ! acquire_camera_lock "info" 5; then
        error "Cannot acquire camera lock for info"
        return 1
    fi
    
    # Use camera info tool to get camera info
    local camera_info_cmd=""
    if command -v "rpicam-hello" >/dev/null 2>&1; then
        camera_info_cmd="rpicam-hello"
    elif command -v "libcamera-hello" >/dev/null 2>&1; then
        camera_info_cmd="libcamera-hello"
    fi
    
    if [[ -n "$camera_info_cmd" ]]; then
        info "Camera information:"
        timeout 5 "$camera_info_cmd" --list-cameras 2>/dev/null | while IFS= read -r line; do
            info "  $line"
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
        error "No PID provided for monitoring"
        return 1
    fi
    
    info "Monitoring camera process $pid ($mode)"
    
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
                info "Camera process $pid reached runtime limit (${runtime}s)"
                terminate_process "$pid"
                break
            fi
        fi
        
        # Periodic status check (debug logging removed as requested)
    done
    
    local end_time
    end_time=$(date +%s)
    local total_runtime=$((end_time - start_time))
    
    info "Camera process $pid finished after ${total_runtime}s"
    return 0
}

# Kill any existing camera processes
kill_camera_processes() {
    info "Checking for existing camera processes"
    
    local processes=("rpicam-vid" "rpicam-hello" "libcamera-vid" "libcamera-hello")
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
        info "Terminated $killed camera processes"
        sleep 2  # Give time for cleanup
    fi
    
    return 0
}

# Initialize camera system
init_camera_system() {
    info "Initializing camera system"
    
    # Check for required tools
    if ! check_libcamera_tools; then
        return 1
    fi
    
    # Kill any existing processes
    kill_camera_processes
    
    # Test camera (optional - skip if no camera hardware)
    if ! test_camera; then
        warn "Camera test failed - this is normal if no camera is connected"
        warn "System will continue but recording/streaming may not work"
    fi
    
    info "Camera system initialized successfully"
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