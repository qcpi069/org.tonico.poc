#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_RIOR4500_build_tapc_claims_data.ksh
# Title         :
#
# Description   : Build APC Claims table for GPO, DSC and XMD 
#
# Maestro Job   : RIOR4500
#
# Parameters    : model_name: gpo, dsc or xmd  
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-12-16   qcpue98u    Modified e-mail id values for prod region 
# 07-28-09   qcpi733     Added GDX APC status update
# 12-21-07   qcpi733     Added logic to compare VCLAIM with TDISCNT_EXT_CLAIM
#                        in order to identify claims that were moved from
#                        one model to another, after they were invoiced.
# 11-02-07   qcpi08a     Initial Creation
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
    }                                                                          >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    . `dirname $0`/Common_GDX_APC_Status_update.ksh $PROCESS_ID ERR
   
    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    
    exit $RETCODE
}

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="QA"
        export ALTER_EMAIL_TO_ADDY="GDXITD@caremark.com"
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXAPC@Caremark.com"
#        EMAIL_TO_ADDY="randy.redus@Caremark.com"
    else
        # Running in Prod region
        SYSTEM="PRODUCTION"
        export ALTER_EMAIL_TO_ADDY="GDXITD@caremark.com"
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXAPC@caremark.com"
    fi
else
    ##########TESTING ONLY############
    # Running in Development region
    SYSTEM="DEVELOPMENT"
    export ALTER_EMAIL_TO_ADDY =="randy.redus@caremark.com"
    EMAIL_FROM_ADDY=$ALTER_EMAIL_TO_ADDY
# uncomment to send test emails to users
    EMAIL_TO_ADDY="randy.redus@caremark.com"
    EMAIL_TO_ADDY=$ALTER_EMAIL_TO_ADDY
fi
 
# Variables
RETCODE=0
JOB="Shared script"
SCHEDULE="RIOR4500"

MODEL=$(echo $1 | dd conv=ucase 2>/dev/null)
MODEL_TYP_CD=$(echo $2 |dd conv=ucase 2>/dev/null)
PROCESS_ID=$3
QUARTER_ID=$4

trunctable="VRAP.TAPC_CLAIMS_${MODEL}"

print $MODEL
print $MODEL_TYP_CD
print $PROCESS_ID
print $QUARTER_ID

FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"
PERIOD_SQL=$SQL_PATH/$FILE_BASE"_period.sql"
INS_SQL=$SQL_PATH/$FILE_BASE".sql"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}_${MODEL}.log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}_${MODEL}.log"

rm -f $LOG_FILE


#-------------------------------------------------------------------------#
# Substitute variable in the sql files
#-------------------------------------------------------------------------#

  function replace {
        typeset _template="$1"
        eval "$(echo 'cat <<END_TEMPLATE_KSH_${$}'; cat ${_template}; echo; echo 'END_TEMPLATE_KSH_${$}';)"
  }

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   } > $LOG_FILE

#-------------------------------------------------------------------------#
# Check passing parameter
#-------------------------------------------------------------------------#

