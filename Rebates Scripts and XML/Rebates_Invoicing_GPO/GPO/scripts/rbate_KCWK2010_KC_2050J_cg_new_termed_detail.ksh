#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK2010_KC2050J_cg_new_termed_detail.ksh   
# Title         : RECAP c/g detail for new and termed groups with missing Rebate ID's
#
# Description   : This file lists Recap carrier groups with missing rebate ID's that have
#                 an effective or term date during the current or previous cycle quarter.
# Maestro Job   : KC_2050J
#
# Parameters    : N/A
#         
# Input         : This script gets the active cycle_gid from the pre-gather report control file 
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 10-12-2004  S.Swanson   Initial Creation.
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh


# for testing
#. /staging/apps/rebates/prod/scripts/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
      export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
      export ALTER_EMAIL_ADDRESS=''
else  
      export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
      export ALTER_EMAIL_ADDRESS='sheree.swanson@caremark.com'
fi

 SCHEDULE="KCWK2010"
 JOB="KC_2050J"
 FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_cg_new_termed_detail"
 SCRIPTNAME=$FILE_BASE".ksh"
 LOG_FILE=$FILE_BASE".log"
 SQL_FILE=$FILE_BASE".sql"
 SQL_PIPE_FILE=$FILE_BASE"_Pipe.lst"
 DAT_FILE=$FILE_BASE".dat"
 FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
 CTRL_FILE="rbate_pre_gather_rpt_control_file_init.dat"
 FTP_NT_IP=AZSHISP00

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$FTP_CMDS
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE

#Set return code to null

RETCODE=''
#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#

print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
print "Starting " $SCRIPTNAME                                                   >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# read the cntl file and execute sql for each cycle_gid 
#-------------------------------------------------------------------------#

while read CTRL_CYCLE_GID CTRL_CYCLE_START_DATE CTRL_CYCLE_END_DATE; do

    CYCLE_GID=$CTRL_CYCLE_GID
    CYCLE_START_DATE=$CTRL_CYCLE_START_DATE
    CYCLE_END_DATE=$CTRL_CYCLE_END_DATE

   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "Control file record read from " $OUTPUT_PATH/$CTRL_FILE               >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "Values are:"                                                          >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_GID = " $CYCLE_GID                                              >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_START_DATE = " $CYCLE_START_DATE                                >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_END_DATE = " $CYCLE_END_DATE                                    >> $OUTPUT_PATH/$LOG_FILE

   DAT_FILE=$FILE_BASE'_'$CYCLE_GID'.dat'
   FILE_OUT=$DAT_FILE

   rm -f $INPUT_PATH/$SQL_FILE
   rm -f $OUTPUT_PATH/$DAT_FILE

   print "Output file for " $CYCLE_GID " is " $OUTPUT_PATH/$DAT_FILE            >> $OUTPUT_PATH/$LOG_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF
SET LINESIZE 175
SET TERMOUT OFF
SET PAGESIZE 0
SET NEWPAGE 0
SET SPACE 0
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET WRAP OFF
SET TRIMSPOOL ON
set verify off
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/$DAT_FILE
alter session enable parallel dml


SELECT
  vali.carr_id
 ,'|'
 ,vali.grp_id
 ,'|'
 ,vali.rbate_affl_cd as rebate_id
 ,'|'
 ,vali.algn_grp_eff_dt
 ,'|'
 ,vali.algn_grp_end_dt
 ,'|'
 ,nm.carr_nm
