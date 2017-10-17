#!/usr/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_DFO_rename_firsthealth_input.ksh
# Title         : Monitor FirstHealth input FTP and Rename
#
# Description   : This script will be triggered by the fhrx_rebate_YYYYMM_all.dat
#                 file being received.  Because it may still be FTPing, this
#                 script will monitor the FTP until it's complete, then 
#                 once complete it will rename the input file to the old
#                 format, and then will create a trigger file that will 
#                 kick off the rest of the DFO processing.
#
# Maestro Job   : GDDY0010 GD_0016J
#
# Parameters    : N/A
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-13-06   qcpi733     Initial Creation.
#
#-------------------------------------------------------------------------#

# Find and run the environment script relative to the location of the 
# current script.
base_dir=$(dirname $0)
. "$base_dir/../Common_GDX_Environment.ksh"
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    else
        # Running in Prod region
        . /GDX/prod/scripts/Common_GDX_Environment.ksh
        export ALTER_EMAIL_ADDRESS=""
    fi
else 
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
fi

FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$LOG_PATH/$FILE_BASE".log"
LOG_ARCH_FILE=$LOG_ARCH_PATH/$FILE_BASE".log"
DFO_PROCESS_TRIGGER=$INPUT_PATH/"GDX_start_dfo_processing.txt"
RETCODE=0

rm -f $LOG_FILE

#DFO specific directories
FTP_STAGING_DIR=$GDX_PATH/dfoftp
STAGING_DIR=$GDX_PATH/staging
export SCRIPT_DIR=$SCRIPT_PATH/DFO
export REF_DIR="$GDX_PATH/control/reffile"
export SUPPORT_MAIL_LIST_FILE="$REF_DIR/DFO_support_maillist.ref"
export MAILFILE=$OUTPUT_PATH/$FILE_BASE"_mail.txt"

print "Starting $SCRIPT_NAME - must have received a fhrx_rebate_YYYYMM_all.dat file." >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

function exit_error {
    RETCODE=$1
    EMAILPARM4='  '
    EMAILPARM5='  '


    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
	print " "  
	print " "  
        print 'Sending email notification with the following parameters'

        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"

        print '****** end of email parameters ******'
    } >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    print "Exiting script with return code >"$RETCODE"<"                       >> $LOG_FILE
    exit $RETCODE
}

#------------------------------------------------------------------
#CHECK IF FILE IN FTP-STAGING DIRECTORY IS STILL BEING FTP'D
#IF SO, WAIT TILL IT BECOMES INACTIVE
#------------------------------------------------------------------

  touch $FTP_STAGING_DIR/ftp_temp_new
  sleep 5
  
  
  find $FTP_STAGING_DIR -name "fhrx_rebate*.dat" \
        -newer $FTP_STAGING_DIR/ftp_temp_new         \
        > $FTP_STAGING_DIR/ftp_temp_newest

  while [[ -s $FTP_STAGING_DIR/ftp_temp_newest ]]
  do
  
     print " "                                                                 >> $LOG_FILE
     print "fhrx_rebate*.dat file is still being FTPd"                         >> $LOG_FILE
     touch $FTP_STAGING_DIR/ftp_temp_new
     sleep 5
  
     find $FTP_STAGING_DIR -name "fhrx_rebate*.dat" \
           -newer $FTP_STAGING_DIR/ftp_temp_new         \
           > $FTP_STAGING_DIR/ftp_temp_newest
  
  done

print " "                                                                      >> $LOG_FILE
print "fhrx_rebate*.dat file FTP is complete "                                 >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

## added on 7/12/06 - qcpi733
# This will do some filename validation on the input file, and rename the file
#    to the old name for the remainder of DFO processing (thx Bryan!).

# Get the filename sent from _IS-Electronic Communications group
ls -1tr $FTP_STAGING_DIR/fhrx_rebate*.dat|read FTP_FHRX_FILE
RETCODE=$?
if [[ $RETCODE != 0 ]]; then 
    print " "                                                                  >> $LOG_FILE
    print "Error when trying to copy the file to the new name. "               >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "cp $FTP_STAGING_DIR/$FTP_FHRX_FILE $FTP_STAGING_DIR/CLAIMS.FIRSTHEALTH.${month}${year}.DAT" >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    exit_error $RETCODE
fi 

