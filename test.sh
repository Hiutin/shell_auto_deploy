#!/bin/bash

function send_file_to_remote {
  local local_file=$1
  local name=$2
  local remote_folder=$3

  echo "Copy local $name file to the remote folder..."
  cp $local_file $remote_folder
  echo "Done!"
}

function check_folder_clean {
  local folder=$1
  local name=$2

  if [ ! -d $folder ]; then
    mkdir $folder
  fi

  if [ "$(ls -A $folder)" ]; then
    echo "Detect files in the $name folder. Clear all files..."
    rm -r $folder/*.*
    # rm -r $folder*.*
    echo "Done!"
  fi
}

function fetch_file {
  local file=$1
  local name=$2

  if [ -f $file ]; then
    echo "Fetch the $name file:" $file
  else
    echo "Error: The $name file does not exsit! Exit!"
    exit 1
  fi
}

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
echo "The path of the target file is" $target_file_path
echo "The path of the setting file is" $config_file_path

target_file="$target_file_path/vsys-all-*.jar"
config_file="$config_file_path/vsys-*.conf"
fetch_file "$target_file" "target"
fetch_file "$config_file" "config"

remote_folder="/Users/aaronyu/Dropbox/vsystems/test_shell"
check_folder_clean "$remote_folder" "remote"
send_file_to_remote "$target_file" "target" "$remote_folder"
send_file_to_remote "$config_file" "config" "$remote_folder"

remote_target_file="$remote_folder/*.jar"
echo "Start the node with target file as" $remote_target_file
remote_config_file="$remote_folder/*.conf"
echo "Start the node with configuration file as" $remote_config_file

echo "The IP of the node is" $node_address
rest_api_address="$node_address:9922"
echo "Rest API is through" $rest_api_address

current_folder=$(pwd)
run_shell="$current_folder/run.sh"
stop_shell="$current_folder/stop.sh"
echo "Generate run.sh in" $current_folder
remote_target_file_run=$(echo $remote_target_file)
remote_config_file_run=$(echo $remote_config_file)
cat <<END > $run_shell
#!/bin/bash

java -jar $remote_target_file_run $remote_config_file_run
END
chmod 755 $run_shell

command="\$(java -jar $remote_target_file_run $remote_config_file_run)"
echo $command
echo "Generate stop.sh in" $current_folder
cat <<END > $stop_shell
#!/bin/bash

pid=\$(pgrep java -jar $remote_target_file_run $remote_config_file_run)
if [ \$pid ]; then
  kill -9 \$pid
fi
END
chmod 755 $stop_shell

send_file_to_remote "$run_shell" "run_shell" "$remote_folder"
send_file_to_remote "$stop_shell" "stop_shell" "$remote_folder"

# xterm -hold -e "echo Hello My World"

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
