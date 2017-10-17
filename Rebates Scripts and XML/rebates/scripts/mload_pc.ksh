#!/bin/sh
#set -x
#-----------------------------------------------------------------------------------------------------------------------#
#
# Script        : mload_pc 
#
# Description   : Teradata mloader executable, cloned from EDW2 team	
#
# Command Line Flags:   Automatically passed in by Informatica
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date      User           Description
# ---------  ----------  -------------------------------------------------
# 01/28/16    qcpi733    Initial creation for ITPR012532 Coventry Files 
#
#-------------------------------------------------------------------------------------------------------------------------#

#-------------------------------------------------------------------------------------------------------------------------#
#                              Caremark Rebates Environment variables
#-------------------------------------------------------------------------------------------------------------------------#

  . `dirname $0`/Common_RCI_Environment.ksh

#-------------------------------------------------------------------------------------------------------------------------#

#-------------------------------------------------------------------------------------------------------------------------#
#                                       Function to exit the script
#-------------------------------------------------------------------------------------------------------------------------#
function exit_Script {

    RETCODE=$1
    ERROR=$2

    if [[ $RETCODE != 0 ]];then
                {
                print " "
                print $ERROR
                print " "
                print " !!! Aborting!!!"
                print " "
                print "return_code = " $RETCODE
                print " "
                print " ------ Ending script $SCRIPTNAME `date` ------"
                }                                                              >> $LOG_FILE
    else
                {
                print " "
                print ".... $SCRIPTNAME  completed with return code $RETCODE ...."
                print " "
                print " ------ Ending script $SCRIPTNAME `date` ------"
                print " "
                }                                                              >> $LOG_FILE
     fi

    return $RETCODE
}


export TD_HOME=/opt/teradata/client/14.10
export LIBPATH=$TD_HOME/tdicu/lib:/usr/teragss/aix-power/client/lib
export TD_ICU_DATA=$TD_HOME/tdicu/lib

# the log generated below needs to have a unique name to it.  Since this
#   script can be executed by numerous other scripts, we determined to generate
#   a random number, 3 times, would build us a unique filename for this
#   temporary file.
RanNum1=$RANDOM
RanNum2=$RANDOM
RanNum3=$RANDOM
RanFileNm="$RanNum1$RanNum2$RanNum3"

LOG="mload_pc_$RanFileNm"
LOG_FILE="$LOG_DIR/$LOG.log"
ARCH_LOGFILE="$ARCH_LOG_DIR/$LOG`date +"%Y%j%H%M%S"`.log"

echo "$@"  > $LOG_FILE
line=`echo "$@" | cut -f2- -d \/ | cut -f1 -d \' `
exec /usr/bin/mload < \/${line} >> $LOG_FILE

rm -f $LOG_FILE
RETCODE=$?

 if [[ $RETCODE != 0 ]]; then
    print "aborting script - Error executing Teradata mloader "
    exit_script $RETCODE "Error executing Teradata mloader"
 fi

exit_Script 0