#strip out directory structure
FTP_FHRX_FILE=${FTP_FHRX_FILE##/*/}

print " "                                                                      >> $LOG_FILE
print "FTP_FHRX_FILE=>"$FTP_FHRX_FILE"<"                                       >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

if ! echo "$FTP_FHRX_FILE" | egrep -q '^fhrx_rebate_20[0-9][0-9]([0][1-9]|1[0-2])_all.dat$'; then
        print " "                                                              >> $LOG_FILE
	print "Invalid file name $FTP_FHRX_FILE"                               >> $LOG_FILE
        print " "                                                              >> $LOG_FILE

        print "calling mailto script" 
        
        {
        print "Script: $SCRIPTNAME"                                            
        print "\nProcessing for First Health Failed:"                         
        print "\nFtp staging directory does NOT have the correct filename format" 
        print "Expecting fhrx_rebate_YYYYMM_all.dat"                        
        print "If file sent does not match this format, email Jeff Barret in Chicago" 
        print " and have him look into what is being sent us."                
        print "\nLook for Log file $LOG_FILE"                                 
        } > $MAILFILE

        export MAIL_SUBJECT="DFO PROCESS FAILED"
        $SCRIPT_DIR/mailto_IS_group.ksh 
        
	print " "                                                              >> $LOG_FILE
	print "Error when trying to read the FTPd filename"                    >> $LOG_FILE
	print "File needs to be in format fhrx_rebate_YYYYMM_all.dat "         >> $LOG_FILE                                                                  >> $LOG_FILE
	print " "                                                              >> $LOG_FILE
	exit_error $RETCODE
fi

# Build the new filename based on the input filename. 
year=$(echo "$FTP_FHRX_FILE" | cut -c 13-16)
month=$(echo "$FTP_FHRX_FILE" | cut -c 17-18 | sed -e '
	s/01/JAN/;
	s/02/FEB/;
	s/03/MAR/;
	s/04/APR/;
	s/05/MAY/;
	s/06/JUN/;
	s/07/JUL/;
	s/08/AUG/;
	s/09/SEP/;
	s/10/OCT/;
	s/11/NOV/;
	s/12/DEC/;')

# first clean up any possible prior runs of same month
rm -f $FTP_STAGING_DIR/"CLAIMS.FIRSTHEALTH.${month}${year}.DAT"
rm -f $STAGING_DIR/"CLAIMS.FIRSTHEALTH.${month}${year}.DAT"
rm -f $STAGING_DIR/FIRSTHEALTH.${month}${year}.*

# copy the ftpd file for remainder of dfo processing
# original input file to be removed in last few steps of processing
cp $FTP_STAGING_DIR/$FTP_FHRX_FILE $FTP_STAGING_DIR/"CLAIMS.FIRSTHEALTH.${month}${year}.DAT"
RETCODE=$?
if [[ $RETCODE != 0 ]]; then 
    print "Error when trying to copy the file to the new name. "               >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "cp $FTP_STAGING_DIR/$FTP_FHRX_FILE $FTP_STAGING_DIR/CLAIMS.FIRSTHEALTH.${month}${year}.DAT" >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    exit_error $RETCODE
fi

print " "                                                                      >> $LOG_FILE
print "Original input file was named - "$FTP_FHRX_FILE                         >> $LOG_FILE
print "Original input file was named - "$FTP_FHRX_FILE                         >> $DFO_PROCESS_TRIGGER
print " "                                                                      >> $LOG_FILE
print "Copied to CLAIMS.FIRSTHEALTH.${month}${year}.DAT"                     >> $LOG_FILE
print "Copied to CLAIMS.FIRSTHEALTH.${month}${year}.DAT"                     >> $DFO_PROCESS_TRIGGER
print " "                                                                      >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE
print `date`                                                                   >> $DFO_PROCESS_TRIGGER
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

################
#Backup current FTP file and cleanup last months
################
# Build the new filename based on the input filename. 
# By reading in the current month MM, determine the number of last month's file
prevmonth=$(echo "$FTP_FHRX_FILE" | cut -c 17-18 | sed -e '
	s/02/01/;
	s/03/02/;
	s/04/03/;
	s/05/04/;
	s/06/05/;
	s/07/06/;
	s/08/07/;
	s/09/08/;
	s/10/09/;
	s/11/10/;
	s/12/11/;
	s/01/12/;')
# Get year from last months file.  DFO supposed to go away end of 2006.
if [[ prevmonth -eq '12' ]]; then 

    prevyear=$(echo "$FTP_FHRX_FILE" | cut -c 13-16 | sed -e '
	s/2007/2006/;
	s/2008/2007/;
	s/2009/2008/;')
else
    prevyear=$(echo "$FTP_FHRX_FILE" | cut -c 13-16)
fi

print "Cleanup last months file.  "                                            >> $LOG_FILE
print "rm -f $FTP_STAGING_DIR/fhrx_rebate_${prevyear}${prevmonth}_all_dat.bkp" >> $LOG_FILE
rm -f "$FTP_STAGING_DIR/fhrx_rebate_${prevyear}${prevmonth}_all_dat.bkp"

print " "                                                                      >> $LOG_FILE
# Copy this months file to the backup file name.  Will be cleaned up next month.
print "Backup this months file to prevent kicking off script again, and in "   >> $LOG_FILE
print "  case of restart being required."                                      >> $LOG_FILE

mv $FTP_STAGING_DIR/$FTP_FHRX_FILE $FTP_STAGING_DIR/$(basename $FTP_FHRX_FILE | sed -e 's/.dat$//')"_dat.bkp"
print "mv $FTP_FHRX_FILE $(basename $FTP_FHRX_FILE | sed -e 's/.dat$//')_dat.bkp" >> $LOG_FILE

# Notify IT about how to restart DFO FirstHealth in case of abend.

print "\nScript: $SCRIPTNAME"                                                          \
     "\n\nIn case that DFO First Health fails:"                                        \
     "\nYou must rename the FTP input file from the backup name to the "             \
     "expected format - fhrx_rebate_YYYYMM_all.dat.  This mv command has the actual " \
     "months for this processing period in it, so you can execute as-is, but do verify." \
     "\n\n\tmv $FTP_STAGING_DIR/$(basename $FTP_FHRX_FILE | sed -e 's/.dat$//')_dat.bkp $FTP_STAGING_DIR/$FTP_FHRX_FILE" \
     "\n\nThen you must have jobs R07PRD01#GDDY0010.GD_0016J and GD_0017J resubmitted."    > $MAILFILE

export MAIL_SUBJECT="DFO PROCESS Restart Instructions - JUST IN CASE"
$SCRIPT_DIR/mailto_IS_group.ksh

print " "                                                                      >> $LOG_FILE
print "Completed processing input data file from FirstHealth. "                >> $LOG_FILE  
print `date`                                                                   >> $LOG_FILE

mv $LOG_FILE $LOG_ARCH_FILE.`date +"%Y%j%H%M"`

exit $RETCODE