FROM
  (SELECT /*+ parallel(scr,12) parallel(scrc,12) full(scr) full(scrc) */  
       DISTINCT
       scr.extnl_lvl_id1                          
      ,scr.extnl_lvl_id3                              
   FROM 
      (SELECT /*+ parallel(alv,15) full(alv) */ *
       FROM dma_rbate2.s_claim_rbate_alv alv) scr,
                              dma_rbate2.t_rbate scrc
       WHERE scr.excpt_id IS NULL  
         AND scr.batch_date BETWEEN TO_DATE('$CYCLE_START_DATE','MMDDYYYY') AND TO_DATE('$CYCLE_END_DATE','MMDDYYYY')  
         AND (scrc.cycle_gid = $CYCLE_GID
              OR scrc.cycle_gid IS NULL)     
         AND scr.claim_gid = scrc.claim_gid(+)
         AND scrc.claim_gid is NULL) mri,
  (SELECT * FROM
         dwcorp.v_algn_lvl_info_ext@dwcorp_reb
   WHERE algn_grp_eff_dt >= ADD_MONTHS(to_date('$CYCLE_START_DATE', 'mmddyyyy'), - 3)
         OR algn_grp_end_dt BETWEEN ADD_MONTHS(TO_DATE('$CYCLE_START_DATE','mmddyyyy'), - 3)
                            AND TO_DATE('$CYCLE_END_DATE','mmddyyyy'))vali,                           
  (SELECT carr_id, grp_id, carr_nm 
   FROM  dwcorp.v_algn_lvl_info@dwcorp_reb
   WHERE algn_grp_eff_dt >= ADD_MONTHS(to_date('$CYCLE_START_DATE', 'mmddyyyy'), - 3)
         OR algn_grp_end_dt BETWEEN ADD_MONTHS(TO_DATE('$CYCLE_START_DATE','mmddyyyy'), - 3)
                            AND TO_DATE('$CYCLE_END_DATE','mmddyyyy'))nm
WHERE mri.extnl_lvl_id1 = vali.carr_id
   AND mri.extnl_lvl_id3 = vali.grp_id
   AND vali.carr_id = nm.carr_id
   AND vali.grp_id = nm.grp_id
ORDER BY vali.carr_id
         ,vali.grp_id;      

quit; 
 
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE            >> $OUTPUT_PATH/$LOG_FILE

   export RETCODE=$?

   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "SQLPlus complete for " $CYCLE_GID                                     >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE



#-------------------------------------------------------------------------#
# Check Return code status for SQL execution                 
#-------------------------------------------------------------------------#
   if [[ $RETCODE != 0 ]]; then
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      print "****  SQL  failed  ****  " $CYCLE_GID                                        >> $OUTPUT_PATH/$LOG_FILE
      print "Error Message will be created"                                     >> $OUTPUT_PATH/$LOG_FILE
      print `date`                                                              >> $OUTPUT_PATH/$LOG_FILE
      print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
      break $RETCODE
   else
      print 'Creating FTP command for PUT ' $OUTPUT_PATH/$FILE_OUT ' to ' $FTP_NT_IP >> $OUTPUT_PATH/$LOG_FILE
      print 'cd /'$REBATES_DIR                                                     >> $OUTPUT_PATH/$FTP_CMDS
      print 'put ' $OUTPUT_PATH/$FILE_OUT $FILE_OUT ' (replace'                    >> $OUTPUT_PATH/$FTP_CMDS
   fi
    
done < $OUTPUT_PATH/$CTRL_FILE

#-------------------------------------------------------------------------#
# FTP the report to an NT server                  
#-------------------------------------------------------------------------#
if [[ $RETCODE = 0 ]]; then 
    print 'quit'                                                                    >> $OUTPUT_PATH/$FTP_CMDS
    print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
    print "....Executing FTP  ...."                                                 >> $OUTPUT_PATH/$LOG_FILE
    print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
    ftp -i $FTP_NT_IP < $OUTPUT_PATH/$FTP_CMDS                                      >> $OUTPUT_PATH/$LOG_FILE

    export RETCODE=$?

    print ".... FTP complete   ...."                                                >> $OUTPUT_PATH/$LOG_FILE
    print `date`                                                                >> $OUTPUT_PATH/$LOG_FILE

fi

if [[ $RETCODE != 0 ]]; then
   print "                                                                 "    >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================"    >> $OUTPUT_PATH/$LOG_FILE
   print "  An error has occurred.  For FTP errors see " $OUTPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   print "  All other errors Look in " $OUTPUT_PATH/$LOG_FILE                   >> $OUTPUT_PATH/$LOG_FILE
   print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
      
   # Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$OUTPUT_PATH/$SCRIPTNAME
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

#-------------------------------------------------------------------------#
# Copy the log file over and end the job                  
#-------------------------------------------------------------------------#

print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ...."               >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

