#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
# Script        : rbate_KC_2060J_PHC_frmly_excpt_rpt.ksh  
# Title         : Summary report of PHC/RXA claims with Formulary Exceptions
#                 was built to show the plans without a formulary assigned
#
# Description   : Extract summary data at Carrier/Account/Group-Plan level 
#                 for PHC/RXA claims with Formulary Exceptions and FTP it  
# Maestro Job   : KC_2060J 
#
# Parameters    : None
#
# Output        : Log file $LOG_ARCH_FILE, Data file $DATA_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-15-09    ax04566    Added 'RXA' for RxAmerica Integration
# 03-21-08    is52701    Initial Creation. 
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# CVS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

#-------------------------------------------------------------------------#
# Set variables
#-------------------------------------------------------------------------#

   if [[ $REGION = "prod" ]];   then
     if [[ $QA_REGION = "true" ]];   then
         # Running in the QA region
         export ALTER_EMAIL_ADDRESS=''
         export COMPLETE_EMAIL_ADDRESS='RebateResearch@caremark.com,yanping.zhao@caremark.com'
         export EMAIL_SUBJECT="QA_PHC_RXA_frmly_excpt_rpt_complete_notification_"`date +"%m/%d/%Y"`

         FTP_CONFIG="
                 r07prd02    /actuate7/DSC/gather_rpts/qa
                 AZSHISP00   /rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
                 "
     else
         # Running in PROD region
         export ALTER_EMAIL_ADDRESS=''
         export COMPLETE_EMAIL_ADDRESS='RebateResearch@caremark.com'
         export EMAIL_SUBJECT="PROD_PHC_RXA_frmly_excpt_rpt_complete_notification_"`date +"%m/%d/%Y"`

         FTP_CONFIG="
                 r07prd02    /actuate7/DSC/gather_rpts
                 AZSHISP00   /rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
                 "
     fi

   else
         # Running in DEV region  
         export ALTER_EMAIL_ADDRESS='yanping.zhao@caremark.com,vidya.vemula@caremark.com'
         export COMPLETE_EMAIL_ADDRESS=$ALTER_EMAIL_ADDRESS
         export EMAIL_SUBJECT="DEV_PHC_RXA_frmly_excpt_rpt_complete_notification_"`date +"%m/%d/%Y"`

#         FTP_CONFIG="
#            tstudb4   /GDX/test/sandbox
#            tstudb4   /GDX/test/temp
#      "
  
          FTP_CONFIG="
                r07prd02    /actuate7/DSC/gather_rpts/dev
                AZSHISP00   /rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports/test
                "
   fi

   CTRL_FILE=$OUTPUT_PATH/"gdx_pre_gather_rpt_control_file_init.dat"
   RETCODE=0

   SCRIPTNAME=$SCRIPT_PATH/$(basename $0)
   FILE_BASE=$(basename $0 | sed -e 's/\.ksh$//')
   LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
   ARCH_LOG_FILE=$OUTPUT_PATH/archive/$FILE_BASE'.log.'$(date +'%Y%j%H%M')
   SQL_FILE=$OUTPUT_PATH/$FILE_BASE".sql"
   EMAIL_TEXT=$OUTPUT_PATH/$FILE_BASE"_email.txt"

   rm -f $LOG_FILE
   rm -f $SQL_FILE
   rm -f $EMAIL_TEXT

#-------------------------------------------------------------------------#
# Function to send complete email
#-------------------------------------------------------------------------#

function complete_email {
    typeset _ROW_CNT=$1

    if [[ $_ROW_CNT = 0 ]]; then
       {
         print "The PHC/RXA Formulary Exception Report found NO EXCEPTIONS for $M_CYCLE_GID at $(date)" 
       } >> $EMAIL_TEXT
    else
       {
         print "The PHC/RXA Formulary Exception Report for $M_CYCLE_GID was created at $(date)."
         print "There are $_ROW_CNT rows in the report. Please review. " 
       } >> $EMAIL_TEXT
    fi

    mailx -s $EMAIL_SUBJECT $COMPLETE_EMAIL_ADDRESS < $EMAIL_TEXT
    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
         exit_script $RETCODE 'Send complete email error'
    fi

}

#-------------------------------------------------------------------------#
# Function to ftp data file 
#-------------------------------------------------------------------------#

