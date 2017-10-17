#!/usr/bin/ksh

###############################################
#SCRIPT NAME : DFO_load_tclaim_ext            #
#                                             #
#PURPOSE     :                                #
#                                             #
#INSTRUCTIONS: This script takes two          #
#              command-line arguments. First  #
#              is the processor Name and the  #
#              second is input file name with #
#              absolute path                  #
#                                             #
#CALLS       :                                #
#                                             #
#RETURNS VALUES: 
# 
#  return code values and meanings for "DFO_load_tclaim_ext.ksh"
#
#  140 series are 'good' return codes
#
#  140 = claims loaded successfully without any duplicates
#  142 = claims loaded but with duplicates in TCLAIM_EXT_EXCP table
#
#  150 series are 'bad' return codes
#
#  150 = non-zero return code on DBA.LOADS table for given load data set
#  152 = SQL error of some sort  
#  154 = Multiple rows in DBA.LOADS for given load data set, further
#        manual investigation is needed to determine if there are problems
#  156 = We never got a row in DBA.LOADS for the load of the given 
#        load data set.  Manual investigation needed
#  
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  07/13/2003  Initial Release                    #
#                                                                           #
#############################################################################

#  export HOME_DIR="/vradfo/test"
#  export REF_DIR="$HOME_DIR/control/reffile"
#  export TEMP_DIR="/vradfo/test/temp/testing"
#  export CLIENT_NAME="frsthlth"
#  export LOG_FILE="$TEMP_DIR/log_file.log"
#  export MAILFILE="$TEMP_DIR/mailfile"
#  export DBA_DATA_LOAD_DIR="/vradfo/prodload"
#  export DATA_LOAD_FILE="dfo.vrap.tclaim_ext.dat.20030701162156"
#  export CLIENT_DIR="/vradfo/test/clients/frsthlth"
#  export DATA_LOAD_FILE="dfo.vrap.tclaim_ext.dat.20030804172557"
#  export SCRIPT_DIR="$HOME_DIR/script"
#
#  above lines are hardcoded values for testing.
#
#################################################################################

  echo "\n***********************************************"   >> $LOG_FILE
  echo "DBA LOAD OF CLAIMS FOR CLIENT $CLIENT_NAME started."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

  THIS_DIR="$PWD"
  cd $TEMP_DIR
 
  CHESTER_PASSWORD_FILE="$REF_DIR/chester_password.ref"
  typeset -i Load_Return_Code=0
  typeset -i LOOP_CTR=1
  DB_2_LOG="$TEMP_DIR/db_2.log"
  DB_2_RTN_CODE="$TEMP_DIR/db_2_return_cd"
  TEMP_RTN_CODE="$TEMP_DIR/return_cd_value"
  CHESTER_USER="vraadmin"
  CHESTER_PASSWORD=$(< $CHESTER_PASSWORD_FILE)
  export Load_Return_Code

 
# DBA_DATA_LOAD="/vradfo/prodload"
  
#  sleep 60
#  db2 "connect to udbmdap user " $CHESTER_USER " using " $CHESTER_PASSWORD" >/dev/null 2>/dev/null
  db2 "connect to udbmdap user " $CHESTER_USER " using " $CHESTER_PASSWORD >>$LOG_FILE 2>>$LOG_FILE
  db2 "select 'rtn_code', ',' ,ret_code from dba.loads where data_file = '$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE'"> $DB_2_LOG 2>>$LOG_FILE
  print $(< $DB_2_LOG)>>$LOG_FILE
              
# loop until we determine we're done with the checking of the dba load script status.
# we'll delete the db2 log file to break the loop

  while [[ -s $DB_2_LOG ]]
  do
     typeset -i SEARCH_RESULT=`cat $DB_2_LOG|grep "  0 record(s) selected."|wc -l`

#    if we didn't find "  0 records" message, then we have 1 or more rows returned

     if (( $SEARCH_RESULT==0 )); then
#       there's SOME rows returned, need to get the 1 return code value from table
#       If there's more than 1 row in the returned record set, we may have some issues.
  
        FILE_LINES=$(wc -l < $DB_2_LOG)     

        if (( $FILE_LINES==7 )); then 
#          7 lines is 1 row returned plus overhead
#          pull out return code value for interogation

           grep "rtn_code" $DB_2_LOG > $DB_2_RTN_CODE 
           echo "db2 return code " $DB_2_RTN_CODE
#           cat $DB_2_RTN_CODE
           cut -f2 -d\, $DB_2_RTN_CODE > $TEMP_RTN_CODE

           typeset -i RETURN_CD_VAL
           RETURN_CD_VAL=$(cat $TEMP_RTN_CODE)

           if ((${RETURN_CD_VAL}==0)); then
              echo "load of claim records was successful " >> $LOG_FILE
   
              let Load_Return_Code=140

