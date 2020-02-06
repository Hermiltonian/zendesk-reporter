#!/bin/sh
now=$(date "+%Y%m%d%H%M%S")
report_file="./results/requests/requests_${now}.txt"

echo "実行時刻：$(date)"

ruby requests.rb "$@" | tee "${report_file}"
