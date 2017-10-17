#!/usr/bin/ksh
#########################################################################
#SCRIPT NAME : DFO_handle_rejects_integration.ksh                       #
#                                                                       #
#  
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
# 6014329      qcpi733       08/21/2006  Changed database user from vraadmin
#                                        and password file from Chester_pass
#                                        word.ref. Changed sql for dba.loads
#                                        to use REJECTED not DELETED col.
#                                        
#                                        
#                                        
#                                        
#                                                                           #
#############################################################################
# export SUPPORT_MAIL_LIST_FILE="/vradfo/test/control/reffile/DFO_support_maillist.ref"
#  export HOME_DIR="/vradfo/prod"
#  export PROCESS_YEAR=2005
#  export PROCESS_MONTH=MAY
#  export REF_DIR="$HOME_DIR/control/reffile"
#  export TEMP_DIR="/vradfo/prod/temp/T20050511151918_P30066"
#  export CLIENT_NAME="PHARMASSESS"
#  export LOG_FILE="$TEMP_DIR/log_file.log"
#  export MAILFILE="$TEMP_DIR/mailfile"
#  export MAIL_SUBJECT="DFO process email subject"
#  export DBA_DATA_LOAD_DIR="/vradfo/prodload"
#  export MAILFILE_TEST="$TEMP_DIR/mailfile_test"
#  export CLIENT_DIR="/vradfo/prod/clients/PHARMASSESS"
#  export DATA_LOAD_FILE="mda.vrap.tclaims.dat.T20050511151918"
#  export SCRIPT_DIR="$HOME_DIR/script"
#  export TEMP_DATA_DIR="/vradfo/prod/temp/T20050511151918_P30066/dat"
#  export UNIQUE_RUN_ID="T20050511151918_P30066"
  
echo "Process begins - `date +'%b %d, %Y %H:%M:%S'`......."
SCRIPT_NAME=`basename $0`


if [[ $HOME_DIR = "/GDX/prod" ]]; then
    sleep 1200
    DATABASE="GDXPRD"
    DBA_DIR="/home/user/gdxprd/loadtest/out"
else 
# no consideration for UAT run
    # Running in Development region
    sleep 60
    DATABASE="GDXDEV"
    DBA_DIR="/home/user/gdxdev/loadtest/out"
fi

