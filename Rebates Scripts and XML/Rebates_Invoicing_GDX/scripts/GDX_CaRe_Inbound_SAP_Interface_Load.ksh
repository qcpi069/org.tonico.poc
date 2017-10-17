#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_CaRe_Inbound_SAP_Interface_Load.ksh
# Title         :
#
# Description   : General Ledger System (SAP) Interface – Inbound transaction staging
#  
# Maestro Job   : GDDY5000/GD_5010J
#
# Parameters    : N/A  
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
#  
# 02-12-09   is31701     Initial Creation
#
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

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}
#-------------------------------------------------------------------------#
#
#-------------------------------------------------------------------------#
# Function to Reload the vrap.RCNT_CASH_BTCH_DTL Table
#-------------------------------------------------------------------------#
function reload_btch_dtl {

   sql="import from $EXPORT_FILE of DEL
           commitcount 5000 messages "$DB2_MSG_FILE"
           replace into VRAP.RCNT_CASH_BTCH_DTL"
   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
print 'reload table vrap.RCNT_CASH_BTCH_DTL RETCODE=<'$RETCODE'>'>> $LOG_FILE

print "-------------------------------------------------------------------"    >>$LOG_FILE

if [[ $RETCODE != 0 ]]; then
        print "ERROR: having problem recovering table from export file ....."  >> $LOG_FILE
        return 1
else
        print "Having problem with import. Reloaded table with backup......"  >> $LOG_FILE
        return 0
fi

}
#-------------------------------------------------------------------------#
#
#-------------------------------------------------------------------------#

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="QA"
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXITD@caremark.com"
    else
        # Running in Prod region
        SYSTEM="PRODUCTION"
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXITD@caremark.com"
    fi
else
    # Running in Development region
    SYSTEM="DEVELOPMENT"
    export ALTER_EMAIL_TO_ADDY="nick.tucker@caremark.com"
    EMAIL_FROM_ADDY=$ALTER_EMAIL_TO_ADDY
fi

# Variables
RETCODE=0
JOBNAME="GD_5010J"
SCHEDULE="GDDY5000"

FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"
COUNT_FILE=$OUTPUT_PATH/$FILE_BASE"_count.dat"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}_${MODEL}.log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

DB2_MSG_FILE=$LOG_FILE.load
EXPORT_FILE=$GDX_PATH/input/GDX_CaRe_MP_SAP.bkp
INPUT_FILE=$GDX_PATH/input/GDX_CaRe_MP_SAP.dat
INPUT_FILE_ARCH=$GDX_PATH/input/archive/CaRe/GDX_CaRe_MP_SAP.dat.`date +"%Y%m%d_%H%M%S"`
TRIG_FILE=$GDX_PATH/input/GDX_CaRe_MP_SAP.trg
rm -f $LOG_FILE
rm -f $DB2_MSG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   } > $LOG_FILE


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
# Step 2. Backup tables, export data into flat files.
#-------------------------------------------------------------------------#

   sql="export to $EXPORT_FILE of DEL select * from VRAP.RCNT_CASH_BTCH_DTL"
   echo "$sql"                                                                 >>$LOG_FILE
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print "----------------------------------------------------------------"    >>$LOG_FILE

if [[ $RETCODE != 0 ]]; then
	print "ERROR: Step 2 abend, having problem backup the table......"     >> $LOG_FILE
	exit_error 999
else
print "********************************************"                           >> $LOG_FILE
print "Step 2 -Backup VRAP.RCNT_CASH_BTCH_DTL table - Completed ......"        >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
fi


#-------------------------------------------------------------------------#
# Step 3. Import data from input file, append to the current tables 
#-------------------------------------------------------------------------#

   
   sql="import from $INPUT_FILE of del modified by coldel| "
   sql=$sql" messages $DB2_MSG_FILE "
   sql=$sql" insert into VRAP.RCNT_CASH_BTCH_DTL "
   sql=$sql"(GL_BTCH_DT,GL_CNTL_GRP_NB,GL_CNTL_GRP_SEQ_NB,GL_BANK_BTCH_NB,GL_LOCK_BOX_NB,GL_LOCK_BOX_NM,"
   sql=$sql" GL_PMT_AMT,GL_MICRO_NB,GL_MICRO_VLD_CD,GL_CHK_NB,GL_UAPLD_ACCT_NB,GL_AR_ACCT_NB,GL_AR_ACCT_NM, "  
   sql=$sql" GL_CO_CD,GL_POST_DOC_NB,GL_NOTE_TXT) "


   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
	print "ERROR: Step 3 abend, having problem with import file......"     >> $LOG_FILE
	reload_btch_dtl
	RETCODE=$?
	if [[ $RETCODE != 0 ]]; then
   	   print "ERROR: Step 3 - both import and reload to table VRAP.RCNT_CASH_BTCH_DTL failed.." >>$LOG_FILE
  	   exit_error 999
	fi
	print "Recovered table VRAP.RCNT_CASH_BTCH_DTL from export file...."   >> $LOG_FILE
# remove the exported file
	rm -f $EXPORT_FILE
	exit_error 999
   fi

#-------------------------------------------------------------------------#
# Step 4. Finish the script and log the time.
#-------------------------------------------------------------------------#
   {
      print "********************************************"
      print "Finishing the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "Final return code is : <" $RETCODE ">"
   }  										>> $LOG_FILE

#-------------------------------------------------------------------------#
# Clean up files and move log file to archive with timestamp
#-------------------------------------------------------------------------#

   rm -f $EXPORT_FILE
   rm -f $TRIG_FILE

# backup the input data file to $GDXROOT/input/archive/CaRe
  mv -f $INPUT_FILE $INPUT_FILE_ARCH

# clean some old log file
 `find "$LOG_ARCH_PATH" -name "GDX_CaRe_Inbound_SAP_Interface_Load*" -mtime +35 -exec rm -f {} \;  `  

# move the log file to the archive directory
  mv -f $LOG_FILE $LOG_FILE_ARCH


  exit $RETCODE
 
