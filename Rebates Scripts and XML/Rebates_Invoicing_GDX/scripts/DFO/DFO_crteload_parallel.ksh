#!/usr/bin/ksh

echo "VALIDATION-V PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."

typeset -i SPLIT_NO=18000

>$MAILFILE
  
THIS_DIR="$PWD"
cd $TEMP_DIR
TEMP_FILE1="temp1.$$"
TEMP_FILE2="temp2.$$"

export IN_REJECT_FILE="in_reject_file"
export IN_WARN_FILE="in_warn_file"
echo "$in data file "   $IN_DATA_FILE
#===================================================================

  split -l $SPLIT_NO $IN_DATA_FILE

  ls -1 x* > $TEMP_FILE1
  NO_OF_SPLIT_FILES=`ls -1 x* 2>/dev/null | wc -l`

  while [[ -s $TEMP_FILE1 ]]
  do

     SPLIT_FILE=`head -1 $TEMP_FILE1`

     mv $SPLIT_FILE $IN_DATA_FILE.$SPLIT_FILE

###     nohup $SCRIPT_DIR/DFO_crteld01.ksh "$SPLIT_FILE" &
     nohup $SCRIPT_DIR/DFO_crteload.ksh "$SPLIT_FILE" &

     sed 1d $TEMP_FILE1 > $TEMP_FILE2

     cp $TEMP_FILE2 $TEMP_FILE1

  done

#===================================================================

  while [ 0 ]
  do
     NO_OF_DONE_FILES=`ls -1 $TEMP_DATA_DIR/done.x* 2>/dev/null | wc -l`

     `cat $DATA_LOG_FILE.x* > $DATA_LOG_FILE`

     if [[ -s $DATA_LOG_FILE ]] then

        echo "killing from size"
        $SCRIPT_DIR/DFO_kill_parallel_processes.ksh >/dev/null
        break

     else
   
        total_rejected_count=`cat $BAD_FILE.x* | wc -l`
##        echo "total: " $total_rejected_count
        
        $SCRIPT_DIR/DFO_check_two_percent_error.pl \
             $IN_REJ_COUNT_REF                     \
             $total_rejected_count

        if [[ $? = 0 ]] then
           :
        else
           if [[ $? = 1 ]] then
              echo "killing from 2%"
              $SCRIPT_DIR/DFO_kill_parallel_processes.ksh >/dev/null
              break
           else
              exit 1
           fi
        fi

     fi

     if [[ $NO_OF_DONE_FILES = $NO_OF_SPLIT_FILES ]] then
        break
     fi

     sleep 60

  done

#===================================================================

  RETURN_CODE=$?
  SCRIPT_NAME=`basename $0`

  $SCRIPT_DIR/DFO_check_error.ksh $SCRIPT_NAME $RETURN_CODE $DATA_LOG_FILE

  RETURN_CODE1=$?

#===================================================================

  `cat $BAD_FILE.x*      > $IN_REJECT_FILE`
  `cat $WARN_FILE.x*     > $IN_WARN_FILE`
  `cat $OUT_DATA_FILE.x* > $OUT_DATA_FILE`
  `cat $LOAD_FILE.x*     > $LOAD_FILE`

  $SCRIPT_DIR/DFO_combine_load.ksh

  RETURN_CODE2=$?

#===================================================================

  if [[ $RETURN_CODE1 != 0 ]] then

     if [[ $RETURN_CODE1 = 13 ]] then

        $SCRIPT_DIR/clean_up.ksh "N"

     fi

     exit 1

  fi

#===================================================================

  if [[ $RETURN_CODE2 != 0 ]] then

     exit 2

  fi

#===================================================================

  echo "\nNo. of records processed: `wc -l $IN_DATA_FILE | cut -f1 -d '/'`"   \
       "\nNo. of records accepted : `wc -l $OUT_DATA_FILE | cut -f1 -d '/'`"   \
       "\nNo. of records rejected : `wc -l $BAD_FILE  | cut -f1 -d '/'`"   \
       "\nNo. of records warned   : `wc -l $IN_WARN_FILE | cut -f1 -d '/'`" 

  echo "Process Successful."
  echo "VALIDATION-V PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."

  exit 0
