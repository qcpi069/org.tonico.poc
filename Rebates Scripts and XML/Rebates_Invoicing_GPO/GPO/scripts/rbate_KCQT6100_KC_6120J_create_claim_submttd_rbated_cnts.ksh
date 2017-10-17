#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCQT6100_KC_6120J_create_claim_submttd_rbated_cnts.ksh   
#
# Description   : This script updates the submitted and rebated counts on the
#		   t_claim_sum_cnt table. These totals are on the 'Quarterly 
#	           Claim Totals' and 'Summary by exception Id' reports.  
#
# Maestro Job   : KC_6120J
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
# 09/16/04  N. Tucker   Initial Creation.
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
export JOB="KC_6120J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_create_claim_submttd_rbated_cnts"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_LOG_FILE=$FILE_BASE".sqllog"
export SQL_FILE=$FILE_BASE".sql"
export SQL_FILE_CYCLE=$FILE_BASE"_cycle.sql"
export CLAIM_SUM_CYCLE_CNTL="rbate_KCQT6100_KC_6100J_claim_sum_cycle_cntl.dat"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$SQL_LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $INPUT_PATH/$SQL_FILE_CYCLE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Perfrom a read loop of the cycle control file 
#-------------------------------------------------------------------------#

print " " 									>> $OUTPUT_PATH/$LOG_FILE
print `date`									>> $OUTPUT_PATH/$LOG_FILE
print "Reading cycle cntl File " 						>> $OUTPUT_PATH/$LOG_FILE
print " " 									>> $OUTPUT_PATH/$LOG_FILE

while read CYCLE_GID CYCLE_BEG_DT CYCLE_END_DT JUNK; do

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

rm -f $INPUT_PATH/$SQL_FILE

cat > $INPUT_PATH/$SQL_FILE << EOF

whenever sqlerror exit 1
set timing on;

SPOOL $OUTPUT_PATH/$SQL_LOG_FILE
alter session enable parallel dml;

update dma_rbate2.t_claim_sum_cnt a 
   set (a.rbated_cnt, a.submitted_cnt) = 
       (SELECT /*+
       ordered
       full(tqr)
       full(excpt)
       parallel(tqr,12)
       pq_distribute(tqr,hash,hash)
       */
     SUM(CASE
         when excpt.RBATED_EXCPT_ID = 1
         then 1 else 0 END) rebated_cnt
    ,SUM(CASE
         when excpt.SUBMTTD_EXCPT_ID = 1
         then 1 else 0 END) submitted_cnt   
    FROM  dma_rbate2.t_excpt_code        excpt
         ,dma_rbate2.tmp_qtr_results     tqr
  WHERE  tqr.excpt_id  = excpt.excpt_id)
 WHERE a.cycle_gid = $CYCLE_GID;



COMMIT;

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

ORA_RETCODE=$?

cat $OUTPUT_PATH/$SQL_LOG_FILE							>> $OUTPUT_PATH/$LOG_FILE

if [[ $ORA_RETCODE = 0  ]]; then
   print " " 									>> $OUTPUT_PATH/$LOG_FILE
   print `date` "Update of T_CLAIM_SUM_CNT successful for cycle " $CYCLE_GID	>> $OUTPUT_PATH/$LOG_FILE
else   
   print " " 									>> $OUTPUT_PATH/$LOG_FILE
   print "Failure in update of submmtd/rebated sum counts "       		>> $OUTPUT_PATH/$LOG_FILE
   print "Oracle RETURN CODE is : " $ORA_RETCODE             			>> $OUTPUT_PATH/$LOG_FILE
   print " " 
   return
fi

RETCODE=$ORA_RETCODE

done < $OUTPUT_PATH/$CLAIM_SUM_CYCLE_CNTL

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" 	>> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    	>> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  	>> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" 	>> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters"          	>> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOB 						     	>> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME 					     	>> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE 					     	>> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 					     	>> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 					     	>> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" 			     	>> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print " " 								     	>> $OUTPUT_PATH/$LOG_FILE
print "Successfully completed job " $JOB 				     	>> $OUTPUT_PATH/$LOG_FILE 
print "Script " $SCRIPTNAME 						     	>> $OUTPUT_PATH/$LOG_FILE
print `date`  								     	>> $OUTPUT_PATH/$LOG_FILE
mv -f  $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

exit $RETCODE

