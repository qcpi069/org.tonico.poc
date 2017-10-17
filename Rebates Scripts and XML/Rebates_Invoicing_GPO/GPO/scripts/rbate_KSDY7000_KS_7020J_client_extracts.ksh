#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSDY7000_KS_7020J_client_extracts.ksh   
# Title         : .
#
# Description   : Extract for rebate registration client extract 
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
# 05/14/04    s.swanson    walkthrough changes
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
   fi
else  
     export REBATES_DIR=rebates_integration
     export MVS_DSN="test.d"
fi
       RETCODE=0
       SCHEDULE="KSDY7000"
       JOB="KS_7020J"
       FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_client_extrct"
       FILE_NAME=$JOB".PCS.P.ZDCKS415"
       SCRIPTNAME=$FILE_BASE".ksh"
       LOG_FILE=$FILE_BASE".log"
       SQL_FILE=$FILE_BASE".sql"
       SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
       DAT_FILE=$FILE_NAME".dat"
       FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
       FTP_NT_IP=204.99.4.30
       TARGET_FILE=$MVS_DSN".ksz7001j.kscc002"


rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS



#----------------------------------
# Oracle userid/password
# specific for rbate_reg database
# and for rbate invoicing
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
print "DAILY CLIENT EXTRACT " >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# CLIENT DAILY EXTRACT
# Set up the Pipe file, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#
print `date` 'Beginning select of CLIENT Extract ' >> $OUTPUT_PATH/$LOG_FILE

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

SELECT DISTINCT
  NVL(lpad(rtrim(c.client_nbr),8,'0'),'00000000') 
 ,NVL(lpad(rtrim(c.report_group_nbr,' '),8,'0'),'00000000')
 ,NVL(lpad(c.pcs_system_id,11,'0'),'00000000000')
 ,NVL(rpad(rtrim(client_name),60, ' '),cast(rpad(' ',60,' ')as char(60)))
 ,NVL(rpad(rtrim(c.aka_name),60, ' '),cast(rpad(' ',60,' ') as char(60)))
 ,NVL(rpad(rtrim(c.health_ind_nbr),10, ' '),'          ')
 ,NVL(rpad(rtrim(r.rac),15, ' '),'               ')
 ,NVL(rpad(rtrim(c.update_userid),10, ' '), '          ')
 FROM
  RBATE_REG.RAC r,
  RBATE_REG.RAC_CLIENT_ASSOC a,
  RBATE_REG.CLIENT c,
  RBATE_REG.RAC_DSPN_FCLY_ASSOC d
WHERE
    r.rac = a.rac
AND
  c.client_nbr = a.client_nbr
AND
  -- Pick out the current records.
   TRUNC(sysdate) between a.rec_eff_dt and a.rec_term_dt
AND
  r.rac = d.rac
AND
  -- Pick out the current records.
   TRUNC(sysdate) between d.rec_eff_dt and d.rec_term_dt
AND
  -- Guarantee we only export 'All' or 'Retail' type clients.
  d.dspn_fcly_type_cd in ('A','R')
;
                    
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

export RETCODE=$?

if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed select of CLIENT Extract ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTPing files ' >> $OUTPUT_PATH/$LOG_FILE
   #FTP to the MVS
   
   
   print 'put ' $OUTPUT_PATH/$DAT_FILE " '"$TARGET_FILE"' " ' (replace'     >> $INPUT_PATH/$FTP_CMDS
   print 'quit'                                                      >> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTP complete ' >> $OUTPUT_PATH/$LOG_FILE
   cat $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   
else

   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Extract ' >> $OUTPUT_PATH/$LOG_FILE
   
   print 'CLIENT Extract RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE


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

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS


print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

