#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_KCMN1150_KC_1150J_monthly_cycle_locking.ksh
# Description  = Locks current Monthly cycle by setting cycle status to "L" 
#                  from "A". Sets the cycle status of the next monthly cycle
#		   to "A" from "I".
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  08/09/2005  is23301               initial script creation
#==============================================================================
#----------------------------------
# Caremark Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh


#--re-route DEV and QA Error E-mails to nick tucker
if [[ $REGION = "prod" ]];   then                                            
  if [[ $QA_REGION = "true" ]];   then                                       
    #--Running in the QA region                                               
    export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'
    EMAIL_LIST="GDXITD@caremark.com"
  else                                                                       
    #--Running in Prod region                                                 
    export ALTER_EMAIL_ADDRESS=''
    EMAIL_LIST="GDXDSCOps@caremark.com,GDXGPOOps@caremark.com,stephanie.clark@caremark.com"
  fi                                                                         
else                                                                         
  #--Running in Development region                                            
  export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'
  EMAIL_LIST="GDXITD@caremark.com"

fi                                                                           


export EXEC_EMAIL=$SCRIPT_PATH"/rbate_email_base.ksh"
export JOB="KC_1150J"
export SCHEDULE="KCMN1150"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_monthly_cycle_locking"
export SCRIPT_NAME=$SCRIPT_PATH"/"$FILE_BASE".ksh"
export LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
export LOG_ARCH=$LOG_ARCH_PATH/$FILE_BASE".log"
export SQL_FILE=$INPUT_PATH/$FILE_BASE".sql"
export LOG_SQL_FILE=$OUTPUT_PATH/$FILE_BASE"_sqllog.lst"
export USER_PSWRD=`cat $SCRIPT_PATH/ora_user.fil`
export DAT_FILE=$OUTPUT_PATH/$FILE_BASE"_cycle_for_email.lst"
export EMAIL_TEXT=$OUTPUT_PATH/$FILE_BASE"_EMAIL_text.txt"

#--Delete the output log and sql file from previous execution if it exists.
rm -f $LOG_FILE
rm -f $SCRIPT_PATH/$SQL_FILE
rm -f $LOG_SQL_FILE

#--build the sql file for SQLPLUS

cat > $SQL_FILE << EOF
set LINESIZE 80
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
whenever sqlerror exit 1

alter session enable parallel dml; 

set linesize 80

SPOOL $DAT_FILE

SELECT RBATE_CYCLE_GID 
  FROM DMA_RBATE2.T_RBATE_CYCLE 
 WHERE RBATE_CYCLE_TYPE_ID = 1 
   AND RBATE_CYCLE_STATUS IN ('L')
   AND UPD_DATE = (SELECT MAX(UPD_DATE) 
                     FROM DMA_RBATE2.T_RBATE_CYCLE 
                    WHERE RBATE_CYCLE_TYPE_ID = 1 
                      AND RBATE_CYCLE_STATUS IN ('L'))
;                      

quit;
EOF

print ' ' 									>> $LOG_FILE
print "executing SQL" 								>> $LOG_FILE
print `date` 									>> $LOG_FILE
print ' ' 									>> $LOG_FILE

#--execute sql file in SQLPLUS

$ORACLE_HOME/bin/sqlplus -s $USER_PSWRD @$SQL_FILE

RETCODE=$?

print 'LOG_SQL_FILE start' 		   				        >> $LOG_FILE
cat $LOG_SQL_FILE                                                               >> $LOG_FILE
print 'LOG_SQL_FILE end' 							>> $LOG_FILE
print 'DAT_FILE start' 								>> $LOG_FILE
cat $DAT_FILE                                                                   >> $LOG_FILE
print 'DAT_FILE end' 								>> $LOG_FILE

if [[ $RETCODE = 0 ]]; then
   read CYCLE_GID_TO_REPORT < $DAT_FILE 
   
cat > $EMAIL_TEXT << EOF9999EMAILTEXT

The monthly Cycle, $CYCLE_GID_TO_REPORT, has been Locked.

Any RUC's received hereafter for the period $CYCLE_GID_TO_REPORT
must now be loaded into the current month via a Force Gather.


EOF9999EMAILTEXT



EMAIL_SUBJECT="Monthly_Cycle_Locking_Status"

mailx -s $EMAIL_SUBJECT $EMAIL_LIST < $EMAIL_TEXT

MAILRETCODE=$?
  if [[ $MAILRETCODE != 0 ]]; then
     print "Locking and Force Gather Email to " $EMAIL_LIST "failed." 		>> $LOG_FILE
     print "The email text to be sent was" 			 		>> $LOG_FILE
     print " " 									>> $LOG_FILE
     cat $EMAIL_TEXT 								>> $LOG_FILE
     print " " 									>> $LOG_FILE
     RETCODE=$MAILRETCODE    
else
  print email reads 
  cat $EMAIL_TEXT
  fi   
fi

#--Process the Return Code

if [[ $RETCODE != 0 ]]; then
#----if non-zero, error occured.  e-mail error and copy log to archive directory
   export JOBNAME=$SCHEDULE" / "$JOB
   export SCRIPTNAME=$SCRIPT_NAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" 		>> $LOG_FILE
   print "JOBNAME is " $JOBNAME 						>> $LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME 						>> $LOG_FILE
   print "LOGFILE is " $LOGFILE 						>> $LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 						>> $LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 						>> $LOG_FILE
   print "****** end of email parameters ******" 				>> $LOG_FILE
   
   . $EXEC_EMAIL
   cp $LOG_FILE $LOG_ARCH.`date +"%Y%j%H%M"`
   exit $RC
else
#----if zero, successful.  Move log to archive directory
print ' ' 									>> $LOG_FILE
print 'Schedule/Job : '$SCHEDULE' '$JOB 					>> $LOG_FILE
print 'completed successfully ' 						>> $LOG_FILE
print ' ' >> $LOG_FILE
   mv -f $LOG_FILE $LOG_ARCH.`date +"%Y%j%H%M"`
fi



