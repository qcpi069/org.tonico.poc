#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_GD_1110J_Prescriber_load.ksh    
# Title         : Import prescriber data into Table claimsp.tprscbr_prescribe1
#                 
#
# Description   : This script waits for a fixed length ASCII file from 
#                 CDW (Zeus/DW).    
#                 The file will be loaded into Rebate GDX table: 
#                         claimsp.tprscbr_prescribe1 
#                 The load is a full replace.
#
#
# Parameters    : N/A 
# 
# Output        : Log file as $LOG_FILE
#
# Input Files   : /GDX/prod/input/QLdata/mda.claimsp.tprscbr_prescribe1.dat
#
# Trigger File  : /GDX/prod/input/QLdata/mda.claimsp.tprscbr_prescribe1.dat.ok.excp
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-29-07   qcpi03o     Initial Creation
# 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh

cd $SCRIPT_PATH
#-------------------------------------------------------------------------#

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
    export ALTER_EMAIL_ADDRESS="helen.tang@caremark.com"
fi


# Variables
RETCODE=0
SCHEDULE=
JOB=""
FILE_BASE=""
SCRIPTNAME=$(basename "$0")

# LOG FILES
LOG_FILE_ARCH=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE_NM=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_NM

DB2_MSG_FILE=$LOG_FILE.load

INPUT_FILE=$GDX_PATH/input/QLdata/mda.claimsp.tprscbr_prescribe1.dat
TRIGGER_FILE=$GDX_PATH/input/QLdata/mda.claimsp.tprscbr_prescribe1.dat.ok.excp


#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#
print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

#-------------------------------------------------------------------------#
# Step 1. Connect to UDB.
#         backup table vrap.tpharm_npi_xref.
#-------------------------------------------------------------------------#

if [[ ! -f $INPUT_FILE  ]]; then
   print "ERROR: Provider file not received......"                             >>$LOG_FILE
   exit_error 999
fi

   print "Connecting to GDX database......"                                    >>$LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >>$LOG_FILE
   RETCODE=$?
print 'RETCODE=<'$RETCODE'>'>> $LOG_FILE

if [[ $RETCODE != 0 ]]; then
   print "ERROR: couldn't connect to database......"                           >>$LOG_FILE
   exit_error $RETCODE
fi


#-------------------------------------------------------------------------#
# Step 2. Import data from input files, overlay the current tables 
#-------------------------------------------------------------------------#

   sql="import from $INPUT_FILE of asc
		modified by usedefaults
	   method L (1 9 ,10 13, 14 43, 44 73, 74 103, 104 106 , 107 166, 167 175,
		176 186, 187 191, 192 195, 196 235, 236 275, 276 315, 316 355, 356 357, 
		358 362, 363 366, 367 369, 370 376 , 377 381, 382 384,
		 385 391, 403 406, 392 392, 393 402,407 410,411 414, 
		432 457, 458 467) 
		commitcount 5000 messages "$DB2_MSG_FILE"
           replace into claimsp.tprscbr_prescribe1"


   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
print 'import Prescriber data RETCODE=<'$RETCODE'>'>> $LOG_FILE


if [[ $RETCODE != 0 ]]; then
	print "ERROR: Step 2 abend, having problem import file......"          >> $LOG_FILE
	exit_error 999
else
print "********************************************"                           >> $LOG_FILE
print "Step 2 - Import data to table tprscbr_prescribe1 - Completed ......"    >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Step 3.  Clean up.                  
#-------------------------------------------------------------------------#

	RETCODE=0
# remove trigger file
	rm -f $TRIGGER_FILE
# remove DB2 message
	rm -f $DB2_MSG_FILE
# backup the input data file to $GDXROOT/input/archive/npixref
	mv -f $INPUT_FILE $GDX_PATH/input/archive/npixref
# clean some old log file?
	`find "$LOG_ARCH_PATH" -name "GDX_GD_1110J_Prescriber_load*" -mtime +35 -exec rm -f {} \;  `

print "********************************************"                           >> $LOG_FILE
print "Step 3 - Clean up - Completed ......"                                   >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

# move log file to archive with timestamp
        mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH

exit $RETCODE
