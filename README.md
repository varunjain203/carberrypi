# carberrypi
This repository is for creating your own raspberry pi based car dashcam.
There are 2 Shell Scripts that manages the video recordings and their start-up.

# record.sh - Record the video and store it under /home/pi/carberryshare/in-progress/


# welcome.sh - Present the Service Menu if user SSH into the carberrypi
- The welcome menu is like service menu or Swiss knife to manage your recordings or change the mode of operation such as Recording (Default) OR Live Streaming.
- When you SSH into the carberrypi, you will be presented a CarBerry DashCam MENU as follows:


# The carberrypi needs to start video recording as soon as it boots up
- Add the following lines in /etc/rc.local
```
/usr/bin/vcdbg set awb_mode 0
/bin/sh /root/record.sh
exit 0
```

 
