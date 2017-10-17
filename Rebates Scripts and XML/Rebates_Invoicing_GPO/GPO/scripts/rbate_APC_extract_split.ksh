#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_APC_extract_split.ksh   
# Title         : APC file processing.
#
# Description   : Determines number of records and submits appropriate number
#                 of jobs to split and zip whole APC file into 10,000,000
#                 record files.
#
# Maestro Job   : Called from rbate_APC_clm_extract.ksh RIOR4500 RI_4500J
#                 and also from RI_4504J.
#
# Parameters    : CYCLE_GID
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02/23/2004  is00241     Remove all export parms except for the variables
#                         used by script rbate_email_base.ksh.
#                         Remove the delete statement that deletes the
#                         APC_DAT_INPUT file at the end of the script.
#                         Add FTP commands to transfer data to the Minn
#                         data mart (AZSHDSP13).
# 05-19-2003  is45401     Changed to accept new parm as input, APCType,
#                         which determines if the file coming in is the
#                         APC Rebated or Submitted claim detail.
#                         Renamed from rbate_APC_file_extract_main.ksh.
# 10-16-2002  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

let MaxFiles=20

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    #running in the QA region
    export ALTER_EMAIL_ADDRESS='richard.hutchison@Caremark.com'
    MVS_FTP_PREFIX='TEST.X'
    DMART_FTP_PREFIX="TEST_APC_"$APCType
    P13_FTP_DIR="cd /rebates_integration/apctop13/apc_zipped/test"
    let Line_Incr=100
    let Sleep_Secs=10
    Email_CC_List="richard.hutchison@Caremark.com"
    Email_TO_List="richard.hutchison@Caremark.com"
    Email_Save=$SCRIPT_PATH"/richard.hutchison"
  else
    # Running in Prod region
    export ALTER_EMAIL_ADDRESS=''
    MVS_FTP_PREFIX='PCS.P'
    DMART_FTP_PREFIX="APC_"$APCType
    P13_FTP_DIR="cd /rebates_integration/apctop13/apc_zipped"
    let Line_Incr=10000000
    let Sleep_Secs=1800
    Email_CC_List="MMRebInvoiceOPS@Caremark.com,MMRebInvoiceITD@Caremark.com,deb.lind@Caremark.com,MMRebPaymentsITD@Caremark.com,Joshua.Silverman@Caremark.com"
    Email_TO_List="gary.kauffman@Caremark.com,pamela.fuerhoff@Caremark.com"
    Email_Save=$SCRIPT_PATH"/gary.kauffman"
  fi
else  
  #Running in Development region
  export ALTER_EMAIL_ADDRESS='randy.redus@Caremark.com'
  MVS_FTP_PREFIX='TEST.X'
  DMART_FTP_PREFIX="TEST_APC_"$APCType
  P13_FTP_DIR="cd /rebates_integration/apctop13/apc_zipped/test"
  let Line_Incr=10000
  let Sleep_Secs=10
  Email_CC_List="randy.redus@Caremark.com,kurt.gries@caremark.com,melissa.champagne@caremark.com,trish.moloney@caremark.com,shyam.antari@caremark.com,peter.merk@caremark.com"
  Email_TO_List="randy.redus@Caremark.com"
  Email_Save=$SCRIPT_PATH"/randy.redus"
fi

#Create numeric variables, and assign values
let Line_Begin=1
let Line_End=0
let Job_Number=0
let LINE_TOT=0
let File_Count=0
let Sleep_Cnt=0
let Retcode=0

FileNameQtr=$1
FileNameYr=$2
APCType=$3
CALLING_SCHEDULE=$4
CALLING_JOB=$5

#the variables needed for the source file location and the NT Server
SCHEDULE="N/A"
JOB="N/A"
APC_OUTPUT_DIR=$OUTPUT_PATH/apc
FILE_BASE="rbate_APC_extract_split"
SCRIPTNAME=$FILE_BASE".ksh"
FILE_CNT="rbate_APC_extract_split_file_count"
FILE_CNT_DAT=$APC_OUTPUT_DIR/$FILE_CNT".dat"
EMAIL_BASE=$OUTPUT_PATH"/rbate_APC_email_base.txt"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH=$FILE_BASE".log"
EXTRACT_CLM_CNT_FILE=$APC_OUTPUT_DIR"/rbate_APC_"$APCType"_clm_extract_wc.dat"
CNTLCARD_DIR=$MVS_FTP_PREFIX'.TM30D011.CNTLCARD(KSZ4900C)'
DMART_FTP_IP='azshisp00'

