#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_CaRe_Inbound_SAP_Interface_Load_to_Payments.ksh
# Title         :
#
# Description   : General Ledger System (SAP) Interface – Inbound transaction staging
#  
# Maestro Job   : GDDY5000/GD_5020J
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
JOBNAME="GD_5020J"
SCHEDULE="GDDY5000"

FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"
COUNT_FILE=$OUTPUT_PATH/$FILE_BASE"_count.dat"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}_${MODEL}.log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

DB2_MSG_FILE=$LOG_FILE.load


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
# Step 3. populate Control Table with valid unit of work 
#-------------------------------------------------------------------------#

   sql="delete from vrap.RCNC_PMT_PRCS_TXN_CNTL "
   
   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'delete from vrap.RCNC_PMT_PRCS_TXN_CNTL RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1  ]]; then
	print "ERROR: Step 3 - Control table delete failure for VRAP.RCNC_PMT_PRCS_TXN_CNTL......"     >> $LOG_FILE
	exit_error 999
   fi
   
   sql=" insert into vrap.RCNC_PMT_PRCS_TXN_CNTL "
   sql=$sql" select PMT_TXN_GID, "  
   sql=$sql"        PMT_DTL_TXN_GID "
   sql=$sql" from VRAP.RCNT_CASH_BTCH_DTL "
   sql=$sql" where dex_vect_cd = 'I' "
   sql=$sql"   and (rec_stat_cd = ' ' "
   sql=$sql"        or rec_stat_cd is null) "


   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'insert into vrap.RCNC_PMT_PRCS_TXN_CNTL RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 3 - Control table population failure for VRAP.RCNC_PMT_PRCS_TXN_CNTL......"     >> $LOG_FILE
	exit_error 999
   fi

