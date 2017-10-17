#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_bld_user_tmp_qtr_results_validation.ksh   
# Title         : APC file processing.
#
# Description   : Extracts TQR Summary information for balancing
# Maestro Job   : RIOR4500 RI_4500J
#
# Parameters    : CYCLE_GID
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIOR4500_bld_user_tmp_qtr_results_validation.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date        ID      PARTE #  Description
# ---------  ---------  -------  ------------------------------------------#
# 09-14-2007  Gries		 Initial Creation. 
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
      FTP_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files
  else
    # Running in Prod region
      FTP_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files/test
  fi
else
  # Running in Development region
      FTP_DIR=/rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/APC_files/test
fi

RETCODE=0
APCType='REBATED'
FTP_IP='204.99.4.30'
SCHEDULE="RIOR4500"
JOB=""
APC_OUTPUT_DIR=$OUTPUT_PATH/apc
FILE_BASE="rbate_RIOR4500_bld_user_tmp_qtr_results_validation"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH=$FILE_BASE".log"
SQL_FILE=$APC_OUTPUT_DIR/$FILE_BASE".sql"
SQL_PIPE_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_pipe.lst"
DAT_FILE_OUTPUT=$APC_OUTPUT_DIR/"apc_tmp_quarter_results_summary_data.txt"
SRVR_FILE="apc_tmp_quarter_results_summary_data.txt"
EMAIL_TEXT_DATA_CENTER=$FILE_BASE"_email.txt" 
FTP_COM_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_ftpcommands.txt"
FTP_IP=AZSHISP00

#added for SOX

rm -f $LOG_FILE
rm -f $DAT_FILE_OUTPUT
rm -f $SQL_PIPE
rm -f $FTP_COM_FILE

print "Starting "$SCRIPTNAME                                                   >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

# The following statements can not be indented.

rm -f $SQL_PIPE_FILE

mkfifo $SQL_PIPE_FILE
dd if=$SQL_PIPE_FILE of=$DAT_FILE_OUTPUT bs=100k &

cat > $SQL_FILE << EOF
set LINESIZE 600
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
alter session set optimizer_mode='first_rows';

SPOOL $SQL_PIPE_FILE

SELECT /*+ parallel(a,12) full(a) */
      a.cycle_gid
      ,'|'
      ,a.model_typ_cd
      ,'|'
      ,a.cntrc_no
      ,'|'
      ,a.pico_no
      ,'|'
      ,a.PYMT_SYS_ELIG_CD
      ,'|'
      ,sum (case when a.excpt_id in (90,91,92) then 1 else 0 end)
      ,'|'
      ,sum (case when a.excpt_id not in (90,91,92) then 1 else 0 end)
      ,'|'
      ,sum (case when a.excpt_id in (90,91,92) then a.claim_type else 0 end)
      ,'|'
      ,sum (case when a.excpt_id not in (90,91,92) then a.claim_type else 0 end) 
      ,'|'
      ,sum (a.claim_type) 
      ,'|'
      ,count(*)
      ,'|'
      ,sum (a.rbate_access)
      ,'|'
      ,sum (a.rbate_mrkt_shr)
      ,'|'
      ,sum (a.rbate_admin_fee)
      ,'|'
      ,sum (a.rbate_access+a.rbate_mrkt_shr+a.rbate_admin_fee)
      ,'|'
      ,sum (case when a.excpt_id in (90,91,92) then a.unit_qty else 0 end)
      ,'|'
      ,sum (case when a.excpt_id not in (90,91,92) then a.unit_qty else 0 end)
      ,'|'
      ,sum (a.unit_qty)
  FROM dma_rbate2.tmp_qtr_results a
 group by a.cycle_gid
         ,a.model_typ_cd
         ,a.cntrc_no
         ,a.pico_no
         ,a.PYMT_SYS_ELIG_CD; 

quit;

EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

print " "
RETCODE=$?

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if  [[ $RETCODE != 0 ]]; then
  print ' ' >> $LOG_FILE
  print "=================== APC Validation Summary EXTRACT SQL FAILED ======================" >> $LOG_FILE
  print "APC Validation Summary EXTRACT SQL FAILED did not complete successfully" >> $LOG_FILE 
  print "UNIX Return code = " $RETCODE >> $LOG_FILE
  tail -20 $DAT_FILE_OUTPUT >> $LOG_FILE
  print " " >> $LOG_FILE
  print "=================================================================" >> $LOG_FILE
else
  print ' ' >> $LOG_FILE
  print "================= APC Validation Summary EXTRACT SQL COMPLETED =====================" >> $LOG_FILE
  print "APC Validation Summary EXTRACT SQL" >> $LOG_FILE
  print `date` >> $LOG_FILE
  print "================================================================="   >> $LOG_FILE
  print 'cd ' $FTP_DIR >> $FTP_COM_FILE
  print 'put ' $DAT_FILE_OUTPUT" " $SRVR_FILE ' (replace' >> $FTP_COM_FILE
  print "quit" >> $FTP_COM_FILE
  ftp -i  $FTP_IP < $FTP_COM_FILE >> $LOG_FILE
fi

   

#start script abend logic
if  [[ $RETCODE != 0 ]]; then
    print "APC Extract Failed - error message is: " >> $LOG_FILE 
    print ' ' >> $LOG_FILE 
    print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
    print "  Error Executing "$SCRIPTNAME"          " >> $LOG_FILE
    print "  Look in "$LOG_FILE       >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE

    # Send the Email notification 

    export JOBNAME=$SCHEDULE" / "$JOB
    export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
    export LOGFILE=$LOG_FILE
    export EMAILPARM4="  "
    export EMAILPARM5="  "

    print "Sending email notification with the following parameters" >> $LOG_FILE
    print "JOBNAME is " $JOBNAME >> $LOG_FILE 
    print "SCRIPTNAME is " $SCRIPTNAME >> $LOG_FILE
    print "LOGFILE is " $LOGFILE >> $LOG_FILE
    print "EMAILPARM4 is " $EMAILPARM4 >> $LOG_FILE
    print "EMAILPARM5 is " $EMAILPARM5 >> $LOG_FILE
    print "****** end of email parameters ******" >> $LOG_FILE

    . $SCRIPT_PATH/rbate_email_base.ksh
    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
    exit $RETCODE
fi

#Clean up files - DO NOT REMOVE THE MVS_CNTCARD_DAT FILE!  Required for RI_4508J job.
rm -f $SQL_FILE

print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE

