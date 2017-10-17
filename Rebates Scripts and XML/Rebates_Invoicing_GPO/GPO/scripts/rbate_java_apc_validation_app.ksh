#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_java_apc_validation_app.ksh   
# Description   : This script executes the java driver for the apc_validation 
#                 process.  
# 
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 
# 01-03-2003  NTucker    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

rm -f $OUTPUT_PATH/rbate_java_apc_validation_app.log

print ' ' >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
print 'Executing java class now' >> $OUTPUT_PATH/rbate_java_apc_validation_app.log

java -classpath .:/staging/apps/rebates/prod/rebateengine/libs/classes12.zip:/staging/apps/rebates/prod/rebateengine/libs/j2ee.jar:/staging/apps/rebates/prod/rebateengine/libs/xerces.jar:/staging/apps/rebates/prod/rebateengine/libs/log4j-1.2.6.jar:/staging/apps/rebates/prod/lib/apc_validation.jar  com.advpcs.rebates.apc.APCValidator /staging/apps/rebates/prod/scripts/apc_UNIX.props

export RETCODE=$?

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   print "================= J O B  A B E N D E D ================" >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   print "  Error Executing rbate_java_ncpdp_app.ksh          " >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   print "  Look in "$OUTPUT_PATH/rbate_java_ncpdp_app.log      >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   print "=======================================================" >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
            
# Send the Email notification 
   export JOBNAME="RIHR2010 / RI_2010J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_java_apc_app.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_java_apc_validation_app.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_java_ncpdp_app.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_java_apc_validation_app.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/rbate_java_apc_validation_app.log $LOG_ARCH_PATH/rbate_java_apc_validation_app.log.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print '....Completed executing rbate_java_apc_validation_app.ksh ....'   >> $OUTPUT_PATH/rbate_java_apc_validation_app.log
mv -f $OUTPUT_PATH/rbate_java_apc_validation_app.log $LOG_ARCH_PATH/rbate_java_apc_validation_app.log.`date +"%Y%j%H%M"`


exit $RETCODE

