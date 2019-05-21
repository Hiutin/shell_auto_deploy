#!/bin/bash

# /Users/aaronyu/Dropbox/vsystems/mainchain/v-systems/target
# /Users/aaronyu/Dropbox/vsystems
#
read -p "Enter the address of a node to be connected: " node_address
echo "The node address is $node_address"
# read -p "Enter the path of the target file: " target_file_path
# read -p "Enter the path of the setting file: " setting_file_path


target_file_path="/Users/aaronyu/Dropbox/vsystems/mainchain/v-systems/target"
setting_file_path="/Users/aaronyu/Dropbox/vsystems"
echo "The path of the target file is: $target_file_path"
echo "The path of the setting file is: $setting_file_path"
target_file="$target_file_path/vsys-all-*.jar"
setting_file="$setting_file_path/vsys-*.conf"

if [ -f $target_file ]; then
  echo "Fetch the target file: " $target_file
else
  echo "Error: The target file does not exsit! Exit!"
  exit 1
fi

if [ -f $setting_file ]; then
  echo "Fetch the setting file: " $setting_file
else
  echo "Error: The setting file does not exsit!"
  exit 1
fi


remote_folder="/Users/aaronyu/Dropbox/vsystems/test_shell/"
if [ ! -d $remote_folder ]; then
  mkdir $remote_folder
fi

if [ "$(ls -A $remote_folder)" ]; then
  echo "Detect files in the remote folder. Clear all files..."
  rm -r $remote_folder*.*
  # rm -rf $folder
  echo "Done!"
fi

echo "Copy local target file to the remote folder..."
cp $target_file $remote_folder
echo "Done!"

echo "Copy local setting file to the remote folder..."
cp $setting_file $remote_folder
echo "Done!"


remote_target_file="$remote_folder"*.*
echo $remote_target_file
# java -jar vsys.jar vsys-config.conf
