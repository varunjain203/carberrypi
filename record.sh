#!/bin/bash

# Set up paths
INPROGRESS="/home/pi/carberryshare/in-progress"
COMPLETED="/home/pi/carberryshare/completed"

# Ensure directories exist
mkdir -p "${INPROGRESS}"
mkdir -p "${COMPLETED}"

# Start recording 2-minute videos for 6 hours (180 videos)
echo -e "\n############## Starting video capture #####################\n"

for i in {1..180}; do
    # Generate timestamp for each video file
    filetime=$(date +"%d-%m-%Y_%H-%M-%S")

    echo -e "\n\t############## Capturing video: ${INPROGRESS}/dashcam-video-${filetime}.h264 #####################\n"

    # Start recording video
    raspivid -awb cloud --sharpness 40 --drc medium -vs -t 120000 -w 1280 -h 720 -fps 33 -rot 90 -o "${INPROGRESS}/dashcam-video-${filetime}.h264"

    # Check if raspivid command was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: raspivid failed to record video at ${filetime}."
        echo "Stopping recording process."
        break  # Exit the loop if recording fails
    fi

    # Log the successful completion of a video capture
    echo "Video ${i} captured successfully: ${INPROGRESS}/dashcam-video-${filetime}.h264"

done

# Final log message
echo -e "\n############## Video capture complete #####################\n"
