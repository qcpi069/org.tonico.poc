#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_t_claim_rpt.ksh  
# Title         : Run the feed_id claim report from dwcorp.rbate_t_claim.
#
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 10-08-02    N. Tucker  Initial Creation. 
# 04-24-03    K. Gries   Modified to use control file created within 
#                        rbate_pre_gather_rpt_control_file_init.ksh
#                        instead of input parms. Added loop to read the
#                        control file and create files for all cycles in
#                        status of A. Made file comma delimited.
#                        Made more parameter efficient.
# 05-18-04    N. Tucker  Added a count for Monthly Medicare Claims
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

export CTRL_FILE="rbate_pre_gather_rpt_control_file_init.dat"

export FILE_BASE="rbate_t_claim_rpt"
export SCRIPTNAME="rbate_t_claim_rpt.ksh"
export LOG_FILE="rbate_t_claim_rpt.log"
export SQL_FILE="rbate_t_claim_rpt.sql"
export DAT_FILE="rbate_t_claim_rpt.dat"
export FTP_CMDS="rbate_t_claim_rpt_ftpcommands.txt"

export FTP_NT_IP=AZSHISP00

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$FTP_CMDS

#-------------------------------------------------------------------------#
## Set vars from input parameters
#-------------------------------------------------------------------------#
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
print "Starting " $SCRIPTNAME                                                   >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE

if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
else  
     export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
fi

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#
while read CTRL_CYCLE_GID CTRL_CYCLE_START_DATE CTRL_CYCLE_END_DATE; do

   export CYCLE_GID=$CTRL_CYCLE_GID
   export CYCLE_START_DATE=$CTRL_CYCLE_START_DATE
   export CYCLE_END_DATE=$CTRL_CYCLE_END_DATE

   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "Control file record read from " $OUTPUT_PATH/$CTRL_FILE               >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "Values are:"                                                          >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_GID = " $CYCLE_GID                                              >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_START_DATE = " $CYCLE_START_DATE                                >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_END_DATE = " $CYCLE_END_DATE                                    >> $OUTPUT_PATH/$LOG_FILE

   export DAT_FILE=$FILE_BASE'_'$CYCLE_GID'.dat'
   export FILE_OUT=$DAT_FILE

   rm -f $INPUT_PATH/$SQL_FILE
   rm -f $OUTPUT_PATH/$DAT_FILE

   print "Output file for " $CYCLE_GID " is " $OUTPUT_PATH/$DAT_FILE            >> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_FILE << EOF
SET LINESIZE 200
SET TERMOUT OFF
SET PAGESIZE 0
SET NEWPAGE 0
SET SPACE 0
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET WRAP OFF
set verify off
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/$DAT_FILE
alter session enable parallel dml

SELECT /*+ full(A1) parallel(A1,24) driving_site(A1) */
    distinct  
    feed_id
   ,','
   ,claim_type
   ,','
   ,count(*) 
   ,','
   ,sum(case
        when dspnd_date < (add_months(to_date('$CYCLE_START_DATE','MMDDYYYY'), -3))
          or dspnd_date is NULL
        THEN 1 ELSE 0 END) count_dspnd_dt    
   ,','   
   ,round(((sum(case
        when dspnd_date < (add_months(to_date('$CYCLE_START_DATE','MMDDYYYY'), -3))
        or dspnd_date is NULL
        THEN 1 ELSE 0 END) / count(*) ) * 100),2) || '%' pctg_of_total
   ,','
   ,sum(case
        when mdcr_ind in ('C','T')
        THEN 1 ELSE 0 END) count_medicare_clms   
  FROM DWCORP.T_CLAIM A1
 WHERE batch_date BETWEEN to_date('$CYCLE_START_DATE','MMDDYYYY') and to_date('$CYCLE_END_DATE','MMDDYYYY')
  and (claim_type in (1, -1) or claim_type is NULL)
GROUP BY feed_id, claim_type
ORDER BY feed_id;
quit; 
 
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE            >> $OUTPUT_PATH/$LOG_FILE

   export RETCODE=$?
   print "SQLPlus complete for " $CYCLE_GID                                     >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return from sqlplus.                  
#-------------------------------------------------------------------------#

   if [[ $RETCODE != 0 ]]; then
      print "                                                                 " >> $OUTPUT_PATH/$LOG_FILE
      print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
      print "  Error Executing " $SCRIPT_PATH/$SCRIPTNAME                       >> $OUTPUT_PATH/$LOG_FILE
      print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
      print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
            

      cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
      exit $RETCODE
   fi

#-------------------------------------------------------------------------#
# FTP the report to an NT server                  
#-------------------------------------------------------------------------#
 
   print 'Creating FTP command for PUT ' $OUTPUT_PATH/$FILE_OUT ' to ' $FTP_NT_IP >> $OUTPUT_PATH/$LOG_FILE
   print 'cd /'$REBATES_DIR                                                     >> $OUTPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$FILE_OUT $FILE_OUT ' (replace'                    >> $OUTPUT_PATH/$FTP_CMDS

done < $OUTPUT_PATH/$CTRL_FILE

print 'quit'                                                                    >> $OUTPUT_PATH/$FTP_CMDS
print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Executing FTP  ...."                                                 >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
ftp -i $FTP_NT_IP < $OUTPUT_PATH/$FTP_CMDS                                      >> $OUTPUT_PATH/$LOG_FILE

print ".... FTP complete   ...."                                                >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE


if [[ $RETCODE != 0 ]]; then
   print "                                                                 "    >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================"    >> $OUTPUT_PATH/$LOG_FILE
   print "  Error in FTP of " $OUTPUT_PATH/$FTP_CMDS                            >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in " $OUTPUT_PATH/$LOG_FILE                                    >> $OUTPUT_PATH/$LOG_FILE
   print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
            

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

