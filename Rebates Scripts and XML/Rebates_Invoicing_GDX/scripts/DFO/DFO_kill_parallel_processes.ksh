#!/usr/bin/ksh

echo "hello"
exec 3< $PROCESSOR_NO_FILE

while read -u3 pid
do

   ps -ef | grep $pid | grep -v grep > $TEMP_DIR/temp.pid

   exec 4< $TEMP_DIR/temp.pid

   while read -u4 data
   do

      pid1=`echo $data | cut -f2 -d " "`
      pid2=`echo $data | cut -f3 -d " "`

      if [[ $pid = $pid2 ]] then
         kill -9 $pid1 2>/dev/null
      fi

   done

   kill -9 $pid 2>/dev/null

done