#================================================
# ACCEPTS TWO COMMAND LINE PARAMETERS: 
# CLIENT NAME AND TEMPORARY DIRECTORY NAME
# WHERE REJECT FILE(s) RESIDE
#================================================

  if [[ $# != 2 ]] then
     echo "Usage DFO_handle_rejects.ksh <CLIENT NAME> <TEMP_DIR>"
     exit 1
  fi

#------------------------------------------------------------------
# CHECK FOR EXISTANCE OF ANY REJECT FILES WITH DATA.
# E-MAIL ONLY IF THERE'S SOMETHING TO EMAIL
#------------------------------------------------------------------
  
  CLIENT_NAME=$1
  TEMP_DATA_DIR=$2
 
  echo "Getting rejects for $CLIENT_NAME from temp directory" \
     "$TEMP_DATA_DIR..."

  cat $TEMP_DATA_DIR/*.reject > $TEMP_DATA_DIR/all.rejects
  typeset -i NO_OF_REJECTED_CHARS
  NO_OF_REJECTED_CHARS=`wc -c < $TEMP_DATA_DIR/all.rejects`
  cp $TEMP_DATA_DIR/all.rejects $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.rejects
  
  if (( $NO_OF_REJECTED_CHARS>=0 )) then
  
#       There are some rejects to be emailed to the client
#       sort them by error number

        sort -t"^" -T /GDX/prod/tmp -k1.4,1.10 $TEMP_DATA_DIR/all.rejects -o $TEMP_DATA_DIR/rejected_files.txt
  
        if [[ $? != 0 ]] then
  
            MAIL_SUBJECT="DFO SCRIPT EXECUTION ERROR"
            echo "Sorting issues in DFO_handle_rejects" >> $LOG_FILE
            echo "DFO script 'DFO_handle_rejects.ksh'" \
                 "\nProcessing for $CLIENT_NAME"       \
                 "\nrejected records could not be sorted" > $MAILFILE
         
## don't exit but continue to process           return 150
            cp $TEMP_DATA_DIR/all.rejects $TEMP_DATA_DIR/rejected_files.txt

        else
          cp $TEMP_DATA_DIR/rejected_files.txt $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.rejects 
        fi

        echo "FTP'ing data in $CLIENT_NAME.rejected_files.txt file to $CLIENT_NAME via prodftp(ecommerce)"  >> $LOG_FILE

        mv $TEMP_DATA_DIR/rejected_files.txt $TEMP_DATA_DIR/$CLIENT_NAME.rejected_files.txt

#### uncomment for prod 
       $SCRIPT_DIR/DFO_ftp_to_prodftp.ksh $CLIENT_NAME.rejected_files.txt $TEMP_DATA_DIR $CLIENT_NAME              
       if [[ $? != 0 ]] then
          echo "problems sending rejected records to prodftp"        \
              "for $CLIENT_NAME.  reference $LOG_FILE" > $MAILFILE 

              MAIL_SUBJECT="problem ftping REJECTED file for " \
               "$PROCESS_MONTH $PROCESS_YEAR for $CLIENT_NAME" \
              $SCRIPT_DIR/mailto_IS_group.ksh $CLIENT_NAME
 
       fi  
  else
        echo "NO REJECTS to be sent for $CLIENT_NAME !!"  >> $LOG_FILE
  
        echo "No rejects to sent for "                             \
             "$CLIENT_NAME.  For those non-believers, look in "     \
             "$TEMP_DATA_DIR for *.reject" > $MAILFILE

        MAIL_SUBJECT="DFO reject processing - for $PROCESS_MONTH $PROCESS_YEAR"
        $SCRIPT_DIR/mailto_IS_group.ksh
        
  fi
  
#------------------------------------------------------------------
  CHESTER_PASSWORD_FILE="$REF_DIR/vactuate_password.ref"
  typeset -i Load_Return_Code=0
  typeset -i LOOP_CTR=1
  DB_2_LOG="$TEMP_DIR/db_2.log"
  DB_2_RTN_ROW="$TEMP_DIR/db_2_return_cd"
  TEMP_RTN_VALUE="$TEMP_DIR/return_cd_value"
  CHESTER_USER="vactuate"
  CHESTER_PASSWORD=$(< $CHESTER_PASSWORD_FILE)
    
#  db2 "connect to gdxprd user " $CHESTER_USER " using " $CHESTER_PASSWORD >>$LOG_FILE 2>>$LOG_FILE
  db2 "connect to $DATABASE user " $CHESTER_USER " using " $CHESTER_PASSWORD >>$LOG_FILE 2>>$LOG_FILE
  db2 "select 'inserted', ',' ,(inserted - rejected), ',' ,rejected from dba.loads where data_file = '$DATA_LOAD_FILE'"> $DB_2_LOG 2>>$LOG_FILE
  print $(< $DB_2_LOG)>>$LOG_FILE
              
  typeset -i SEARCH_RESULT=`cat $DB_2_LOG|grep "  0 record(s) selected."|wc -l`

# if we didn't find "  0 records" message, then we have 1 or more rows returned
# grep returns a "0" when it finds the search arguement

   if (( $SEARCH_RESULT==0 )); then
#     there's SOME rows returned, need to get the 1 return code value from table
#     If there's more than 1 row in the returned record set, we may have some issues.
   
      FILE_LINES=$(wc -l < $DB_2_LOG)     
 
     if (( $FILE_LINES==7 )); then 
#       7 lines is 1 row returned plus overhead
#       pull out return code value for interogation

        grep "inserted" $DB_2_LOG > $DB_2_RTN_ROW
        cut -f2 -d\, $DB_2_RTN_ROW > $TEMP_RTN_VALUE
        
        echo "added claims " `cat $TEMP_RTN_VALUE`
        
        typeset -i TOTAL_ADDED_CLAIMS
        let TOTAL_ADDED_CLAIMS="$(cat $TEMP_RTN_VALUE)"
        echo "total rows added to db $TOTAL_ADDED_CLAIMS" >> $LOG_FILE

        cut -f3 -d\, $DB_2_RTN_ROW > $TEMP_RTN_VALUE

        typeset -i TOTAL_DUPLICATE_CLAIMS
        let TOTAL_DUPLICATE_CLAIMS="$(cat $TEMP_RTN_VALUE)"
        echo "total duplicate rows $TOTAL_DUPLICATE_CLAIMS" >> $LOG_FILE

        typeset -i TOTAL_CLAIMS
        TOTAL_CLAIMS=`wc -l < $TEMP_DATA_DIR/*.claims`
        echo "total claims input $TOTAL_CLAIMS" >>$LOG_FILE

#       total claims may need to be adjusted by claims that were rejected 
#       during the conversion process.  Add the following:

        typeset -i TOTAL_CONVERTED_REJECTS
        TOTAL_CONVERTED_REJECTS=`wc -l < $TEMP_DATA_DIR/*convert.reject`
        echo "total converted rejects $TOTAL_CONVERTED_REJECTS" >>$LOG_FILE

        TOTAL_CLAIMS='TOTAL_CONVERTED_REJECTS + TOTAL_CLAIMS'

        typeset -i TOTAL_REJECTS
        TOTAL_REJECTS=`wc -l < $TEMP_DATA_DIR/all.rejects`
        echo "total rejected claims $TOTAL_REJECTS" >>$LOG_FILE
     
        # we'll back into the voided pairs that were dropped.
           
        typeset -i TOTAL_VOIDED_PAIRS
        TOTAL_VOIDED_PAIRS='TOTAL_CLAIMS - TOTAL_ADDED_CLAIMS - TOTAL_REJECTS - TOTAL_DUPLICATE_CLAIMS'
        echo "total voided pairs $TOTAL_VOIDED_PAIRS" >>$LOG_FILE
        typeset -i TOTAL_REJECTED
        TOTAL_REJECTED='TOTAL_REJECTS + TOTAL_DUPLICATE_CLAIMS'

        echo "Hello,\n\nDFO claims intake processing for $CLIENT_NAME for" \
             "$PROCESS_MONTH $PROCESS_YEAR is complete.\n\n"               \
             "Claims:\t\t\t$TOTAL_CLAIMS\n"                                \
             "less Voided Pairs:\t<$TOTAL_VOIDED_PAIRS>\n"                 \
             "less Rejected:\t\t<$TOTAL_REJECTED>\n"                       \
             "\nTotal claims added:\t$TOTAL_ADDED_CLAIMS"                  \
             "\n\nPlease feel free to contact the GDXITD Oncall"  \
             "or Melissa Champagne with any issues/questions/requests"   \
             "for additional information you may have." > $MAILFILE
  
        MAIL_SUBJECT="DFO $PROCESS_MONTH claims intake has completed for $CLIENT_NAME"
##        $SCRIPT_DIR/mailto_IS_group.ksh
        $SCRIPT_DIR/mailto_contract_admin_group.ksh
#6014329        let Load_Return_Code=142 <<- this is a good return code, continue processing
        let Load_Return_Code=0
     else
#          Record set results file had other than 7 lines in it.
#          Check for 1 line, which would indicate a DB2 SQL error like:
#          "SQL0204N "DBA.LOADS_1" is an undefined name. SQLSTATE=42704"

           if (( $FILE_LINES==1 )); then 
              echo "Bad SQL return code: `cat $DB_2_LOG` " >> $LOG_FILE
              echo "Script $SCRIPT_NAME (Email reporting of DFO Processing)"  \
                   "for $CLIENT_NAME had problems:"                           \
                   "\nBad SQL return code: `cat $DB_2_LOG` "                  \
                   "\nreference $LOG_FILE" > $MAILFILE
  
              MAIL_SUBJECT="DFO email reporting of processing for $CLIENT_NAME error"	
              $SCRIPT_DIR/mailto_IS_group.ksh
                    
              let Load_Return_Code=152
              
           else              
              echo "number of lines in file " $FILE_LINES >> $LOG_FILE
              echo "Multiple rows in DBA.LOADS for where clause = "           \
                   "$DATA_LOAD_FILE "    >> $LOG_FILE
                
              echo "Script $SCRIPT_NAME (Email reporting of DFO Processing)"  \
                   "for $CLIENT_NAME had problems:                   "        \
                   "\nMultiple rows in DBA.LOADS for where clause = "         \
                   "\n$DATA_LOAD_FILE "                    \
                   "\nreference $LOG_FILE" > $MAILFILE
  
              MAIL_SUBJECT="DFO email reporting of processing for $CLIENT_NAME error"	
              $SCRIPT_DIR/mailto_IS_group.ksh

              let Load_Return_Code=154
           fi
        fi
   else         
#       found a " 0 record(s) selected ", so no results for given load data file 

        echo "DFO email reporting of processing for $CLIENT_NAME"             \
             "\nhad problems.  Looking in DBA.LOADS for where data_file ="    \
             "\n$$DATA_LOAD_FILE "                          \
             "\nreference $LOG_FILE" > $MAILFILE
  
              MAIL_SUBJECT="DFO email reporting of processing for $CLIENT_NAME error"	
              $SCRIPT_DIR/mailto_IS_group.ksh

        rm $DB_2_LOG         
        let Load_Return_Code=156
  fi

  db2 connect reset>/dev/null 2>/dev/null

  echo "\n***********************************************" >> $LOG_FILE
  echo "DFO email reporting of processing for $CLIENT_NAME ended." >>$LOG_FILE 
  echo "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE  
  echo "***********************************************\n" >> $LOG_FILE
  
  echo "Process return code: $Load_Return_Code"
  echo "Process ended - `date +'%b %d, %Y %H:%M:%S'`......."

  return $Load_Return_Code
