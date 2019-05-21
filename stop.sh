#!/bin/bash

pid=$(pgrep java -jar /Users/aaronyu/Dropbox/vsystems/test_shell/vsys-all-0.1.1.jar /Users/aaronyu/Dropbox/vsystems/test_shell/vsys-testnet.conf)
if [ $pid ]; then
  kill -9 $pid
fi
