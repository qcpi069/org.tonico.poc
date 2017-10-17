#!/bin/ksh
#==============================================================================
#
# File Name    = rbate_load_matchedscrc.ksh
# Description  = Execute the pk_gather_claims.prc_load_matchedscrc PL/SQL package
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
rm $OUTPUT_PATH/rbate_load_matchedscrc.log

cd $INPUT_PATH
rm rbate_load_matchedscrc.sql

cat > rbate_load_matchedscrc.sql << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL ../output/rbate_load_matchedscrc.log
SET TIMING ON
--set serveroutput on
alter session enable parallel dml; 
 
EXEC dma_rbate2.pk_gather_claims.prc_load_matchedscrc 
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_load_matchedscrc.sql

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_load_matchedscrc.sql                        "
   echo "  Look in "$OUTPUT_PATH/rbate_load_matchedscrc.log
   echo "================================================================="
   
# Send the Email notification 
   export JOBNAME="KCWK1028 / KC_1028J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_load_matchedscrc.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_load_matchedscrc.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_load_matchedscrc.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_load_matchedscrc.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_load_matchedscrc.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_load_matchedscrc.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_load_matchedscrc.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_load_matchedscrc.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_load_matchedscrc.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   exit $RC
else
   cp $OUTPUT_PATH/rbate_load_matchedscrc.log    $LOG_ARCH_PATH/rbate_load_matchedscrc.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_load_matchedscrc.ksh .....



