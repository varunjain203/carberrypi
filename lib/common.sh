#!/bin/bash
# Common functions and utilities for the dashcam system

# Source configuration - try multiple locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try different config file locations
CONFIG_LOCATIONS=(
    "${CONFIG_FILE:-}"                           # Environment variable if set
    "$SCRIPT_DIR/../config/dashcam.conf"         # Relative to lib directory
    "$(pwd)/config/dashcam.conf"                 # Relative to current directory
    "/home/pi/carberrypi/config/dashcam.conf"    # Absolute path
)

CONFIG_FILE=""
for location in "${CONFIG_LOCATIONS[@]}"; do
    if [[ -n "$location" ]] && [[ -f "$location" ]]; then
        CONFIG_FILE="$location"
        break
    fi
done

if [[ -n "$CONFIG_FILE" ]] && [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found in any of these locations:" >&2
    for location in "${CONFIG_LOCATIONS[@]}"; do
        if [[ -n "$location" ]]; then
            echo "  - $location" >&2
        fi
    done
    echo "Current working directory: $(pwd)" >&2
    echo "Script directory: $SCRIPT_DIR" >&2
    exit 1
fi

# Simple output functions (no logging)
info() {
    echo "INFO: $*"
}

warn() {
    echo "WARN: $*" >&2
}

error() {
    echo "ERROR: $*" >&2
}

# Directory management
ensure_directories() {
    local dirs=(
        "$BASE_DIR"
        "$BASE_DIR/$IN_PROGRESS_DIR"
        "$BASE_DIR/$COMPLETED_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            info "Creating directory: $dir"
            mkdir -p "$dir" || {
                error "Failed to create directory: $dir"
                return 1
            }
        fi
    done
    
    # Set proper permissions
    chmod 755 "$BASE_DIR" "$BASE_DIR/$IN_PROGRESS_DIR" "$BASE_DIR/$COMPLETED_DIR"
    return 0
}

# Camera resource management
acquire_camera_lock() {
    local mode="$1"
    local timeout="${2:-30}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if (set -C; echo "$$:$mode:$(date +%s)" > "$LOCK_FILE") 2>/dev/null; then
            return 0
        fi
        
        # Check if existing lock is stale
        if [[ -f "$LOCK_FILE" ]]; then
            local lock_info
            lock_info=$(cat "$LOCK_FILE" 2>/dev/null)
            local lock_pid
            lock_pid=$(echo "$lock_info" | cut -d: -f1)
            
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                rm -f "$LOCK_FILE"
                continue
            fi
        fi
        
        sleep 1
        ((count++))
    done
    
    return 1
}

release_camera_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_info
        lock_info=$(cat "$LOCK_FILE" 2>/dev/null)
        local lock_pid
        lock_pid=$(echo "$lock_info" | cut -d: -f1)
        
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$LOCK_FILE"
            return 0
        else
            return 1
        fi
    else
        return 0
    fi
}

get_camera_status() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_info
        lock_info=$(cat "$LOCK_FILE" 2>/dev/null)
        local lock_pid lock_mode lock_time
        IFS=: read -r lock_pid lock_mode lock_time <<< "$lock_info"
        
        if kill -0 "$lock_pid" 2>/dev/null; then
            echo "LOCKED:$lock_mode:$lock_pid:$lock_time"
        else
            echo "STALE:$lock_mode:$lock_pid:$lock_time"
        fi
    else
        echo "FREE"
    fi
}

