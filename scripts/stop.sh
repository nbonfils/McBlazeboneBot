#!/bin/sh

# This script stops the Feed The Beast container, but warns the players and waits before doing it.

sudo docker exec ftb console say Stopping server in 2 minutes
sleep(2m)
sudo docker exec ftb console say Stopping now
sudo docker stop ftb`
if [ $? -eq 0 ] then
    echo -n "Success"
else
    echo -n "Fail"
fi
