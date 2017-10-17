#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_claims_load_initial.ksh	
# Description  = Execute the pk_gather_claims.load_initial_claims PL/SQL package
# Author       = Nick Tucker
# Date Written = June 10, 2002
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
rm load_initial_claims.log

cd $INPUT_PATH
rm load_initial_claims.sql

#cat > load_initial_claims.sql << EOF
#WHENEVER SQLERROR EXIT FAILURE
#SPOOL ../output/load_initial_claims.log
#SET TIMING ON
#EXEC pk_gather_claims.load_initial_claims
#EXIT
#EOF


cat > load_initial_claims.sql << EOF
EXEC dma_rbate2.pk_gather_claims.load_initial_claims;
EXIT
EOF
$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/load_initial_claims.sql

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing load_initial_claims.sql                          "
   echo "  Look in "$OUTPUT_PATH/load_initial_claims.log
   echo "================================================================="
   exit $RC
else
   cd $OUTPUT_PATH
   cp $OUTPUT_PATH/load_initial_claims.log  $LOG_ARCH_PATH/load_initial_claims.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing load_initial_claims.ksh .....



