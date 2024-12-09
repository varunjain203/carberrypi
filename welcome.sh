#!/bin/bash
# When a user logs on to Raspberry Pi manually, it should execute the Welcome DashCam Menu script in the bash profile file.

# Set paths
INPROGRESS="/home/pi/carberryshare/in-progress"
COMPLETED="/home/pi/carberryshare/completed"

# Get file counts
list_crecords=$(ls "${COMPLETED}" | wc -l)
list_irecords=$(ls "${INPROGRESS}" | wc -l)
number_records=$(find "${INPROGRESS}" -type f | wc -l)

# Get process ID and process name for ongoing raspivid process
processid=$(ps -ef | grep -i raspivid | grep -v grep | awk '{print $2}')
processname=$(ps -ef | grep -i raspivid | grep -v grep | awk '{print $8}')

# Display welcome message
echo ""
echo "           ###### WELCOME TO CarBerry DashCam MENU ######"
echo ""

# Show completed recordings
if [[ "${list_crecords}" -gt 0 ]]; then
    echo "Here are your completed recordings:"
    echo "$list_crecords recordings found."
    ls -lrth "${COMPLETED}" | tail -n +2 | awk '{print $5, $6, $7, $8, $9}'
    echo ""

    # Ask user if they want to stop any ongoing recordings
    if [[ -z "${processid}" ]]; then
        echo "No ongoing recording process found!"
    else
        echo ">> An ongoing recording is found! >> STOP IT???"
        echo "Process name: ${processname}"
        read -p "Do you want to stop it? (y/n): " answer1
        if [[ "${answer1}" == "y" ]]; then
            kill -9 "${processid}"
            echo "Recording stopped."
        else
            echo "Recording continues."
        fi
    fi
else
    echo "No recordings found in completed."
fi

# Ask User if they want to convert in-progress recordings to MP4
echo ""
echo "No ongoing recordings found!"
echo "Do you want to convert present ${number_records} recordings to MP4?"
read -p "(y/n): " answer2
if [[ "${answer2}" == "y" ]]; then
    cd "${INPROGRESS}"
    for file in *.h264; do
        echo ">>>>>>> Converting H.264 to MP4..."
        MP4Box -add "${file}" -fps 33 "${COMPLETED}/${file}.mp4" &
    done
    wait  # Wait for all background processes to finish
    echo "Conversion complete."
else
    echo "Conversion skipped."
fi

# Get the local IP and IPv6 address
ipa=$(ifconfig wlan0 | awk '/inet / {print $2}')
ipv6addr=$(ifconfig wlan0 | awk '/inet6 / {print $2}')

# Stream live option
streamprocessid=$(ps -ef | grep carberrystream.py | grep -v grep | awk '{print $2}')
echo "Do you want to stream live? (y/n):"
read -p "(y/n): " answer3

if [[ "${answer3}" == "y" ]]; then
    if [[ -z "${streamprocessid}" ]]; then
        python3 /root/carberrystream.py &
        echo "Please visit: http://${ipa}:8000 to see the live stream."
        echo "Internet Stream available at: http://[${ipv6addr}]:8000"
    else
        echo "Streaming already exists. Process ID: ${streamprocessid}"
        echo "Do you want to stop the streaming? (y/n):"
        read -p "(y/n): " answer4
        if [[ "${answer4}" == "y" ]]; then
            kill -9 "${streamprocessid}"
            echo "Live stream stopped!"
        else
            echo "Live streaming continues..."
        fi
    fi
else
    if [[ -z "${streamprocessid}" ]]; then
        echo "No live streaming currently."
    else
        echo "Stopping existing stream..."
        kill -9 "${streamprocessid}"
        echo "Live stream stopped!"
    fi
fi