if [[ $# < 3 ]] || [[ $# > 4 ]]; then
        print "Usage: $0 <model> <model type> <process id> [quarter]"
        print "Usage: $0 <model> <model type> <process id> [quarter]"           >> $LOG_FILE
        exit_error 1
fi

. `dirname $0`/Common_GDX_APC_Status_update.ksh $PROCESS_ID STRT

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >> $LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >> $LOG_FILE
   RETCODE=$?
   print "Connect to $DATABASE: RETCODE=<" $RETCODE ">"                        >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......"                        >> $LOG_FILE
      exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Decide QUARTER_ID. Check if its passed as argument else fetch from DB
#-------------------------------------------------------------------------#
    
   if [[ -z $QUARTER_ID ]]; then
      #Query database to fetch QUARTER_ID   
      print "QUARTER_ID not passed as argument.  "  >> $LOG_FILE
      print "Querying database to fetch QUARTER_ID.... "  >> $LOG_FILE
      
      sql="SELECT CAST(QUARTER_ID AS CHAR(6)) FROM VRAP.TCUR_INV_PRD WITH UR"
      echo "$sql"  >>$LOG_FILE
      sql=$(echo "$sql" | tr '\n' ' ')
      
      db2 -px "$sql" | read QUARTER_ID
      RETCODE=$?
      print ' RETCODE=<'$RETCODE'>'>> $LOG_FILE
      
      if [[ $RETCODE = 0 ]]; then
        print " " >> $LOG_FILE
        print "QUARTER_ID info found in VRAP.TCUR_INV_PRD. " >> $LOG_FILE
        print "QUARTER_ID being used is " $QUARTER_ID >> $LOG_FILE
        print " " >> $LOG_FILE
      else
        print " " >> $LOG_FILE
        print "QUARTER_ID information not available for further processing. " >> $LOG_FILE
        exit_error $RETCODE
        print " " >> $LOG_FILE
      fi
   else
      print "QUARTER_ID = $QUARTER_ID passed as argument. "
      print "QUARTER_ID = $QUARTER_ID passed as argument. "  >> $LOG_FILE
   fi

cat > $PERIOD_SQL << EOFSQL

      SELECT QUARTER_ID, CHAR(PERIOD_BEGIN_DT, USA), CHAR(PERIOD_END_DT, USA)
        FROM VRAP.TDISCNT_PERIOD
       WHERE QUARTER_ID = '$QUARTER_ID' 
         AND PERIOD_LEVEL = 'QUARTER'
        WITH UR;

EOFSQL

#-------------------------------------------------------------------------#
# Get quarter id, period begin and end date from GDX 
#-------------------------------------------------------------------------#

   print "Get quarter id, period begin and end date from GDX"                   >> $LOG_FILE
   OUTPUT_PERIOD=$(db2 -stxf $PERIOD_SQL)
   RETCODE=$?
   print "Get quarter, RETCODE: RETCODE=<" $RETCODE ">"                         >> $LOG_FILE

   if [[ $RETCODE > 1 ]]; then
       print " "                                                                >> $LOG_FILE
       print "Error: select quarter, begin and end dates...... "                >> $LOG_FILE
       exit_error $RETCODE
   else
       if [[ $RETCODE = 1 ]]; then
          print " "                                                             >> $LOG_FILE
          print "No quarter found to process from VRAP.TDISCNT_PERIOD. "        >> $LOG_FILE
          exit_error $RETCODE
          print " "                                                             >> $LOG_FILE
       else
          print " "                                                             >> $LOG_FILE
          print "Quarter found to process from VRAP.TDISCNT_PERIOD "            >> $LOG_FILE
          print "$OUTPUT_PERIOD" | read QUARTER_ID PERIOD_BEGIN_DT PERIOD_END_DT
          print "QUARTER_ID is " $QUARTER_ID                                    >> $LOG_FILE
          print "begin date is " $PERIOD_BEGIN_DT                               >> $LOG_FILE
          print "end date is " $PERIOD_END_DT                                   >> $LOG_FILE
          print " "                                                             >> $LOG_FILE
       fi
    fi

#-------------------------------------------------------------------------#
# Truncate table 
#-------------------------------------------------------------------------#

   print "Truncate table $trunctable"                                          >> $LOG_FILE
   TRUNC_SQL="import from /dev/null of del replace into $trunctable"
   db2 -stvxw $TRUNC_SQL                                                       >> $LOG_FILE
   RETCODE=$?
   print "Truncate table, RETCODE: RETCODE=<" $RETCODE ">"                     >> $LOG_FILE

   if [[ $RETCODE > 1 ]]; then
       print " "                                                               >> $LOG_FILE
       print "Error: truncate table $trunctable...... "                        >> $LOG_FILE
       exit_error $RETCODE
       print " "                                                               >> $LOG_FILE
   fi

#-------------------------------------------------------------------------#
# Insert APC Claims Data 
#-------------------------------------------------------------------------#

  print "Insert rows for APC Claims table "                                    >> $LOG_FILE
print `date +"%D %r %Z"` >> $LOG_FILE
   SQL_FILE="${INS_SQL}.tmp.${$}"
  replace $INS_SQL > $SQL_FILE
  cat $SQL_FILE                                                                >> $LOG_FILE
  db2 -stvxwf $SQL_FILE                                                        >> $LOG_FILE
  RETCODE=$?
print `date +"%D %r %Z"` >> $LOG_FILE

  rm -f $SQL_FILE

  print "Insert table, RETCODE: RETCODE=<" $RETCODE ">"                        >> $LOG_FILE
                                        
  if [[ $RETCODE > 1 ]]; then
      print " "                                                                >> $LOG_FILE
      print "Error: insert APC Claims Data...... "                             >> $LOG_FILE
      print " "                                                                >> $LOG_FILE
      exit_error $RETCODE
  else
      #rm -f $SQL_FILE
      print " "                                                                >> $LOG_FILE
      print "Successfully inserted rows "                                      >> $LOG_FILE
      print "If RETCODE == 1, no rows were inserted"                           >> $LOG_FILE
      RETCODE=0
  fi


##############################
## ONLY RUN FOR GDX MODELS! ##
##############################
if [[ $MODEL == "RXMAX" ]]; then
    #skip this entire section, down to below the email
    print " "                                                                  >> $LOG_FILE
    print "Skipping the check for missing VCLAIM claims. $MODEL is not a "     >> $LOG_FILE
    print "GDX model. "                                                        >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    #-------------------------------------------------------------------------#
    # Check locked report data in TDISCNT_EXT_CLAIM_$MODEL to see if any of 
    #   the core claims were not available in VCLAIM_$MODEL to build the 
    #   proper APC claim record in TAPC_CLAIM_$MODEL.
    #-------------------------------------------------------------------------#

    UDB_EXPORT_CLAIM_CHECK_COLHDRS=$OUTPUT_PATH/$FILE_BASE"_missing_claim_data_colhdrs.dat"
    UDB_EXPORT_CLAIM_CHECK=$OUTPUT_PATH/$FILE_BASE"_missing_claim_data.dat"
    CLAIM_CHECK_RESULTS_MSG=$OUTPUT_PATH/$FILE_BASE"_missing_claim_findings.txt"
    ITD_EMAIL_INFO=$OUTPUT_PATH/$FILE_BASE"_email_itd_info.txt"
    MAILFILE=$OUTPUT_PATH/$FILE_BASE"_email_body.txt"

    rm -f $UDB_EXPORT_CLAIM_CHECK_COLHDRS
    rm -f $UDB_EXPORT_CLAIM_CHECK
    rm -f $CLAIM_CHECK_RESULTS_MSG
    rm -f $ITD_EMAIL_INFO
    rm -f $MAILFILE 
   touch $ITD_EMAIL_INFO
    UDB_CLAIM_CHECK_SQL="export to $UDB_EXPORT_CLAIM_CHECK of del modified by coldel| "
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL"SELECT EXT.RPT_ID,EXT.HVST_ID,CAST(SUM((EXT.BASE_DISCNT_AMT+EXT.FRMLY_DISCNT_AMT+"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL"EXT.CNTRCT_DISCNT_AMT+EXT.PRC_PTCT_DISCNT_AMT)) AS DECIMAL(10,2)) PMT_ACC_DISCNT_AMT"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL",CAST(SUM(EXT.PRFMC_DISCNT_AMT) AS DECIMAL(10,2)) PMT_PRFMC_DISCNT_AMT"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL",CAST(SUM(EXT.ADMN_DISCNT_AMT) AS DECIMAL(10,2)) PMT_ADMN_DISCNT_AMT"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL" FROM VRAP.TDISCNT_APC_RPT TAR, VRAP.TDISCNT_EXT_CLAIM_$MODEL EXT LEFT JOIN"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL" VRAP.VCLAIM_$MODEL CLM ON EXT.CLAIM_ID = CLM.CLAIM_ID AND CLM.INV_ELIG_DT"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL" BETWEEN '$PERIOD_BEGIN_DT' AND '$PERIOD_END_DT' WHERE TAR.QUARTER_ID = $QUARTER_ID"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL" AND TAR.MODEL_TYP_CD = '$MODEL_TYP_CD' AND EXT.HVST_ID = TAR.HVST_ID"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL" AND EXT.PERIOD_ID = TAR.PERIOD_ID AND EXT.DISCNT_RUN_MODE_CD = TAR.DISCNT_RUN_MODE_CD"
    UDB_CLAIM_CHECK_SQL=$UDB_CLAIM_CHECK_SQL" AND CLM.CLAIM_ID IS NULL GROUP BY EXT.RPT_ID,EXT.HVST_ID WITH UR"

    print $UDB_CLAIM_CHECK_SQL                                                     >>$LOG_FILE
    db2 -stvx $UDB_CLAIM_CHECK_SQL                                                 >>$LOG_FILE

    RETCODE=$?

    print " "                                                                      >> $LOG_FILE
    print "Export RETCODE=<"$RETCODE">"                                            >> $LOG_FILE
    print " "                                                                      >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "ERROR: Step 4 abend, having problem checking and exporting dups."   >> $LOG_FILE
        exit_error $RETCODE
    else
        print "********************************************"                       >> $LOG_FILE
        print "Step 4 - Export of dups in $UDB_LOAD_TABLE_NAME - Completed ..."    >> $LOG_FILE
        print "********************************************"                       >> $LOG_FILE
    fi

    print " "                                                                      >> $LOG_FILE

    wc -l $UDB_EXPORT_CLAIM_CHECK | read EXPORT_DATA_ROWCOUNT JUNK

    RETCODE=$?

    print " "                                                                      >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "ERROR: Having problem counting the rows in the "                    >> $LOG_FILE
        print "$UDB_CLAIM_CHECK_SQL file."                                         >> $LOG_FILE
        exit_error $RETCODE
    else
        if [[ $EXPORT_DATA_ROWCOUNT -gt 0 ]]; then 
            EMAIL_SUBJECT="APC-$(echo $SYSTEM|dd conv=ucase 2>/dev/null) $QUARTER_ID-WARNING-Claims moved from $MODEL to another model after being invoiced"
            print "\nWARNING: While building the VRAP.TAPC_CLAIMS_$MODEL table"    >> $CLAIM_CHECK_RESULTS_MSG
            print "there were claims in VRAP.TDISCNT_EXT_CLAIM_$MODEL (rebated)"   >> $CLAIM_CHECK_RESULTS_MSG
            print "that were not found in VRAP.VCLAIM_$MODEL.  This occurs when"   >> $CLAIM_CHECK_RESULTS_MSG
            print "the claim was rebated and report locked, but then the claims"   >> $CLAIM_CHECK_RESULTS_MSG
            print "model was changed from $MODEL to another."                      >> $CLAIM_CHECK_RESULTS_MSG
            print "\nBecause a record in VCLAIM_$MODEL could not be found, we"     >> $CLAIM_CHECK_RESULTS_MSG
            print "could not find all of the necessary data to build the"          >> $CLAIM_CHECK_RESULTS_MSG
            print "TAPC_CLAIMS_$MODEL record."                                     >> $CLAIM_CHECK_RESULTS_MSG
            print "\nBelow you will find the summary information on claims that"   >> $CLAIM_CHECK_RESULTS_MSG
            print "were missing, pipe delimited, including column headers."        >> $CLAIM_CHECK_RESULTS_MSG
            print "\nPlease notify GDXITD if we need to stop the APC process,"     >> $CLAIM_CHECK_RESULTS_MSG
            print "as this error has not stopped the process.\n\n"                 >> $CLAIM_CHECK_RESULTS_MSG

            print "\n\n\n\nITD info:\n\tJob: $JOB\n\tSchedule: $SCHEDULE"          >> $ITD_EMAIL_INFO
            print "\tScript: $SCRIPT_PATH/$SCRIPTNAME"                             >> $ITD_EMAIL_INFO
            print "\tSystem: $(echo $GDX_ENV_SETTING|dd conv=ucase 2>/dev/null)"   >> $ITD_EMAIL_INFO
            print "\tLog file: $LOG_FILE_ARCH"                                     >> $ITD_EMAIL_INFO

            print "RPT_ID|HVST_ID|PMT_ACC_DISCNT_AMT|PMT_PRFMC_DISCNT_AMT|PMT_ADMN_DISCNT_AMT" >> $UDB_EXPORT_CLAIM_CHECK_COLHDRS
        else
            EMAIL_SUBJECT="APC-$(echo $SYSTEM|dd conv=ucase 2>/dev/null) $QUARTER_ID VRAP.TAPC_CLAIMS_$MODEL loaded without issues"
            print "\nWe checked for claims that moved from $MODEL to another"      >> $CLAIM_CHECK_RESULTS_MSG
            print "model after they were included in a report and locked.  If"     >> $CLAIM_CHECK_RESULTS_MSG
            print "any claims were moved, they would not have been found in"       >> $CLAIM_CHECK_RESULTS_MSG
            print "VCLAIM_$MODEL."                                                 >> $CLAIM_CHECK_RESULTS_MSG
            print "\nAll $MODEL claims with rebates were found in VCLAIM_$MODEL."  >> $CLAIM_CHECK_RESULTS_MSG
            # empty out the following two files used in the duplicate identified email
            print " "                                                              >> $UDB_EXPORT_CLAIM_CHECK_COLHDRS
            print " "                                                              >> $UDB_EXPORT_CLAIM_CHECK
        fi
        cat $CLAIM_CHECK_RESULTS_MSG                                               >> $LOG_FILE
    fi

    print " "                                                                      >> $LOG_FILE

    #-------------------------------------------------------------------------#
    # Send notification of load.                  
    #-------------------------------------------------------------------------#

    print "\nLoad of the VRAP.TAPC_CLAIMS_$MODEL table for $QUARTER_ID has just"   >> $MAILFILE
    print "completed."                                                             >> $MAILFILE
    cat $CLAIM_CHECK_RESULTS_MSG                                                   >> $MAILFILE
    cat $UDB_EXPORT_CLAIM_CHECK_COLHDRS                                            >> $MAILFILE
    cat $UDB_EXPORT_CLAIM_CHECK                                                    >> $MAILFILE
    cat $ITD_EMAIL_INFO                                                            >> $MAILFILE
    print "\n\n------END OF EMAIL BODY----------------------------------"          >> $MAILFILE

    chmod 777 $MAILFILE

    mailx -r $EMAIL_FROM_ADDY -s "$EMAIL_SUBJECT" $EMAIL_TO_ADDY < $MAILFILE

    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
        print " "                                                                  >> $LOG_FILE
        print "================== J O B  A B E N D E D ======="                    >> $LOG_FILE
        print "  Error sending email to Business "                                 >> $LOG_FILE
        print "  Look in " $LOG_FILE                                               >> $LOG_FILE
        print "==============================================="                    >> $LOG_FILE
                exit_error 999
    else
        print "********************************************"                       >> $LOG_FILE
        print "Email sucessfully sent to : " $EMAIL_TO_ADDY                        >> $LOG_FILE
        print "********************************************"                       >> $LOG_FILE
        print " "                                                                  >> $LOG_FILE
    fi   
fi

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
{
    print "********************************************"
    print "Finishing the script $SCRIPTNAME ......"
    print `date +"%D %r %Z"`
    print "Final return code is : <" $RETCODE ">"
}  >> $LOG_FILE


# Update the GDX APC status
  . `dirname $0`/Common_GDX_APC_Status_update.ksh $PROCESS_ID END                 >> $LOG_FILE

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

mv -f $LOG_FILE $LOG_FILE_ARCH

exit $RETCODE
 
