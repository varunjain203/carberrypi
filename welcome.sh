#!/bin/bash

# Define paths
INPROGRESS=/home/pi/carberryshare/in-progress
COMPLETED=/home/pi/carberryshare/completed
STREAMING_PID_FILE="/tmp/streaming_pid"

# Function to check if the recording process is running
check_recording() {
    # Check if raspivid (video recording) is running
    if ps aux | grep -i 'raspivid' | grep -v 'grep' > /dev/null
    then
        return 0  # Recording is running
    else
        return 1  # No recording running
    fi
}

# Function to check if the streaming process is running
check_streaming() {
    # Check if the stream server (stream.py) is running
    if [ -f "$STREAMING_PID_FILE" ] && ps -p $(cat "$STREAMING_PID_FILE") > /dev/null 2>&1
    then
        return 0  # Streaming is running
    else
        return 1  # No streaming process running
    fi
}

# Function to start streaming
start_streaming() {
    echo "Starting live stream..."
    # Start the Python streaming script in the background and store the PID
    python3 /root/carberrystream.py &
    STREAM_PID=$!
    echo $STREAM_PID > "$STREAMING_PID_FILE"  # Save the PID of the streaming process
    echo "Stream is available at http://<your-pi-ip>:8000"
}

# Function to stop streaming
stop_streaming() {
    if check_streaming; then
        STREAM_PID=$(cat "$STREAMING_PID_FILE")
        echo "Stopping live streaming..."
        kill -9 $STREAM_PID
        rm "$STREAMING_PID_FILE"  # Remove the PID file
        echo "Live stream stopped!"
    else
        echo "No live stream is currently running."
    fi
}

# Display the main menu
echo "Welcome to CarBerry DashCam!"
echo "1. Start Recording"
echo "2. Start/Stop Live Streaming"
echo "3. View Completed Recordings"
echo "4. Exit"
read -p "Choose an option (1-4): " choice

case $choice in
  1)
    # Start recording by invoking the record.sh script
    if check_recording; then
        echo "Recording is already in progress. Do you want to stop it? (y/n)"
        read stop_recording
        if [ "$stop_recording" == "y" ]; then
            echo "Stopping the current recording..."
            pkill -f raspivid  # Stop raspivid process
            echo "Recording stopped!"
        fi
    fi

    echo "Starting recording..."
    ./record.sh  # Start a new recording
    ;;
  
  2)
    # Start/Stop live streaming
    if check_streaming; then
        echo "A stream is already running. Do you want to stop it? (y/n)"
        read stop_stream
        if [ "$stop_stream" == "y" ]; then
            stop_streaming
        else
            echo "Continuing the current live stream."
        fi
    else
        start_streaming
    fi
    ;;
  
  3)
    # Show completed recordings
    echo "Here are your completed recordings:"
    ls -lrth $COMPLETED
    ;;
  
  4)
    # Exit the script
    echo "Exiting... Goodbye!"
    exit 0
    ;;
  
  *)
    echo "Invalid choice, please try again."
    ;;
esac
