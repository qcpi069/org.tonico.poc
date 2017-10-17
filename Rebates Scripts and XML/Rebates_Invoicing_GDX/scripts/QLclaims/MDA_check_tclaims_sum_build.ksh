#!/usr/bin/ksh

###############################################
#SCRIPT NAME : MDA_check_tclaims_sum_build    #
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
#  return code values and meanings for "MDA_check_tclaims_sum_build.ksh"
#
#  140 series are 'good' return codes
#
#  140 = claims loaded successfully without any duplicates
#
#  150 series are 'bad' return codes
#
#  150 = non-zero return code on DBA.LOADS table for given load data set
#  151 = We never got a row in DBA.LOADS for the load of the given 
#        load data set.  Manual investigation needed
#  152 = SQL error of some sort  
#  154 = Multiple rows in DBA.LOADS for given load data set, further
#        manual investigation is needed to determine if there are problems
#  155 = claims loaded but with duplicates in TCLAIMS_EXCP table 
#        (should NEVER get this, as it is an exception)
#  
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  04/01/2004  Initial Release                    #
#                                                                           #
#############################################################################

#  export HOME_DIR="/vracobol/prod"
#  export REF_DIR="$HOME_DIR/control/reffile"
#  export TEMP_DIR="/vracobol/prod/temp/testing"
#  export LOG_FILE="$TEMP_DIR/log_file.log"
#  export MAILFILE="$TEMP_DIR/mailfile"
#  export DBA_DATA_LOAD_DIR="/datar1"
#  export DATA_LOAD_DIR="/vradfo/prodload"
#  export DATA_LOAD_FILE="mda.vrap.tclaims.dat.T20040601000003"
#  export SCRIPT_DIR="$HOME_DIR/script"
#
#  above lines are hardcoded values for testing.
#
#################################################################################

  echo "\n***********************************************"   >> $LOG_FILE
  echo "DBA REBUILD OF TCLAIMS_SUM FOR $RUN_MODE claims intake started."     \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

  THIS_DIR="$PWD"
  cd $TEMP_DIR
 
  CHESTER_PASSWORD_FILE="$REF_DIR/chester_password.ref"
  typeset -i LOOP_CTR=1
  DB_2_LOG="$TEMP_DIR/db_2.log"
  DB_2_RTN_CODE="$TEMP_DIR/db_2_return_cd"
  MAX_LOAD_DATE="$TEMP_DIR/max_load_date"
  TEMP_LOAD_DT="$TEMP_DIR/temp_load_date"
  TEMP_RTN_CODE="$TEMP_DIR/return_cd_value"
  CHESTER_USER="vraadmin"
  CHESTER_PASSWORD=$(< $CHESTER_PASSWORD_FILE)
    
#  sleep 60
#  db2 "connect to udbmdap user " $CHESTER_USER " using " $CHESTER_PASSWORD" >/dev/null 2>/dev/null
  db2 "connect to udbmdap user " $CHESTER_USER " using " $CHESTER_PASSWORD >>$LOG_FILE 2>>$LOG_FILE

  SQL_TEXT="select 'load_date', ',' ,max(load_date) from dba.loads where data_file='$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE'"
  echo "SQL TEXT " $SQL_TEXT
  db2 "$SQL_TEXT"> $DB_2_LOG 2>>$LOG_FILE
  print $(< $DB_2_LOG)>>$LOG_FILE
  
  FILE_LINES=$(wc -l < $DB_2_LOG)     

# we'll should ALWAYS get some sort of max_load_date returned (hopefully) 

  if (( $FILE_LINES!=7 )); then 

     db2 connect reset>/dev/null 2>/dev/null

     echo "Load Processing for $RUN_MODE tclaims_sum rebuild had problems:"     \
          "\nNo rows found in DBA.LOADS, where data_file ="               \
          "\ndata_file = $DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE"                  \
          "\nreference $LOG_FILE" > $MAILFILE

     MAIL_SUBJECT="MDA $RUN_MODE tclaims_sum rebuild PROCESS"
     $SCRIPT_DIR/mailto_IS_group.ksh

     let Load_Return_Code=152

     echo "at end Load_Return_Code: " $Load_Return_Code
     echo "\n***********************************************"   >> $LOG_FILE
     echo "TCLAIMS_SUM rebuild for $RUN_MODE CLAIMS load ended with unknown status."           \
          "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
     echo "***********************************************\n" >> $LOG_FILE

     return $Load_Return_Code
  fi  

# (( $FILE_LINES==7 ))
# 7 lines is 1 row returned plus overhead
# pull out load_date value for use in next SQL where clause

  grep "load_date" $DB_2_LOG > $MAX_LOAD_DATE
  echo "load_date " $MAX_LOAD_DATE
  cut -f2 -d\, $MAX_LOAD_DATE > $TEMP_LOAD_DT

  print "`cat $TEMP_LOAD_DT`"

  SQL_TEXT="select 'rtn_code', ',' ,ret_code from dba.loads where table='vrap.tclaims_sum' and load_date>=ltrim('`cat $TEMP_LOAD_DT`')"
  echo "SQL TEXT " $SQL_TEXT
  db2 "$SQL_TEXT"> $DB_2_LOG 2>>$LOG_FILE
  print $(< $DB_2_LOG)>>$LOG_FILE
              