Email_From="MMReb.Invoice.ITD@Caremark.com"

rm -f $LOG_FILE
rm -f $EMAIL_BASE
rm -f $EXTRACT_CLM_CNT_FILE
rm -f $FILE_CNT_DAT

print "Starting " $SCRIPTNAME  >> $LOG_FILE
print `date` >> $LOG_FILE

if [ $# -lt 5 ]; then
    print " " >> $LOG_FILE
    print "Insufficient arguments passed to script." >> $LOG_FILE
    print "FileNameQtr >"$FileNameQtr"<, FileNameYr >"$FileNameYr"<"  >> $LOG_FILE
    print "Calling Schedule >"$CALLING_SCHEDULE"<"  >> $LOG_FILE
    print "CALLING_JOB >"$CALLING_JOB"<"  >> $LOG_FILE
    print "APCType >"$APCType"<."  >> $LOG_FILE
    print " " >> $LOG_FILE
    RETCODE=1
fi

# -z means 'is null'
if [[ -z $RETCODE || $RETCODE = 0 ]]; then

  # Submitted and Rebated files are treated differently in some sections, the same in others.
  case $APCType in 
    "REBATED" )
      APC_DAT_INPUT=$APC_OUTPUT_DIR"/rbate_"$CALLING_SCHEDULE"_"$CALLING_JOB"_APC_rbated_clm_extract.dat"
      #Next file variables used for data cleanup
      APC_ZIP_OUTPUT=$APC_OUTPUT_DIR"/rbate_"$CALLING_SCHEDULE"_"$CALLING_JOB"_APC_rbated_clm_extract.zip"
      DMART_FTP_COMMANDS=$APC_OUTPUT_DIR/$FILE_BASE"_ftpcommands.txt"
      DMART_FILENAME=$DMART_FTP_PREFIX"_FILE"
      DMART_TRG_FILENAME=$DMART_FTP_PREFIX"_FILE.TRIGGER" 
      rm -f $DMART_FTP_COMMANDS
      rm -f $DMART_TRG_FILENAME
      print " " >> $LOG_FILE
      print " APCType is Rebated" >> $LOG_FILE
      print " " >> $LOG_FILE ;;
    "SUBMTTD" )
      APC_DAT_INPUT=$APC_OUTPUT_DIR"/rbate_"$CALLING_SCHEDULE"_"$CALLING_JOB"_APC_submttd_clm_extract.dat"
      #Next file variables used for data cleanup
      APC_ZIP_OUTPUT=$APC_OUTPUT_DIR"/rbate_"$CALLING_SCHEDULE"_"$CALLING_JOB"_APC_submttd_clm_extract.zip"
      DMART_FTP_COMMANDS=$APC_OUTPUT_DIR/$FILE_BASE"_ftpcommands.txt"
      DMART_FILENAME=$DMART_FTP_PREFIX"_FILE"
      DMART_TRG_FILENAME=$DMART_FTP_PREFIX"_FILE.TRIGGER" 
      rm -f $DMART_FTP_COMMANDS
      rm -f $DMART_TRG_FILENAME
      print " " >> $LOG_FILE
      print " APCType is Submitted" >> $LOG_FILE
      print " " >> $LOG_FILE ;;
    * )
      print " "
      print "ERROR:  INPUT PARM APCType MUST be 'REBATED', or 'SUBMITTED'."  >> $LOG_FILE
      print "        Passed in value is >"$APCType"<." >> $LOG_FILE
      print "Script will abend now." >> $LOG_FILE
      print " "
      RETCODE=1 ;;
  esac
fi

#  ************************************************************************

