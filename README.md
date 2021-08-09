# carberrypi
This repository is for creating your own raspberry pi based car dashcam.

# record.sh - Record the video and store it

```
root@carberrypi:/home/pi/carberryshare# ls -lrth
total 52K
drwxr-xr-x 2 root root  20K Jun 20 13:10 completed
drwxr-xr-x 2 root root  28K Jun 21 14:00 in-progress
```


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
# carberrystream.py

- Streams live feed from dash camera to the internet via Ipv4 and Ipv6 both
- When Live Streaming is chosen, your Pi's local and internet facing IP-address link will be displayed.
- I have rotated the camera at 90 Deg. because I wanted to place PI such that the USB power cable is attached from the bottom.

```
root@carberrypi:~# ./welcome.sh

           ###### WELCOME TO CarBerry DashCam MENU ######

Do you want to stream live ?
y
Please visit: http://192.168.29.107:8000 to see the live stream.
Internet Stream available at :- http://[4567:201:1c:7890:a378:a1b2:f7ab:1234]:8000

```

# Share the recordings via SAMBA/CIFS

- To be able to to access the recordings instantly you can implement a Samba server.
- Add the following lines at the last of /etc/samba/smb.conf
- Android - Install any Network File Manager from Android Play Store
- Use Files app on IOs on your Iphone and configure it to add the Samba File Share
```
[carberryshare]
        path = /home/pi/carberryshare
        comment = casrshare
        browseable = yes
        read only = no
        writable = yes
        public = yes
```
 
