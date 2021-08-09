#!/bin/bash

timestamp=$(date +"%d-%m6-%Y_%H-%M-%S")
export INPROGRESS=/home/pi/carberryshare/in-progress
export COMPLETED=/home/pi/carberryshare/completed
echo -e "\n ############## Creating path for videos: ${INPROGRESS} #####################\n"
mkdir ${INPROGRESS}
mkdir ${COMPLETED}


# Start recording 2 minute videos for 6 hrs
# Thats the max number of hours in general a person drives in a single stretch
for i in `seq 1 180`
do
        export filetime=$(date +"%d-%h-%Y_%H-%M-%S")
        echo -e "\n\t############## Capturing video: ${INPROGRESS}/dashcam-video-${filetime}.h264 #####################\n"
        raspivid -awb cloud --sharpness 40 --drc medium -vs -t 120000 -w 1280 -h 720 -fps 33 -rot 90 -o ${INPROGRESS}/dashcam-video-${filetime}.h264
done