# loop until we determine we're done with the checking of the dba load script status.
# we'll delete the db2 log file to break the loop

  while [[ -s $DB_2_LOG ]]
     do
        typeset -i SEARCH_RESULT=`cat $DB_2_LOG|grep "  0 record(s) selected."|wc -l`

#       if we didn't find "  0 records" message, then we have 1 or more rows returned

        if (( $SEARCH_RESULT==0 )); then
#          there's SOME rows returned, need to get the 1 return code value from table
#          If there's more than 1 row in the returned record set, we may have some issues.
  
           FILE_LINES=$(wc -l < $DB_2_LOG)     
 
           if (( $FILE_LINES==7 )); then 
#             7 lines is 1 row returned plus overhead
#             pull out return code value for interogation

              grep "rtn_code" $DB_2_LOG > $DB_2_RTN_CODE 
              echo "db2 return code " `cat $DB_2_RTN_CODE`
              cut -f2 -d\, $DB_2_RTN_CODE > $TEMP_RTN_CODE

              typeset -i RETURN_CD_VAL
              RETURN_CD_VAL=$(cat $TEMP_RTN_CODE)

              if ((${RETURN_CD_VAL}==0)); then
                 echo "rebuild of tclaim_sum table was successful "   \
                      "\nON `date +'%A %B %d %Y AT %T HRS.'`"    >> $LOG_FILE

                 rm $DB_2_LOG
                 let Load_Return_Code=140
 
              else
                 echo "tclaim_sum rebuild was NOT successful!!!! " >> $LOG_FILE
                 echo "Load Processing for $RUN_MODE claims intake had problems:"   \
                      "\nNon-Zero return code was returned:"                        \
                      "\n $RETURN_CD_VAL"                                           \
                      "\nreference $LOG_FILE" > $MAILFILE
  
                 MAIL_SUBJECT="MDA dba tclaim_sum rebuild PROCESS"
                 $SCRIPT_DIR/mailto_IS_group.ksh
         
                 rm $DB_2_LOG
                 let Load_Return_Code=150
              fi
           else
#             Record set results file had other than 7 lines in it.
#             Check for 1 line, which would indicate a DB2 SQL error like:
#             "SQL0204N "DBA.LOADS_1" is an undefined name. SQLSTATE=42704"

              if (( $FILE_LINES==1 )); then 
                 echo "Bad SQL return code: `cat $DB_2_LOG` " >> $LOG_FILE
                 echo "Processing for $RUN_MODE tclaims_sum rebuild had problems:"   \
                      "\nBad SQL return code: `cat $DB_2_LOG` "                     \
                      "\nreference $LOG_FILE" > $MAILFILE
  
                  MAIL_SUBJECT="MDA dba tclaims_sum rebuild PROCESS SQL error"
                  $SCRIPT_DIR/mailto_IS_group.ksh
                    
                  ### email DBAs here too?
                  rm $DB_2_LOG         
                  let Load_Return_Code=152
              
              else              
                 echo "number of lines in file " $FILE_LINES >> $LOG_FILE
                 echo "Multiple rows in DBA.LOADS for where clause = "             \
                      "$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE "    >> $LOG_FILE
   
                 echo "Processing for $RUN_MODE tclaims_sum rebuild had problems:"  \
                      "\nMultiple rows in DBA.LOADS for where clause = "           \
                      "\n$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE "                      \
                      "\nreference $LOG_FILE" > $MAILFILE
  
                 MAIL_SUBJECT="MDA dba tclaims_sum rebuild PROCESS error"
                 $SCRIPT_DIR/mailto_IS_group.ksh
                 rm $DB_2_LOG         
                 let Load_Return_Code=154
              fi
           fi
        else         
#          found a " 0 record(s) selected ", so no results from load script yet. 
#          wait a minute then re-issue the SQL against the LOADS table

           sleep 60

#          SQL text set above, re-issuing in a loop
###        SQL_TEXT="select 'rtn_code', ',' ,ret_code from dba.loads where table='vrap.tclaims_sum' and load_date>=ltrim('`cat $TEMP_LOAD_DT`')"

           db2 "$SQL_TEXT"> $DB_2_LOG 2>>$LOG_FILE

#          since we're looping based on the existance of the file DB_2_LOG existance, 
#          we could get into an infinite loop here if the DBA load script never inserts a results
#          row into DBA.LOADS.  We'll use a counter to limit the time we wait.

           let LOOP_CTR=LOOP_CTR+1
           if (($LOOP_CTR>220)); then
              echo "Processing for $RUN_MODE tclaims_sum rebuild had problems:"     \
                   "\nNo rows found in DBA.LOADS, where data_file ="               \
                   "\n$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE "                         \
                   "\nLoop counter exceeded limit of 220 min wait"                 \
                   "\nreference $LOG_FILE" > $MAILFILE
  
              MAIL_SUBJECT="MDA dba tclaims_sum rebuild PROCESS error"
              $SCRIPT_DIR/mailto_IS_group.ksh
              rm $DB_2_LOG         
              let Load_Return_Code=151
           fi
        fi
  done

  db2 connect reset>/dev/null 2>/dev/null

  echo "at end Load_Return_Code: " $Load_Return_Code
  echo "\n***********************************************"   >> $LOG_FILE
  echo "DBA REBUILD OF TCLAIMS_SUM for $RUN_MODE CLAIMS load ended."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE
  
  return $Load_Return_Code
