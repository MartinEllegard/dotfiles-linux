#!/bin/bash

while getopts d: flag; do
	case "${flag}" in
	d) delay=${OPTARG} ;;
	esac
done

# Set default value for delay if not provided
if [ -z "$delay" ]; then
	delay=60
fi

action=$1

# if aciton is not provided, exit
if [ -z "$action" ]; then
	echo "No action provided. Exiting."
	exit 1
fi

sleep $delay

# Run Action with hyprctl
hyprctl dispatch $action
