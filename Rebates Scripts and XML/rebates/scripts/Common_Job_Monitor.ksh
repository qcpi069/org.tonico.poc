
#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_Job_Monitor.ksh
#
# Description   : PSR.TF.10210 RCI Late Claim Pull Alert - Script to Monitor Job or Job Stream Status. 
#
# The purpose is to alert production support if a job has not started on time or not completed on time.
# This script will be scheduled from Maestro. It will check trigger files / flag files to determine job status.
# This job will fail with exit code 1 if an alert to production support is needed. The exit code 1 will 
# set the AlarmPoint noticed as defined in the Maestro job definition. 
#
# Job Monitor Document
# http://sharepoint/sites/TACprodsupport/Shared%20Documents/Rebates/Abends/Job%20Monitor%20Alert.docx
#
# SYNTAX: $SCRIPTNAME -j JOB_ID -t CHECK_START -d DIR_NAME -f FILE_NAME.txt
#
# PARAMATERS:
#  j = JOB_ID. This can be any meastro job id, job stream or word such as "claim_load" that has meaning to production support
#  -j <JobID> Job ID or Name to watch
#  -t <Type> Either CHECK_START, CHECK_END, START_JOB, or END_JOB"
#  -d <Directory_Name> Rebates subdirectory
#  -f <File_Name> file name
#
# Output        : Output files will be named based on -t parameter.
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date      User ID    Description
#-----------  --------   -------------------------------------------------#
# 09-29-2016  qcpi2bw    PSR.TF.10210 RCI Late Claim Pull Alert (Mike Jones)
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RCI_Environment.ksh
# Unit test variables to be removed before unit testing begins
#  TO_MAIL='michael.jones2@cvshealth.com'

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=$SCRIPTNAME" Abended in "$REGION" "`date`

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR
        print " "
        print " !!! Aborting !!!"
        print " "
        print "return_code = " $RETCODE
        print " "        
        print "!!! Please Check Job Status and INFORM the Business if there are any job delays !!!"
        print " "        
        print "For further action, please open Rebates Service Delivery SharePoint Document at http://sharepoint/sites/TACprodsupport/Shared%20Documents/Rebates/Abends/Job%20Monitor%20Alert.docx"
        print " "
        print " ------ Ending script " $SCRIPTNAME $SCRIPT `date`
   }    >> $LOG_FILE

    mailx -s "$EMAIL_SUBJECT" $TO_MAIL < $LOG_FILE

   exit $RETCODE
}

#-------------------------------------------------------------------------#
# Function to exit the script needs to fail to force an alert
#-------------------------------------------------------------------------#
function exit_alarm {
   RETCODE=$1

   EMAIL_SUBJECT=$WATCH_JOB" Job Monitor WARNING in "$REGION" "`date`

   {
        print " "
        print "!!! Please Check Job Status and INFORM the Business if there are any job delays !!!"
        print " "
        print "For further action, please open Rebates Service Delivery SharePoint Document at http://sharepoint/sites/TACprodsupport/Shared%20Documents/Rebates/Abends/Job%20Monitor%20Alert.docx"
        print " "
        print " ------ Ending script " $SCRIPTNAME $SCRIPT `date`
   }    >> $LOG_FILE

    mailx -s "$EMAIL_SUBJECT" $TO_MAIL < $LOG_FILE

   exit $RETCODE
}

#-------------------------------------------------------------------------#
# Function - Log Check was Good
#-------------------------------------------------------------------------#
function exit_ok {
   RETCODE=$1

   {
        print " "
        print "No further action needed"
        print " "
        print " ------ Ending script " $SCRIPTNAME $SCRIPT `date`
   }    >> $LOG_FILE
   
		# ARCHIVE LOG FILE
		mv -f $LOG_FILE $LOG_FILE_ARCH
		  if [[ $? != 0 ]]; then
		         print "ERROR: Moving Log file - $LOG_FILE "
		         RETCODE=1
		         exit_error $RETCODE " Error moving $LOG_FILE to $LOG_FILE_ARCH"					>> $LOG_FILE
		  fi
    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Build Variables
#-------------------------------------------------------------------------#

# Common Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")

# LOG FILES
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"

# Remove last Log file
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Input Parameter Validation
#-------------------------------------------------------------------------#

print "#######################################"									>> $LOG_FILE
print "### Common_Job_Monitor  $TIME_STAMP ###"									>> $LOG_FILE
print "#######################################"									>> $LOG_FILE

while getopts t:j:d:f: argument
do
      case $argument in
          j)WATCH_JOB=$OPTARG;;
          t)ACTION_TYPE=$OPTARG;;
          d)WATCH_DIR=$OPTARG;;
          f)WATCH_FILE=${REBATES_HOME}/${WATCH_DIR}/$OPTARG;;
          *)
            echo "\n Usage: $SCRIPTNAME -j -t -d -f"								>> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -j JOB_ID -t CHECK_START -d DIR_NAME -f FILE_NAME.txt"		>> $LOG_FILE
            echo "\n -j <JobID> Job ID or Name to watch "		>> $LOG_FILE
            echo "\n -t <Type> Either CHECK_START, CHECK_END, START_JOB, or END_JOB" 			>> $LOG_FILE
            echo "\n -d <Directory_Name> Rebates subdirectory"				>> $LOG_FILE
            echo "\n -f <File_Name> file name"				>> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done												>> $LOG_FILE