#-------------------------------------------------------------------------#
# Step 4. Populate Payment table from SAP staging table 
#-------------------------------------------------------------------------#

   
   sql="insert into vrap.RCNT_RBAT_MFG_PMT ( "
   sql=$sql" PMT_TXN_GID, "
   sql=$sql" VEND_ID, "
   sql=$sql" GL_AR_ACCT_NB, "
   sql=$sql" GL_BANK_CD, " 
   sql=$sql" PMT_AMT, "  
   sql=$sql" BANK_DPST_DT, "  
   sql=$sql" PMT_MTHD_CD, "  
   sql=$sql" REF_NB_ID, "  
   sql=$sql" GL_DOC_NB, " 
   sql=$sql" DOC_TYP_CD, "  
   sql=$sql" INSRT_TS, "  
   sql=$sql" POST_DT, "  
   sql=$sql" CMNT_TXT, "  
   sql=$sql" LAST_UPDT_USER_ID, "  
   sql=$sql" LAST_UPDT_TS, "  
   sql=$sql" ap_CO_CD, "  
   sql=$sql" GL_ACCT_ID, "
   sql=$sql" pmt_stat_cd ) " 
   sql=$sql" (SELECT SAPDTL.PMT_TXN_GID, "  
   sql=$sql"         sapacct.vend_id, "  
   sql=$sql"         SAPDTL.GL_AR_ACCT_NB, "
   sql=$sql"         case when sapacct.AP_CO_CD in ('301', '607') and sapacct.MODEL_TYP_CD = 'G' "
   sql=$sql"              then 1 "
   sql=$sql"	          when sapacct.AP_CO_CD in ('170') and sapacct.MODEL_TYP_CD = 'D' "
   sql=$sql"              then 2 "
   sql=$sql"		  when sapacct.AP_CO_CD in ('230') and sapacct.MODEL_TYP_CD = 'X' "
   sql=$sql"              then 3 "
   sql=$sql"		  when sapacct.AP_CO_CD in ('607') and sapacct.MODEL_TYP_CD = 'X' "
   sql=$sql"              then 4 "
   sql=$sql"		  ELSE null "
   sql=$sql"	     end, "		
   sql=$sql"         SAPDTL.GL_PMT_AMT, "  
   sql=$sql"         SAPDTL.GL_BTCH_DT, "  
   sql=$sql"         tvr79.cd_nb, "   
   sql=$sql"         SAPDTL.GL_CHK_NB, "  
   sql=$sql"         SAPDTL.GL_POST_DOC_NB, "  
   sql=$sql"         tvr77.cd_nb, "  
   sql=$sql"         CURRENT_TIMESTAMP, "  
   sql=$sql"         SAPDTL.GL_BTCH_DT, "  
   sql=$sql"         SAPDTL.GL_NOTE_TXT, "  
   sql=$sql"         SAPDTL.LAST_UPDT_USER_ID, "  
   sql=$sql"         CURRENT_TIMESTAMP, "  
   sql=$sql"         SAPDTL.GL_CO_CD, "  
   sql=$sql"         SAPDTL.GL_UAPLD_ACCT_NB, "  
   sql=$sql"         1 "  
   sql=$sql"    FROM VRAP.RCNT_CASH_BTCH_DTL SAPDTL "
   sql=$sql"         join VRAP.RCNC_PMT_PRCS_TXN_CNTL TRANSCTL "
   sql=$sql"	       on (TRANSCTL.PMT_TXN_GID = SAPDTL.PMT_TXN_GID) "
   sql=$sql"	     left outer join (select tvr.cd_nb,substr(tvr.CD_NM,1,1) as cd_nm " 
   sql=$sql"                            from vrap.tvndr_rebt_cd tvr where tvr.TYP_CD = 79) tvr79 " 
   sql=$sql"	       on substr(sapdtl.GL_CHK_NB,1,1) = tvr79.cd_nm "
   sql=$sql"	     left outer join (select tvr.cd_nb,tvr.CD_NMON_TXT " 
   sql=$sql"                            from vrap.tvndr_rebt_cd tvr where tvr.TYP_CD = 77) tvr77 "
   sql=$sql"	       on sapdtl.GL_DOC_TYP_CD = tvr77.cd_nmon_txt " 
   sql=$sql"         left outer join VRAP.RCNT_RBAT_PAYR SAPACCT "
   sql=$sql"	       on (SAPDTL.GL_AR_ACCT_NB = SAPACCT.AR_SER_4_ACCT_ID "
   sql=$sql"            or SAPDTL.GL_AR_ACCT_NB = SAPACCT.AR_SER_5_ACCT_ID)) "  
 


   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 3 abend, population of Payment table is having an issue......"     >> $LOG_FILE
	exit_error 999
   fi

#-------------------------------------------------------------------------#
# Step 3. Update the Staging as sent 
#-------------------------------------------------------------------------#

   
   sql="update VRAP.RCNT_CASH_BTCH_DTL SAPDTL "
   sql=$sql" set SAPDTL.rec_stat_cd = 'C', "
   sql=$sql"     SAPDTL.LAST_UPDT_TS = current_timestamp, "
   sql=$sql"     SAPDTL.LAST_UPDT_USER_ID = 'SYSTEM' "
   sql=$sql" where SAPDTL.PMT_TXN_GID in "
   sql=$sql" (select transctl.PMT_TXN_GID "
   sql=$sql"   from vrap.RCNC_PMT_PRCS_TXN_CNTL transctl) "
  

   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 3 abend, failure in update of staging table......"     >> $LOG_FILE
	exit_error 999
   fi
#-------------------------------------------------------------------------#
# Step 4. Delete the Control table 
#-------------------------------------------------------------------------#

   
   sql="DELETE from vrap.RCNC_PMT_PRCS_TXN_CNTL "


   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 3 abend, failure in Delete of the control table......"     >> $LOG_FILE
	exit_error 999
   fi

#-------------------------------------------------------------------------#
# Step 5. Finish the script and log the time.
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


# clean some old log file
 `find "$LOG_ARCH_PATH" -name "GDX_CaRe_Inbound_SAP_Interface_Load_to_Payments*" -mtime +35 -exec rm -f {} \;  `  

# move the log file to the archive directory
  mv -f $LOG_FILE $LOG_FILE_ARCH

  if [[ $RETCODE -lt 2 ]]; then
     RETCODE=0
  fi
  exit $RETCODE
 
