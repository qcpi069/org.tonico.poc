#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : invoice_Extract_Files_Sftp.ksh
# Title         : Load reports from ETL box to UNIX
#
#
# Description   : This script will perform the below operations
#                 1) It will recieve file name as parameter
#                 2) It will search the TgtFiles directory for
#                    <filename>_HEADER
#                    <filename>_BODY
#                    <filename>_TRAILER
#                 3) It will merger the 3 file to create <filename>
#                 4) SFTP <filename>.gz to GDX UNIX box which will be later sent
#                    to AETNA via SFTP script.
#                 5) If SFTP is successful then remove the files
#
#                 Script will be called by 3 Informatica workflows
#                 to SFTP file for 3 type of invoice reports
#                 1) Invoiced Claim Extract
#                 2) Invoiced Estimate Extract
#                 3) Invoice Adjustment Extract
#
# Parameters    : File NAME (Any one of below file name)
#                 INVCLMEXTRACT.<YYYYMMDD>.<YYYYMMDD>
#                 INVESTCLMEXTRACT.<YYYYMMDD>.<YYYYMMDD>
#                 INVADJCLMEXTRACT.<YYYYMMDD>.<YYYYMMDD>
#
# Output        : Log file as $LOG_FILE
#
# Input Files   : /opt/pcenter/dev1/rebates/TgtFiles
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-21-13   qcpi0rb     Initial Creation
# 08-05-13   qcpi2d6     Changed REGION to get the different stream
# 09-29-14   qcpue98u    GZIP the extract before ftp to PRDRGD1
# 06-24-15   qcpue98u    Change FTP to SFTP
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

    print "aborting $SCRIPTNAME due to errors. RETCODE = $RETCODE "  >> $LOG_FILE

    # Copy logs files into archive directory
      cp -f $LOG_FILE $LOG_FILE_ARCH
      exit $RETCODE
}

#-------------------------------------------------------------------------#
# Step 1. Recieve file name prefix for files to be merged and sent.
#-------------------------------------------------------------------------#
REPORT_NAME_PREFIX=$1

# Set Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")


# LOG FILES
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"

#Report files
SOURCE_FILE_PATH=$REBATES_HOME/TgtFiles
TARGET_FILE_NAME=$SOURCE_FILE_PATH/$REPORT_NAME_PREFIX

# Remove log file if present
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "********************************************"     >> $LOG_FILE
print "Starting the script $SCRIPTNAME ............"     >> $LOG_FILE
print `date +"%D %r %Z"`                                 >> $LOG_FILE
print "********************************************"     >> $LOG_FILE

if [[ $REPORT_NAME_PREFIX = '' ]]; then
      print "ERROR: Please enter file name as parameter "
      RETCODE=1
      exit_error $RETCODE
fi

cd $SOURCE_FILE_PATH

#-------------------------------------------------------------------------#
# Step 2. Check existence of HEADER, DETAIL and TRAILER files to be merged.
#-------------------------------------------------------------------------#

if [[ -s ${REPORT_NAME_PREFIX}_HEADER  &&  -s ${REPORT_NAME_PREFIX}_DETAIL  &&  -s ${REPORT_NAME_PREFIX}_TRAILER ]]; then
   print "Header, detail and trailer file are present. Processing started for file with $REPORT_NAME_PREFIX prefix"  >> $LOG_FILE
else
   print "Atleast of the input file not present\empty. Please check input files (header, detail or trailer)"  >> $LOG_FILE
   RETCODE=1
   exit_error $RETCODE
fi

#-------------------------------------------------------------------------#
# Step 3. Merge HEADER, DETAIL and TRAILER files into one file.
#-------------------------------------------------------------------------#

print "Merging HEADER, DETAIL and TRAILER file into one file " >> $LOG_FILE

awk '{print}' ${REPORT_NAME_PREFIX}_HEADER ${REPORT_NAME_PREFIX}_DETAIL ${REPORT_NAME_PREFIX}_TRAILER > $TARGET_FILE_NAME

gzip $TARGET_FILE_NAME 

TARGET_FILE_NAME=$TARGET_FILE_NAME".gz"

REPORT_FILE_NAME=$REPORT_NAME_PREFIX".gz" 

#-------------------------------------------------------------------------#
# Step 4. SFTP the informatica files from ETL BOX to GDX UNIX Box .
#-------------------------------------------------------------------------#

print "SFTP Starts"                                                             >> $LOG_FILE
echo $REPORT_FILE_NAME
# REPORT_FILE_NAME variable has fully qualified path and filename
$REBATES_HOME/scripts/Common_SFTP_Process.ksh -p $SCRIPTNAME -s $REPORT_FILE_NAME -t $REPORT_FILE_NAME

RETURN_CODE=$?

if [[ $RETURN_CODE != 0 ]]; then
   print "SFTP Step failed"                                                     >> $LOG_FILE
   exit_error 1
fi

print "SFTP Completed"                                                          >> $LOG_FILE

#-------------------------------------------------------------------------#
# Step 5. Remove files.
#-------------------------------------------------------------------------#
print "Remove files ......................................."                   >> $LOG_FILE


# Removing temporary files
rm -f ${REPORT_NAME_PREFIX}*

print "********************************************"                           >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH
exit $RETCODE