#             check for any duplicates the autoloader kicked out.

              db2 "select 'deleted_count', ',' ,deleted from dba.loads where data_file = '$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE'"> $DB_2_LOG
              grep "deleted_count"  $DB_2_LOG > $DB_2_RTN_CODE 
              cut -f2 -d\, $DB_2_RTN_CODE > $TEMP_RTN_CODE
              RETURN_CD_VAL=$(< $TEMP_RTN_CODE)
              if ((${RETURN_CD_VAL}!=0)); then
                 echo "Some claim records were not loaded: duplicates" >> $LOG_FILE
                 echo "Load Processing for $CLIENT_NAME warning:"               \
                      "\nsome claims were rejected as duplicates:"              \
                      "\n $RETURN_CD_VAL claims that reside in TCLAIM_EXT_EXCP" \
                      "\nreference $LOG_FILE" > $MAILFILE
  
                 MAIL_SUBJECT="DFO dba load claims PROCESS warning"
                 $SCRIPT_DIR/mailto_IS_group.ksh
                 let Load_Return_Code=142
              fi
              rm $DB_2_LOG
          else
              echo "load of claim records was NOT successful!!!! " >> $LOG_FILE
              echo "Load Processing for $CLIENT_NAME had problems:"   \
                   "\nNon-Zero return code was returned:"             \
                   "\n $RETURN_CD_VAL"                                \
                   "\nreference $LOG_FILE" > $MAILFILE
  
              MAIL_SUBJECT="DFO dba load claims PROCESS"
              $SCRIPT_DIR/mailto_IS_group.ksh
      
              rm $DB_2_LOG
              let Load_Return_Code=150
           fi
        else
#          Record set results file had other than 7 lines in it.
#          Check for 1 line, which would indicate a DB2 SQL error like:
#          "SQL0204N "DBA.LOADS_1" is an undefined name. SQLSTATE=42704"

           if (( $FILE_LINES==1 )); then 
              echo "Bad SQL return code: `cat $DB_2_LOG` " >> $LOG_FILE
              echo "Load Processing for $CLIENT_NAME had problems:"        \
                   "\nBad SQL return code: `cat $DB_2_LOG` "               \
                   "\nreference $LOG_FILE" > $MAILFILE
  
                    MAIL_SUBJECT="DFO dba load claims PROCESS SQL error"
                    $SCRIPT_DIR/mailto_IS_group.ksh
                    
                    ### email DBAs here too?
              rm $DB_2_LOG         
              let Load_Return_Code=152
              
           else              
              echo "number of lines in file " $FILE_LINES >> $LOG_FILE
              echo "Multiple rows in DBA.LOADS for where clause = "        \
                   "$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE "    >> $LOG_FILE
                
              echo "Load Processing for $CLIENT_NAME had problems:"        \
                   "\nMultiple rows in DBA.LOADS for where clause = "      \
                   "\n$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE "                 \
                   "\nreference $LOG_FILE" > $MAILFILE
  
                    MAIL_SUBJECT="DFO dba load claims PROCESS"
                    $SCRIPT_DIR/mailto_IS_group.ksh
              rm $DB_2_LOG         
              let Load_Return_Code=154
           fi
        fi
     else         
#       found a " 0 record(s) selected ", so no results from load script yet. 
#       wait a minute then re-issue the SQL against the LOADS table

        sleep 60
        db2 "select 'rtn_code', ',' ,ret_code from dba.loads where data_file = '$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE'"> $DB_2_LOG

#       since we're looping based on the existance of the file DB_2_LOG existance, 
#       we could get into an infinite loop here if the DBA load script never inserts a results
#       row into DBA.LOADS.  We'll use a counter to limit the time we wait.

        let LOOP_CTR=LOOP_CTR+1
        if (($LOOP_CTR>10)); then
           echo "Load Processing for $CLIENT_NAME had problems:"        \
                "\nNo rows found in DBA.LOADS, where data_file ="       \
                "\n$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE "                 \
                "\nLoop counter exceeded limit of 10 min wait"          \
                "\nreference $LOG_FILE" > $MAILFILE
  
                 MAIL_SUBJECT="DFO dba load claims PROCESS"
                 $SCRIPT_DIR/mailto_IS_group.ksh

           rm $DB_2_LOG         
           let Load_Return_Code=156
        fi
     fi
  done

  db2 connect reset>/dev/null 2>/dev/null

  echo "\n***********************************************"   >> $LOG_FILE
  echo "DBA LOAD OF CLAIMS FOR CLIENT $CLIENT_NAME ended."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE
 
  echo "tclaim_load_ext ksh ret: " $Load_Return_Code >> $LOG_FILE

  return $Load_Return_Code

