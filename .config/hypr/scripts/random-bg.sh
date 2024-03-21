#!/bin/bash

directory=~/wallpapers
monitors=$(hyprctl monitors | grep Monitor | awk '{print $2}')

# Check if the directory exists
if [ -d "$directory" ]; then
	while true; do
		# Pick a random background from the directory
		random_background=$(ls $directory/* | shuf -n 1)

		# Unload old wallpapers from memory
		hyprctl hyprpaper unload all

		# Load the new background into memory
		hyprctl hyprpaper preload $random_background

		# Set the background for each monitor
		for monitor in $monitors; do
			hyprctl hyprpaper wallpaper "$monitor, $random_background"
		done

		# Sleep for 5 minutes
		sleep 300
	done
fi
