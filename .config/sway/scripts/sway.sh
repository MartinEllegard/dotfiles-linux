#!/bin/bash

#Lauch Sway with env variables

export XDG_CURRENT_DESKTOP=sway

exec /usr/bin/sway "$@"
