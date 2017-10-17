#!/bin/ksh
#==============================================================================
#
# File Name    = rbate_gather_alv_claims.ksh
# Description  = Execute the pk_gather_claims.get_rbate_alv_claims PL/SQL package
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
# test for pvcs
db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#  Delete the previous runs output log.
rm $OUTPUT_PATH/rbate_gather_alv_claims.log

cd $INPUT_PATH
rm rbate_gather_alv_claims.sql

cat > rbate_gather_alv_claims.sql << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL ../output/rbate_gather_alv_claims.log
SET TIMING ON
--set serveroutput on
alter session enable parallel dml; 
 
EXEC dma_rbate2.pk_gather_claims.prc_get_rbate_alvclaims 
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_gather_alv_claims.sql

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_gather_alv_claims.sql                        "
   echo "  Look in "$OUTPUT_PATH/rbate_gather_alv_claims.log
   echo "================================================================="
   
# Send the Email notification 
   export JOBNAME="KCWK1000 / KC_1000J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_gather_alv_claims.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_gather_alv_claims.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_gather_alv_claims.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_gather_alv_claims.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_gather_alv_claims.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_gather_alv_claims.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_gather_alv_claims.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_gather_alv_claims.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_gather_alv_claims.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   exit $RC
else
   cp $OUTPUT_PATH/rbate_gather_alv_claims.log    $LOG_ARCH_PATH/rbate_gather_alv_claims.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_gather_alv_claims.ksh .....



