#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_claims_trim.ksh
# Description  = Execute the pk_cycle_util.purge_old_scr_claims PL/SQL package
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  05-16-03  is31701                 modified to pass the table name in
#  10-01-02  K. Gries                added rbate_email_base.ksh call.
#
#  09/12/02  is45401                 changed package from which procedure is 
#                                    run, from pk_gather_claims, renamed
#                                    procedure from purge_old_claims. 
#  08-17-02  K. Gries                added dma_rbate2 qualification.
#
#  06/28/02  is45401                 added comments; added copy of log to
#                                    log archive path, with timestamp;
#  06/13/02  is31701                 initial script creation
#==============================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh


if [ $# -lt 1 ] 
then
    print ' ' >> $OUTPUT_PATH/rbate_claims_trim.log
    print 'Insufficient arguments passed to script.' >> $OUTPUT_PATH/rbate_rbate_claims_trim.log
    print ' ' >> $OUTPUT_PATH/rbate_claims_trim.log
    exit 1
fi

export TABLE_NAME=`print $1`

export EDW_USER="/"
#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#  Delete the previous runs output log.
rm $OUTPUT_PATH/rbate_claims_trim.log

#  Delete the previous runs sql file.

rm $INPUT_PATH/rbate_claims_trim.sql

cd $INPUT_PATH

export PACKAGE_NAME=dma_rbate2.pk_cycle_util.purge_old_scr_claims

PKGEXEC=$PACKAGE_NAME\(\'$TABLE_NAME\'\);

print ' ' >> $OUTPUT_PATH/rbate_claims_trim.log
print 'Exec stmt is $PKGEXEC' >> $OUTPUT_PATH/rbate_claims_trim.log

cat > rbate_claims_trim.sql << EOF
WHENEVER SQLERROR EXIT FAILURE
SPOOL ../output/rbate_claims_trim.log
SET TIMING ON
exec $PKGEXEC; 
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_claims_trim.sql

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_claims_trim.sql                        "
   echo "  Look in "$OUTPUT_PATH/rbate_claims_trim.log
   echo "================================================================="
            
# Send the Email notification 
   export JOBNAME="KCBW5000 / KC_5000J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_claims_trim.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_claims_trim.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_claims_trim.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_claims_trim.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_claims_trim.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_claims_trim.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_claims_trim.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_claims_trim.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_claims_trim.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   exit $RC
else
#  Copy the log from the successful execution to the log archive directory with a timestamp.
   cp $OUTPUT_PATH/rbate_claims_trim.log  $LOG_ARCH_PATH/rbate_claims_trim.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_claims_trim.ksh .....



