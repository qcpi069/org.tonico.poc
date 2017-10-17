#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_APC_extract_zip.ksh   
# Title         : APC file processing.
#
# Description   : Creates an output from a block of records from an input 
#                 file, and then Zips up the output, and transmits 
#                 to the MVS and then Data Mart -input was Rebated Claims,
#                 or it just transmits to the Data Mart -input was
#                 Submitted Claims.
#
# Maestro Job   : Called from rbate_APC_extract_split.ksh
#
# Parameters    : JobNumber, SplitStartRec, SplitEndRec, APCType.
#
# Output        : Log file as $OUTPUT_PATH/rbate_APC_extract_zipN.log
#                 where N is the JobNumber passed into the script
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-23-04    is00241     Remove all export parms except for the variables
#                         used by script rbate_email_base.ksh.
#                         Remove all FTP commands for the MVS. 
#                         Do not remove the FTP commands for the data mart.
#                         Add FTP commands to transfers data to the Minn
#                         data mart (AZSHDSP13).
#                         Remove the logic that zips the APC file.
#                         Change the FTP commands that FTP the zipped files
#                         to MVS to FTP the unzipped files.
# 05-27-03    is45401     Initial Creation, cloned/replaced the script
#                         rbate_APC_file_extract_zip.ksh.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

JobNumber=$1
SplitStartRec=$2
SplitEndRec=$3
# APCType is passed in from the *clm_extract script. Value either 'REBATED'
#    or 'SUBMTTD'.
APCType=$4
CALLING_SCHEDULE=$5
CALLING_JOB=$6

RETCODE=0
if [[ $# -lt 6 ]]; 
then
    print " " >> $LOG_FILE
    print "=============== MISSING ARGUMENTS SCRIPT FAILED==================" >> $LOG_FILE
    print "Insufficient arguments passed to script." >> $LOG_FILE
    print "JobNumber >"$JobNumber"<, SplitStartRec >"$SplitStartRec"<"  >> $LOG_FILE
    print "SplitEndRec >"$SplitEndRec"<, APCType >"$APCType"<"  >> $LOG_FILE
    print "Calling Schedule >"$CALLING_SCHEDULE"<"  >> $LOG_FILE
    print "CALLING_JOB >"$CALLING_JOB"<"  >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    print " " >> $LOG_FILE
    RETCODE=1
fi

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
# Running in the QA region
        export ALTER_EMAIL_ADDRESS='richard.hutchison@advancepcs.com'
        DMART_FTP_DIR="cd /rebates_integration/apcftp_in/test"
        DMART_FTP_PREFIX="TEST_APC_"$APCType
        let Line_Incr=50
        let Sleep_Secs=10
        Email_CC_List='richard.hutchison@advancepcs.com'
        Email_TO_List='richard.hutchison@advancepcs.com'
    else
# Running in Prod region
        export ALTER_EMAIL_ADDRESS=''
        DMART_FTP_DIR="cd /rebates_integration/apcftp_in"
        DMART_FTP_PREFIX="APC_"$APCType
        let Line_Incr=10000000
        let Sleep_Secs=3600
    fi
else  
# Running in Development region
    export ALTER_EMAIL_ADDRESS='richard.hutchison@advancepcs.com'
    DMART_FTP_DIR="cd /rebates_integration/apcftp_in/test"
    DMART_FTP_PREFIX="TEST_APC_"$APCType
fi

APC_OUTPUT_DIR=$OUTPUT_PATH/apc
DMART_FTP_IP='azshisp00'
FILE_BASE="rbate_APC_extract_zip"
SCRIPTNAME=$FILE_BASE".ksh"
JOB_SCRIPTNAME=$FILE_BASE$JobNumber".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE"_"$APCType$JobNumber".log"
LOG_ARCH=$FILE_BASE"_"$APCType$JobNumber".log"


# NOTE that the Data Mart Trigger file name is used in the rbate_APC_extract_split.ksh, 
# the rbate_APC_extract_zip.ksh and the rbate_RIOR4500_RI_4504J_APC_submttd_clm_extract.ksh 
# scripts, so if the name changes, it must change in all four scripts.

DMART_FTP_TRG=$APC_OUTPUT_DIR/$FILE_BASE"_DMART"$JobNumber'.trg'

rm -f $LOG_FILE

print "Starting "$SCRIPTNAME >> $LOG_FILE
print `date` >> $LOG_FILE

# -z means 'is null'
if [[ -z $RETCODE || $RETCODE = 0 ]]; then

# Submitted and Rebated files are treated differently in some sections, the same in others.
  case $APCType in 
    "REBATED" )
      print " " >> $LOG_FILE
      print " APCType is Rebated" >> $LOG_FILE
      print " " >> $LOG_FILE 
      APC_DAT_INPUT=$APC_OUTPUT_DIR"/rbate_"$CALLING_SCHEDULE"_"$CALLING_JOB"_APC_rbated_clm_extract.dat"
      APC_SPLIT_DAT_INPUT=$APC_OUTPUT_DIR"/rbate_APC_rbated_extract_split"$JobNumber".dat"
      DMART_FTP_COMMANDS=$APC_OUTPUT_DIR/$FILE_BASE$JobNumber"_dmartftpcommands.txt"
      DMART_FILENAME=$DMART_FTP_PREFIX"_FILE"$JobNumber
      DMART_TRG_FILENAME=$DMART_FTP_PREFIX"_FILE"$JobNumber".TRIGGER" 
      rm -f $DMART_FTP_COMMANDS
      rm -f $DMART_TRG_FILENAME
      ;;
    "SUBMTTD" )
      print " " >> $LOG_FILE
      print " APCType is Submitted" >> $LOG_FILE
      print " " >> $LOG_FILE 
      APC_DAT_INPUT=$APC_OUTPUT_DIR"/rbate_"$CALLING_SCHEDULE"_"$CALLING_JOB"_APC_submttd_clm_extract.dat"
      APC_SPLIT_DAT_INPUT=$APC_OUTPUT_DIR"/rbate_APC_submttd_extract_split"$JobNumber".dat"
      DMART_FTP_COMMANDS=$APC_OUTPUT_DIR/$FILE_BASE$JobNumber"_dmartftpcommands.txt"
      DMART_FILENAME=$DMART_FTP_PREFIX"_FILE"$JobNumber
      DMART_TRG_FILENAME=$DMART_FTP_PREFIX"_FILE"$JobNumber".TRIGGER" 
      rm -f $DMART_FTP_COMMANDS
      rm -f $DMART_TRG_FILENAME
      ;;
    * )
      print " "
      print "ERROR:  INPUT PARM APCType MUST be 'REBATED', or 'SUBMITTED'."  >> $LOG_FILE
      print "        Passed in value is >"$APCType"<." >> $LOG_FILE
      print "Script will abend now." >> $LOG_FILE
      print " "
      RETCODE=1 ;;
  esac
