#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSDY7000_KS_7000J_rptclnt_extracts.ksh   
# Title         : .
#
# Description   : Extract for rebate registration reporting client extract 
#                 to the MVS
#                 
#                 
# Maestro Job   : KSDYSSSS KS_JJJJJ
#
# Parameters    : N/A - 
#                
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-08-2004  S.Swanson    Initial Creation.
# 05-04-2004  S.Swanson    Walkthrough changes
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export MVS_DSN="PCS.P"
   if [[$QA_REGION = "true"]]; then
     export MVS_DSN="test.x"
     export ALTER_EMAIL_ADDRESS='sheree.swanson@caremark.com'
   fi
else  
     export REBATES_DIR=rebates_integration
     export MVS_DSN="test.d"
     export ALTER_EMAIL_ADDRESS='sheree.swanson@caremark.com'
fi
       RETCODE=0

       SCHEDULE="KSDY7000"
       JOB="KS_7000J"
       FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_rptclnt_extrct"
       FILE_NAME=$JOB".PCS.P.ZDCKS400"
       SCRIPTNAME=$FILE_BASE".ksh"
       LOG_FILE=$FILE_BASE".log"
       SQL_FILE=$FILE_BASE".sql"
       SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
       DAT_FILE=$FILE_NAME".dat"
       FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
       FTP_NT_IP=204.99.4.30
       TARGET_FILE=$MVS_DSN".ksz7001j.kscc000"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS



#----------------------------------
# Oracle userid/password
# specific for rbate_reg database
# ora.user used for rbate invoicing
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`





#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script if applicable
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/$LOG_FILE
print "TODAYS DATE " `date` >> $OUTPUT_PATH/$LOG_FILE
print "DAILY RPTCLNT EXTRACT " >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# REPORTING CLIENT DAILY EXTRACT
# Set up the Pipe file, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#
print `date` 'Beginning select of RPTCLNT Extract ' >> $OUTPUT_PATH/$LOG_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF
set LINESIZE 800
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
set trimspool on
alter session enable parallel dml;

spool $OUTPUT_PATH/$SQL_PIPE_FILE;

SELECT
 NVL(lpad(rtrim(rpt_client.report_group_nbr,' '),8,'0'),'00000000')
,NVL(rpad(rtrim(rpt_client.report_group_name,' '),40,' '),'                                       ') 
,NVL(rpad(rtrim(update_userid,' '),40, ' '),'                                        ')         
from rbate_reg.rpt_client;
                    
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

export RETCODE=$?

if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed select of rptclnt Extract ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTPing files ' >> $OUTPUT_PATH/$LOG_FILE
   #FTP to the MVS
   
   
   print 'put ' $OUTPUT_PATH/$DAT_FILE " '"$TARGET_FILE"' " ' (replace'     >> $INPUT_PATH/$FTP_CMDS
   print 'quit'                                                      >> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTP complete ' >> $OUTPUT_PATH/$LOG_FILE
   cat $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
#fi
else

#if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Extract ' >> $OUTPUT_PATH/$LOG_FILE
   export RETCODE=$RETCODE
   print 'RPTCLT Extract RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   
#fi
 

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

#if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE       >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS


print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