function run_ftp {
    # pulls stdin into a variable
    typeset _FTP_COMMANDS=$(cat)                                       
    typeset _FTP_OUTPUT=""
    typeset _ERROR_COUNT=""

    print "Transferring to $FTP_HOST using commands:"                          >> $LOG_FILE
    print "$_FTP_COMMANDS"                                                     >> $LOG_FILE
    print ""                                                                   >> $LOG_FILE
    _FTP_OUTPUT=$(print "$_FTP_COMMANDS" | ftp -i -v "$FTP_HOST")
    RETCODE=$?

    print "FTP_OUTPUT: $_FTP_OUTPUT"                                           >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        exit_script $RETCODE "FTP FAILED "
    fi

    # Parse the ftp output for errors
    # 400 and 500 level replies are errors
    # You have to vilter out the bytes sent message
    # it may say something 404 bytes sent and you don't
    # want to mistake this for an error message.
    _ERROR_COUNT=$(echo "$_FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')

    if [[ $_ERROR_COUNT -gt 0 ]]; then
            RETCODE=$_ERROR_COUNT
            exit_script $RETCODE "FTP FAILED "
    fi
}
 
#-------------------------------------------------------------------------#
# Function to exit the script
#-------------------------------------------------------------------------#

function exit_script {
    typeset _RETCODE=$1
    typeset _ERRMSG="$2"
    if [[ -z $_RETCODE ]]; then
        _RETCODE=0
        print " " >> $LOG_FILE
        print "Inside the exit_script function - successful run occurring" >> $LOG_FILE
        print " " >> $LOG_FILE
        print " "
        print "Inside the exit_script function - successful run occurring"
        print " "
    fi 
    if [[ $_RETCODE != 0 ]]; then
        print " "
        print "Inside the exit_script function - abend occurring"
        print " "
        print " " >> $LOG_FILE
        print "Inside the exit_script function - abend occurring" >> $LOG_FILE
        print " " >> $LOG_FILE
        print "                                                              " >> $LOG_FILE
        print "===================== J O B  A B E N D E D ===================" >> $LOG_FILE
        if [[ -n "$_ERRMSG" ]]; then
                print "  Error Message: $_ERRMSG"                              >> $LOG_FILE
        fi
        print "  Error Executing " $SCRIPTNAME                                 >> $LOG_FILE
        print "  Look in "$LOG_FILE                                            >> $LOG_FILE
        print "==============================================================" >> $LOG_FILE
        
        # Send the Email notification
        export JOBNAME=$SCRIPTNAME
        export SCRIPTNAME=$SCRIPTNAME
        export LOGFILE=$LOG_FILE
        export EMAILPARM4="$_ERRMSG "
        export EMAILPARM5="  "

        print "Sending email notification with the following parameters"       >> $LOG_FILE
        print "JOBNAME is    " $JOBNAME                                        >> $LOG_FILE
        print "SCRIPTNAME is " $SCRIPTNAME                                     >> $LOG_FILE
        print "LOGFILE is    " $LOGFILE                                        >> $LOG_FILE
        print "EMAILPARM4 is " $EMAILPARM4                                     >> $LOG_FILE
        print "EMAILPARM5 is " $EMAILPARM5                                     >> $LOG_FILE
        print "****** end of email parameters ******"                          >> $LOG_FILE

        . $SCRIPT_PATH/rbate_email_base.ksh

        cp -f $LOG_FILE $ARCH_LOG_FILE
        exit $_RETCODE
    else
        print " "                                                              >> $LOG_FILE
        print "....Completed executing " $SCRIPTNAME " ...."                   >> $LOG_FILE
        print `date`                                                           >> $LOG_FILE
        print "==============================================================" >> $LOG_FILE
        mv -f $LOG_FILE $ARCH_LOG_FILE
        
        exit $_RETCODE
    fi
}

#-------------------------------------------------------------------------#
# Start the scripts
#-------------------------------------------------------------------------#

   print "Starting " $SCRIPTNAME                                                  >> $LOG_FILE
   print `date`                                                                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# Get cycle date from input data file               
#-------------------------------------------------------------------------#

   if [[ ! -s $CTRL_FILE ]]; then
       exit_script 999 "Control file $CTRL_FILE is EMPTY"
   fi

   READ_VARS='
       M_CTRL_CYCLE_GID
       M_CTRL_CYCLE_START_DATE
       M_CTRL_CYCLE_END_DATE
       Q_CTRL_CYCLE_GID
       Q_CTRL_CYCLE_START_DATE
       Q_CTRL_CYCLE_END_DATE
       JUNK
   '
   while read $READ_VARS; do

      export M_CYCLE_GID=$M_CTRL_CYCLE_GID
      export Q_CYCLE_GID=$Q_CTRL_CYCLE_GID
      export CYCLE_START_DATE=$Q_CTRL_CYCLE_START_DATE
      export CYCLE_END_DATE=$Q_CTRL_CYCLE_END_DATE

   done < $CTRL_FILE

   {
      print " "                                                                   
      print "Control file record read from " $CTRL_FILE                          
      print `date`                                                              
      print " "                                                                
      print "Values are:"       
      print "Monthly CYCLE_GID = " $M_CYCLE_GID                                              
      print "Quarterly CYCLE_GID = " $Q_CYCLE_GID                       
      print "CYCLE_START_DATE = " $CYCLE_START_DATE                         
      print "CYCLE_END_DATE   = " $CYCLE_END_DATE                          
   }  >> $LOG_FILE

   if [[ -z $M_CYCLE_GID || -z $Q_CYCLE_GID || -z $CYCLE_START_DATE || -z $CYCLE_END_DATE ]]; then
       exit_script 999 "One of the cycle parms is null"
   fi

#-------------------------------------------------------------------------#
# Set variable based on cycle date from input data file
#-------------------------------------------------------------------------#

   DATA_FILE=$OUTPUT_PATH/$FILE_BASE"_"$M_CYCLE_GID".dat"
   FTP_DATA_FILE=$FILE_BASE"_"$M_CYCLE_GID"_"$(date +"%Y%m%d_%H%M%S")".dat"

   rm -f $DATA_FILE

#-------------------------------------------------------------------------#
# Oracle userid/password
#-------------------------------------------------------------------------#

   db_user_password=`cat $SCRIPT_PATH/ora_user.fil`
   print " " >> $LOG_FILE
   print "Output data file is :" $DATA_FILE >> $LOG_FILE

#-------------------------------------------------------------------------#
# Set up extract SQL
#-------------------------------------------------------------------------#

cat > $SQL_FILE << EOFSQL

    alter session enable parallel dml
    -- NEXT LINE MUST BE BLANK!!! OTHERWISE ERRORS WILL NOT STOP THE SQL EXECUTION!!!

    whenever sqlerror exit failure
    set LINESIZE 200
    set PAGESIZE 0
    set NEWPAGE 0
    set SPACE 0
    set ECHO OFF
    set HEADING OFF
    set FEEDBACK OFF
    set verify off

    select 'Starting pull data' as descr, ' - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;

    set TERMOUT OFF

    SPOOL $DATA_FILE

    SELECT /*+ ordered 
           full(ruc)
           parallel(ruc,12)
           use_hash(ruc) 
           pq_distribute(ruc,hash,hash)
           no_merge(pfe)
           cardinality(ruc,30000000)
           */
            pfe.extnl_src_code
            , ','
	    , pfe.extnl_lvl_id1
            , ','
            , pfe.extnl_lvl_id2
            , ','
	    , pfe.extnl_lvl_id3
            , ','
	    , ruc.plan_code
            , ','
	    , ruc.clm_lvl_3_id data_src_cd
            , ','
	    , pfe.rbate_id
            , ','
	    , pfe.batch_month
            , ','
	    , count(*)
      FROM (
           SELECT /*+ full(a) parallel(a,12) cardinality(a,10000) */
                    a.claim_gid
                  , a.extnl_src_code
                  , a.extnl_lvl_id1
                  , a.extnl_lvl_id2
                  , a.extnl_lvl_id3
                  , a.rbate_id
                  , to_char(a.batch_date,'yyyyMM') batch_month 
             FROM dma_rbate2.s_claim_rbate_cycle a
            WHERE a.cycle_gid = $Q_CYCLE_GID -- Current Processing Quarter CycleGID
              AND a.extnl_src_code in ('PHC','PHCE', 'RXA') --PharmaCare and EPS Mail, RxAmerica
              AND (a.excpt_id = 5 OR a.frmly_id is null OR a.frmly_id = '00001' OR a.frmly_gid = -2) 
                   --formulary exception, no formulary assigned or invalid formularyID assigned
            UNION
           SELECT /* full(b) parallel(b,12) cardinality(b,10000)  */
                   b.claim_id
                 , b.extnl_src_cd   extnl_src_code
                 , b.extnl_lvl_1_id extnl_lvl_id1
                 , b.extnl_lvl_2_id extnl_lvl_id2
                 , b.extnl_lvl_3_id extnl_lvl_id3
                 , b.rbate_id
                 , to_char(b.inv_elig_dt,'yyyyMM') batch_month 
             FROM dma_rbate2.s_claim_non_gpo_excpt b
            WHERE b.cycle_gid = $M_CYCLE_GID -- Current Processing Month CycleGID
              AND b.extnl_src_cd in ('PHC','PHCE','RXA') --PharmaCare and EPS Mail, RxAmerica
              AND (b.excpt_id = 5 OR b.frmly_id is null OR b.frmly_id = '00001' OR b.frmly_gid = -2) 
                  --formulary exception, no formulary assigned or invalid formularyID assigned
           ) pfe --PharmaCare Formulary Exception claims
           , dma_rbate2.s_claim_rbate_ruc ruc
     WHERE ruc.batch_date between to_date('$CYCLE_START_DATE','MM-dd-yyyy') -- Current Processing Quarter Start Date
                              AND to_date('$CYCLE_END_DATE','MM-dd-yyyy')   -- Current Processing Quarter End Date
       AND ruc.claim_gid = pfe.claim_gid
  GROUP BY pfe.extnl_src_code
           , pfe.extnl_lvl_id1
           , pfe.extnl_lvl_id2
           , pfe.extnl_lvl_id3
           , ruc.plan_code
           , ruc.clm_lvl_3_id 
           , pfe.rbate_id
           , pfe.batch_month;

    spool off
    set TERMOUT ON

    select 'Completed pull data' as descr, ' - ', to_char(sysdate,'MM/DD/YYYY HH12:MI:SS AM') as timest from dual;
    quit;

EOFSQL

#-------------------------------------------------------------------------#
# Execute the SQL and extract data
#-------------------------------------------------------------------------#

   $ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE    >> $LOG_FILE
   RETCODE=$?

   if [[ $RETCODE != 0 ]] ; then
       exit_script $RETCODE 'SQL Error'
   fi

#-------------------------------------------------------------------------#
# Count output file
#-------------------------------------------------------------------------#

    wc -l $DATA_FILE | read DATA_FILE_ROWCOUNT JUNK
    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
        exit_script $RETCODE 'Count data file error'
    fi
 
#-------------------------------------------------------------------------#
# Build FTP Command and FTP the data file
#-------------------------------------------------------------------------#

   print ""                                             >> $LOG_FILE
   print "Build FTP Command and FTP data file"          >> $LOG_FILE

    # Read non-empty lines from FTP_CONFIG
    print "$FTP_CONFIG" | while read FTP_HOST FTP_DIR; do
       if [[ -z $FTP_HOST ]]; then
            continue
       fi

       print " "                                                      >> $LOG_FILE
       print "Start transfering $DAT_FILE to $FTP_DIR in $FTP_HOST"   >> $LOG_FILE
       print `date +"%D %r %Z"`                                       >> $LOG_FILE

       {
           print "ascii"
           if [[ -n $FTP_DIR ]]; then
                print "cd $FTP_DIR"
           fi
           print "put "$DATA_FILE $FTP_DATA_FILE " (replace"
           print "bye"
       } | run_ftp "$FTP_HOST" 

       print " "                                                         >> $LOG_FILE
       print "Completed transfering $DAT_FILE to $FTP_DIR in $FTP_HOST"  >> $LOG_FILE
       print `date +"%D %r %Z"`                                          >> $LOG_FILE

   done

#-------------------------------------------------------------------------#
# Send complete email and log the time.
#-------------------------------------------------------------------------#

   print " "   >> $LOG_FILE
   print "Send complete email" >> $LOG_FILE

   complete_email $DATA_FILE_ROWCOUNT

   print `date +"%D %r %Z"`                                          >> $LOG_FILE

#-------------------------------------------------------------------------#
# Exit the script
#-------------------------------------------------------------------------#

   exit_script $RETCODE
