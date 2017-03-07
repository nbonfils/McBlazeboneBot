#!/bin/sh

# This script restarts the Feed The Beast container, but warns the players and waits before doing it.

sudo docker exec ftb console say Restarting server in 2 minutes
sleep(2m)
sudo docker exec ftb console say Restarting now
sudo docker restart ftb`
if [ $? -eq 0 ] then
    echo -n "Success"
else
    echo -n "Fail"
fi
