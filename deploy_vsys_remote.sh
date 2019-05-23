#!/bin/bash

deploy_pretest=0
deploy_type="testnet"
deploy_status="run" # stop or run
node_address="18.223.113.52" # 18.223.113.52
node_pem="vsysDeployTest.pem"
local_pem_folder="/Users/aaronyu/Dropbox/vsystems/pem"
local_project_folder="/Users/aaronyu/Dropbox/vsystems/mainchain/v-systems"

java_version_old="1.8"
java_version_new="1.9"

server_name="ubuntu"
server_disk_dir="/home/$server_name/ssd"
server_disk_device="/dev/nvme0n1"
server_disk_entry="$server_disk_device    $server_disk_dir ext4    defaults    0 0"
server_project_dir="/home/$server_name/ssd/v-systems-main"
server_log_file="node.log"

communication_port="9922 9923 9921"
rest_api_port="9922"
deploy_wait_check_time=15
deploy_height_test_wait_time=5
deploy_height_test_number=3

function mount_server {
  local key=$1
  local server=$2
  local server_name=$3
  local disk_dir=$4
  local disk_device=$5
  local entry=$6

  ssh -i "$key" "$server" "
  #!/bin/bash
  mkdir -p $disk_dir
  if mountpoint -q \"$disk_dir\"; then
    echo \"Disk has already mounted\"
  else
    echo \"To mount the disk of server (\"$server\")\"
    sudo mkfs.ext4 $disk_device
    sudo mount $disk_device $disk_dir
    sudo chown $server_name:$server_name $disk_dir
    echo $entry | sudo tee -a /etc/fstab
  fi
  "
}

