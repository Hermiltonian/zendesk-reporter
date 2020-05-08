#!/bin/sh
now=$(date "+%Y%m%d%H%M%S")
report_file="./results/reports/report_${now}.txt"

echo "実行時刻：$(date)"
ruby inspect_tickets.rb $* | tee "${report_file}"
