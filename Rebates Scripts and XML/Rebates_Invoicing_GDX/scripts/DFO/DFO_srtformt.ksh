#!/usr/bin/ksh

echo "SORTING FOR VOID PROCESSING BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Identifying voids & reformting data into key field.."   >> $LOG_FILE

>$MAILFILE

#===================================================================
## point to database

#############################
# set variables for db login
#############################

. $SCRIPT_DIR/dbenv.ksh

print  "DB name is  " $DBNAME				>> $LOG_FILE
print  "DB User is  " $DBUSER				>> $LOG_FILE
print  "DB PW is  " $DBPSWD				>> $LOG_FILE


  export ICLMS="$IN_DATA_FILE"
  export OCLMS="$OUT_DATA_FILE"
  export OLOG="$DATA_LOG_FILE"
  export IREJC="$IN_REJ_COUNT_REF"
  export IEREF="$ERROR_DESC_FILE"
  export OREJ="$BAD_FILE"  
  export OREJC="$OUT_REJ_COUNT_REF"

  echo "error description file name " >>$LOG_FILE
  echo $ERROR_DESC_FILE >> $LOG_FILE

  export ICLMS OCLMS OLOG IREJC IEREF OREJ OREJC

  $EXE_DIR/srtform2 >> $LOG_FILE 
##  /vradfo/prod/aix/aixexec/srtform2 >> $LOG_FILE
  
#===================================================================

  RETURN_CODE=$?
  SCRIPT_NAME=`basename $0`
 
  $SCRIPT_DIR/DFO_check_error.ksh $SCRIPT_NAME $RETURN_CODE $OLOG

#===================================================================

  RETURN_CODE=$?

  if [[ $RETURN_CODE != 0 ]] then

     if [[ $RETURN_CODE = 13 ]] then

        $SCRIPT_DIR/clean_up.ksh "N"

     fi

     exit 1

  fi

  echo "\nNo. of records processed: `wc -l $ICLMS | cut -f1 -d '/'`"  \
       "\nNo. of records accepted : `wc -l $OCLMS | cut -f1 -d '/'`"  \

  echo "Process Successful."
  echo "SORTING FOR VOID PROCESSING ENDED - `date +'%b %d, %Y %H:%M:%S'`......."

  exit 0
