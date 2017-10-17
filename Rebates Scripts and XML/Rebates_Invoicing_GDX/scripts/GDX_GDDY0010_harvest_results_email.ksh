#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDDY0010_harvest_results_email.ksh   
# Title         : Email status of Harvest processing.
#
# Description   : This script will check the status of Harvest for GPO, XMD
#                 or Discount processing, reporting out the number of 
#                 records that need to be processed.
#
#                 NOTE!  This runs differently for GPO,XMD than Discount in 
#                 the fact that Discount jobs will submit this hourly AND
#                 from within the GDX_GDDY0010_actuate_rpt_harvest.ksh
#                 script.  GPO, XMD will only submit this script via the 
#                 above script.
#
# Maestro Job   : GDDY0010 / GD_0034J
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 12-14-05   is00084    6005148   Modified to accomodate Medicare-D changes
# 06-30-05   qcpi733    5998083   Changed code to look for trigger file 
#                                 when input parm is PROCESSING and if file
#                                 is not present, don't send email.
# 05-04-05   qcpi733    5998053   Initial Creation.
# 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
  #      export ALTER_EMAIL_ADDRESS="nandini.namburi@caremark.com"
        export ALTER_EMAIL_ADDRESS=""
        SYSTEM="QA"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        SYSTEM="PRODUCTION"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="nandini.namburi@caremark.com"
    SYSTEM="DEVELOPMENT"
fi

RETCODE=0
#Capture input here for use in FILE_BASE variable.
#  turn the Model Type input into uppercase
MODEL_TYP_CD=$(echo $1|dd conv=ucase 2>/dev/null)
STATUS=$2
REPORT_TYPE=$3
TOT_HARVEST_CNT=$4

SCHEDULE="GDDY0010"
JOB=""
FILE_BASE="GDX_"$SCHEDULE"_harvest_results_email_"$MODEL_TYP_CD
# LOG FILES 
LOG_FILE_ARCH=$FILE_BASE".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_ARCH
SCRIPTNAME=$FILE_BASE".ksh"
# Output files
EMAIL_ARCHIVE=$OUTPUT_ARCH_PATH/$FILE_BASE"_archived.txt"`date +"%Y%j%H%M"`
# Input files
REBATE_REPORT_DIR=""
MKTSHR_REPORT_DIR=""
REBATE_RPT_CNT=0
MKTSHR_RPT_CNT=0
EMAIL_SUBJECT=""
EMAIL_BODY=$OUTPUT_PATH/$FILE_BASE"_body.txt"
# Put date in format of 12 hr:minutes:seconds am/pm on Abbrv Month Day, 4 digit year. The double quotes
#    allows for extra fields without having to redo the date command.
EMAIL_DATE=`date +"%l:%M:%S %p %Z on %b %e, %Y"`

# Cleanup from previous run
rm -f $LOG_FILE
rm -f $EMAIL_BODY

