#!/bin/bash

function shut_down_local_pid {
  local pid=$1
  echo "The process ID $pid is shutting down!"
  kill -9 $pid
  echo "Done!"
}

function get_process_pid {
  local command=$1
  pid=$(pgrep $command)
  if [ $pid ]; then
    echo $pid
  else
    echo -1
  fi
}

function send_file_to_deploy {
  local local_file=$1
  local name=$2
  local deploy_folder=$3

  echo "To copy local $name file to the deploy folder..."
  cp $local_file $deploy_folder
  echo "Done!"
}

function check_folder_clean {
  local folder=$1
  local name=$2

  if [ ! -d $folder ]; then
    mkdir "$folder/"
  fi

  if [ "$(ls -A $folder)" ]; then
    echo "Detect files in the $name folder. Clear all files..."
    rm -rf $folder/*
    echo "Done!"
  fi
}

function fetch_file {
  local file=$1
  local name=$2

  if [ -f $file ]; then
    echo "Fetch the $name file" $file
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
  local height=$(json_extract "height" "$result")
  local height_max=$height
  local change_time=0

  for (( i=1; i<=$check_time; i++))
  do
    sleep $timer
    result=$(curl -X GET --header 'Accept: application/json' -s "$rest_api/blocks/height")
    height=$(json_extract "height" "$result")
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

# deploy_server="local" # local or remote
# deploy_status="stop" # stop or run
# node_address="127.0.0.1" # 18.223.113.52 127.0.0.1
# node_pem=""

deploy_server="remote" # local or remote
deploy_status="stop" # stop or run
node_address="18.223.113.52" # 18.223.113.52 127.0.0.1
node_pem="vsysDeployTest.pem"

blockchain_type="testnet"
deploy_pretest=3
deploy_wait_check_time=5
deploy_height_test_wait_time=5
deploy_height_test_number=3

local_project_folder="/Users/aaronyu/Dropbox/vsystems/mainchain/v-systems"
# local_project_folder=$(pwd)
# deploy_folder="/Users/aaronyu/Dropbox/vsystems/test_shell"
deploy_folder="/ssd/v-systems-main"

echo "The deploy server is $deploy_server with $deploy_pretest pretest and finally it will $deploy_status!"
echo "The node address for deploy is $node_address"
echo "The project folder in local machine is $local_project_folder"

target_file_path="$local_project_folder/target"
echo "The path of the target file is" $target_file_path
echo "The path of the config file is" $local_project_folder
target_file="$target_file_path/vsys-all-*.jar"
config_file="$local_project_folder/vsys-*$blockchain_type.conf"
fetch_file "$target_file" "target"
fetch_file "$config_file" "config"

check_folder_clean "$deploy_folder" "deploy"
send_file_to_deploy "$target_file" "target" "$deploy_folder"
send_file_to_deploy "$config_file" "config" "$deploy_folder"

deploy_target_file="$deploy_folder/*.jar"
echo "Deploy the node with target file as" $deploy_target_file
deploy_config_file="$deploy_folder/*.conf"
echo "Deploy the node with configuration file as" $deploy_config_file

current_folder=$(pwd)
run_shell="$current_folder/run.sh"
stop_shell="$current_folder/stop.sh"

echo "Generate run.sh in" $current_folder
deploy_target_file_run=$(echo $deploy_target_file)
deploy_config_file_run=$(echo $deploy_config_file)
command_run="java -jar $deploy_target_file_run $deploy_config_file_run"
cat <<END > $run_shell
#!/bin/bash

java -jar $deploy_target_file_run $deploy_config_file_run
END
chmod 755 $run_shell

echo "Generate stop.sh in" $current_folder
cat <<END > $stop_shell
#!/bin/bash

pid=\$(pgrep java -jar $deploy_target_file_run $deploy_config_file_run)
if [ \$pid ]; then
  kill -9 \$pid
fi
END
chmod 755 $stop_shell

send_file_to_deploy "$run_shell" "run_shell" "$deploy_folder"
send_file_to_deploy "$stop_shell" "stop_shell" "$deploy_folder"
rm "$current_folder/run.sh"
rm "$current_folder/stop.sh"

rest_api_address="$node_address:9922"
echo "Rest API is through" $rest_api_address

cd $deploy_folder

normal_status_time=0
for (( i=1; i<=$deploy_pretest; i++))
do
  echo "To deploy the blockchain for the "$i"-th pretest..."
  nohup bash $deploy_folder/run.sh  > $deploy_folder/log.txt &
  echo "Done!"

  echo "To check the process ID in the node $node_address (in $deploy_wait_check_time seconds)..."
  sleep $deploy_wait_check_time
  pid=$(get_process_pid "$command_run")
  if [ $pid -eq -1 ]; then
    echo "The system is not running in $node_address. Pretest ("$i"-th) failed!"
  else
    echo "The process ID of the "$i"-th pretest is $pid"
    echo "To check the height of the blockchain for the "$i"-th pretest... (with $deploy_height_test_wait_time times)"
    read node_status height_max change_time < <(check_height "$rest_api_address" "$deploy_height_test_wait_time" "$deploy_height_test_number")
    if [ $node_status == "Normal" ]; then
      echo "> Max height of the blockchain is: $height_max"
      echo "> The status of the blockchain is: $node_status ($change_time times with height change out of $deploy_height_test_number checks)"
    else
      echo ">The status of the blockchain is: $node_status"
    fi
  fi

  if [ $node_status == "Normal" ]; then
    normal_status_time=$(( normal_status_time + 1 ))
  fi

  echo "The process ID $pid of the "$i"-th pretest is shut down!"
  pid=$(get_process_pid "$command_run")
  if [ "$pid" -gt "-1" ]; then
    kill -9 $pid
  fi
  echo "Done!"
done

echo "$deploy_pretest pretest(s) finished! $normal_status_time pretests(s) Normal!"

if [ "$normal_status_time" -ne "$deploy_pretest" ]; then
  echo "Pretest does NOT pass! Exit!"
  exit 1
fi

if [ "$normal_status_time" -eq "$deploy_pretest" ] && [ $deploy_status == "stop" ]; then
  echo "Pretest passed! Bash file finished!"
fi

if [ "$normal_status_time" -eq "$deploy_pretest" ] && [ $deploy_status == "run" ]; then
  echo "To deploy vsys after pretest..."
  if [ $deploy_status == "run" ]; then
    nohup bash $deploy_folder/run.sh  > $deploy_folder/log.txt &
  fi
  echo "Done!"
  sleep $deploy_wait_check_time
  pid=$(get_process_pid "$command_run")
  echo "Plese keep the process ID of this deploy: $pid"
  echo "Bash file finished!"
fi
