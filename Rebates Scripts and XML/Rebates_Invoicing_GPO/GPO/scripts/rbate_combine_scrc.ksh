#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_combine_scrc.ksh   
# Title         : Executes the procedure that combines the seperate SCRC tables
                  into THE s_claim_rbate_cycle table.
#
# Description   : Closes the cycle.
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 
# 05-02-2003  IS31701    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables  
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

rm -f $OUTPUT_PATH/rbate_combine_scrc.log

export EDW_USER="/"

#-------------------------------------------------------------------------#
# Check for proper parameters passed; if none, exit
# Additional check for $1 performed after $OBJTYPE defined below
#-------------------------------------------------------------------------#

if [ $# -lt 1 ] 
then
    print ' ' >> $OUTPUT_PATH/rbate_combine_scrc.log
    print 'Insufficient arguments passed to script.' >> $OUTPUT_PATH/rbate_combine_scrc.log
    print ' ' >> $OUTPUT_PATH/rbate_combine_scrc.log
    exit 1
fi

#-------------------------------------------------------------------------#
## Set vars from input parameters
#-------------------------------------------------------------------------#

export CYCLE_GID=`print $1`

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

PKGEXEC='dma_rbate2.pk_cycle_util.prc_combine_scrc'\(\'$CYCLE_GID\'\);
print ' ' >> $OUTPUT_PATH/rbate_combine_scrc.log
print 'Exec stmt is $PKGEXEC' >> $OUTPUT_PATH/rbate_combine_scrc.log

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

rm -f $INPUT_PATH/rbate_combine_scrc.sql

cat > $INPUT_PATH/rbate_combine_scrc.sql << EOF
set serveroutput on size 1000000
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/rbate_combine_scrc.log
SET TIMING ON
exec $PKGEXEC;
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_combine_scrc.sql

export RETCODE=$?

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "  Error Executing rbate_combine_scrc.ksh          " >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "  Look in "$OUTPUT_PATH/rbate_combine_scrc.log       >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "=================================================================" >> $OUTPUT_PATH/rbate_combine_scrc.log
            
# Send the Email notification 
   export JOBNAME="KCOR2200 / KC_2200J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_combine_scrc.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_combine_scrc.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_combine_scrc.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_combine_scrc.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_combine_scrc.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/rbate_combine_scrc.log $LOG_ARCH_PATH/rbate_combine_scrc.log.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print '....Completed executing rbate_combine_scrc.ksh ....'   >> $OUTPUT_PATH/rbate_combine_scrc.log
mv -f $OUTPUT_PATH/rbate_combine_scrc.log $LOG_ARCH_PATH/rbate_combine_scrc.log.`date +"%Y%j%H%M"`


exit $RETCODE