print "\n"							>> $LOG_FILE
print " Parameter values passed for current run are: "		>> $LOG_FILE
print " Action Type      : $ACTION_TYPE "		>> $LOG_FILE
print " Watch Job ID     : $WATCH_JOB "    	>> $LOG_FILE
print " Watch Directory  : $WATCH_DIR "	    >> $LOG_FILE
print " Watch File       : $WATCH_FILE "	  >> $LOG_FILE
print "\n"							>> $LOG_FILE

if [[ $WATCH_JOB = '' || $ACTION_TYPE = '' || $WATCH_DIR = '' || $WATCH_FILE = '' ]]; then
      RETCODE=1
            echo "\n Usage: $SCRIPTNAME -j -t -d -f"								>> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -j JOB_ID -t CHECK_START -d DIR_NAME -f FILE_NAME.txt"		>> $LOG_FILE
            echo "\n -j <JobID> Job ID or Name to watch "		>> $LOG_FILE
            echo "\n -t <Type> Either CHECK_START, CHECK_END, START_JOB, or END_JOB" 			>> $LOG_FILE
            echo "\n -d <Directory_Name> Rebates subdirectory"				>> $LOG_FILE
            echo "\n -f <File_Name> file name"				>> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
      exit_error ${RETCODE} "Incorrect arguments passed"
fi

#-------------------------------------------------------------------------#
# ACTION TYPE CASE : DETERMINE ACTION TO TAKE
#-------------------------------------------------------------------------#

case $ACTION_TYPE in
	"CHECK_START") #This means to Check if the job has started. If the watch file is missing, then job has started
			if [[ -e $WATCH_FILE ]]; then
		      RETCODE=1
		      print "$WATCH_FILE is found. Job $WATCH_JOB has not started yet!"		>> $LOG_FILE
		      exit_alarm $RETCODE $WATCH_JOB				>> $LOG_FILE
			else
		      print "$WATCH_FILE is not found. $WATCH_JOB started"		>> $LOG_FILE
		      exit_ok 0 
			fi
		;;
                        
	"CHECK_END")#Check if Job has completed. If watch file is found, the job has completed
			if [[ -e $WATCH_FILE ]]; then
		      print "$WATCH_FILE is found. Job $WATCH_JOB has completed"		>> $LOG_FILE
		      exit_ok 0 
			else
					RETCODE=1
		      print "$WATCH_FILE is not found. $WATCH_JOB is still running"		>> $LOG_FILE
		      exit_alarm $RETCODE $WATCH_JOB				>> $LOG_FILE
			fi
		;;

	"START_JOB")# Job has started. Remove watch file if it exists
		      if [[ -e $WATCH_FILE ]]; then
			      print "Action is $ACTION_TYPE. $WATCH_FILE will be removed"		>> $LOG_FILE
		      	rm -f $WATCH_FILE
				      if [[ $? != 0 ]]; then
	         			print "ERROR: Removing $WATCH_FILE "
	         			RETCODE=1
	         			exit_error $RETCODE " Error in deleting watch file $WATCH_FILE"						>> $LOG_FILE
	         		fi
     			fi    
     			exit_ok 0
		   		;;
		
	"END_JOB")# Job has Finished. Create watch file
			    print "Action is $ACTION_TYPE. $WATCH_FILE will be created"		>> $LOG_FILE
		      print "$WATCH_JOB has completed" > $WATCH_FILE
		      if [[ $? != 0 ]]; then
         			print "ERROR: creating $WATCH_FILE "
         			RETCODE=1
         			exit_error $RETCODE " Error in creating watch file $WATCH_FILE"						>> $LOG_FILE
     			fi
     			exit_ok 0
		;;
                        
	"*") # INVALID ACTION TYPE, SEND ERROR
			RETCODE=1
			print "INVALID ACTION TYPE $ACTION_TYPE. PLEASE CHECK CORRECT ACTION TYPES"		>> $LOG_FILE
			exit_error ${RETCODE} "Invalid Action Type"
		;;

esac


