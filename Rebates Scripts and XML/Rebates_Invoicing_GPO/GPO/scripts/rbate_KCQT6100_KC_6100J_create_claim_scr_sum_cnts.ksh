#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCQT6100_KC_6100J_create_claim_scr_sum_cnts.ksh   
# 
#         
# Description   : This script updates the force_gather and scr counts on the
#		   t_claim_sum_cnt table. These totals are on the 'Quarterly 
#	           Claim Totals' and 'Summary by exception Id' reports.  
#
# Maestro Job   : KC_6100J
#
# Parameters    : N/A
#         
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#                  
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09/15/04  N. Tucker   Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
      export REBATES_DIR=rebates_integration
      export REPORT_DIR=reporting_prod/rebates/data
else  
     export REBATES_DIR=rebates_integration
     export REPORT_DIR=reporting_test/rebates/data
fi


export SCHEDULE="KCQT6100"
export JOB="KC_6100J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_create_claim_scr_sum_cnts"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_LOG_FILE=$FILE_BASE".sqllog"
export SQL_FILE=$FILE_BASE".sql"
export SQL_FILE_CYCLE=$FILE_BASE"_cycle.sql"
export DAT_FILE=$FILE_BASE".dat"
export CLAIM_SUM_CYCLE_CNTL="rbate_"$SCHEDULE"_"$JOB"_claim_sum_cycle_cntl.dat"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$SQL_LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $INPUT_PATH/$SQL_FILE_CYCLE
rm -f $OUTPUT_PATH/$CLAIM_SUM_CYCLE_CNTL

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Write a file out of the cycle_gid we need to process  
#-------------------------------------------------------------------------#

print " " 									>> $OUTPUT_PATH/$LOG_FILE
print `date` 									>> $OUTPUT_PATH/$LOG_FILE
print "Building cycle cntl File " 						>> $OUTPUT_PATH/$LOG_FILE
print " " 									>> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_FILE_CYCLE << EOF
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
SPOOL $OUTPUT_PATH/$CLAIM_SUM_CYCLE_CNTL
alter session enable parallel dml; 

SELECT cur.rbate_cycle_gid
      ,' '
      ,TO_CHAR(trc.cycle_start_date,'MMDDYYYY')
      ,' '
      ,TO_CHAR(trc.cycle_end_date,'MMDDYYYY')
 FROM (SELECT MAX(rbate_cycle_gid) rbate_cycle_gid
         FROM dma_rbate2.t_rbate_cycle
        WHERE rbate_cycle_type_id = 2
          AND   rbate_cycle_status = UPPER('C')) cur
      ,dma_rbate2.t_rbate_cycle trc
WHERE cur.rbate_cycle_gid = trc.rbate_cycle_gid
;

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE_CYCLE

ORA_RETCODE=$?

if [[ $ORA_RETCODE = 0  ]]; then
   print " " 							    	         >> $OUTPUT_PATH/$LOG_FILE
   print `date` "Completed getting the cycle_gid and dates" 		  	 >> $OUTPUT_PATH/$LOG_FILE
   print " " 							    		 >> $OUTPUT_PATH/$LOG_FILE
else   
   print " " 									 >> $OUTPUT_PATH/$LOG_FILE
   print "Failure getting the cycle_gid "      					 >> $OUTPUT_PATH/$LOG_FILE
   print "Oracle RETURN CODE is : " $ORA_RETCODE             			 >> $OUTPUT_PATH/$LOG_FILE
   print " " 									 >> $OUTPUT_PATH/$LOG_FILE
   return
fi


while read CYCLE_GID CYCLE_BEG_DT CYCLE_END_DT JUNK; do

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#-------------------------------------------------------------------------#

rm -f $INPUT_PATH/$SQL_FILE

cat > $INPUT_PATH/$SQL_FILE << EOF

whenever sqlerror exit 1
set timing on;

SPOOL $OUTPUT_PATH/$SQL_LOG_FILE

alter session enable parallel dml;

update dma_rbate2.t_claim_sum_cnt a 
   set a.force_gather_cnt = 
       (select count(*)
          from dma_rbate2.s_claim_rbate_force 
   where batch_date between to_date('$CYCLE_BEG_DT','MMDDYYYY') 
    	                and to_date('$CYCLE_END_DT','MMDDYYYY'))
where a.cycle_gid = $CYCLE_GID; 

COMMIT;

update dma_rbate2.t_claim_sum_cnt a 
   set (a.scr_cnt, a.scr_excpt_cnt) = 
       (select count(*),
               SUM(CASE
                   when scr.excpt_id is not null 
           	   then 1 else 0 END) excpt_cnt  
         from dma_rbate2.v_combined_scr scr 
        where batch_date between to_date('$CYCLE_BEG_DT','MMDDYYYY')
                             and to_date('$CYCLE_END_DT','MMDDYYYY'))
where a.cycle_gid = $CYCLE_GID;

COMMIT;

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

ORA_RETCODE=$?

cat $OUTPUT_PATH/$SQL_LOG_FILE							>> $OUTPUT_PATH/$LOG_FILE

if [[ $ORA_RETCODE = 0  ]]; then
   print " " 									>> $OUTPUT_PATH/$LOG_FILE
   print `date` "Update of T_CLAIM_SUM_CNT successful for " $CYCLE_GID 		>> $OUTPUT_PATH/$LOG_FILE
else   
   print " " 									>> $OUTPUT_PATH/$LOG_FILE
   print "Failure in update of scr sum counts "       				>> $OUTPUT_PATH/$LOG_FILE
   print "Oracle RETURN CODE is : " $ORA_RETCODE             			>> $OUTPUT_PATH/$LOG_FILE
   return
fi

RETCODE=$ORA_RETCODE

done < $OUTPUT_PATH/$CLAIM_SUM_CYCLE_CNTL

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " 								     >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters"          >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOB 						     >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME 					     >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE 					     >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 					     >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 					     >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" 			     >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print ' ' 								     >> $OUTPUT_PATH/$LOG_FILE
print "Successfully completed job " $JOB 				     >> $OUTPUT_PATH/$LOG_FILE 
print "Script " $SCRIPTNAME 						     >> $OUTPUT_PATH/$LOG_FILE
print `date`  								     >> $OUTPUT_PATH/$LOG_FILE
mv -f  $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

exit $RETCODE

