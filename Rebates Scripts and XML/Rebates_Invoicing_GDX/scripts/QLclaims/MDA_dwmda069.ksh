#!/usr/bin/ksh

echo "Incentive Type Code addition PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Adding ITC code field..."

>$MAILFILE

#===================================================================

  IVRA1="$IN_DATA_FILE"
  IDATE="$BILLG_END_DT_OVERRIDE_FILE"
  OVRA1="$LOAD_FILE"
  OERR1="$ERROR_FILE"
  ONRBT="$NON_REBATEABLE_CLAIMS"
  export IVRA1 IDATE OVRA1 OERR1 ONRBT
   
  /vracobol/prod/aix/aixexec/dwmda069 > $LOG_DIR/dwmda069.cbl.logging

  grep times $LOG_DIR/dwmda069.cbl.logging > $LOG_DIR/SBO_audit

#===================================================================
 
  RETURN_CODE=$?
  SCRIPT_NAME=`basename $0`

  $SCRIPT_DIR/MDA_check_error.ksh $SCRIPT_NAME $RETURN_CODE $dd_OERR1   

#===================================================================

  RETURN_CODE=$?

  if [[ $RETURN_CODE != 0 ]] then

     if [[ $RETURN_CODE = 13 ]] then

        $SCRIPT_DIR/clean_up.ksh "N"

     fi

     exit 1

  fi

##  export MDA_RECORDS_SENT=`cat $FTP_STAGING_DIR/*control*$DATE_OF_FILE* | cut -c 31-39`
##  export MDA_RECORDS_READ=`wc -l $dd_IVRA1 | cut -f1 -d '/'`
##  export MDA_RECORDS_CREATED=`wc -l $dd_OVRA1 | cut -f1 -d '/'`
##  export MDA_RECORDS_REJECTED=`wc -l $dd_ONRBT | cut -f1 -d '/'`

typeset -i  MDA_RECORDS_SENT
typeset -i  MDA_RECORDS_READ
typeset -i  MDA_RECORDS_CREATED
typeset -i  MDA_RECORDS_REJECTED

  export MDA_RECORDS_SENT=`cat $FTP_STAGING_DIR/*control*$DATE_OF_FILE* | cut -c 31-39`
  export MDA_RECORDS_READ=`wc -l $IVRA1 | cut -f1 -d '/'`
  export MDA_RECORDS_CREATED=`wc -l $OVRA1 | cut -f1 -d '/'`
  export MDA_RECORDS_REJECTED=`wc -l $ONRBT | cut -f1 -d '/'`
    
  print "\\nNo. of records sent: $MDA_RECORDS_SENT "        \
       "\\nNo. of records processed: $MDA_RECORDS_READ "   \
       "\\nNo. of records accepted : $MDA_RECORDS_CREATED" \
       "\\nNo. of records rejected (medicare) : $MDA_RECORDS_REJECTED " > $MAILFILE_SBO

  cat $MAILFILE_SBO $LOG_DIR/SBO_audit > $TEMP_DIR/mailfile_sbo_copy
  cp -p $TEMP_DIR/mailfile_sbo_copy $MAILFILE_SBO

# print totals out in log
  echo `print $MAILFILE_SBO` >> $LOG_FILE

# begin audit total verification of numbers
  let CALC_NUM=$MDA_RECORDS_SENT-$MDA_RECORDS_READ

  if (($CALC_NUM!=0)); then
      echo "email notifying MDA support of audit total issues..." >> $LOG_FILE
      echo "LOAD Processing for $RUN_MODE claims processsing has "  \
            "\n audit total issues.  \n" `print $MAILFILE_SBO`  > $MAILFILE

      MAIL_SUBJECT="MDA PROCESS TCLAIMS TABLE LOAD audit exception 1"
      $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1
  fi
  let CALC_NUM=$MDA_RECORDS_READ-$MDA_RECORDS_CREATED-$MDA_RECORDS_REJECTED
  if (($CALC_NUM!=0)); then
      echo "email notifying MDA support of audit total issues..." >> $LOG_FILE
      echo "LOAD Processing for $RUN_MODE claims processsing has "  \
            "\n audit total issues.  \n" `print $MAILFILE_SBO`  > $MAILFILE

      MAIL_SUBJECT="MDA PROCESS TCLAIMS TABLE LOAD audit exception 2"
      $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1
  fi

#  need to copy SBO audits to where all SBO audit reports are being saved.

#  cp -p "$TEMP_DATA_DIR/psvnrbt.dat" $HOME_DIR/nonrebateable_claims/psvnrbt.dat.$DATE_OF_FILE
   print "`cat $MAILFILE_SBO`" > $SARBANES_OXLEY_DIR/Audit_totals.$DATE_OF_FILE

  if [[ $? != 0 ]] then
     echo "problems saving SBO audit totals" >> $LOG_FILE

     print "problems moving SBO audit info from $MAILFILE_SBO to "      \
           "$SARBANES_OXLEY_DIR/Audit_totals.$DATE_OF_FILE" > $MAILFILE
        
     MAIL_SUBJECT="MDA claims load process problem saving SBO audit totals"
     $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>$1  
  fi

  echo "Claims load records were created..."
  echo "Process Successful."
  echo "ITC PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
