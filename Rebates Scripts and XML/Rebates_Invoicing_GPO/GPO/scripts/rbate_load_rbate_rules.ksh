#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_load_rbate_rules.ksh
# Description  = Execute SQLload to populate lcm's into T_RBATE_ID_RULE            
# Author       = Nick Tucker
# Date Written = June 17, 2002
#
#=====================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

cd $OUTPUT_PATH
rm rbate_rule.log

$ORACLE_HOME/bin/sqlldr $db_user_password $INPUT_PATH/rbate_rule.ctl

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_load_rbate_rules.ksh                        "
   echo "  Look in "$OUTPUT_PATH/rbate_rule.log
   echo "================================================================="
   exit $RC
else
   cd $OUTPUT_PATH
   cp $OUTPUT_PATH/rbate_rule.log     $LOG_ARCH_PATH/rbate_rule.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_load_rbate_ids.ksh  .....



