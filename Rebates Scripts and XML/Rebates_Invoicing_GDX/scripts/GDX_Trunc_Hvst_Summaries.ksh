#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_Trunc_Hvst_Summaries.ksh
# Title         :
#
# Description   : Queries the THARVEST_QUE and looks for ETL_APPL_STUS_CD
#                 where there is an error or an ETL in progress moving 
#                 data from the Harvest summaries into the TRBI database.
#                 When no process is running and no harvests are in error
#                 then truncate the two Harvest summary tables:
#                 VRAP.TMKTSHR_RPT_SUM and VRAP.TDISCNT_RBAT_RPT_SUM
#                 
# Maestro Job   : RDWKSUN1 RD_1462J
#
# Parameters    : None
#
# Output        : Log file as $LOG_DIR/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-13-13   qcpi733     Initial Creation for ITPR0001971
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh

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

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}

# Region specific variables
   if [[ $REGION = "prod" ]];   then
      if [[ $QA_REGION = "true" ]];   then
        export ALTER_EMAIL_TO_ADD="gdxsittest@caremark.com"
        EMAIL_TO_ADD="gdxsittest@caremark.com"
        SYSTEM="QA"
      else
        export ALTER_EMAIL_TO_ADD=""
        EMAIL_TO_ADD="gdxitd@caremark.com"
        SYSTEM="PRODUCTION"
      fi
   else
        export ALTER_EMAIL_TO_ADD="randy.redus@caremark.com"
        EMAIL_TO_ADD="randy.redus@caremark.com"
        SYSTEM="DEVELOPMENT"
   fi

# Variables and temp files
RETCODE=0
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"

EMAIL_SUB="System cannot truncate Harvest Summaries"
EMAIL_BODY=$OUTPUT_PATH/$SCRIPTNAME"_email_body.txt"
rm -f $EMAIL_BODY
print "Informational mostly, but if repeatedly occurring each week research "  >> $EMAIL_BODY
print "should ensue. \n\nThe GDX UNIX script was not able to truncate the "    >> $EMAIL_BODY
print "Harvest summary tables because it found there were ETL_APPL_STAT_CD "   >> $EMAIL_BODY
print "values of 0 (new meaning Harvest was running), or 1 (waiting for "      >> $EMAIL_BODY
print "Harvest to run), or 2 (ETL is running - this should not occur because " >> $EMAIL_BODY
print "of Maestro resource assignments), or 99 (error occurred in ETL and "    >> $EMAIL_BODY
print "has not been set to 1 (forces ETL to retry) or 100 (fix is to rerun "   >> $EMAIL_BODY
print "harvest).  \n\nIf there are THARVEST_QUE.ETL_APPL_STUS_CD values of "   >> $EMAIL_BODY
print "99, these need to be researched and rest to 1 or 100, otherwise this "  >> $EMAIL_BODY
print "truncate script will never issue the truncate."                         >> $EMAIL_BODY
print "\n\n--------------------"                                               >> $EMAIL_BODY
print "This email was generated from $SCRIPTNAME on the GDX box when the "     >> $EMAIL_BODY
print "script was unable to issue the truncate."                               >> $EMAIL_BODY
print "Scripts directory: $SCRIPTS_DIR"                                        >> $EMAIL_BODY

SQL_FILE=$SQL_PATH/$FILE_BASE"_THARVEST_QUE.sql"
DATA_FILE=$OUTPUT_PATH/$FILE_BASE"_THARVEST_QUE_out.dat"

rm -f $SQL_FILE
rm -f $DATA_FILE
rm -f $TODAYS_DATE_FILE

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print " "
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   }                                                                           > $LOG_FILE

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

print "Connecting to GDX database......"                                       >> $LOG_FILE
db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"              >> $LOG_FILE
RETCODE=$?
print "Connect to $DATABASE: RETCODE=<" $RETCODE ">"                           >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then
    print "ERROR: couldn't connect to database......"                          >> $LOG_FILE
    exit_error $RETCODE
fi

# If there are THARVEST_QUE.HVST_GID rows where the ETL_APPL_STUS_CD values reflect 
#   that the ETL is running (value 2) or 99 (error, fix not complete), then the 
#   truncate cannot run.

SQL_FILE="select count(*) from VRAP.tharvest_que where ETL_APPL_STUS_CD not in (3,100)"

print " "                                                                      >> $LOG_FILE
print "SQL to run: $SQL_FILE"                                                  >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

db2 -x $SQL_FILE > $DATA_FILE
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print " "                                                                  >> $LOG_FILE
    print "ERROR: Select of row count from THARVEST_QUE"                       >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print $SQL_FILE                                                            >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Return code is : <" $RETCODE ">"                                    >> $LOG_FILE
    exit_error $RETCODE
fi
 
read row_cnt < $DATA_FILE
 
print " "                                                                      >> $LOG_FILE
print "Count returned: $row_cnt"                                               >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

# If the count returned is > 0 then cannot issue the truncate.  Simply complete the script.

if [[ $row_cnt -gt 0 ]]; then
    print " "                                                                  >> $LOG_FILE
    print "Cannot issue the truncate, email sent "                             >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    # Send email to group that the truncate did not run
    #quotes around the EMAIL_SUBJECT are required to preserve spaces in the subject
    mailx -s "$EMAIL_SUB"  $EMAIL_TO_ADD < $EMAIL_BODY
else
    print " "                                                                  >> $LOG_FILE
    print "All THARVEST_QUE rows are in ETL complete or 100 error status "     >> $LOG_FILE
    print "Issue the truncates"                                                >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    #Issue the truncate
    TRUNC_SQL="import from /dev/null of del replace into VRAP.TDISCNT_RBAT_RPT_SUM"

    db2 -stvxw $TRUNC_SQL                                                      >> $LOG_FILE
    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
        print " "                                                              >> $LOG_FILE
        print "ERROR: Could not complete truncation:"                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print $TRUNC_SQL                                                       >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Return code is : <" $RETCODE ">"                                >> $LOG_FILE
        exit_error $RETCODE
    fi

    TRUNC_SQL="import from /dev/null of del replace into VRAP.TMKTSHR_RPT_SUM"

    db2 -stvxw $TRUNC_SQL                                                      >> $LOG_FILE
    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
        print " "                                                              >> $LOG_FILE
        print "ERROR: Could not complete truncation:"                          >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print $TRUNC_SQL                                                       >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Return code is : <" $RETCODE ">"                                >> $LOG_FILE
        exit_error $RETCODE
    fi
fi #end row_cnt check

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
{
    print "********************************************"
    print "Finishing the script $SCRIPTNAME ......"
    print `date +"%D %r %Z"`
    print "Final return code is : <" $RETCODE ">"
    print " "
}                                                                              >> $LOG_FILE

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

rm -f $EMAIL_BODY
rm -f $SQL_FILE
rm -f $DATA_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH

exit $RETCODE
 