# Script requires only 2 parameters to be passed, others are optional.
if [[ $# -lt 2 ]]; then 
    print "Error receiving input parameters.  Did not receive input parms"     >> $LOG_FILE
    print "  as expected:  "                                                   >> $LOG_FILE
    print "MODEL_TYP_CD = >$MODEL_TYP_CD<"                                     >> $LOG_FILE
    print "STATUS       = >$STATUS<"                                           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Script will abend."                                                 >> $LOG_FILE
    RETCODE=1    
else
    cat $INPUT_PATH/$FILE_BASE"_TO_list.txt"|read EMAIL_TO_LIST
    cat $INPUT_PATH/$FILE_BASE"_CC_list.txt"|read EMAIL_CC_LIST
    cat $INPUT_PATH/$FILE_BASE"_FROM_list.txt"|read EMAIL_FROM_LIST
    #Read in what the email file is going to be called.  The email is saved to a file based on 
    #  the TO addressess.  Use this to move the file to an archive at the end.
    cat $INPUT_PATH/$FILE_BASE"_TO_list.txt"|read EMAIL_ARCHIVE_NAME
    #-------------------------------------------------------------------------#
    # Starting the script to Harvest the Actuate files
    #-------------------------------------------------------------------------#
    print `date`                                                               >> $LOG_FILE
    print "Starting the script to email Harvest status."                       >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# First capture the input parameters.
#-------------------------------------------------------------------------#
 
if [[ $RETCODE = 0 ]]; then 

#    if [[ $STATUS = "" ]]; then 
#        STATUS="Current Processing Status"
#    fi
    #change REPORT_TYPE to title case if all lower or all upper

    case $MODEL_TYP_CD in 
        "G" )
            #model is GPO
            MODEL="GPO"
            INPUT_TRG_HOME=$INPUT_PATH"/GPOHarvest"
            REBATE_REPORT_DIR=$INPUT_TRG_HOME"/Rebate"
            MKTSHR_REPORT_DIR="INVALID" ;;
        "D" )
            #model is Discount
            MODEL="Discount"
            INPUT_TRG_HOME=$INPUT_PATH"/DISHarvest"
            REBATE_REPORT_DIR=$INPUT_TRG_HOME"/Rebate"
            MKTSHR_REPORT_DIR=$INPUT_TRG_HOME"/Marketshare" ;;
        "X" )
            #model is XMD
            MODEL="XMD"
            INPUT_TRG_HOME=$INPUT_PATH"/XMDHarvest"
            REBATE_REPORT_DIR=$INPUT_TRG_HOME"/Rebate"
            MKTSHR_REPORT_DIR="INVALID" ;;            
        * )
            print "Error - invalid MODEL_TYP_CD passed in. Value must be "     >> $LOG_FILE
            print "  D for Discount or G for GPO or X for XMD."                >> $LOG_FILE
            print "Script will abend."                                         >> $LOG_FILE
            RETCODE=1 ;;
    esac
    MODEL_UCASE=$(echo $MODEL|dd conv=ucase 3>/dev/null)
    #this job is run hourly, but also needs this trigger to run.  Need to delete at end.
    MAESTRO_TRG_FILE=$INPUT_TRG_HOME/$MODEL"_Harvest_Running.trg"
    
    if [[ "$STATUS" = "Completed" || "$STATUS" = "Starting" ]]; then
        EMAIL_SUBJECT=$MODEL" "$REPORT_TYPE" Harvest "$STATUS`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
    else
        if [[ $MODEL_TYP_CD = "G" || $MODEL_TYP_CD = "X" ]]; then 
            #Add report type to subject when STATUS = Processing
            EMAIL_SUBJECT=$MODEL" "$REPORT_TYPE" Harvest "$STATUS`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
        else
            #Add report type to subject when STATUS = Processing
            EMAIL_SUBJECT=$MODEL" Harvest "$STATUS`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
        fi
    fi
fi    

if [[ $STATUS = "Processing" ]]; then
    if [[ -f $MAESTRO_TRG_FILE ]]; then 
        print "Status = $STATUS and the trigger file exists, send email."      >> $LOG_FILE
    else
        #make the script skip the rest of the logic and dont send an email.
        RETCODE=9999
    fi
fi

print " "                                                                      >> $LOG_FILE
print "=============================================================="         >> $LOG_FILE
print " "                                                                      >> $LOG_FILE



if [[ $RETCODE != 0 ]]; then 
    print "Bypassing Report counts because of previous error."                 >> $LOG_FILE
else

    print "\n***************** $SYSTEM HARVESTING UPDATE *****************"                                  >> $EMAIL_BODY
    print "***************************** FOR $MODEL_UCASE ***************************\n"                                  >> $EMAIL_BODY
    #Get the counts of the Rebate Reports for the email, and build this section of the email
    # put date in 

    if [[ $REPORT_TYPE = "Rebate" || $STATUS = "Processing" ]]; then
        #note that the -1tr is a one not an L
        print "REBATE STATUS AS OF $EMAIL_DATE:"                                                                        >> $EMAIL_BODY
        cd $REBATE_REPORT_DIR
        # Do a list on the directory putting the results in a single (1) column, then do a word count based on lines,
        #    then read that line count into the variable.
        ls -1tr|wc -l|read REBATE_RPT_CNT

        if [[ $REBATE_RPT_CNT = 0 ]]; then
            if [[ $STATUS = "Completed" ]]; then
                print "\tTotal Rebate Reports Harvested - $TOT_HARVEST_CNT   OK to Allocate $MODEL Rebate ONLY!\n"                  >> $EMAIL_BODY
                print "***********************************************************************************\n"                                >> $EMAIL_BODY
                print "\tLET THE ALLOCATION BEGIN (if you do not need to run more reports)!!\n\n"                           >> $EMAIL_BODY
            else
                print "\t$REBATE_RPT_CNT - Number of Rebate Files.  OK to Allocate $MODEL Rebates ONLY!\n"                  >> $EMAIL_BODY
            fi
        else
            print "\t$REBATE_RPT_CNT - Number of Rebate Files left to harvest!\n"                                       >> $EMAIL_BODY
            print "\tDO NOT ALLOCATE $MODEL_UCASE REBATES!\n"                                                                        >> $EMAIL_BODY
            print "\tAllocation for $REPORT_TYPE can NOT begin until Harvesting is completed!!\n"                                         >> $EMAIL_BODY
            print "\t\tPLEASE BE PATIENT!!\n"                                                                         >> $EMAIL_BODY
            print "\t\tHARVESTING MUST COMPLETE!!\n\n"                                                                  >> $EMAIL_BODY
        fi
    fi

    #Check for Market Share reports, but only for Discount
    if [[ $MODEL_TYP_CD = 'D' && ($REPORT_TYPE = "Marketshare" || $STATUS = "Processing") ]]; then
        # Get the counts of the Market Share reports for the email, and build this section of the email.
        print "MARKET SHARE STATUS AS OF $EMAIL_DATE:"                                                                    >> $EMAIL_BODY

        #note that the -1tr is a one not an L
        cd $MKTSHR_REPORT_DIR
        # Do a list on the directory putting the results in a single (1) column, then do a word count based on lines,
        #    then read that line count into the variable.
        ls -1tr|wc -l|read MKTSHR_RPT_CNT

        if [[ $MKTSHR_RPT_CNT = 0 ]]; then
            if [[ $STATUS = "Completed" ]]; then
                print "\tTotal Market Share Reports Harvested - $TOT_HARVEST_CNT   OK to Allocate $MODEL Market Share ONLY!\n"   >> $EMAIL_BODY
                print "***********************************************************************************\n"                                >> $EMAIL_BODY
                print "\tLET THE ALLOCATION BEGIN (if you do not need to run more reports)!!\n\n"                           >> $EMAIL_BODY
            else
                print "\t$MKTSHR_RPT_CNT - Number of Market Share Files.  OK to Allocate $MODEL Market Share ONLY!\n"   >> $EMAIL_BODY
            fi
        else
            print "\t$MKTSHR_RPT_CNT - Number of Market Share Files left to harvest!\n"                             >> $EMAIL_BODY
            print "\tDO NOT ALLOCATE DISCOUNT MARKET SHARE!\n"                                                               >> $EMAIL_BODY
            print "\tAllocation for $REPORT_TYPE can NOT begin until Harvesting is completed!!\n"                                         >> $EMAIL_BODY
            print "\t\tPLEASE BE PATIENT!!\n"                                                                         >> $EMAIL_BODY
            print "\t\tHARVESTING MUST COMPLETE!!\n\n"                                                                  >> $EMAIL_BODY
        fi
    fi

    #Dont send out an email if there are no reports in either process, unless STATUS="Completed".
    if [[ $REBATE_RPT_CNT > 0 || $MKTSHR_RPT_CNT > 0 || $STATUS = "Completed" ]]; then

        if [[ $REGION = "test" ]]; then
            print "\n\nThis run occured in the DEVELOPMENT region."                                                     >> $EMAIL_BODY
        else
            print "\n\nThis run occured in the PRODUCTION region."                                                     >> $EMAIL_BODY
        fi

        #Email parms set at top of script, and in above case.  Subject (-s) must be in quotes if spaces are in the subject.
        cd $INPUT_PATH
        mailx -F -r $EMAIL_FROM_LIST -c $EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $EMAIL_TO_LIST < $EMAIL_BODY 

        # The mailx -F parm puts the email into a filename based on the first TO person.  Move this file to the
        #    output dir.
        mv -f $EMAIL_ARCHIVE_NAME $EMAIL_ARCHIVE  >> $LOG_DIR
    else
        print "No email to send, no Reports to count!"                         >> $LOG_FILE
    fi
fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
 
if [[ $RETCODE != 0 ]]; then
    if [[ $RETCODE = 9999 ]]; then
        #script was submitted from the hourly status job, but there was not a trigger file
        #  present, so we didn't want to do anything.  Dont abend, but dont write a log either.
        rm -f $LOG_FILE
        #reset the return code for the exit
        RETCODE=0
    else
        #script was supposed to send email, but an error occurred.

        EMAILPARM4="  "
        EMAILPARM5="  "

        . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
        cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`
    fi
    exit $RETCODE
fi

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`

rm -f $EMAIL_BODY
# DO NOT REMOVE THE MAESTRO_TRG_FILE - script that created it will handle the removal
return $RETCODE

