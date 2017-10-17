#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_load_rbate_ids.ksh
# Description  = Execute SQLload to populate lcm's into T_RBATE_ID            
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
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
rm $OUTPUT_PATH/rbate_id.log

$ORACLE_HOME/bin/sqlldr $db_user_password $INPUT_PATH/rbate_id.ctl

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_load_rbate_ids.ksh                        "
   echo "  Look in "$OUTPUT_PATH/rbate_id.log
   echo "================================================================="
   exit $RC
else
#  Delete the trigger file for rebate ids.  The next run is dependant on the trigger file, as well as 
#    a time dependancy.
   rm $INPUT_PATH/rptid2cg.trigger
#  Copy the output log to the archive directory, with a timestamp.
   cp $OUTPUT_PATH/rbate_id.log     $LOG_ARCH_PATH/rbate_id.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_load_rbate_ids.ksh  .....



