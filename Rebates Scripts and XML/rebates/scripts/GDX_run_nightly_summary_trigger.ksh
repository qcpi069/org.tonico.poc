#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_run_nightly_summary_Trigger.ksh
# Title         :
#
# Description   : This job when run will create a trigger file for the
#                 PRDETL1 schedule RDDY1500 job RD_1500J.
#
# Maestro Job   : RDDY1200 RD_1298J
#
# Parameters    : None
#
# Output        : Log file as $LOG_DIR/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-08-13   qcpi733     Initial Creation for ITPR0001971
# 08-05-13   qcpi2d6     Changed REGION to get the different streams
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RCI_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=$SCRIPTNAME" Abended In "$REGION" "`date`

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR
        print " "
        print " !!! Aborting !!!"
        print " "
        print "return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`
   }    >> $LOG_FILE

   mailx -s "$EMAIL_SUBJECT" $TO_MAIL                                          < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE

}

# Region specific variables
if [[ $REGION = "PROD" ]];   then
    export ALTER_EMAIL_TO_ADD=""
    EMAIL_TO_ADD="gdxitd@caremark.com"
fi
if [ $REGION = "SIT1"  -o $REGION = "SIT2" ];   then
    export ALTER_EMAIL_TO_ADD="gdxsittest@caremark.com"
    EMAIL_TO_ADD="gdxsittest@caremark.com"
fi
if [ $REGION = "DEV1"  -o $REGION = "DEV2" ];   then
    export ALTER_EMAIL_TO_ADD="randy.redus@caremark.com"
    EMAIL_TO_ADD="randy.redus@caremark.com"
fi

# Variables and temp files
RETCODE=0
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"

TRIGGER_FILE=$INPUT_DIR/"Trigger_Snapshots.trg"

# LOG FILES
LOG_FILE_ARCH="${ARCH_LOG_DIR}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_DIR}/${FILE_BASE}.log"

rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print " "
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   }                                                                           > $LOG_FILE

#-------------------------------------------------------------------------#
# Build the trigger
#-------------------------------------------------------------------------#

print "This file is being built to trigger the GDX nightly summary process"    >> $TRIGGER_FILE
print " "                                                                      >> $TRIGGER_FILE
print "This file was built in $SCRIPTNAME and will be removed by the "         >> $TRIGGER_FILE
print "first job in the GDX nightly summary batch process"                     >> $TRIGGER_FILE

print " "                                                                      >> $LOG_FILE
print "Trigger file built "                                                    >> $LOG_FILE
print "$TRIGGER_FILE"                                                          >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
{
    print "********************************************"
    print "Finishing the script $SCRIPTNAME ......"
    print `date +"%D %r %Z"`
    print "Final return code is : <" $RETCODE ">"
    print " "
}                                                                              >> $LOG_FILE

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

mv -f $LOG_FILE $LOG_FILE_ARCH

exit $RETCODE
