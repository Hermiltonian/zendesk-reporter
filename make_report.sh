#!/bin/sh
now=$(date "+%Y%m%d%H%M%S")
report_file="./results/report_${now}.txt"

ruby inspect_tickets.rb | tee "${report_file}"
