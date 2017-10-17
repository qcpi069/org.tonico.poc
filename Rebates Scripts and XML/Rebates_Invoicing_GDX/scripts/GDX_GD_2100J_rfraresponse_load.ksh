#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_GD_2100J_rfraresponse_load.ksh    
# Title         : Load the rfraresponse file into the vrap.trfra_rsp table
#                 
#
# Description   : This script loads a fixed length ASCII file from 
#                 the rfra process which runs on DMADOM4.  
#                 The file will be loaded into Rebate GDX table: 
#                         VRAP.TRFRA_RSP 
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
# 08-10-07   is31701     Added new step to load the PHC Frmly/Drug info
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
# Function to ftp the file from DMADOM4 to GDX
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
JOB="GD_2100J"
SCRIPTNAME="GDX_GD_2100J_rfraresponse_load.ksh"

# LOG FILES
LOG_FILE_ARCH=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE_NM=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_NM

DB2_MSG_FILE=$LOG_FILE.load

INPUT_FILE=$GDX_PATH/input/rfraresponse.txt
FTP_FILE_NAME="rfraresponse.txt.gz"
FTP_FILE=$GDX_PATH/input/rfraresponse.txt.gz
FTP_HOST="DMADOM4"
FTP_INPUT_PATH="/usr/local/apps/formulary/rfra/output"
UDB_SQL_FILE=$SQL_PATH/$FILE_BASE"_udb.sql"

#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#

print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE


#-------------------------------------------------------------------------#
# Step 1. FTP the rfraresponse file from DMADOM4 to GDX and unzip it.
#-------------------------------------------------------------------------#

{
    print "bin"
    print "cd $FTP_INPUT_PATH"
    print "get $FTP_FILE_NAME $FTP_FILE"
    print "bye"
} | run_ftp "$FTP_HOST"

if [ ! -f $FTP_FILE ]; then
	print "No file found to unzip at"                    			>> $LOG_FILE
	print "$FTP_FILE - exiting with error"               			>> $LOG_FILE
	RETCODE=1
        exit_ERROR $RETCODE
fi

gunzip $FTP_FILE

if [[ $RETCODE != 0 ]]; then
   print "ERROR: couldn't unzip the $FTP_FILE_NAME file....."                   >>$LOG_FILE
   exit_error $RETCODE
fi

#-------------------------------------------------------------------------#
# Step 2. Connect to UDB using the loader Id.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >>$LOG_FILE
   db2 -p "connect to $DATABASE user $LOAD_CONNECT_ID using $LOAD_CONNECT_PWD" >>$LOG_FILE
   RETCODE=$?
   print 'RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......"                           >>$LOG_FILE
      exit_error $RETCODE
   fi


#-------------------------------------------------------------------------#
# Step 3. load data from input files, overlay the current tables 
#-------------------------------------------------------------------------#

   sql="load from $INPUT_FILE of asc
		modified by usedefaults
	   method L (1 10, 11 11, 12 12, 13 13, 14 24, 25 25, 26 26, 27 27,29 29, 30 34,35 95, 96 96,97 156) 
		savecount 3000 messages "$DB2_MSG_FILE"
           replace into vrap.trfra_rsp
		(FRMLY_ID,FRMLY_SRC_CD,FRMLY_PRCS_CD,FRMLY_CLOS_TYP_CD,NDC_LC11_ID,FRMLY_DRUG_STAT_CD,
		 RBAT_PREF_STAT_CD,LOCK_CD,OTC_CD,MSG_NB,BRND_DRUG_NM,DUM_MSG_CD,MSG_TXT) nonrecoverable
           data buffer 1000 sort buffer 1000 cpu_parallelism 1"


   echo "$sql"                                                                  >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -pxw "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   
print 'import trfra_rsp RETCODE=<'$RETCODE'>'					>> $LOG_FILE

 
if [[ $RETCODE != 0 ]]; then
	print "ERROR: Step 3 abend, having problem import file......"          	>> $LOG_FILE
	exit_error 999
else
	print "********************************************"                    >> $LOG_FILE
	print "Step 3 - Import data to table trfra_rsp - Completed ......"      >> $LOG_FILE
	print "********************************************"                    >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Step 4.  Now load the PHC Frmly/Drug                   
#-------------------------------------------------------------------------#

cat > $UDB_SQL_FILE << 99EOFSQLTEXT99

INSERT INTO VRAP.TRFRA_RSP 
	 (FRMLY_ID
	 ,FRMLY_SRC_CD
	 ,NDC_LC11_ID
	 ,FRMLY_DRUG_STAT_CD
	 ,RBAT_PREF_STAT_CD
	 ,BRND_DRUG_NM)
SELECT      
     FRMLY_ID 
    ,FRMLY_SRC_CD
    ,NDC_LC11_ID 
    ,CASE 
     WHEN FRMLY_DRUG_STAT_CD = '1' THEN 'Y'
     ELSE 'N' END FRMLY_DRUG_STAT_CD
    ,RBAT_PREF_STAT_CD
    ,BRND_DRUG_NM  
 from vrap.TFRMLY_DRUG_RESULTS_PHC a 
where a.EFF_DT <= current date
  and a.END_DT >= current date;

99EOFSQLTEXT99

    print " "                                                                  >> $LOG_FILE
    print "cat udb sql file "                                                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
cat $UDB_SQL_FILE                                                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "end cat of udb sql file "                                           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    
db2 -stvxf $UDB_SQL_FILE                                                   >> $LOG_FILE 

    RETCODE=$?

    print " "                                                                  >> $LOG_FILE
    if [[ $RETCODE != 0 && $RETCODE != 1 ]]; then 
        print "Error inserting data into vrap.TRFRA_RSP "            	       >> $LOG_FILE
	   print "  from vrap.TFRMLY_DRUG_RESULTS_PHC "		       	       >> $LOG_FILE	
        print "Return Code = "$RETCODE                                         >> $LOG_FILE
        exit_error 999
        print " "                                                              >> $LOG_FILE
    else
        print "Return Code from insert to vrap.TRFRA_RSP  "$RETCODE            >> $LOG_FILE
        print "Successful Insert - continue with script."                      >> $LOG_FILE
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
