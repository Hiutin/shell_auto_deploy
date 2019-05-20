#!/bin/bash

# /Users/aaronyu/Dropbox/vsystems/mainchain/v-systems/target
read -p "Enter the address of a node to be connected: "  node_address
echo "The node address is $node_address"
read -p "Enter the path of the target file: " target_file_path
target_file="$target_file_path/vsys_all_*.zip"
echo $target_file
# echo "The input target file is: $target_file_path"
# cp target/vsys-all-*.jar ../vsys-node/v-systems.jar
