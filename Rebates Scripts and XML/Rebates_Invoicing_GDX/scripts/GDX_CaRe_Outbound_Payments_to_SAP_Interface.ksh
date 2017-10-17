#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_CaRe_Outbound_Payments_to_SAP_Interface.ksh
# Title         :
#
# Description   : General Ledger System (SAP) Interface – Outbound transaction staging
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
# 02-12-09   is23301     Initial Creation
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
JOBNAME="GD_5020J"
SCHEDULE="GDDY5000"

PROCESS_CTRL=$1

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
# Step 3. Delete the Control table 
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
# Step 4. populate Control Table with valid unit of work 
#-------------------------------------------------------------------------#

if [[ $PROCESS_CTRL != 'BATCH' ]]; then

#-------------------------------------------------------------------------#
#  process the Immediate Send transactions
#-------------------------------------------------------------------------#   
   sql=" insert into vrap.RCNC_PMT_PRCS_TXN_CNTL "
   sql=$sql" select pmt.PMT_TXN_GID, "  
   sql=$sql"	 pmtappl.PMT_DTL_TXN_GID "
   sql=$sql"   from VRAP.RCNT_RBAT_MFG_PMT pmt, "
   sql=$sql"	 vrap.RCNT_RBAT_MFG_PMT_APPL pmtappl "	
   sql=$sql" where pmt.PMT_STAT_CD in (2) "
   sql=$sql"   and pmtappl.GL_SEND_CD = 'I' "
   sql=$sql"   and pmt.PMT_TXN_GID = pmtappl.PMT_TXN_GID "
else

#-------------------------------------------------------------------------#
#  process the Immediate Send transactions
#-------------------------------------------------------------------------#   
   sql=" insert into vrap.RCNC_PMT_PRCS_TXN_CNTL "
   sql=$sql" select pmt.PMT_TXN_GID, "  
   sql=$sql"	 pmtappl.PMT_DTL_TXN_GID "
   sql=$sql"   from VRAP.RCNT_RBAT_MFG_PMT pmt, "
   sql=$sql"	 vrap.RCNT_RBAT_MFG_PMT_APPL pmtappl "
   sql=$sql" where pmt.PMT_STAT_CD in (2) "
   sql=$sql"   and pmt.PMT_TXN_GID = pmtappl.PMT_TXN_GID "

fi

   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'insert into vrap.RCNC_PMT_PRCS_TXN_CNTL RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 4 - Control table population failure for VRAP.RCNC_PMT_PRCS_TXN_CNTL......"     >> $LOG_FILE
	exit_error 999
   fi

