#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSDY7000_KS_7080J_MbrCnt_extracts.ksh   
# Title         : .
#
# Description   : Extract for rebate registration Member Count extract 
#                 to the MVS
#                 
#                 
# Maestro Job   : KSDY7000 KS_7080
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
# 05/14/2004  S.Swanson    Walkthrough changes
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
# 11-19-2007  ax04566     Drop the filter of processor_cd
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh


if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export ALTER_EMAIL_ADDRESS=''
     export MVS_DSN="PCS.P"
   if [[$QA_REGION = "true"]]; then
     export MVS_DSN="test.x"
     export ALTER_EMAIL_ADDRESS='' 
   fi
else
     export ALTER_EMAIL_ADDRESS=''  
     export REBATES_DIR=rebates_integration
     export MVS_DSN="test.d"
fi
 RETCODE=0

 SCHEDULE="KSDY7000"
 JOB="KS_7080J"
 FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_MbrCnt_extrct"
 FILE_NAME=$JOB".PCS.P.KSCC050"
 SCRIPTNAME=$FILE_BASE".ksh"
 LOG_FILE=$FILE_BASE".log"
 SQL_FILE=$FILE_BASE".sql"
 SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
 DAT_FILE=$FILE_NAME".dat"
 FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
 FTP_NT_IP=204.99.4.30
 TARGET_FILE=$MVS_DSN".ksz7001j.kscc050"

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
print "DAILY Member Count EXTRACT " >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# RAC DAILY EXTRACT
# Set up the Pipe file, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#
print `date` 'Beginning select of Member Count Extract ' >> $OUTPUT_PATH/$LOG_FILE

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

SELECT /*+ PARALLEL (carrier_group,12) PARALLEL (enrollment,12) FULL(carrier_group) FULL (enrollment)*/ 
                 rpad(rtrim(c.rac),5,' ')
               ||rpad(rtrim(enroll_yr),4,' ')
               ||rpad(rtrim(DECODE(enroll_qtr,1,'Q1',2,'Q2',3,'Q3', 4,'Q4')),2,' ')
               ||lpad(sum(clinical_membership),9,'0') 
               ||lpad(sum(rebate_membership),9,'0')
         FROM
             RBATE_REG.carrier_group c
             ,RBATE_REG.enrollment e
             ,RBATE_REG.RAC r
         WHERE
             -- (r.processor_cd = '1' or r.processor_cd = '9') and
             r.rac = c.rac and
             extl_src_cd IN ('RECAP', 'RXC') and
             e.pcs_system_id = c.pcs_system_id
         GROUP BY c.rac, enroll_yr, enroll_qtr 
     UNION
        (select/*+ PARALLEL (client,12) PARALLEL (enrollment,12) 
                   FULL(client) FULL(enrollment)*/
             rpad(rtrim(client_nbr),5,' ')
           ||rpad(rtrim(enroll_yr),4,' ')
           ||rpad(rtrim(DECODE(enroll_qtr,1,'Q1',2,'Q2',3,'Q3', 4,'Q4')),2,' ')
           ||lpad(sum(clinical_membership),9,'0')
           ||lpad(sum(rebate_membership),9,'0')
         from
             RBATE_REG.enrollment e,
             RBATE_REG.Client c
         WHERE
             e.pcs_system_id = c.pcs_system_id
         GROUP BY c.client_nbr, enroll_yr, enroll_qtr)
;
                    
quit;
EOF


$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

export RETCODE=$?

if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed select of Member Count Extract ' >> $OUTPUT_PATH/$LOG_FILE
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
   
   print 'Member Count Extract RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
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

rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

