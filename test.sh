#!/bin/bash

# /Users/aaronyu/Dropbox/vsystems/mainchain/v-systems/target
read -p "Enter the address of a node to be connected: " node_address
echo "The node address is $node_address"
read -p "Enter the path of the target file: " target_file_path
target_file="$target_file_path/vsys-all-*.jar"
if [ -f $target_file ]; then
  echo "Get the target file: " $target_file
else
  echo "Error: The target file does not exsit!"
  exit 1
fi
echo "go go go"