#-------------------------------------------------------------------------#
# Step 5. Populate Payment table from SAP staging table 
#-------------------------------------------------------------------------#

   
   sql=" insert into vrap.RCNT_CASH_BTCH_DTL "
   sql=$sql"(PMT_TXN_GID, "
   sql=$sql" DEX_VECT_CD, "
   sql=$sql" PMT_DTL_TXN_GID, "
   sql=$sql" PRCS_CNTL_MTHD_CD, "
   sql=$sql" GL_PMT_AMT, "
   sql=$sql" GL_UAPLD_ACCT_NB, "
   sql=$sql" GL_AR_ACCT_NB, "
   sql=$sql" GL_CO_CD, "
   sql=$sql" GL_POST_DOC_NB, "
   sql=$sql" DOC_DT, "
   sql=$sql" DOC_NB, "
   sql=$sql" GL_DOC_TYP_CD, "
   sql=$sql" GL_QTR_ASGN_CD, "
   sql=$sql" REC_STAT_CD, "
   sql=$sql" INSRT_TS, "
   sql=$sql" LAST_UPDT_TS, "
   sql=$sql" LAST_UPDT_USER_ID, "
   sql=$sql" GL_AR_ACCT_NM, "
   sql=$sql" GL_NOTE_TXT) "
   sql=$sql" ((SELECT distinct pmt.PMT_TXN_GID, "  
   sql=$sql"         'O', "
   sql=$sql"          0, "
   sql=$sql"         'B', "
   sql=$sql"          pmt.PMT_AMT, "
   sql=$sql"          pmt.GL_ACCT_ID, "
   sql=$sql"          '', "
   sql=$sql"          pmt.AP_CO_CD, "
   sql=$sql"          pmt.GL_DOC_NB, "
   sql=$sql"          coalesce(pmt.BANK_DPST_DT, pmt.post_dt, current_date), "
   sql=$sql"          pmt.GL_DOC_NB, "
   sql=$sql"          case when pmt.DOC_TYP_CD = 4 then 'RC' "
   sql=$sql"	           when pmt.DOC_TYP_CD = 10 then 'RZ' "
   sql=$sql"		   else ' ' "
   sql=$sql"	      end, "  
   sql=$sql"          '', "  
   sql=$sql"          ' ', "   
   sql=$sql"          current_timestamp, "  
   sql=$sql"          current_timestamp, "  
   sql=$sql"          pmt.LAST_UPDT_USER_ID, "  
   sql=$sql"          sapacct.VEND_NM, "  
   sql=$sql"          substr(pmt.CMNT_TXT,1,50) " 			 
   sql=$sql"     FROM (VRAP.RCNC_PMT_PRCS_TXN_CNTL TRANSCTL " 
   sql=$sql"            Join VRAP.RCNT_RBAT_MFG_PMT pmt " 
   sql=$sql"              On transctl.PMT_TXN_GID = pmt.PMT_TXN_GID) " 
   sql=$sql"            Left outer join vrap.RCNT_RBAT_PAYR sapacct " 
   sql=$sql"              On (pmt.GL_AR_ACCT_NB = sapacct.AR_SER_4_ACCT_ID " 
   sql=$sql"		   or pmt.GL_AR_ACCT_NB = sapacct.AR_SER_5_ACCT_ID) "
   sql=$sql"    ) " 
   sql=$sql"    UNION "  
   sql=$sql"    (SELECT pmt.PMT_TXN_GID, "  
   sql=$sql"            'O', "  
   sql=$sql"            pmtappl.PMT_DTL_TXN_GID, "  
   sql=$sql"            'B', "  
   sql=$sql"            pmtappl.REV_AMT*(-1), "  
   sql=$sql"            pmtappl.GL_ACCT_ID, "  
   sql=$sql"            pmtappl.AR_SER_5_ACCT_ID, "  
   sql=$sql"            pmtappl.AP_CO_CD, "  
   sql=$sql"            CASE when trc77.cd_nmon_txt = 'RC' "    
   sql=$sql"                 then ' ' "  
   sql=$sql"                 else pmt.GL_DOC_NB "  
   sql=$sql"            end, "  
   sql=$sql"            coalesce(pmt.BANK_DPST_DT, pmt.post_dt, current_date ), "  
   sql=$sql"            case when trc77.cd_nmon_txt = 'RC' "   
   sql=$sql"                 then pmt.GL_DOC_NB "  
   sql=$sql"                 else pmt.GL_DOC_NB "  
   sql=$sql"            end, "  
   sql=$sql"            substr(trc77.cd_nmon_txt,1,2), "  
   sql=$sql"            (case when substr(pmtappl.pmt_prd_id,1,1) = 'Q' "
   sql=$sql"                  then SUBSTR(pmtappl.pmt_prd_id,4,2) concat "
   sql=$sql"            	   'Q' concat "
   sql=$sql"                       SUBSTR(pmtappl.pmt_prd_id,3,1) "
   sql=$sql"                  when substr(pmtappl.pmt_prd_id,1,1) = 'M' "
   sql=$sql"                  then SUBSTR(tp.PERIOD_PARENT_ID,4,2) concat "
   sql=$sql"                       'Q' concat  "
   sql=$sql"            	   SUBSTR(tp.PERIOD_PARENT_ID,3,1) concat "
   sql=$sql"            	   ' ' concat "
   sql=$sql"            	   substr(pmtappl.pmt_prd_id,2,2) "
   sql=$sql"                  else pmtappl.pmt_prd_id	"	 
   sql=$sql"             end) concat ' ' concat trc81.cd_nm concat ' ' concat trc80.cd_nm, "  
   sql=$sql"            ' ', "   
   sql=$sql"            current_timestamp, "  
   sql=$sql"            current_timestamp, "  
   sql=$sql"            pmtappl.LAST_UPDT_USER_ID, "  
   sql=$sql"            sapacct.VEND_NM, "  
   sql=$sql"            substr(pmt.CMNT_TXT,1,50) " 			 
   sql=$sql"     FROM ((VRAP.RCNC_PMT_PRCS_TXN_CNTL TRANSCTL " 
   sql=$sql"            Join VRAP.RCNT_RBAT_MFG_PMT pmt " 
   sql=$sql"              On transctl.PMT_TXN_GID = pmt.PMT_TXN_GID) " 
   sql=$sql"            Join vrap.RCNT_RBAT_MFG_PMT_APPL pmtappl " 
   sql=$sql"                 Join vrap.tdiscnt_period tp "
   sql=$sql"                   on tp.period_id = pmtappl.pmt_prd_id " 
   sql=$sql"              On pmt.PMT_TXN_GID = pmtappl.PMT_TXN_GID " 
   sql=$sql"             And transctl.PMT_DTL_TXN_GID = pmtappl.PMT_DTL_TXN_GID) " 
   sql=$sql"            Left outer join vrap.RCNT_RBAT_PAYR sapacct " 
   sql=$sql"              On pmtappl.AR_SER_5_ACCT_ID = sapacct.AR_SER_5_ACCT_ID "
   sql=$sql"            Left outer join (Select trc.CD_NB as cd_nb, "  
   sql=$sql"                                    trc.CD_NMON_TXT as cd_nmon_Txt "   
   sql=$sql"           from vrap.TVNDR_REBT_CD trc "  
   sql=$sql"          where trc.TYP_CD = 77) trc77 "
   sql=$sql"          on pmtappl.DOC_TYP_CD = trc77.cd_Nb "  
   sql=$sql"        Left outer join " 
   sql=$sql"    (Select trc.CD_NB as cd_nb, "  
   sql=$sql"                trc.CD_NM as cd_nm "   
   sql=$sql"           from vrap.TVNDR_REBT_CD trc "  
   sql=$sql"          where trc.TYP_CD = 80) trc80 " 
   sql=$sql"      on pmtappl.CO_BE_ID = trc80.cd_nb "   
   sql=$sql"         Left outer join " 
   sql=$sql"    (Select trc.CD_NB as cd_nb, " 
   sql=$sql"   	         trc.CD_NM as cd_nm "   
   sql=$sql"           from vrap.TVNDR_REBT_CD trc "  
   sql=$sql"          where trc.TYP_CD = 81) trc81 "  
   sql=$sql"   		on pmtappl.REV_TYP_CD = trc81.cd_nb) )"  

   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 5 abend, population of Payment table is having an issue......"     >> $LOG_FILE
	exit_error 999
   fi

