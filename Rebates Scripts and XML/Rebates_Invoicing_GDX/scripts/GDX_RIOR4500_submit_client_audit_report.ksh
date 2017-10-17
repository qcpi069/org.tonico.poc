#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_RIOR4500_submit_client_audit_report.ksh   
# Title         : Submits a request to Actuate Server to run Client Audit Report.
#
# Description   : Submits a request to Actuate Server to run Client Audit Report. 
#                 It takes two parameters. 
#                 First one a model type(GPO, DSC, XMD) which is required.
#                 Second is an optional Quarter(YYYY0Q).
#                 If Quarter is not passed previous calendar Quarter will be used.

# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; non-zero = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 10-08-06   is860       Initial Creation
# 
#-------------------------------------------------------------------------#


#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4='  '
    EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi
    
    {
        print 'Sending email notification with the following parameters'
    
        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"
    
        print '****** end of email parameters ******'
    } >> $LOG_FILE
    
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}
#-------------------------------------------------------------------------#


#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="shyam.antari@caremark.com"
fi

#Capture input here for use in FILE_BASE variable.
#  turn the Model Type input into uppercase
MODEL=$(echo $1|dd conv=ucase 2>/dev/null)

RETCODE=0
SCHEDULE="RIOR4500"
JOB=""
FILE_BASE="GDX_"$SCHEDULE"_submit_client_audit_report_"$MODEL""
SCRIPTNAME=$(basename "$0")

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script 
#-------------------------------------------------------------------------#
print `date`                                                                   >> $LOG_FILE
print "Starting the script to Submit Client Audit Report."                     >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
 
#-------------------------------------------------------------------------#
# First capture the input parameters.
#-------------------------------------------------------------------------#
 
if [[ $# -lt 1 ]]; then 
    print "Missing required MODEL parameter"                                   >> $LOG_FILE
    print "MODEL  = >$MODEL<"                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Script will abend."                                                 >> $LOG_FILE
    exit_error 1    
fi

print "MODEL  = >$MODEL<"                                                      >> $LOG_FILE
    


#-------------------------------------------------------------------------#
# Call the Java SubmitClientAuditReport
#-------------------------------------------------------------------------#

JAVACMD=$JAVA_HOME/bin/java
print "----------------------------------------------------------------"    >>$LOG_FILE
print "$($JAVACMD -version 2>&1)"                                           >>$LOG_FILE
print "----------------------------------------------------------------"    >>$LOG_FILE
    
print "$JAVACMD" "-Dlog4j.configuration=log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.actuate.SubmitClientAuditReport $MODEL $2 >> $LOG_FILE

"$JAVACMD" "-Dlog4j.configuration=log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.actuate.SubmitClientAuditReport $MODEL $2 > ${LOG_FILE}_temp
export RETCODE=$?

cat ${LOG_FILE}_temp >> $LOG_FILE
rm ${LOG_FILE}_temp
print "RETCODE=$RETCODE "                                                   >> $LOG_FILE
if [[ $RETCODE != 0 ]] ; then
    exit_error $RETCODE
fi


# Move $LOGFILE to the archive directory if return code = 0
mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
  
exit $RETCODE
