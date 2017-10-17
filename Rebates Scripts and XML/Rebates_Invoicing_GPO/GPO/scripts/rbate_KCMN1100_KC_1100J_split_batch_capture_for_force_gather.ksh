#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_KCMN1100_KC_1100J_split_batch_capture_for_force_gather.ksh
# Description  = Acquires Split Batches and inserts them into 
#                  t_force_gather_cntl monthly to ensure force gather of split
#		   batch claims.
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
  else                                                                       
    #--Running in Prod region                                                 
    export ALTER_EMAIL_ADDRESS=''                                            
  fi                                                                         
else                                                                         
  #--Running in Development region                                            
  export ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'                    
fi                                                                           


export EXEC_EMAIL=$SCRIPT_PATH"/rbate_email_base.ksh"
export JOB="KC_1100J"
export SCHEDULE="KCMN1100"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_split_batch_capture_for_force_gather"
export SCRIPT_NAME=$SCRIPT_PATH"/"$FILE_BASE".ksh"
export LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
export LOG_ARCH=$LOG_ARCH_PATH/$FILE_BASE".log"
export SQL_FILE=$INPUT_PATH/$FILE_BASE".sql"
export LOG_SQL_FILE=$OUTPUT_PATH/$FILE_BASE".sqllog"
export USER_PSWRD=`cat $SCRIPT_PATH/ora_user.fil`

export CTRL_FILE=$OUTPUT_PATH/"gdx_pre_gather_rpt_control_file_init.dat"

#--Delete the output log and sql file from previous execution if it exists.
rm -f $LOG_FILE
rm -f $SCRIPT_PATH/$SQL_FILE
rm -f $LOG_SQL_FILE

READ_VARS='
	M_CTRL_CYCLE_GID
	M_CTRL_CYCLE_START_DATE
	M_CTRL_CYCLE_END_DATE
	Q_CTRL_CYCLE_GID
	Q_CTRL_CYCLE_START_DATE
	Q_CTRL_CYCLE_END_DATE
	JUNK
'

read $READ_VARS < $CTRL_FILE

CYCLE_GID=$M_CTRL_CYCLE_GID
CYCLE_START_DATE=$M_CTRL_CYCLE_START_DATE
CYCLE_END_DATE=$M_CTRL_CYCLE_END_DATE

print " "                                                                    >> $LOG_FILE
print "Control file record read from " $OUTPUT_PATH/$CTRL_FILE               >> $LOG_FILE
print `date`                                                                 >> $LOG_FILE
print " "                                                                    >> $LOG_FILE
print "Values are:"                                                          >> $LOG_FILE
print "CYCLE_GID = " $CYCLE_GID                                              >> $LOG_FILE
print "CYCLE_START_DATE = " $CYCLE_START_DATE                                >> $LOG_FILE
print "CYCLE_END_DATE = " $CYCLE_END_DATE                                    >> $LOG_FILE

#--build the sql file for SQLPLUS

cat > $SQL_FILE << EOF
set LINESIZE 200
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
SPOOL $LOG_SQL_FILE
alter session enable parallel dml; 

INSERT INTO DMA_RBATE2.T_FORCE_GATHER_CNTL
SELECT /*+ parallel(VB,8) parallel(TRC,8) */
       VB.BATCH_GID, 
       TO_DATE(TO_CHAR(VB.BATCH_RECPT_DATE,'MMDDYYYY'),'MMDDYYYY'), 
       (SELECT MAX(RBATE_CYCLE_GID) 
          FROM DMA_RBATE2.T_RBATE_CYCLE 
         WHERE RBATE_CYCLE_TYPE_ID = 1 
           AND RBATE_CYCLE_STATUS IN ('A')), 
       NULL,                                           
       DECODE(VB.EXTNL_SRC_CODE,'RECAP',VB.EXTNL_SRC_CODE,'RXC',VB.EXTNL_SRC_CODE,'RUC'),
       SYSDATE,                                       
       SYSDATE,                                       
       NULL,                                    
       'Y'                                            
FROM DMA_RBATE2.V_BATCH@DWCORP_REB VB
    ,DMA_RBATE2.T_RBATE_CYCLE TRC
WHERE TO_DATE(TO_CHAR(VB.BATCH_LOAD_DATE,'MMDDYYYY'),'MMDDYYYY') BETWEEN TO_DATE(TO_CHAR(TRC.CYCLE_START_DATE,'MMDDYYYY'),'MMDDYYYY') AND TO_DATE(TO_CHAR(TRC.CYCLE_END_DATE,'MMDDYYYY'),'MMDDYYYY')
  AND TO_DATE(TO_CHAR(VB.BATCH_RECPT_DATE,'MMDDYYYY'),'MMDDYYYY') < TO_DATE(TO_CHAR(TRC.CYCLE_START_DATE,'MMDDYYYY'),'MMDDYYYY')
  AND TRC.RBATE_CYCLE_GID = (SELECT MAX(RBATE_CYCLE_GID)
                               FROM DMA_RBATE2.T_RBATE_CYCLE
                              WHERE RBATE_CYCLE_TYPE_ID = 1
                                AND   RBATE_CYCLE_STATUS IN ('A'))
  AND UPPER (vb.batch_status) = 'T'
  AND VB.BATCH_GID <> VB.BATCH_GID_ROOT  
  AND VB.EXTNL_SRC_CODE NOT IN ('QLC') 
  AND VB.BATCH_GID||TO_DATE(TO_CHAR(VB.BATCH_LOAD_DATE,'MMDDYYYY'),'MMDDYYYY') 
      NOT IN (SELECT BATCH_GID||TO_DATE(TO_CHAR(BATCH_DATE,'MMDDYYYY'),'MMDDYYYY')  
                FROM DMA_RBATE2.T_FORCE_GATHER_CNTL)
; 
quit;

EOF

##  AND VB.BATCH_GID NOT IN (select /*+ parallel(scr,8) */ distinct BATCH_GID
##                             from v_combined_scr scr
##                            where BATCH_DATE between add_months(to_date('$M_CTRL_CYCLE_START_DATE','mmddyyyy'),-1) and add_months(to_date('$M_CTRL_CYCLE_END_DATE','mmddyyyy'),-1) 
##                          )



print ' ' 									>> $LOG_FILE
print "executing SQL" 								>> $LOG_FILE
cat $SQL_FILE >> $LOG_FILE
print `date` 									>> $LOG_FILE
print ' ' 									>> $LOG_FILE

#--execute sql file in SQLPLUS
$ORACLE_HOME/bin/sqlplus -s $USER_PSWRD @$SQL_FILE >> $LOG_FILE

RETCODE=$?

print "RETCODE is $RETCODE" >> $LOG_FILE
if [[ $RETCODE = 1 ]]; then 
      print "******************************************" 		>> $LOG_FILE
      print "******************************************" 		>> $LOG_FILE
      print "******************************************" 		>> $LOG_FILE
      print "                                          " 		>> $LOG_FILE
      print "No rows inserted into Force Gather Control" 		>> $LOG_FILE
      print "                                          " 		>> $LOG_FILE
      print "******************************************" 		>> $LOG_FILE
      print "******************************************" 		>> $LOG_FILE
      print "******************************************" 		>> $LOG_FILE
      RETCODE=$?
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



