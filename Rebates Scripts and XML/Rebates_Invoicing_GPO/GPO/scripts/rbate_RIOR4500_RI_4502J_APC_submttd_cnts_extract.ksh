#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_RI_4502J_APC_submttd_cnts_extract.ksh   
# Title         : APC file processing.
#
# Description   : Extracts APC records into a summarized file, for feed
#                 of Submitted claim counts for Payments.
# Maestro Job   : RIOR4500 RI_4502J
#
# Parameters    : NONE
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIOR4500_RI_4502J_APC_submttd_cnts_extract.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date        ID      PARTE #  Description
# ---------  ---------  -------  ------------------------------------------#
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
# 03/10/2005  IS23301   6002298  Modify to select the 6 new split fields.
# 06-30-04    IS45401   5994785  Changed view in data extract to use new
#                                V_APC_SUBMTTD_CNTS instead of 
#                                V_APC_CYCLE_SUBMTTD_CNTS;  removed all 
#                                export commands; Removed input parm of
#                                CYCLE_GID, no longer needed.
# 02/23/04    is00241            Changes for APC Validation project
# 05-20-03    IS45401            Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

#Always build these variables/values

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
    ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'
    MVS_FTP_PREFIX='TEST.X'
    SCHEMA_OWNER="dma_rbate2"
  else
    # Running in Prod region
    ALTER_EMAIL_ADDRESS=''
    MVS_FTP_PREFIX='PCS.P'
    SCHEMA_OWNER="dma_rbate2"
  fi
else
  # Running in Development region
  ALTER_EMAIL_ADDRESS='nick.tucker@caremark.com'
  MVS_FTP_PREFIX='TEST.D'
  SCHEMA_OWNER="dma_rbate2"
fi

#the variables needed for the source file location and the NT Server
FTP_IP='204.99.4.30'
SCHEDULE="RIOR4500"
JOB="RI_4502J"
APC_OUTPUT_DIR=$OUTPUT_PATH/apc
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_APC_submttd_cnts_extract"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH=$FILE_BASE".log"
SQL_FILE=$APC_OUTPUT_DIR/$FILE_BASE".sql"
SQL_PIPE_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_pipe.lst"
DAT_FILE=$APC_OUTPUT_DIR/$FILE_BASE".dat"
TRG_FILE=$APC_OUTPUT_DIR/$FILE_BASE".trg"
MVS_FTP_COM_FILE=$APC_OUTPUT_DIR/$FILE_BASE"_ftpcommands.txt" 
MVS_FTP_TRG=" '"$MVS_FTP_PREFIX".KSZ4900.SUMM.SUBMTTD.CNTS.TRIGGER'"
MVS_FTP_DAT=" '"$MVS_FTP_PREFIX".KSZ4921J.APCFINAL.SUBMTTD.SUMMARY'"

rm -f $LOG_FILE
rm -f $DAT_FILE
rm -f $SQL_FILE
rm -f $SQL_PIPE_FILE
rm -f $TRG_FILE
rm -f $MVS_FTP_COM_FILE

print "Starting "$SCRIPTNAME                                                   >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

print ' '                                                                      >> $LOG_FILE
print "Executing APC Submitted Counts Extract SQL"                             >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

# Output being spooled here needs to match the format of the MVS COPYBOOK KSZ4PCCX
# No WHERE clause is used on the SQL because the view being used pulls from a table 
#   with only one calendar quarters worth of data.

mkfifo $SQL_PIPE_FILE
dd if=$SQL_PIPE_FILE of=$DAT_FILE bs=100k &

cat > $SQL_FILE << EOF
set LINESIZE 94
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
SPOOL $SQL_PIPE_FILE
alter session enable parallel dml; 

select 
    rbate_id
   ,mail_order_code
   ,copay_src_code
   ,year
   ,qtr
   ,clm_cnt
   ,extnl_src_code
   ,EXTNL_LVL_ID1
   ,EXTNL_LVL_ID2
   ,EXTNL_LVL_ID3
   ,srx_drug_flg
   ,user_field6_flag
from $SCHEMA_OWNER.V_APC_SUBMTTD_CNTS
;

commit;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

RETCODE=$?

print ' '                                                                      >> $LOG_FILE
print "Completed SQL call for Submitted Claim Counts."                         >> $LOG_FILE 
print `date`                                                                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print "APC Extract SQL Failed - error message is: "                         >> $LOG_FILE 
   print ' '                                                                   >> $LOG_FILE 
   tail -20 $DAT_FILE                                                          >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================"   >> $LOG_FILE
   print "  Error Executing "$SCRIPTNAME"          "                           >> $LOG_FILE
   print "  Look in "$LOG_FILE                                                 >> $LOG_FILE
   print "================================================================="   >> $LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE" / "$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters"            >> $LOG_FILE
   print "JOBNAME is " $JOBNAME                                                >> $LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME                                          >> $LOG_FILE
   print "LOG_FILE is " $LOG_FILE                                              >> $LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4                                          >> $LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5                                          >> $LOG_FILE
   print "****** end of email parameters ******"                               >> $LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $LOG_FILE $LOG_ARCH_ARCH.`date +"%Y%j%H%M"`
   exit $RETCODE
else
  print ' '                                                                    >> $LOG_FILE
  print "FTPing ASCII output to MVS " $FTP_IP                                  >> $LOG_FILE

  # build ftp commands and ftp file here 
  print 'ascii'                                                                >> $MVS_FTP_COM_FILE

  print 'put ' $DAT_FILE " " $MVS_FTP_DAT ' (replace'                          >> $MVS_FTP_COM_FILE 

  print "Trigger file for " $MVS_FTP_DAT                                       >> $TRG_FILE 
  # print 'put ' $TRG_FILE " " $MVS_FTP_TRG ' (replace'                          >> $MVS_FTP_COM_FILE 

  print 'quit'                                                                 >> $MVS_FTP_COM_FILE 

  print " "                                                                    >> $LOG_FILE
  print "Start Concatonating FTP Commands "                                    >> $LOG_FILE
  cat $MVS_FTP_COM_FILE                                                        >> $LOG_FILE
  print "End Concatonating FTP Commands "                                      >> $LOG_FILE
  print " "                                                                    >> $LOG_FILE

  ftp -i  $FTP_IP < $MVS_FTP_COM_FILE                                          >> $LOG_FILE

  print ' '                                                                    >> $LOG_FILE
  print "Completed FTP"                                                        >> $LOG_FILE
  print `date`                                                                 >> $LOG_FILE

  print ' '                                                                    >> $LOG_FILE
  print "Completed executing APC Submitted Counts Extract "                    >> $LOG_FILE
  print `date`                                                                 >> $LOG_FILE
fi

#Clean up files
rm -f $SQL_FILE
rm -f $SQL_PIPE_FILE
rm -f $TRG_FILE
rm -f $MVS_FTP_COM_FILE

print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`


exit $RETCODE

