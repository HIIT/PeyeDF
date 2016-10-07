#!/bin/bash
# see active sessions with screen -ls and reattach with screen -r "$SESSION_NAME"

screen -dmS "Raw (eye stream)" ./node.py config.ini raw_eyestream
screen -dmS "Event (eye stream)" ./node.py config.ini event_eyestream
screen -dmS "Dispatcher (eye stream)" ./dispatcher.py config.ini dispatcher
echo "Started three screens:"
screen -ls
