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
# 6014329      qcpi733       08/21/2006 Corrected the DBA.LOADS query that 
#                                       tried to determine if there were 
#                                       duplicate claims loaded and rejected.
#                                       Changed initial sleep from 60 secs to
#                                       1200 based on avg run time for dba
#                                       load of 23 minutes in Maestro.
#                                       Changed the password file from 
#                                       chester_password.ref and changed user
#                                       from vraadmin.
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
 
  CHESTER_PASSWORD_FILE="$REF_DIR/vactuate_password.ref"
  typeset -i Load_Return_Code=0
  typeset -i LOOP_CTR=1
  DB_2_LOG="$TEMP_DIR/db_2.log"
  DB_2_RTN_CODE="$TEMP_DIR/db_2_return_cd"
  TEMP_RTN_CODE="$TEMP_DIR/return_cd_value"
  CHESTER_USER="vactuate"
  CHESTER_PASSWORD=$(< $CHESTER_PASSWORD_FILE)
  export Load_Return_Code
  RETCODE=0


#6014329 - initial sleep giving the dba's load time to complete.  Change from 60 to 1200 (20 mins)
print `date +"%D %r %Z"` >> $LOG_FILE
print "Sleeping 20 mins to give DBA load a chance to complete." >> $LOG_FILE
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

print " "  >> $LOG_FILE
print `date +"%D %r %Z"` >> $LOG_FILE
print "Validate load by checking DBA.LOAD table." >> $LOG_FILE


db2 "connect to $DATABASE user " $CHESTER_USER " using " $CHESTER_PASSWORD >>$LOG_FILE 2>>$LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Connection to $DATABASE failed.  "   >> $LOG_FILE
    return 199
fi

print " "  >> $LOG_FILE
print "Checking the DBA.LOADS table for a row where the DATA_FILE = $DATA_LOAD_FILE" >> $LOG_FILE
print " "  >> $LOG_FILE

db2 "select 'rtn_code', ',' filler ,ret_code from dba.loads where data_file = '$DATA_LOAD_FILE'"> $DB_2_LOG 2>>$LOG_FILE
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
           print " " >> $LOG_FILE
           print "RETURN_CD_VAL = $RETURN_CD_VAL" >> $LOG_FILE
           print " " >> $LOG_FILE

          if [[ ${RETURN_CD_VAL} -eq 0 ]]; then

              echo "load of claim records was successful " >> $LOG_FILE
   
              let Load_Return_Code=140
              rm $DB_2_LOG

          elif [[ ${RETURN_CD_VAL} -eq 2 ]]; then

#             check for any duplicates the autoloader kicked out.

#6014329              db2 "select 'deleted_count', ',' ,deleted from dba.loads where data_file = '$DATA_LOAD_FILE'"> $DB_2_LOG
              db2 "select 'rejected_count', ',' ,rejected from dba.loads where data_file = '$DATA_LOAD_FILE'"> $DB_2_LOG
              grep "rejected_count"  $DB_2_LOG > $DB_2_RTN_CODE 
              cut -f2 -d\, $DB_2_RTN_CODE > $TEMP_RTN_CODE
              REJ_CNT=$(< $TEMP_RTN_CODE)

              echo "Some claim records were not loaded." >> $LOG_FILE
              echo "Load Processing for $CLIENT_NAME warning: some claims were rejected!"              \
                   "\n\n\t$REJ_CNT claims were rejected.  This can be caused by duplicate key violations or NULL value violations." \
                   "\n\nNo - duplicate claims are not saved off to a table, you can't with an import statement." \
                   "\nLog File $LOG_FILE" > $MAILFILE

              MAIL_SUBJECT="DFO dba load claims PROCESS warning-DUP OR NULL VALUES"
              $SCRIPT_DIR/mailto_IS_group.ksh
              let Load_Return_Code=142

              rm $DB_2_LOG
          else

              echo "load of claim records was NOT successful!!!! " >> $LOG_FILE
              echo "Load Processing for $CLIENT_NAME had problems: $RETURN_CD_VAL"   \
                   "\nA database error occurred, returing: "             \
                   "\nLog File = $LOG_FILE" \
                   "\n\nLast 100 lines of dba load msg file:"         \
                   tail -100 $DBA_DIR/vrap.tclaim_stage_dfo.msg     > $MAILFILE
  
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
                   "$DATA_LOAD_FILE "    >> $LOG_FILE
                
              echo "Load Processing for $CLIENT_NAME had problems:"        \
                   "\nMultiple rows in DBA.LOADS for where clause = "      \
                   "\n$DATA_LOAD_FILE "                 \
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

	print "Sleep number $LOOP_CTR waiting for DBA_LOADS to be populated. " >> $LOG_FILE
        sleep 60
        db2 "select 'rtn_code', ',' ,ret_code from dba.loads where data_file = '$DATA_LOAD_FILE'"> $DB_2_LOG

#       since we're looping based on the existance of the file DB_2_LOG existance, 
#       we could get into an infinite loop here if the DBA load script never inserts a results
#       row into DBA.LOADS.  We'll use a counter to limit the time we wait.

        let LOOP_CTR=LOOP_CTR+1
        if (($LOOP_CTR>60)); then
           echo "Load Processing for $CLIENT_NAME had problems:"        \
                "\nNo rows found in DBA.LOADS, where data_file ="       \
                "\n$DATA_LOAD_FILE "                 \
                "\nLoop counter exceeded limit of 60 min wait"          \
                "\nreference $LOG_FILE" > $MAILFILE
  
                 MAIL_SUBJECT="DFO dba load claims PROCESS"
                 $SCRIPT_DIR/mailto_IS_group.ksh

           rm $DB_2_LOG         
           let Load_Return_Code=156
        fi
     fi

  done

  if [[ $Load_Return_Code -ge 150 ]]; then
      print " " >> $LOG_FILE
      print " " >> $LOG_FILE
      print "Next 100 lines from DBA Load messages file " >> $LOG_FILE
      tail -100 $DBA_DIR/vrap.tclaim_stage_dfo.msg >> $LOG_FILE
      print " " >> $LOG_FILE
      print " " >> $LOG_FILE
  fi

  db2 connect reset>/dev/null 2>/dev/null

  echo "\n***********************************************"   >> $LOG_FILE
  echo "DBA LOAD OF CLAIMS FOR CLIENT $CLIENT_NAME ended."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE
 
  echo "tclaim_load_ext ksh ret: " $Load_Return_Code >> $LOG_FILE

  return $Load_Return_Code