# Process management
is_process_running() {
    local pid="$1"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

terminate_process() {
    local pid="$1"
    local timeout="${2:-10}"
    
    if ! is_process_running "$pid"; then
        return 0
    fi
    
    kill -TERM "$pid" 2>/dev/null
    
    # Wait for graceful termination
    local count=0
    while [[ $count -lt $timeout ]] && is_process_running "$pid"; do
        sleep 1
        ((count++))
    done
    
    # Force kill if still running
    if is_process_running "$pid"; then
        kill -KILL "$pid" 2>/dev/null
        sleep 1
    fi
    
    if is_process_running "$pid"; then
        return 1
    else
        return 0
    fi
}

# File management
move_completed_video() {
    local filename="$1"
    local source="$BASE_DIR/$IN_PROGRESS_DIR/$filename"
    local dest="$BASE_DIR/$COMPLETED_DIR/$filename"
    
    if [[ ! -f "$source" ]]; then
        return 1
    fi
    
    mv "$source" "$dest"
}

cleanup_old_files() {
    local max_files="$1"
    local completed_dir="$BASE_DIR/$COMPLETED_DIR"
    
    if [[ ! -d "$completed_dir" ]]; then
        return 0
    fi
    
    # Count current files
    local file_count
    file_count=$(find "$completed_dir" -name "*.h264" | wc -l)
    
    if [[ $file_count -le $max_files ]]; then
        return 0
    fi
    
    # Remove oldest files
    local files_to_remove=$((file_count - max_files))
    
    find "$completed_dir" -name "*.h264" -type f -printf '%T@ %p\n' | \
        sort -n | \
        head -n "$files_to_remove" | \
        cut -d' ' -f2- | \
        while IFS= read -r file; do
            rm "$file" 2>/dev/null
        done
}

get_disk_usage() {
    local path="$BASE_DIR"
    if [[ -d "$path" ]]; then
        df "$path" | awk 'NR==2 {print $5}' | sed 's/%//'
    else
        echo "0"
    fi
}

get_recording_count() {
    local completed_dir="$BASE_DIR/$COMPLETED_DIR"
    if [[ -d "$completed_dir" ]]; then
        find "$completed_dir" -name "*.h264" | wc -l
    else
        echo "0"
    fi
}

# System status
get_system_status() {
    local camera_status
    camera_status=$(get_camera_status)
    
    local disk_usage
    disk_usage=$(get_disk_usage)
    
    local recording_count
    recording_count=$(get_recording_count)
    
    echo "Camera: $camera_status"
    echo "Disk Usage: ${disk_usage}%"
    echo "Recordings: $recording_count"
    echo "Uptime: $(uptime -p)"
}

# Validation functions
validate_config() {
    local errors=0
    
    # Check camera settings
    if [[ ! "$CAMERA_WIDTH" =~ ^[0-9]+$ ]] || [[ $CAMERA_WIDTH -le 0 ]]; then
        error "Invalid camera width: $CAMERA_WIDTH"
        ((errors++))
    fi
    
    if [[ ! "$CAMERA_HEIGHT" =~ ^[0-9]+$ ]] || [[ $CAMERA_HEIGHT -le 0 ]]; then
        error "Invalid camera height: $CAMERA_HEIGHT"
        ((errors++))
    fi
    
    if [[ ! "$CAMERA_FRAMERATE" =~ ^[0-9]+$ ]] || [[ $CAMERA_FRAMERATE -le 0 ]]; then
        error "Invalid camera framerate: $CAMERA_FRAMERATE"
        ((errors++))
    fi
    
    if [[ ! "$CAMERA_ROTATION" =~ ^(0|90|180|270)$ ]]; then
        error "Invalid camera rotation: $CAMERA_ROTATION (must be 0, 90, 180, or 270)"
        ((errors++))
    fi
    
    # Check paths
    if [[ ! -d "$(dirname "$BASE_DIR")" ]]; then
        error "Base directory parent does not exist: $(dirname "$BASE_DIR")"
        ((errors++))
    fi
    
    # Check streaming port
    if [[ ! "$STREAMING_PORT" =~ ^[0-9]+$ ]] || [[ $STREAMING_PORT -lt 1024 ]] || [[ $STREAMING_PORT -gt 65535 ]]; then
        error "Invalid streaming port: $STREAMING_PORT (must be 1024-65535)"
        ((errors++))
    fi
    
    return $errors
}

# Initialize system
init_system() {
    # Validate configuration
    if ! validate_config; then
        error "Configuration validation failed"
        return 1
    fi
    
    # Ensure directories exist
    if ! ensure_directories; then
        error "Failed to create directory structure"
        return 1
    fi
    
    # Clean up any stale locks
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_info
        lock_info=$(cat "$LOCK_FILE" 2>/dev/null)
        local lock_pid
        lock_pid=$(echo "$lock_info" | cut -d: -f1)
        
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -f "$LOCK_FILE"
        fi
    fi
    
    return 0
}

# Cleanup function for script exit
cleanup_on_exit() {
    release_camera_lock
}

# Set trap for cleanup
trap cleanup_on_exit EXIT