fi

if [[ -z $RETCODE || $RETCODE = 0 ]]; then
    print " " >> $LOG_FILE
    print "performing the sed for JobNumber " $JobNumber  >> $LOG_FILE
    print `date` >> $LOG_FILE
    sed -n $2,$3p $APC_DAT_INPUT >> $APC_SPLIT_DAT_INPUT
    RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
        print " " >> $LOG_FILE
        print "=================== SED COMMAND FAILED ==========================" >> $LOG_FILE
        print "-n parm = " -n >> $LOG_FILE
        print "$2 parm = " $2 >> $LOG_FILE
        print "$3p parm = " $3p >> $LOG_FILE
        print "$APC_DAT_INPUT parm = " $APC_DAT_INPUT >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    else
        print " " >> $LOG_FILE
        print "SED command completed successfully"  >> $LOG_FILE
        print `date` >> $LOG_FILE
    fi
fi

if [[ $RETCODE = 0 ]]; then
#  FTP the claims to the APC Data Mart.

    print " " >> $LOG_FILE
    print "Ftp to Data Mart started "   >> $LOG_FILE
    print `date` >> $LOG_FILE

    print " " >> $DMART_FTP_COMMANDS
    print $DMART_FTP_DIR >> $DMART_FTP_COMMANDS
    print "put " $APC_SPLIT_DAT_INPUT " " $DMART_FILENAME ' (replace' >> $DMART_FTP_COMMANDS 

    print "ascii" >> $DMART_FTP_COMMANDS
    print "Trigger file for " $DMART_FILENAME >> $DMART_FTP_TRG
    print "put " $DMART_FTP_TRG " " $DMART_TRG_FILENAME ' (replace' >> $DMART_FTP_COMMANDS 

    print "quit" >> $DMART_FTP_COMMANDS 

    print " " >> $LOG_FILE
    print "Ftping the " $APC_SPLIT_DAT_INPUT " to the APC Data Mart"   >> $LOG_FILE
    print `date` >> $LOG_FILE

    ftp -i  $DMART_FTP_IP < $DMART_FTP_COMMANDS >> $LOG_FILE
    
    RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
        print " " >> $LOG_FILE
        print "=================== DATA MART FTP JOB ABENDED ===================" >> $LOG_FILE
        print "Error Executing the DATA MART FTP for "$JOB_SCRIPTNAME >> $LOG_FILE
        print "  Look in "$LOG_FILE       >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    else
        rm -f $APC_SPLIT_DAT_INPUT
        print " " >> $LOG_FILE
        print "Start Concatonating Data Mart FTP Commands" >> $LOG_FILE
        cat $DMART_FTP_COMMANDS >> $LOG_FILE
        print "End Concatonating Data Mart FTP Commands" >> $LOG_FILE
        print " " >> $LOG_FILE

        print " " >> $LOG_FILE
        print "Ftp to Data Mart complete "   >> $LOG_FILE
        print `date` >> $LOG_FILE
    fi
    
fi

if [[ $RETCODE != 0 ]]; then
# Send the Email notification 
   export JOBNAME="Called from rbate_APC_extract_split.ksh which was called from Schedule "$CALLING_SCHEDULE" / "$CALLING_JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4=" "
   export EMAILPARM5=" "
   
   print "Sending email notification with the following parameters" >> $LOG_FILE
   print "JOBNAME is " $JOBNAME >> $LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $LOG_FILE
   print "LOGFILE is " $LOGFILE >> $LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $LOG_FILE
   print "****** end of email parameters ******" >> $LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

#Clean up files - DO NOT DELETE THE DMART_FTP_TRG, otherwise the rbate_APC_extract_split.ksh will never stop.
rm -f $DMART_FTP_COMMANDS
rm -f $APC_SPLIT_DAT_INPUT

print "....Completed executing $JOB_SCRIPTNAME ...."   >> $LOG_FILE
print `date` >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE

