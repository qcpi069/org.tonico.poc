#!/bin/ksh
#==============================================================================
#
# File Name    = rbate_refresh_cycle.ksh
# Description  = Execute the pk_cycle_util.do_refresh PL/SQL package
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION 
#
#==============================================================================
# 04-21-03   is31701                 Change script to execute the new 
#                                      pk_refresh_driver.prc_active_cycle_driver. 
# 10-01-02    K. Gries               added rbate_email_base.ksh call.
#
#  06/28/02  is45401                 added comments; added copy of log to 
#                                    log archive path, with timestamp;
#  06/13/02  is31701                 initial script creation
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
rm $OUTPUT_PATH/rbate_refresh_cycle.log

cd $INPUT_PATH
rm rbate_refresh_cycle.sql

# for dv02, Jack Silvey says use only 5 megs, not 50.

# when using hash_area_size, each parallel query 
#  will use the hast_area_size to calculate the amount
# of memory it can use, so, at 5mb, parallel 12 will use
# a total of 60 megs.

#next line has the way it USED to be in this script:
#alter session set hash_area_size = 50331648


cat > rbate_refresh_cycle.sql << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL ../output/rbate_refresh_cycle.log
SET TIMING ON
--set serveroutput on
alter session enable parallel dml; 
 
EXEC dma_rbate2.pk_refresh_restart_driver.prc_active_cycle_driver 
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_refresh_cycle.sql

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_refresh_cycle.sql                        "
   echo "  Look in "$OUTPUT_PATH/rbate_refresh_cycle.log
   echo "================================================================="
   
# Send the Email notification 
   export JOBNAME="KCOR2000 / KC_2000J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_refresh_cycle.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_refresh_cycle.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_refresh_cycle.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_refresh_cycle.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_refresh_cycle.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_refresh_cycle.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_refresh_cycle.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_refresh_cycle.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_refresh_cycle.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   exit $RC
else
   cp $OUTPUT_PATH/rbate_refresh_cycle.log    $LOG_ARCH_PATH/rbate_refresh_cycle.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_refresh_cycle.ksh .....