#-------------------------------------------------------------------------#
# Step 6. Update the Payments as sent 
#-------------------------------------------------------------------------#

   
   sql="update VRAP.RCNT_RBAT_MFG_PMT pmt "
   sql=$sql" set pmt.PMT_STAT_CD = 3, "
   sql=$sql"     pmt.PMT_APLD_DT = current_date, "
   sql=$sql"     pmt.LAST_UPDT_TS = current_timestamp "
   sql=$sql" where pmt.PMT_TXN_GID in "
   sql=$sql" (select transctl.PMT_TXN_GID "
   sql=$sql"   from vrap.RCNC_PMT_PRCS_TXN_CNTL transctl) "
  

   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 6 abend, failure in update of payment table......"     >> $LOG_FILE
	exit_error 999
   fi

#-------------------------------------------------------------------------#
# Step 7. Update the Payments as sent 
#-------------------------------------------------------------------------#

   
   sql="update VRAP.RCNT_RBAT_MFG_PMT_appl pmtappl "
   sql=$sql" set pmtappl.post_DT = current_date, "
   sql=$sql"     pmtappl.LAST_UPDT_TS = current_timestamp "
   sql=$sql" where pmtappl.PMT_TXN_GID in "
   sql=$sql" (select transctl.PMT_TXN_GID "
   sql=$sql"   from vrap.RCNC_PMT_PRCS_TXN_CNTL transctl) "
  

   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 7 abend, failure in update of payment appl table......"     >> $LOG_FILE
	exit_error 999
   fi
#-------------------------------------------------------------------------#
# Step 8. Delete the Control table 
#-------------------------------------------------------------------------#

   
   sql="DELETE from vrap.RCNC_PMT_PRCS_TXN_CNTL "


   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
   print 'import npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE -gt 1 ]]; then
	print "ERROR: Step 8 abend, failure in Delete of the control table......"     >> $LOG_FILE
	exit_error 999
   fi
#-------------------------------------------------------------------------#
# Step 9. Finish the script and log the time.
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
 `find "$LOG_ARCH_PATH" -name "GDX_CaRe_Outbound_Payments_to_SAP_Interface*" -mtime +35 -exec rm -f {} \;  `  

# move the log file to the archive directory
  mv -f $LOG_FILE $LOG_FILE_ARCH

 if [[ $RETCODE -lt 2 ]]; then
    RETCODE=0
 fi   

exit $RETCODE
 
