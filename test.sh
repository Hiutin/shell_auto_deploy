#!/bin/bash

function json_extract {
  local key=$1
  local json=$2

  local string_regex='"([^"\]|\\.)*"'
  local number_regex='-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?'
  local value_regex="${string_regex}|${number_regex}|true|false|null"
  local pair_regex="\"${key}\"[[:space:]]*:[[:space:]]*(${value_regex})"

  if [[ ${json} =~ ${pair_regex} ]]; then
    local result=$(sed 's/^"\|"$//g' <<< "${BASH_REMATCH[1]}")
    echo $result
  else
    return 0
  fi
}

function check_height {
  local rest_api=$1
  local timer=$2
  local check_time=$3

  local result=$(curl -X GET --header 'Accept: application/json' -s "$rest_api/blocks/height")
  local height=$(json_extract height "$result")
  local height_max=$height
  local change_time=0

  for (( i=1; i<=$check_time; i++))
  do
    sleep $timer
    result=$(curl -X GET --header 'Accept: application/json' -s "$rest_api/blocks/height")
    height=$(json_extract height "$result")
    read height_max change_time < <(height_record "$height_max" "$height" "$change_time")
  done

  if [ $change_time -gt 0 ]; then
    echo "Normal" $height_max $change_time
  else
    echo "Abnormal" $height_max $change_time
  fi
}

function height_record {
  local height_max=$1
  local height_current=$2
  local change_time=$3

  if [ $(( $height_max - $height_current )) -ge 0 ]; then
    echo $height_max $change_time
  else
    echo $height_current $(( $change_time + 1 ))
  fi
}

# /Users/aaronyu/Dropbox/vsystems/mainchain/v-systems/target
# /Users/aaronyu/Dropbox/vsystems
# read -p "Enter the address of a node to be connected: " node_address
# echo "The node address is $node_address"
# read -p "Enter the path of the target file: " target_file_path
# read -p "Enter the path of the setting file: " config_file_path


node_address="127.0.0.1" # 54.193.47.112
target_file_path="/Users/aaronyu/Dropbox/vsystems/mainchain/v-systems/target"
config_file_path="/Users/aaronyu/Dropbox/vsystems"
echo "The path of the target file is: $target_file_path"
echo "The path of the setting file is: $config_file_path"
target_file="$target_file_path/vsys-all-*.jar"
config_file="$config_file_path/vsys-*.conf"

if [ -f $target_file ]; then
  echo "Fetch the target file: " $target_file
else
  echo "Error: The target file does not exsit! Exit!"
  exit 1
fi

if [ -f $config_file ]; then
  echo "Fetch the config file: " $config_file
else
  echo "Error: The config file does not exsit!"
  exit 1
fi


remote_folder="/Users/aaronyu/Dropbox/vsystems/test_shell/"
if [ ! -d $remote_folder ]; then
  mkdir $remote_folder
fi

if [ "$(ls -A $remote_folder)" ]; then
  echo "Detect files in the remote folder. Clear all files..."
  rm -r $remote_folder*.*
  # rm -r $folder*.*
  echo "Done!"
fi

echo "Copy local target file to the remote folder..."
cp $target_file $remote_folder
echo "Done!"

echo "Copy local config file to the remote folder..."
cp $config_file $remote_folder
echo "Done!"

remote_target_file="$remote_folder*.jar"
remote_config_file="$remote_folder*.conf"

echo "Start the node with target file as $remote_target_file"
echo "Start the node with configuration file as $remote_config_file"

echo "The IP of the node is $node_address"
rest_api_address="$node_address:9922"
echo "Rest API is through $rest_api_address"

current_folder=$(pwd)
run_shell="$current_folder/run.sh"
stop_shell="$current_folder/stop.sh"
echo "file $run_shell"
echo "file $stop_shell"
echo "Generate run.sh and stop.sh in $current_folder"
cat <<END > $run_shell
#!/bin/bash

java -jar $remote_target_file $remote_config_file
END
chmod 755 $run_shell

# java -jar $remote_target_file $remote_config_file
# sleep 20

# timer=5
# check_time=2
# check_node_status=0
# echo "Checking the height of the blockchain... (to check the height with $check_time times)"
# read node_status height_max change_time < <(check_height "$rest_api_address" "$timer" "$check_time")
# echo "Max height of the blockchain is: $height_max"
# echo "The status of the blockchain is: $node_status ($change_time times with height change out of $check_time checks)"

# java -jar $remote_target_file $remote_config_file
