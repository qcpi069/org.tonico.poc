#!/usr/bin/ksh

echo "`date +'%b %d, %Y %H:%M:%S'`:Validating"  \
     "record length fo each record......"

>$MAILFILE
>$BAD_FILE
  
typeset -i rejected_record_count=0

OLD_IFS=$IFS
IFS="^"

exec 3< $IN_DATA_FILE

while read -u3 DATA
do
   RECORD_LENGTH=`echo $DATA | wc -c`

   if [[ $RECORD_LENGTH -ne 290 ]] then
    
      rejected_record_count=`expr $rejected_record_count + 1`

      DUMMY_PERL_SCRIPT="print sprintf "'"%07d"'", $rejected_record_count"
      echo $DUMMY_PERL_SCRIPT
      ERROR_RECORD_KEY=`echo $DUMMY_PERL_SCRIPT | /usr/bin/perl`

      echo $ERROR_RECORD_KEY

      echo "SCR$ERROR_RECORD_KEY:IVRL:$DATA" >> $BAD_FILE

   fi

done

IFS=$OLD_IFS

#===================================================================

  RETURN_CODE=$?
  SCRIPT_NAME=`basename $0`


   if [[ -s $BAD_FILE ]] then

      echo "Input data file has variable record length"

      echo "Script: $SCRIPT_NAME"                       \
           "\nProcessing for $CLIENT_NAME Failed:"      \
           "Input data file has variable record length" \
          "\nLook for Log file $LOG_FILE" > $MAILFILE
 
      MAIL_SUBJECT="DFO PROCESS"
 
      $SCRIPT_DIR/mailto_IS_group.ksh

      MAIL_BODY_FILE="$INVALID_FILE_MAIL_BODY"

      $SCRIPT_DIR/mailto_contract_admin_group.ksh

      $SCRIPT_DIR/clean_up.ksh "N"

      exit 200

   else

      if [[ $RETURN_CODE != 0 ]] then

         MAIL_SUBJECT="DFO SCRIPT EXECUTION ERROR"
         echo "DFO script $SCRIPT_NAME"   \
              "execution error occurred" > $MAILFILE

         $SCRIPT_DIR/mailto_IS_group.ksh

         exit 300

     fi

   fi