if [[ $RETCODE = 0 ]]; then
#  FTP the claims to the Minn Data Mart.

    print " " >> $LOG_FILE
    print "=================================================================" >> $LOG_FILE
    print "Ftp uncompressed " $APCType " Claim Detail to the Minn Data Mart started "   >> $LOG_FILE
    print `date` >> $LOG_FILE

    print $P13_FTP_DIR >> $DMART_FTP_COMMANDS
    print "put " $APC_DAT_INPUT " '"$DMART_FILENAME"' (replace" >> $DMART_FTP_COMMANDS 

    print "quit" >> $DMART_FTP_COMMANDS 

    ftp -i  $DMART_FTP_IP < $DMART_FTP_COMMANDS >> $LOG_FILE
    
    RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
        print " " >> $LOG_FILE
        print "=================== DATA MART FTP JOB ABENDED ===================" >> $LOG_FILE
        print "Error Executing the DATA MART FTP for "$JOB_SCRIPTNAME >> $LOG_FILE
        print "  Look in "$LOG_FILE       >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    else
        print " " >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
        print "Start Concatenating Minn Data Mart FTP Commands" >> $LOG_FILE
        cat $DMART_FTP_COMMANDS >> $LOG_FILE
        print "End Concatenating Minn Data Mart FTP Commands" >> $LOG_FILE
        print " " >> $LOG_FILE
        print "Ftp to Minn Data Mart complete "   >> $LOG_FILE
        print `date` >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
    fi
fi

if [[ -z $RETCODE || $RETCODE = 0 ]]; then
  #-------------------------------------------------------------------------#
  # Redirect all output to log file and Log start message to 
  # application log
  #-------------------------------------------------------------------------#
  ## Display special env vars used for this script
  #-------------------------------------------------------------------------#
  print " " >> $LOG_FILE
  print "getting line count via wc -l command" >> $LOG_FILE
  print `date` >> $LOG_FILE

  wc -l $APC_DAT_INPUT >> $EXTRACT_CLM_CNT_FILE

  while read wc_line_count junk_s; do
    APC_NBR_RECS=$wc_line_count
  done < $EXTRACT_CLM_CNT_FILE

  print " " >> $LOG_FILE
  print "done getting line count via wc -l command" >> $LOG_FILE
  print "Line count is " $APC_NBR_RECS >> $LOG_FILE
  print `date` >> $LOG_FILE

#-------------------------------------------------------------------------#
# Commenting the below WHILE LOOP code snippet as part of 6005148
#-------------------------------------------------------------------------#

#  while [[ $LINE_TOT -lt $APC_NBR_RECS ]]; do

#    let Job_Number=Job_Number+1
#    let Line_End=Line_End+Line_Incr

#    if [[ $Line_End -lt $APC_NBR_RECS ]]; then

#      print " " >> $LOG_FILE
#      print "Calling asynchronously rbate_APC_extract_zip.ksh, sending JobNumber >"$Job_Number"<," >> $LOG_FILE
#      print "and Record Count Start >"$Line_Begin"<, and Record Count End >"$Line_End"<." >> $LOG_FILE
#      print "Other parms passed - APCType >"$APCType"<" >> $LOG_FILE
#      print "Schedule >"$CALLING_SCHEDULE"<, Job >"$CALLING_JOB"<"  >> $LOG_FILE

#      . $SCRIPT_PATH/rbate_APC_extract_zip.ksh $Job_Number $Line_Begin $Line_End $APCType $CALLING_SCHEDULE $CALLING_JOB&
#      RETCODE=$?
#      if [[ $RETCODE != 0 ]]; then
#          print " " >> $LOG_FILE
#          print "=============== APC EXTRACT ZIP ABENDED =========================" >> $LOG_FILE
#          print "APC Extract Zip script abended." >> $LOG_FILE
#          print `date` >> $LOG_FILE
#          print "=================================================================" >> $LOG_FILE
#          print " " >> $LOG_FILE
#      fi
#      let Line_Begin="Line_Begin+Line_Incr"

#    else
#      print " " >> $LOG_FILE
#      print "doing last call of rbate_APC_extract_zip.ksh for JobNumber "$Job_Number" Line_Begin value of "$Line_Begin" Line_End value of "$Line_End >> $LOG_FILE
#      print "Other parms passed - APCType >"$APCType"<" >> $LOG_FILE
#      print "Schedule >"$CALLING_SCHEDULE"<, Job >"$CALLING_JOB"<"  >> $LOG_FILE
#      print `date` >> $LOG_FILE

