#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_GD_2101J_rfraresponse_hdr_load.ksh    
# Title         : FTP and load the rfraresponse header file into the
#		    vrap.trfra_rsp_hdr table
#                 
#
# Description   : This script loads a fixed length ASCII file from 
#                 the rfra process which runs on DMADOM4.  
#                 The file will be loaded into the GDX table: 
#                         VRAP.TRFRA_RSP_HDR 
#                 
#                 The load is a full replace of the table.
#
#
# Parameters    : N/A 
# 
# Output        : Log file as $LOG_FILE
#
# Input Files   : GDX/prod/input
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-30-07   is31701     Initial Creation
# 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#
#. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4='MAILPAGER'
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

    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH
    exit $RETCODE
}
#-------------------------------------------------------------------------#
# Function to ftp the file 
#-------------------------------------------------------------------------#
function run_ftp {
    typeset _FTP_COMMANDS=$(cat) # pulls stdin into a variable
    typeset _FTP_OUTPUT=""
    typeset _ERROR_COUNT=""
    
    print "Getting Remote file from $FTP_HOST using commands:"                 >> $LOG_FILE
    print "$_FTP_COMMANDS"                                                     >> $LOG_FILE
    print ""                                                                   >> $LOG_FILE
    _FTP_OUTPUT=$(print "$_FTP_COMMANDS" | ftp -i -v $FTP_HOST)
    RETCODE=$?  
    
    print "$_FTP_OUTPUT"                                                       >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "Errors occurred during ftp."                                    >> $LOG_FILE
        exit_error $RETCODE
    fi
    
    # Parse the ftp output for errors
    # 400 and 500 level replies are errors
    # You have to filter out the bytes sent message
    # it may say something 404 bytes sent and you don't
    # want to mistake this for an error message. 
    _ERROR_COUNT=$(echo "$_FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')
    if [[ $_ERROR_COUNT -gt 0 ]]; then
        print "Errors occurred during ftp."                                    >> $LOG_FILE
        RETCODE=5
        exit_error $RETCODE
    fi
}

#-------------------------------------------------------------------------#
# Region specific variables
#-------------------------------------------------------------------------#



# Region specific variables
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
    export ALTER_EMAIL_ADDRESS="nick.tucker@caremark.com"
fi


# Variables
RETCODE=0
SCHEDULE="GDMN2100"
JOB="GD_2101J"
SCRIPTNAME="GDX_GD_2101J_rfraresponse_hdr_load.ksh"

# LOG FILES
LOG_FILE_ARCH=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE_NM=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_NM

DB2_MSG_FILE=$LOG_FILE.load


INPUT_FILE=$GDX_PATH"/input/header.txt"
FTP_FILE_NAME="header.txt"
FTP_FILE=$GDX_PATH"/input/header.txt"
FTP_HOST="DMADOM4"
FTP_INPUT_PATH="/export/home/prodschd/MONTHLY"


#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#
print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE


#-------------------------------------------------------------------------#
# Step 1. FTP the rfraresponse header file from DMADOM4 to GDX.
#-------------------------------------------------------------------------#

{
    print "cd $FTP_INPUT_PATH"
    print "get $FTP_FILE_NAME $FTP_FILE"
    print "bye"
} | run_ftp "$FTP_HOST"

if [ ! -f $FTP_FILE ]; then
	print "No file found after rfraresponse header FTP"                    	>> $LOG_FILE
	print "$FTP_FILE - exiting with error"               			>> $LOG_FILE
	RETCODE=1
        exit_ERROR $RETCODE
fi


#-------------------------------------------------------------------------#
# Step 2. Connect to UDB.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >>$LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"          >>$LOG_FILE
   RETCODE=$?
print 'RETCODE=<'$RETCODE'>'>> $LOG_FILE

if [[ $RETCODE != 0 ]]; then
   print "ERROR: couldn't connect to database......"                           >>$LOG_FILE
   exit_error $RETCODE
fi

   
#-------------------------------------------------------------------------#
# Step 3. Import data from input files, overlay the current tables 
#-------------------------------------------------------------------------#

   sql="import from $INPUT_FILE of asc
		modified by usedefaults
	   method L (7 8, 10 11, 2 5) 
		commitcount 3000 messages "$DB2_MSG_FILE"
           replace into vrap.trfra_rsp_hdr
		(HDR_MM,HDR_DD,HDR_YYYY)"


   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -pxw "$sql"                                                             >>$LOG_FILE
   RETCODE=$?
print 'import trfra_rsp RETCODE=<'$RETCODE'>'				       >> $LOG_FILE

 
if [[ $RETCODE != 0 ]]; then
	print "ERROR: Step 3 abend, having problem import file......"          >> $LOG_FILE
	exit_error 999
else
	print "********************************************"                   >> $LOG_FILE
	print "Step 3 - Import data to table trfra_rsp_hdr - Completed ......" >> $LOG_FILE
	print "********************************************"                   >> $LOG_FILE
fi


#-------------------------------------------------------------------------#
# Step 5.  Clean up.                  
#-------------------------------------------------------------------------#

	RETCODE=0
# remove the input file 
	rm -f $INPUT_FILE
# remove DB2 message
        rm -f $DB2_MSG_FILE

print "********************************************"                           >> $LOG_FILE
print "Step 5 - Clean up - Completed ......"                                   >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

# move log file to archive with timestamp
        mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH

exit $RETCODE
