#!/bin/ksh
#==============================================================================
#
# File Name    = rbate_find_elig_inactive_cycles.ksh
# Description  = Execute the pk_cycle_util.prc_find_elig_inactive_cycles PL/SQL package
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION 
#
#==============================================================================
#
#  05/01/03  is31701                 initial script creation
#==============================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#  Delete the previous runs output log.
rm $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log

cd $INPUT_PATH
rm rbate_find_elig_inactive_cycles.sql

cat > rbate_find_elig_inactive_cycles.sql << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL ../output/rbate_find_elig_inactive_cycles.log
SET TIMING ON
--set serveroutput on
alter session enable parallel dml; 
 
EXEC dma_rbate2.pk_cycle_util.prc_find_elig_inactive_cycles 
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_find_elig_inactive_cycles.sql

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_find_elig_inactive_cycles.sql                        "
   echo "  Look in "$OUTPUT_PATH/rbate_find_elig_inactive_cycles.log
   echo "================================================================="
   
# Send the Email notification 
   export JOBNAME="KCMN5000 / KC_5000J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_find_elig_inactive_cycles.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_find_elig_inactive_cycles.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   exit $RC
else
   cp $OUTPUT_PATH/rbate_find_elig_inactive_cycles.log    $LOG_ARCH_PATH/rbate_find_elig_inactive_cycles.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_find_elig_inactive_cycles.ksh .....