#      let Line_End=$APC_NBR_RECS
#      . $SCRIPT_PATH/rbate_APC_extract_zip.ksh $Job_Number $Line_Begin $Line_End $APCType $CALLING_SCHEDULE $CALLING_JOB&
#      RETCODE=$?
#      if [[ $RETCODE != 0 ]]; then
#        print " " >> $LOG_FILE
#        print "=============== APC EXTRACT ZIP ABENDED =========================" >> $LOG_FILE
#        print "APC Extract Zip script abended." >> $LOG_FILE
#        print `date` >> $LOG_FILE
#        print "=================================================================" >> $LOG_FILE
#        print " " >> $LOG_FILE
#      else
#        print " " >> $LOG_FILE
#        print "=============== APC EXTRACT ZIP ENDED ===========================" >> $LOG_FILE
#        print "APC Extract Zip script ended successfully." >> $LOG_FILE
#        print `date` >> $LOG_FILE
#        print "=================================================================" >> $LOG_FILE
#        print " " >> $LOG_FILE
#      fi
#      let LINE_TOT=$APC_NBR_RECS  
#    fi    
#  done

#  print " " >> $LOG_FILE
#  print "waiting for all jobs to complete "  >> $LOG_FILE
#  print `date` >> $LOG_FILE

#  while [[ $File_Count != $Job_Number ]]; do

#    rm -f $FILE_CNT_DAT
#    if [[ ! -a $APC_OUTPUT_DIR/rbate_APC_extract_zip_DMART1.trg ]]; then
#       print " " >> $FILE_CNT_DAT
#    else
       # NOTE that the Data Mart Trigger file name is used in the rbate_APC_extract_split.ksh, 
       # the rbate_APC_extract_zip.ksh and the rbate_RIOR4500_RI_4504J_APC_submttd_clm_extract.ksh 
       # scripts, so if the name changes, it must change in all four scripts.
#       ls $APC_OUTPUT_DIR/rbate_APC_extract_zip_DMART*.trg > $FILE_CNT_DAT
#    fi
#    let File_Count=0

#    while read file_name; do
#      let File_Count="File_Count+1"
#    done < $FILE_CNT_DAT

#     print " " >> $LOG_FILE
#     print "Number of jobs complete is "$File_Count  >> $LOG_FILE
#     print `date` >> $LOG_FILE

#    if [[ $File_Count != $Job_Number ]]; then
  # lets sleep for $Sleep_Secs (time assigned at top) and check again    
#      let Sleep_Cnt="Sleep_Cnt+1"
#      print "file count is "$File_Count >> $LOG_FILE 
#      print "job number is "$Job_Number >> $LOG_FILE 
#      print "Sleeping for "$Sleep_Secs" seconds.  Total times sleeping = "$Sleep_Cnt"." >> $LOG_FILE 
#      sleep $Sleep_Secs 

#    fi

#  done

    #Now that all the split and zip jobs are done, we can ZIP the Extracted claim data file
    # that holds all of the extracted data for the Rebated and or the Submitted claim data,
    # and after the zip is done, we can delete the original data file.  We can also delete the 
    # already split and zipped data files - but we CANNOT remove any of the split zip files, 
    # because the FTP's may still be running.

    print " " >> $LOG_FILE
    print "Zipping up the file " $APC_DAT_INPUT " into " $APC_ZIP_OUTPUT   >> $LOG_FILE
    print `date` >> $LOG_FILE

    rm -f $APC_ZIP_OUTPUT
    $GZIP_EXECUTABLE -c $APC_DAT_INPUT > $APC_ZIP_OUTPUT
    RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
        print " " >> $LOG_FILE
        print "=============== GZIP_EXECUTABLE COMMAND FAILED ==================" >> $LOG_FILE
        print "GZIP_EXECUTABLE script abended." >> $LOG_FILE
        print "RETURN CODE = " $RETCODE >> $LOG_FILE
        print `date` >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
        print " " >> $LOG_FILE
    else
        print " " >> $LOG_FILE
        print "=============== GZIP_EXECUTABLE COMMAND COMPLETED ===============" >> $LOG_FILE
        print "Completed Zip for file " $APC_ZIP_OUTPUT   >> $LOG_FILE
        print `date` >> $LOG_FILE
        print "=================================================================" >> $LOG_FILE
        print " " >> $LOG_FILE
    fi
fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
   print "  Error Executing " $SCRIPTNAME >> $LOG_FILE
   print "  Look in " $LOG_FILE       >> $LOG_FILE
   print "=================================================================" >> $LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCRIPTNAME", called from "$CALLING_SCHEDULE" / "$CALLING_JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
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
print " " >> $LOG_FILE

rm -f $EMAIL_BASE
print "Sending E-mail notification that the "$APCType" APC is created. " >> $LOG_FILE

#syntax for mailx- -s subject base_email_receiver
# can put in a -c command, before the -s command, that is CC on the email.  If multiple CCs exist, use single quotes around all.
# -F command stores a copy of the email, named after the first email recipient.
# -r command uses the next name as the FROM person in the email.  For this address, use periods for separators.
# The Email TO list/person, MUST come after the subject.

print "The Detail Rebated Claims APC file, and the Detail " >> $EMAIL_BASE
print "Submitted Claims APC file, combined, make up the Complete " >> $EMAIL_BASE
print "APC file for the Cycle. " >> $EMAIL_BASE
print " " >> $EMAIL_BASE

case $APCType in 
    "REBATED" )
      print "The Detail Rebated Claims APC file for "$FileNameQtr $FileNameYr" has "$APC_NBR_RECS >> $EMAIL_BASE
      print "Rebated Claims.  It has been successfully created, and is " >> $EMAIL_BASE
      print "currently being distributed to the MVS, and the Data Mart." >> $EMAIL_BASE
      print " " >> $EMAIL_BASE
      print "PLEASE NOTE:  The Rebated Claims APC file has NOT YET BEEN VALIDATED. " >> $EMAIL_BASE
      print " " >> $EMAIL_BASE
      print "The Summarized Submitted Claims APC file, has already been " >> $EMAIL_BASE
      print "created, and distributed to the MVS, only." >> $EMAIL_BASE
      print " " >> $EMAIL_BASE
      print "The Detail Submitted Claims APC file will be created next, " >> $EMAIL_BASE
      print "and sent to the Data Mart. " >> $EMAIL_BASE
      print " " >> $EMAIL_BASE
      Email_Subject="Rebated Detail APC File Created"
      ;;
    "SUBMTTD" )
      print "The Detail Submitted Claims APC file for "$FileNameQtr $FileNameYr" has "$APC_NBR_RECS >> $EMAIL_BASE
      print "Submitted Claims.  It has been successfully created, and is"  >> $EMAIL_BASE
      print "currently being distributed to the Data Mart, only." >> $EMAIL_BASE
      print " " >> $EMAIL_BASE
      print "PLEASE NOTE:  The Rebated Claims APC file has NOT YET BEEN VALIDATED. " >> $EMAIL_BASE
      print " " >> $EMAIL_BASE
      Email_Subject="Submitted Detail APC File Created"
      ;;
esac

print " " >> $EMAIL_BASE
print "If you have any questions, please reply to this email," >> $EMAIL_BASE
print "and the Rebates ITD group will receive it." >> $EMAIL_BASE
print " " >> $EMAIL_BASE
print "Thanks, ITD Rebates " >> $EMAIL_BASE
print " " >> $EMAIL_BASE

#Email parms set at top of script, and in above case.  Subject (-s) must be in quotes if spaces are in the subject.
mailx -F -r $Email_From -c $Email_CC_List -s "$Email_Subject" $Email_TO_List < $EMAIL_BASE

# The mailx -F parm puts the email into a filename based on the first TO person.  Move this file to the
#    APC output dir.
mv -f $Email_Save $APC_OUTPUT_DIR"/rbate_APC_email_notification.txt"`date +"%Y%j%H%M"`

#Clean up files
rm -f $EMAIL_BASE
rm -f $EXTRACT_CLM_CNT_FILE
rm -f $FILE_CNT_DAT

print " " >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
print `date` >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE

