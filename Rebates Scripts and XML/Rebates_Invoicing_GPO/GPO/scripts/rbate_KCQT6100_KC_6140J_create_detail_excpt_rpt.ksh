#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCQT6100_KC_6140J_create_detail_excpt_rpt.ksh   
#
# Description   : This script creates the file used by Crystal Reports to 
#                 produce the 'Quarterly Claim Summary by Excpt Id' report.  
#
# Maestro Job   : KC_6140J
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
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
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
export JOB="KC_6140J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_create_detail_excpt_rpt"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_LOG_FILE=$FILE_BASE".sqllog"
export SQL_FILE=$FILE_BASE".sql"
export SQL_FILE_CYCLE=$FILE_BASE"_cycle.sql"
export SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
export FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
export CLAIM_SUM_CYCLE_CNTL="rbate_KCQT6100_KC_6100J_claim_sum_cycle_cntl.dat"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$SQL_LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $INPUT_PATH/$SQL_FILE_CYCLE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS

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
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
export DAT_FILE=$FILE_BASE"_"$CYCLE_GID".dat"
rm -f $OUTPUT_PATH/$DAT_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF
set LINESIZE 200
set trimspool on
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF 
set WRAP off
set serveroutput off
set verify off
whenever sqlerror exit 1
set timing off;

alter session enable parallel dml;

spool $OUTPUT_PATH/$SQL_PIPE_FILE;

select  
    SUBSTR(TO_CHAR(a.cycle_gid,'000000'),2,6)
   ,SUBSTR(TO_CHAR(a.excpt_id,'000'),2,3)
   ,REPLACE(SUBSTR(a.excpt_rsn,1,50),',',' ')
   ,NVL(to_char(SUM(a.clm_cnt),'000000000S'),'000000000+')
from 
(select /*+ full(scrc) parallel(scrc,12) full(excpt) */ scrc.cycle_gid, scrc.excpt_id, excpt.excpt_rsn, count(scrc.claim_gid) clm_cnt
  from dma_rbate2.s_claim_rbate_cycle scrc,
       dma_rbate2.t_excpt_code        excpt
  where cycle_gid = $CYCLE_GID
    and scrc.excpt_id = excpt.excpt_id
    and excpt.excpt_stat = 'E'
  group by scrc.cycle_gid, scrc.excpt_id, excpt.excpt_rsn
UNION ALL
select /*+ full(tqr) parallel(tqr,12) full(excpt) */ tqr.cycle_gid, tqr.excpt_id, excpt.excpt_rsn, count(tqr.claim_gid) clm_cnt
  from dma_rbate2.tmp_qtr_results     tqr,
       dma_rbate2.t_excpt_code        excpt
  where tqr.excpt_id = excpt.excpt_id
  group by tqr.cycle_gid, tqr.excpt_id, excpt.excpt_rsn) a 
group by SUBSTR(TO_CHAR(a.cycle_gid,'000000'),2,6)
        ,SUBSTR(TO_CHAR(a.excpt_id,'000'),2,3)
        ,SUBSTR(a.excpt_rsn,1,50)
order by SUBSTR(TO_CHAR(a.cycle_gid,'000000'),2,6)
        ,SUBSTR(TO_CHAR(a.excpt_id,'000'),2,3)
        ,SUBSTR(a.excpt_rsn,1,50);

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

ORA_RETCODE=$?

print `date` "Completed select of claim summary by excpt_id rpt. for " $CYCLE_GID  >> $OUTPUT_PATH/$LOG_FILE
#-------------------------------------------------------------------------#
# If everything is fine FTP the file to the DATA directory on Crystal Server.                  
#-------------------------------------------------------------------------#

if [[ $ORA_RETCODE = 0 ]]; then
   print " "								 >> $OUTPUT_PATH/$LOG_FILE
   print `date` "FTPing files for cycle "$CYCLE_GID 			 >> $OUTPUT_PATH/$LOG_FILE
   export FTP_NT_IP=AZSHISP00
   export FTP_FILE="rbate_"$JOB"_"$SCHEDULE"_create_detail_excpt_rpt_"$CYCLE_GID".txt"   
   rm -f $INPUT_PATH/$FTP_CMDS
   print 'cd /'$REBATES_DIR                                          	>> $INPUT_PATH/$FTP_CMDS
   print 'cd '$REPORT_DIR                                            	>> $INPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$DAT_FILE $FTP_FILE ' (replace'         	>> $INPUT_PATH/$FTP_CMDS  
   print 'quit'                                                      	>> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS 				>> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTP complete ' 					>> $OUTPUT_PATH/$LOG_FILE
   FTP_RETCODE=$?
   if [[ $FTP_RETCODE = 0 ]]; then
      print " " 							>> $OUTPUT_PATH/$LOG_FILE
      print `date` "FTP of "$OUTPUT_PATH/$DAT_FILE" to "$FTP_FILE" complete" >> $OUTPUT_PATH/$LOG_FILE
      RETCODE=$FTP_RETCODE
   else
      RETCODE=$FTP_RETCODE
   fi    
else
   RETCODE=$ORA_RETCODE
fi   

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "Failure in select for summary report for cycle " $CYCLE_GID     >> $OUTPUT_PATH/$LOG_FILE
   print "Oracle RETURN CODE is : " $ORA_RETCODE            		  >> $OUTPUT_PATH/$LOG_FILE
   print "FTP RETURN CODE is    : " $FTP_RETCODE            		  >> $OUTPUT_PATH/$LOG_FILE
   print " " >> $OUTPUT_PATH/$LOG_FILE
   return
fi


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

