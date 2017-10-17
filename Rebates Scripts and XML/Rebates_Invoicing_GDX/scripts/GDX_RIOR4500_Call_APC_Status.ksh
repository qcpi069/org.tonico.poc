#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_RIOR4500_Call_APC_Status.ksh
# Title         : Calls the Common_GDX_APC_Status_update.ksh 
#
# Description   : Calls the Common_GDX_APC_Status_update.ksh, passing 
#                 through input parms, to update the start or end timestamp
#                 for a VRAP.TAPC_QTR_PRCS_EVENT row, along with setting
#                 the process status for the job.
#
# Abends        :
#
# Maestro Job   : Multiple 
#
# Parameters    : Must have two input parms to successfully run.
#               : First parm is a PRCS_ID value from the EVENT table. 
#               : Second parm is either STRT | END, which tells the APC 
#                     status script what to set the PRCS_STAT_TXT to.
# 
# Output        : Log file as $LOG_FILE, 
#
# Input Files   : 
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-06-10   qcpi733     Initial script
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4=$PRCS_ID
    EMAILPARM5=$PRCS_STAT

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print 'Sending email notification with the following parameters'

        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is PRCS_ID value passed in - >$EMAILPARM4<"
        print "EMAILPARM5 is PRCS_STAT_TXT command passed in - >$EMAILPARM5<"

        print "****** end of email parameters ******"
    } >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`

    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

#-------------------------------------------------------------------------#
# Region specific variables
#-------------------------------------------------------------------------#

if [[ $REGION = "prod" ]]; then
    if [[ $QA_REGION = "true" ]]; then
        ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    else
        ALTER_EMAIL_ADDRESS="gdxitd@caremark.com"
    fi
else
    ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
fi

#-------------------------------------------------------------------------#
# Check passing parameter
#-------------------------------------------------------------------------#

#Variables needed in case of failure in this section
RETCODE=0
SCRIPTNAME=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}_input_error.log"
LOG_FILE="${LOG_PATH}/${FILE_BASE}_input_error.log"

rm -f $LOG_FILE

print " "
print " "                                                                      >> $LOG_FILE

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
    print "Usage Error:"                                                       >> $LOG_FILE
    print "Usage: $0 <PRCS_ID value> <STRT | END | ERR>"                       >> $LOG_FILE
    print "Current Usage:"                                                     >> $LOG_FILE
    print "    PRCS_ID = >$PRCS_ID<"                                           >> $LOG_FILE
    print "    PRCS_STAT = >$PRCS_STAT<"                                       >> $LOG_FILE
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
            print "Improper use of paramters."                                 >> $LOG_FILE
            print "First parameter needs to be the PRCS_ID, which is numeric"  >> $LOG_FILE
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
            print "PRCS_STAT passsed in was valid value...."                   >> $LOG_FILE
            print "Valid Values are only STRT, END, or ERR."                   >> $LOG_FILE
            RETCODE=5
            ;; 
    esac
    if [[ RETCODE -ne 0 ]]; then
        exit_error 1
    fi

fi

print " "
print " "                                                                      >> $LOG_FILE

#------------------------------------------------------------------------#
# Variables
#-------------------------------------------------------------------------#

# get rid of the log file built during the testing of input parms
rm -f $LOG_FILE

# rebuild log filename by adding parm information
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}_PRCS_ID_"$PRCS_ID"_"$PRCS_STAT".log"
LOG_FILE="${LOG_PATH}/${FILE_BASE}_PRCS_ID_"$PRCS_ID"_"$PRCS_STAT".log"

rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
print " "
print " "                                                                      >> $LOG_FILE

#print to log file
print "Input parms:"                                                           >> $LOG_FILE
print "    PRCS_ID = >$PRCS_ID<"                                               >> $LOG_FILE
print "    PRCS_STAT = >$PRCS_STAT<"                                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

print "Connecting to GDX $DATABASE......"                                      >> $LOG_FILE
db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"              >> $LOG_FILE
RETCODE=$?
print "Connect to $DATABASE: RETCODE=<" $RETCODE ">"                           >> $LOG_FILE
print " "
print " "                                                                      >> $LOG_FILE

if [[ $RETCODE -ne 0 ]]; then
    print "ERROR: couldn't connect to database......"
    print "ERROR: couldn't connect to database......"                          >> $LOG_FILE
    exit_error $RETCODE
else
    print "Connection to $DATABASE successful....."
    print "Connection to $DATABASE successful....."                            >> $LOG_FILE
fi

print " "
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Perform the call to APC status script
#-------------------------------------------------------------------------#

print "Calling the APC status script: "                                        >> $LOG_FILE
print "`dirname $0`/Common_GDX_APC_Status_update.ksh $PRCS_ID $PRCS_STAT"      >> $LOG_FILE

. `dirname $0`/Common_GDX_APC_Status_update.ksh $PRCS_ID $PRCS_STAT            >> $LOG_FILE

print " "
print " "                                                                      >> $LOG_FILE

if [[ $RETCODE -ne 0 ]]; then
    print "ERROR: Problem in the APC Status script......"
    print "ERROR: Problem in the APC Status script......"                      >> $LOG_FILE
    exit_error $RETCODE
else
    print "Call to APC status script successful....."
    print "Call to APC status script successful....."                          >> $LOG_FILE
fi

print " "
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Script completed
#-------------------------------------------------------------------------#

    print " "
    print " "
    print "....Completed executing $SCRIPTNAME ...."
    date +"%D %r %Z"

{
    print
    print
    print "....Completed executing $SCRIPTNAME ...."
    date +"%D %r %Z"

} >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`

exit $RETCODE

