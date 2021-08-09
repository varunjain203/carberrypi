# carberrypi
This repository is for creating your own raspberry pi based car dashcam.
There are 2 Shell Scripts that manages the video recordings and their start-up.

# record.sh - Record the video and store it under /home/pi/carberryshare/in-progress/


# welcome.sh - Present the Service Menu if user SSH into the carberrypi
- The welcome menu is like service menu or Swiss knife to manage your recordings or change the mode of operation such as Recording (Default) OR Live Streaming.
- When you SSH into the carberrypi, you will be presented a CarBerry DashCam MENU as follows:


```
###### WELCOME TO CarBerry DashCam MENU ######

Here are your completed recordings :-

6.1M Jun 20 13:10 dashcam-video-15-Jun-2021_13-10-03.h264.mp4
40M Jun 20 13:10 dashcam-video-15-Jun-2021_16-17-29.h264.mp4
11M Jun 20 13:10 dashcam-video-15-Jun-2021_17-42-37.h264.mp4

>> There is an ongoing Recording found >> STOP IT ???!
y

 --> No on-going Recordings found!
 Do you want to convert present 1 recordings to MP4 ?
n

Do you want to stream live ?
n
NO LIVE Streaming....
```

# The carberrypi needs to start video recording as soon as it boots up
- Add the following lines in /etc/rc.local
```
/usr/bin/vcdbg set awb_mode 0
/bin/sh /root/record.sh
exit 0
```

 
