#!/usr/bin/ksh

echo "SORTING FOR VOID PROCESSING BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Identifying voids & reformting data into key field.."   >> $LOG_FILE

#>$MAILFILE

#===================================================================
## point to database

. $SCRIPT_DIR/dbenv.ksh

#############################
# set variables for db login
#############################

export DBNAME=$DATABASE 
export DBUSER=$CONNECT_ID
export DBPSWD=$CONNECT_PWD  

  export ICLMS="/vradfo/prod/temp/T20050331130221_P55258/dat/PHARMASSESS.Mar2005.claims"
  export OCLMS="/vradfo/prod/temp/T20050331130221_P55258/dat/PHARMASSESS.Mar2005.srtformt.good"
  export OLOG="/vradfo/prod/temp/T20050331130221_P55258/dat/PHARMASSESS.Mar2005.srtformt.log"
  export IREJC="/vradfo/prod/temp/T20050331130221_P55258/dat/DFO_reject_count.convert.ref"
  export IEREF="/vradfo/prod/aix/compile/DFO_error_desc_index.ref"
  export OREJ="/vradfo/prod/temp/T20050331130221_P55258/dat/PHARMASSESS.Mar2005.srtformt.reject"  
  export OREJC="/vradfo/prod/temp/T20050331130221_P55258/dat/DFO_reject_count.srtformt.ref"

  echo "error description file name " >>$LOG_FILE
##  echo $ERROR_DESC_FILE >> $LOG_FILE

##  export ICLMS OCLMS OLOG IREJC IEREF OREJ OREJC

  $EXE_DIR/srtform2 >>"$LOG_DIR/program_out1" 2>"$LOG_DIR/error.log" 
##  /vradfo/prod/aix/aixexec/srtform2 >>"/vradfo/prod/log/program_out1" 2>"/vradfo/prod/log/error.log"
  
#===================================================================

  RETURN_CODE=$?
#  SCRIPT_NAME=`basename $0`
 
#  $SCRIPT_DIR/DFO_check_error.ksh $SCRIPT_NAME $RETURN_CODE $OLOG

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
