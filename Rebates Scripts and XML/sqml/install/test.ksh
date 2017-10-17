#!/usr/bin/ksh

basedir=`dirname $0`"/../.."
cd $basedir
basedir=`pwd`

echo "basedir = $basedir" 

scripts/Common_java_db_interface.ksh refresh_client_model_association.xml &
job_pid=$!

sleep 2
tail -f output/rbate_refresh_client_model_association.log &
tail_pid=$!

wait $job_pid
kill $tail_pid