function deploy_vsys_to_server {
  local key=$1
  local server=$2
  local dir=$3
  local log_file=$4

  local wait_time=10

  echo "To deploy vsys in $server; Start..."
  ssh -i "$key" "$server" "
  #!/bin/bash
  if [ ! -d \"$dir\" ]; then
    echo \" > The given directory (\"$dir\") does not exist! Exit!\"
    exit
  else
    target_file=\$(echo $dir/*.jar)
    if [ ! -f \"\$target_file\" ]; then
      echo \" > The target file does not exist in the directory (\"$dir\")! Exit!\"
      exit
    fi
    config_file=\$(echo $dir/*.conf)
    if [ ! -f \"\$config_file\" ]; then
      echo \" > The config file does not exist in the directory (\"$dir\")! Exit!\"
      exit
    fi
  fi

  cd ssd/v-systems-main/
  nohup java -jar \$target_file \$config_file > ./$log_file &
  echo \" > Done!\"
  "
}

function kill_old_process_by_port {
  local key=$1
  local server=$2
  local port=$3

  echo "To kill old process from port ($port) in $server; Start..."
  ssh -i "$key" "$server" "
  #!/bin/bash
  for i in $port
  do
    echo \" > Checking progress on port \$i\"
    pid_str=\$(sudo netstat -ltnp | grep -w \":\$i\"| awk '{print \$7}')
    if [ -z \$pid_str ]; then
      echo \" > > The port \$i does not in any process\"
    else
      echo \" > > pid string is \$pid_str\"
    fi
    if [ ! -z \$pid_str ]; then
        IFS='/' read -r -a temp_array <<< \$pid_str
        pid=\$temp_array
        echo \" > > To kill pid: \$pid\"
        if [ ! -z \$pid ]; then
          sudo kill -9 \$pid
          while sudo kill -0 \$pid; do
              sleep 1
          done
        fi
    fi
  done
  "
  echo " > All port checked! Kill done!"
}

function check_process_by_port {
  local key=$1
  local server=$2
  local port=$3

  ssh -i "$key" "$server" "
  #!/bin/bash
  pid_str=\$(sudo netstat -ltnp | grep -w \":\$$port\"| awk '{print \$7}')
  if [ -z \$pid_str ]; then
    echo \"1: -1\"
  fi
  if [ ! -z \$pid_str ]; then
      IFS='/' read -r -a temp_array <<< \$pid_str
      pid=\$temp_array
      if [ ! -z \$pid ]; then
        echo \"2 \$pid\"
      else
        echo \"3 -1\"
      fi
  fi
  "
}

function check_update_server_JRE {
  local key=$1
  local server=$2
  local old_version=$3
  local new_version=$4

  echo "To check java in $server (between $old_version and $new_version); Start..."
  ssh -i "$key" "$server" "
  #!/bin/bash
  flag=0
  if type -p java; then
      echo \" > Found java executable in $server\"
      _java=java
  elif [[ -n \"\$JAVA_HOME\" ]] && [[ -x \"\$JAVA_HOME/bin/java\" ]]; then
      echo \" > Found java executable in JAVA_HOME\"
      _java=\"\$JAVA_HOME/bin/java\"
  else
      echo \" > No JDK 8 in $server\"
      flag=1
  fi
  if [[ \"\$_java\" ]]; then
    version=\$(\"\$_java\" -version 2>&1 | awk -F '\"' '/version/ {print \$2}')
    echo \" > Java version: \$version\"

    if [[ ! \"\$version\" <  $old_version ]] && [[ \"\$version\" < $new_version ]]; then
        echo \" > JDK is 1.8, no update needed\"
    else
        echo \" > JDK is not suitable, reinstall openJDK 8...\"
        printf 'Y' | sudo apt-get remove openJDK*
        flag=1
    fi
  fi

  if [ \"\$flag\" -eq 1 ]; then
      echo \" > Server ($server) is installing JDK 8...\"
      printf '\n' | sudo add-apt-repository ppa:openjdk-r/ppa
      sudo apt-get update
      printf 'Y' | sudo apt-get install openjdk-8-jdk
  fi
  "
}

function check_server_folder_clean {
  local key=$1
  local server=$2
  local folder=$3

  ssh -i "$key" "$server" "
  #!/bin/bash
  mkdir -p "$folder"
  if [ \"\$(ls -A $folder)\" ]; then
    echo \"Detect files in the server (\"$server\") for the directory (\"$folder\")\"
    echo \" > Clear all files and subfolders...\"
    rm -r "$folder/*"
  fi
  "
}

function send_file_to_server {
  local key=$1
  local server=$2
  local target_file=$3
  local server_dir=$4
  local name=$5

  echo "To send local $name file to the server ($server) by the directory ($server_dir)..."
  scp -i "$key" "$target_file" "$server:$server_dir"
  ssh -i "$key" "$server" "chmod -R 700 $server_dir"
}

function fetch_local_file {
  local file=$1
  local name=$2

  if [ -f $file ]; then
    echo "Fetch the $name local file by" $file
  else
    echo "Error: The $name local file does not exist! Exit!"
    exit
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

echo "======================= prepare to deploy in server $node_address ======================="

fetch_local_file "$local_pem_folder/$node_pem" "pem"
chmod 700 "$local_pem_folder/$node_pem"

# mount_server "$local_pem_folder/$node_pem" "$server_name@$node_address" \
# "$server_name" "$server_disk_dir" "$server_disk_device" "$server_disk_entry"

# check_server_folder_clean "$local_pem_folder/$node_pem" \
# "$server_name@$node_address" "$server_project_dir"

target_file_path="$local_project_folder/target"
target_file="$target_file_path/vsys-all-*.jar"
config_file="$local_project_folder/vsys-*$deploy_type.conf"
echo "The path of the target file is" $target_file_path
echo "The path of the config file is" $local_project_folder
fetch_local_file "$target_file" "target"
fetch_local_file "$config_file" "config"

echo "The deploy server is $node_address with $deploy_pretest pretest and finally it will $deploy_status!"
echo " > The node address for deploy is $node_address"
echo " > The project folder in local machine is $local_project_folder"

# send_file_to_server "$local_pem_folder/$node_pem" "$server_name@$node_address" \
# "$(echo $target_file)" "$server_project_dir" "target"
# send_file_to_server "$local_pem_folder/$node_pem" "$server_name@$node_address" \
# "$(echo $config_file)" "$server_project_dir" "config"

# check_update_server_JRE "$local_pem_folder/$node_pem" \
# "$server_name@$node_address" "$java_version_old" "$java_version_new"

echo "======================= start $deploy_pretest pretests of deploy ======================="
echo "The following conducts $deploy_pretest pretests of deploy (deploy->shutdown for $deploy_pretest times)"

normal_status_time=0
for (( i=1; i<=$deploy_pretest; i++))
do
  echo "<To conduct the "$i"-th pretest>"
  node_status=""

  kill_old_process_by_port "$local_pem_folder/$node_pem" \
  "$server_name@$node_address" "$communication_port"

  deploy_vsys_to_server "$local_pem_folder/$node_pem" \
  "$server_name@$node_address" "$server_project_dir" "$server_log_file"

  sleep $deploy_wait_check_time

  height_change_test_flag=0
  echo "To test the HEIGHT of blockchain in $node_address"
  rest_api_address="$node_address:$rest_api_port"
  echo " > Rest API is through" $rest_api_address
  result=$(curl -X GET --header 'Accept: application/json' -s "$rest_api_address/blocks/height")
  height=$(json_extract "height" "$result")

  if [ ! -z "$height" ]; then
    if [ $height -ge 1 ]; then
      echo " > The height of the blockchain is $height"
      height_change_test_flag=1
    else
      echo " > Something wrong for the blockchain with the height as $height"
    fi
  else
    echo " > Something wrong for the blockchain in $node_address as the height is empty"
  fi

  if [ $height_change_test_flag -eq 1 ]; then
    echo "To test the HEIGHT CHANGE of blockchain in $node_address for the "$i"-th pretest (with $deploy_height_test_wait_time seconds waiting for block generation)"
    read node_status height_max change_time < <(check_height "$rest_api_address" "$deploy_height_test_wait_time" "$deploy_height_test_number")
    if [ "$node_status" == "Normal" ]; then
      echo " > Max height of the blockchain is: $height_max"
      echo " > The status of the blockchain is: $node_status ($change_time times with height change out of $deploy_height_test_number checks)"
    else
      echo " > The status of the blockchain is: $node_status"
    fi
  fi

  if [ "$node_status" == "Normal" ]; then
    normal_status_time=$(( normal_status_time + 1 ))
  fi

  kill_old_process_by_port "$local_pem_folder/$node_pem" \
  "$server_name@$node_address" "$communication_port"
done

echo "Statistics: $deploy_pretest pretest(s) finished! $normal_status_time pretests(s) Normal!"

if [ "$normal_status_time" -ne "$deploy_pretest" ]; then
  echo "Pretest does NOT pass! Exit!"
  exit
fi

if [ "$normal_status_time" -eq "$deploy_pretest" ] && [ $deploy_status == "stop" ]; then
  echo "Pretest passed without deploy! Bash file finished!"
  echo "=============================================="
fi

if [ "$normal_status_time" -eq "$deploy_pretest" ] && [ $deploy_status == "run" ]; then
  echo "======================= deploy vsys after $deploy_pretest pretest ======================="
  if [ $deploy_status == "run" ]; then
    kill_old_process_by_port "$local_pem_folder/$node_pem" \
    "$server_name@$node_address" "$communication_port"

    deploy_vsys_to_server "$local_pem_folder/$node_pem" \
    "$server_name@$node_address" "$server_project_dir" "$server_log_file"

    sleep $deploy_wait_check_time

    height_change_test_flag=0
    echo "To test the HEIGHT of blockchain in $node_address"
    rest_api_address="$node_address:$rest_api_port"
    echo " > Rest API is through" $rest_api_address
    result=$(curl -X GET --header 'Accept: application/json' -s "$rest_api_address/blocks/height")
    height=$(json_extract "height" "$result")
    echo " > The height of the deploy blockchain in $node_address is $height"
  fi
  echo " > Deploy! Done!"
  echo "Pretest passed ($deploy_pretest times) with successful deploy! Bash file finished!"
  echo "=============================================="
fi
