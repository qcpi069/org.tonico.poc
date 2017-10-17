#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_claims_load_daily.ksh
# Description  = Execute the pk_gather_claims.load_daily_claims PL/SQL package
# Author       = Nick Tucker
# Date Written = June 06, 2002
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
rm load_daily_claims.log

cd $INPUT_PATH
rm load_daily_claims.sql

cat > load_daily_claims.sql << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL ../output/load_daily_claims.log
SET TIMING ON
EXEC dma_rbate2.pk_gather_claims.load_daily_claims
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/load_daily_claims.sql

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing load_daily_claims.sql                          "
   echo "  Look in "$OUTPUT_PATH/load_daily_claims.log
   echo "================================================================="
   exit $RC
else
   cd $OUTPUT_PATH
   cp $OUTPUT_PATH/load_daily_claims.log  $LOG_ARCH_PATH/load_daily_claims.log.`date +"%Y%j%H%M"`
fi

   
echo .... Completed executing load_daily_claims.ksh .....



