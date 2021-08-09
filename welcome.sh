#!/bin/bash
# When a user logs on to Raspberry Pi manually -> should  execute Welcome DashCam Menu script in the bash profile file.

# Inform the user there is a current video recording going on with details of path and file name.
export INPROGRESS=/home/pi/carberryshare/in-progress
export COMPLETED=/home/pi/carberryshare/completed
list_crecords=`ls /home/pi/carberryshare/completed/ | wc -l`
list_irecords=`ls /home/pi/carberryshare/in-progress/ | wc -l`
number_records=`ls -lrth /home/pi/carberryshare/in-progress/|sed '1d'| wc -l`
processid=$(ps -ef | grep -i raspivid | grep -v grep | awk '{print $2, $3}')
processname=$(ps -ef | grep -i raspivid | grep -v grep | awk '{print $20}')
echo ""
        echo "           ###### WELCOME TO CarBerry DashCam MENU ######" 
echo ""
 if [ ${list_crecords} != NULL ]
  then
        echo "Here are your completed recordings :-"
        echo $number_crecords 
        ls -lrth /home/pi/carberryshare/completed |sed '1d'| awk '{print $5, $6, $7, $8, $9}'
        echo ""
        # Ask user if want to stop any recordings ?
            if [ -z "${processid}" ]
            then
                echo -e "No ongoing recording process found !"
           # echo -e " >> There is an ongoing Recording >> STOP IT ?"
           # echo -e ${processname_raspivid}
            else
             echo -e ">> There is an ongoing Recording found >> STOP IT ???!"
             echo -e ${processname}
             read answer1
                if [ ${answer1} == "y" ]
                then
                     kill -9 ${processid}
                    # systemctl stop carberrypi.service
                else
                echo " >>>  Recording is continuing >>>"
                fi

            fi
else 
        echo "No recordings found in completed"
fi


        # Ask User, if it wants PI to convert the in-progress recordings to MP4 ?
#convert () {
        echo ""
        echo " --> No on-going Recordings found!"
        echo " Do you want to convert present $number_records recordings to MP4 ?"
        echo ""
        read answer2
                if [ ${answer2} == "y" ]
                then
                cd ${INPROGRESS}
                for file in `ls *.h264`
                do
                        echo -e ">>>>>>>  H.264 to MP4 conversion started ...."
                        MP4Box -add ${file} -fps 33 ${COMPLETED}/${file}.mp4 &
                #       rm -fr ${file}
                done
                else
                echo ""
                fi
                rm -fr ${file}
#       }
echo ""
ipa=$(ifconfig wlan0 | sed '1d' | sed '2,9d' | awk '{print $2}')
ipv6addr=$(ifconfig wlan0 | sed '4!d' |awk '{print $2}')
streamprocessid=`ps -ef | grep carberrystream.py|grep -v grep | awk '{print $2}'`
echo "Do you want to stream live ?"
read answer3
if [ ${answer3} == "y" ]
then
        if [ -z ${streamprocessid} ]
        then
         python3 /root/carberrystream.py &
         echo "Please visit: http://${ipa}:8000 to see the live stream."
         echo "Internet Stream available at :- http://[${ipv6addr}]:8000"
         echo 
         else
         echo " Streaming already exists ...."
         echo ${streamprocessid} "   Please visit: http://${ipa}:8000 to see the live stream."
         echo ""
         echo "Do you want to stop Streaming ???"
                 read answer4
                 if [ ${answer4} == "y" ]
                 then
                         echo "... stopping Live Streaming..."
                         kill -9 ${streamprocessid}
                         echo "Live Stream STOPPED !"

                  else
                        echo "LIVE STREAMING Continues..."
                fi
         fi
else
        if [ -z ${streamprocessid} ]
        then
        echo "NO LIVE Streaming...."
        else
        echo "Stopping existing stream also...."
        kill -9 ${streamprocessid}
        echo "Live Stream Stopped !! "
        fi
fi
