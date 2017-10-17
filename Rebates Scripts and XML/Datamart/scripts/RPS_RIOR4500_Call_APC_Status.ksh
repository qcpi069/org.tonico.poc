#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_RIOR4500_Call_APC_Status.ksh 
# Title         : Used to update the APC status of an event when the event
#                   job is out of our control (ie, DBA jobs).
# Description   : This script calls the RPS_GDX_APC_Status_update.ksh
#                   which then will update the specified APC event (job)
#                   start or end timestamp, and the process status text.
#
#                 The first attempt to call teh RPS_GDX_APC_Status_update.ksh
#                   script was done through Maestro with no calling parent
#                   script.  The testing worked in DEV/SIT, but not when
#                   executed in production.  Since we cannot test in prod,
#                   this parent script is being built to do the call.
#
# 
# Abends        : 
#                                 
# Output        : Log file as $LOGFILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-13-10   qcpi733     Initial development
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

function exit_error {
    RETCODE=$1

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print 'Sending email notification with the following parameters'

        print "SCRIPTNAME is $SCRIPT"
        print "LOGFILE is $LOGFILE"

        print "****** end of email parameters ******"
    } >> $LOGFILE

    EMAIL_SUBJECT=$SCRIPT" abending in RPS "$REGION
    mailx -s "$EMAIL_SUBJECT" $SUPPORT_EMAIL_ADDRESS                           < $LOGFILE
  
    print ".... $SCRIPT  abended ...."                                         >> $LOGFILE

    cp $LOGFILE       $ARCH_LOGFILE"."`date +"%Y%j%H%M"` 

    exit $RETCODE
}

cd $SCRIPT_PATH

SCRIPT=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_BASE=$FILE_BASE".log"
LOG=$LOG_BASE
LOGFILE="$LOG_PATH/$LOG"
ARCH_LOGFILE=$LOG_ARCH_PATH/$LOG
RETCODE=0

if [[ $REGION = "prod" ]]; then
    if [[ $QA_REGION = "true" ]]; then
        SUPPORT_EMAIL_ADDRESS="randy.redus@caremark.com"
    else
        SUPPORT_EMAIL_ADDRESS="gdxitd@caremark.com"
    fi
else
    SUPPORT_EMAIL_ADDRESS="randy.redus@caremark.com"
fi

rm -f $LOGFILE

PRCS_ID=$1
# convert all input for PRCS_STAT to upper case
PRCS_STAT=$(echo $2|dd conv=ucase 2>/dev/null)

if [[ $# -lt 2 ]]; then
    #print to console - maestro job log
    print "Usage Error:"                                                      
    print "Usage: $0 <PRCS_ID value> <STRT | END | ERR>"
    print "Current Usage:"
    print "    PRCS_ID = >$PRCS_ID<"
    print "    PRCS_STAT = >$PRCS_STAT<"
    #print to log file
    print "Usage Error:"                                                       >> $LOGFILE
    print "Usage: $0 <PRCS_ID value> <STRT | END | ERR>"                       >> $LOGFILE
    print "Current Usage:"                                                     >> $LOGFILE
    print "    PRCS_ID = >$PRCS_ID<"                                           >> $LOGFILE
    print "    PRCS_STAT = >$PRCS_STAT<"                                       >> $LOGFILE
    exit_error 1
else

    #print to console - maestro job log
    print "Input parms:" 
    print "    PRCS_ID = >$PRCS_ID<"
    print "    PRCS_STAT = >$PRCS_STAT<"
    print " "

    case $PRCS_ID in 
        *[!0-9]*) 
            print "Improper use of paramters."
            print "First parameter needs to be the PRCS_ID, which is numeric"
            print "Improper use of paramters."                                 >> $LOGFILE
            print "First parameter needs to be the PRCS_ID, which is numeric"  >> $LOGFILE
            RETCODE=5
            ;; 
    esac
    case $PRCS_STAT in    
        "STRT"|"END"|"ERR")
            print " "
            ;;
        *)
            print "PRCS_STAT passsed in was invalid value...."
            print "Valid Values are only STRT, END, or ERR."
            print "PRCS_STAT passsed in was valid value...."                   >> $LOGFILE
            print "Valid Values are only STRT, END, or ERR."                   >> $LOGFILE
            RETCODE=5
            ;; 
    esac
    if [[ RETCODE -ne 0 ]]; then
        exit_error 1
    fi

    #Input values are good - rebuild the log file name
    LOG_BASE=$FILE_BASE"_PRCS_ID_"$PRCS_ID"_"$PRCS_STAT".log"
    LOG=$LOG_BASE
    LOGFILE="$LOG_PATH/$LOG"
    ARCH_LOGFILE=$LOG_ARCH_PATH/$LOG

    print " Starting script " $SCRIPT `date`                              
    print " Starting script " $SCRIPT `date`                                   >> $LOGFILE

    #print to log file
    print "Input parms:"                                                       >> $LOGFILE
    print "    PRCS_ID = >$PRCS_ID<"                                           >> $LOGFILE
    print "    PRCS_STAT = >$PRCS_STAT<"                                       >> $LOGFILE
    print " "                                                                  >> $LOGFILE
  
fi

print " "
print " "                                                                      >> $LOGFILE


################################################################
# connect to udb
################################################################

if [[ $RETCODE == 0 ]]; then 
    $UDB_CONNECT_STRING                                                        >> $LOGFILE 
    export RETCODE=$?
    if [[ $RETCODE != 0 ]]; then 
        print "!!! terminating script - cant connect to udb " 
       print "!!! terminating script - cant connect to udb "                   >> $LOGFILE  
    fi
fi

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh $PRCS_ID $PRCS_STAT               >> $LOGFILE

RETCODE=$?

#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
    print "aborting $SCRIPT due to errors " 
    print "aborting $SCRIPT due to errors "                                    >> $LOGFILE 

    exit_error $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`                  >> $LOGFILE 

#################################################################
# cleanup from successful run
#################################################################
mv $LOGFILE       $ARCH_LOGFILE"."`date +"%Y%j%H%M"` 

print $SCRIPT " return_code = " $RETCODE

exit $RETCODE
