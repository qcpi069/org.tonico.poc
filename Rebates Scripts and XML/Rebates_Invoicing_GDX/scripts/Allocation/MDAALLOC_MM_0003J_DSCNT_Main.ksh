#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MM_0003J_DSCNT_Main.ksh   
# Title         : Clonable BASE module.
#
# Description   : For use in creating new scripts from a common look.
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
# 10-14-05   qcpi733    6004155   Added logic to email oncall pagers when 
#                                 allocation error occurs.
# 04-18-05   qcpi733    5998083   Changed code to include input MODEL_TYP_CD 
#                                 and to use this field and pass it to other
#                                 scripts.  Removed Trigger file use and 
#                                 check that kept from running same job 
#                                 again.  Also removed 'sleep 600' logic
#                                 that would keep Allocate running while
#                                 Harvest finished - Maestro will continue
#                                 to submit Allocates.
# 01-13-2005 K. Gries             Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark MDA Allocation Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/MDA_Allocation_env.ksh

MODEL_TYP_CD=$(echo $1|dd conv=ucase 2>/dev/null)

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="QA"
        export ALTER_EMAIL_ADDRESS=""
        ALLOC_ERROR_EMAIL_TO_LIST="8478780604@messaging.nextel.com,8884302503@archwireless.net"
        ALLOC_ERROR_EMAIL_CC_LIST="GDXITD@caremark.com"
 #       ALLOC_ERROR_EMAIL_TO_LIST="nandini.namburi@caremark.com"
 #       ALLOC_ERROR_EMAIL_CC_LIST="nandini.namburi@caremark.com"
  	
    else
        # Running in Prod region
        SYSTEM="Production"
        export ALTER_EMAIL_ADDRESS=""
        ALLOC_ERROR_EMAIL_TO_LIST="8478780604@messaging.nextel.com,8884302503@archwireless.net"
        ALLOC_ERROR_EMAIL_CC_LIST="GDXITD@caremark.com"
    fi
else
    # Running in Development region
    SYSTEM="Development"
    export ALTER_EMAIL_ADDRESS="nandini.namburi@caremark.com"
    ALLOC_ERROR_EMAIL_TO_LIST="nandini.namburi@caremark.com"
    ALLOC_ERROR_EMAIL_CC_LIST="nandini.namburi@caremark.com"
    if [[ `whoami` != "vactuate" ]]; then 
        print " " 
        print "ATTN DEVELOPER:  Allocation must be run as user VACTUATE in R07TST07"
        print " " 
        exit 1
    fi
fi

#the variables needed for the source file location and the NT Server
RETCODE=0
BASE_INPUT_DIR="/GDX/$REGION/input"
SCHEDULE="MDAALLOC"
JOB="MM_0003J"
FILE_BASE=$SCHEDULE"_"$JOB"_""DSCNT_Main"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$LOG_PATH/$FILE_BASE"_"$MODEL_TYP_CD".log"
LOG_ARCH=$LOG_ARCH_PATH/$FILE_BASE"_"$MODEL_TYP_CD".log"
SQL_FILE_NAME=$SQL_PATH/$FILE_BASE"_"$MODEL_TYP_CD".sql"
SELECT_SQL=$SQL_PATH/$FILE_BASE"_"$MODEL_TYP_CD"_SELECT.sql"
COUNT_FILE=$LOG_PATH/$FILE_BASE"_"$MODEL_TYP_CD"_count.dat"
PERIOD_FILE=$LOG_PATH/$FILE_BASE"_"$MODEL_TYP_CD"_Period.dat"
SNGL_SEL_OUTPUT_FILE=$LOG_PATH/$FILE_BASE"_"$MODEL_TYP_CD"_Single_Select_Output.dat"

PASSWORD_FILE="$BASE_INPUT_DIR/PWD_file"
PASSWORD_FILE_TEST="$BASE_INPUT_DIR/PWD_file_test"
HARVEST_STILL_GOING="FALSE"

SCHEMA_OWNER="VRAP"
TALLOCATN_OWNER="VRAP"

EMAIL_SUBJECT=""
rm -f $LOG_FILE

print "Starting " $SCRIPTNAME  >> $LOG_FILE
print `date` >> $LOG_FILE
print " "    >> $LOG_FILE
chmod 666 $LOG_FILE

### validate input parm
### Use this commented IF if we use Maestro to submit, otherwise sticking with crontab and assume no 
###   input parm means Discount is running.
if [[ $# -lt 1 ]]; then
    print "No input parm received, assumption is that Discount is running."    >> $LOG_FILE
    MODEL_TYP_CD = 'D'
fi
 
print "Input parameter MODEL_TYP_CD = >$MODEL_TYP_CD<"                         >> $LOG_FILE

if [[ $MODEL_TYP_CD = "D" || $MODEL_TYP_CD = "G" || $MODEL_TYP_CD = "X" ]]; then
    if [[ $MODEL_TYP_CD = "D" ]]; then
        REBATE_REPORT_DIR="$BASE_INPUT_DIR/DISHarvest/Rebate"
        MKTSHR_REPORT_DIR="$BASE_INPUT_DIR/DISHarvest/Marketshare"
        MODEL="DSC"
    elif [[ $MODEL_TYP_CD = "G" ]]; then 
        REBATE_REPORT_DIR="$BASE_INPUT_DIR/GPOHarvest/Rebate"
        MODEL="GPO"
    else
        REBATE_REPORT_DIR="$BASE_INPUT_DIR/XMDHarvest/Rebate"
        MODEL="XMD"
    fi
else 
    print "Input parameter passed, but invalid.  Must pass in D for"       >> $LOG_FILE
    print "  Discount or G for GPO or X for XMD."                          >> $LOG_FILE
    RETCODE=1
fi

EMAIL_TEXT=$LOG_PATH/"MDA_Allocation_DSCNT_error_email_"$MODEL".txt"

rm -rf $EMAIL_TEXT

if [[ $RETCODE = 0 ]]; then 

    print `date` >> $LOG_FILE
    print '**********************************************************' >>$LOG_FILE 
    export SQL_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" >> $LOG_FILE
    ##########export SQL_CONNECT_STRING="connect to udbmdap user $CONNECT_ID using $CONNECT_PWD" >> $LOG_FILE
    print '**********************************************************' >>$LOG_FILE 

    db2 -p $SQL_CONNECT_STRING >> $LOG_FILE

    SQLCODE=$?

    if [[ $SQLCODE != 0 ]]; then
       print "Script " $SCRIPTNAME "failed in the DB CONNECT." >> $LOG_FILE
       print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
       exit 
    fi   

    SQL_STRING="Select count(*) from $TALLOCATN_OWNER.tallocatn_schedule where REQ_STAT_CD = 'P' and ALOC_TYP_CD = 'DISC' AND MODEL_TYP_CD = '$MODEL_TYP_CD'"
    print $SQL_STRING >> $LOG_FILE 

    db2 -px $SQL_STRING > $COUNT_FILE

    SQLCODE=$?

    if [[ $SQLCODE != 0 ]]; then
       print "Script " $SCRIPTNAME "failed in the initial COUNT step querying TALLOCATN_SCHEDULE." >> $LOG_FILE
       print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
       exit 
    fi   

    read COUNT < $COUNT_FILE

    print "Count of Pending entries in the TALLOCAN_SCHEDULE table is : <" $COUNT ">" >>$LOG_FILE 

    if [[ $COUNT > 0 ]]; then

        # call to EMAIL STARTED was here but moved down below the read for the period id, so that we could include it in the email
        #   cd $SCRIPT_PATH
        #   print "Exec MDA_Allocation_DSCNT_email_started.ksh" >> $LOG_FILE
        #   $SCRIPT_PATH/MDA_Allocation_DSCNT_email_started.ksh $LOG_FILE $MODEL_TYP_CD

           SQL_STRING="Select PERIOD_ID from $TALLOCATN_OWNER.tallocatn_schedule where REQ_STAT_CD = 'P' and ALOC_TYP_CD = 'DISC' AND MODEL_TYP_CD = '$MODEL_TYP_CD' GROUP BY PERIOD_ID"
           print $SQL_STRING >>$LOG_FILE 

           db2 -px $SQL_STRING > $PERIOD_FILE

           SQLCODE=$?

           if [[ $SQLCODE != 0 ]]; then
              print "Script " $SCRIPTNAME "failed querying TALLOCATN_SCHEDULE for Period IDs for pre-allocation." >> $LOG_FILE
              print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
              exit  
           fi   

           FIRST_READ=1
           while read rec_PERIOD_ID ; do
             if [[ $FIRST_READ = 1 ]]; then
               if [[ $rec_PERIOD_ID > ' ' ]]; then
                  PERIOD_ID=$rec_PERIOD_ID
                  FIRST_READ=0
               else
                  "We don't have a PERIOD_ID now even though the count was greater than 1." >> $LOG_FILE
                  exit
               fi   
             else
               FIRST_READ=0
               if [[ $rec_PERIOD_ID > ' ' ]]; then
                  PERIOD_ID=$PERIOD_ID"','"$rec_PERIOD_ID
               fi   
             fi
           done < $PERIOD_FILE

           cd $SCRIPT_PATH
           print "Exec MDA_Allocation_DSCNT_email_started.ksh $LOG_FILE $MODEL_TYP_CD $PERIOD_ID" >> $LOG_FILE
           $SCRIPT_PATH/MDA_Allocation_DSCNT_email_started.ksh $LOG_FILE $MODEL_TYP_CD $PERIOD_ID

           print "Select PERIOD_ID,' ',DISCNT_RUN_MODE_CD,' ',ALOC_TYP_CD,' ',CNTRCT_ID,' ',RPT_ID,' ',REQ_DT,' ',REQ_TM,' ',REQ_STAT_CD from $TALLOCATN_OWNER.tallocatn_schedule where REQ_STAT_CD = 'P' and ALOC_TYP_CD = 'DISC' AND MODEL_TYP_CD = '$MODEL_TYP_CD' and timestamp(REQ_DT,REQ_TM) = (select min(timestamp(REQ_DT,REQ_TM)) from $TALLOCATN_OWNER.tallocatn_schedule where REQ_STAT_CD = 'P' and ALOC_TYP_CD = 'DISC' AND MODEL_TYP_CD = '$MODEL_TYP_CD')" > $SELECT_SQL

           db2 -xf $SELECT_SQL > $SNGL_SEL_OUTPUT_FILE
           SQLCODE=$?

           LOOPDONE='FALSE'
           while [[ $LOOPDONE = 'FALSE' ]]; do
              if [[ $SQLCODE = 0 ]]; then 
                 read PERIOD_ID DISCNT_RUN_MODE_CD ALOC_TYP_CD CNTRCT_ID RPT_ID REQ_DT REQ_TM REQ_STAT_CD < $SNGL_SEL_OUTPUT_FILE
                 print `date` >> $LOG_FILE
                 print "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&" >> $LOG_FILE
                 print "&  PERIOD_ID" $PERIOD_ID  >> $LOG_FILE
                 print "&  DISCNT_RUN_MODE_CD" $DISCNT_RUN_MODE_CD  >> $LOG_FILE
                 print "&  ALOC_TYP_CD" $ALOC_TYP_CD  >> $LOG_FILE
                 print "&  CNTRCT_ID" $CNTRCT_ID  >> $LOG_FILE
                 print "&  RPT_ID" $RPT_ID  >> $LOG_FILE
                 print "&  REQ_DT" $REQ_DT  >> $LOG_FILE
                 print "&  REQ_TM" $REQ_TM  >> $LOG_FILE
                 print "&  REQ_STAT_CD" $REQ_STAT_CD  >> $LOG_FILE
                 print "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&" >> $LOG_FILE

                 print "====================================================================" >> $LOG_FILE
             print "Building SQL MDA_Allocation_DISCNT_pre_allocation_sql010.ksh " >> $LOG_FILE
             print "====================================================================" >> $LOG_FILE
             . $SCRIPT_PATH/MDA_Allocation_DISCNT_pre_allocation_sql010.ksh $SQL_FILE_NAME $LOG_FILE $PERIOD_ID $CNTRCT_ID $RPT_ID $SCHEMA_OWNER $MODEL_TYP_CD
             print `date`"======db2 MDA_Allocation_DISCNT_pre_allocation_sql010.ksh ==START======" >> $LOG_FILE
             db2 -stvxf $SQL_FILE_NAME >> $LOG_FILE
             SQLCD010=$?
             print "SQLCD010 is :" $SQLCD010 >> $LOG_FILE
             print `date`"======db2 MDA_Allocation_DISCNT_pre_allocation_sql010.ksh ==END======" >> $LOG_FILE
             if [[ $SQLCD010 != 1 ]]; then
                print "Script " $SCRIPTNAME "found records or failed in execution of SQL from MDA_Allocation_DSCNT_pre_allocation_sql010.ksh." >> $LOG_FILE
                print "Return code is : <" $SQLCD010 ">" >> $LOG_FILE
             fi
             print "====================================================================" >> $LOG_FILE
             print "Building SQL MDA_Allocation_DISCNT_pre_allocation_sql020.ksh " >> $LOG_FILE
             print "====================================================================" >> $LOG_FILE
             . $SCRIPT_PATH/MDA_Allocation_DISCNT_pre_allocation_sql020.ksh $SQL_FILE_NAME $LOG_FILE $PERIOD_ID $CNTRCT_ID $RPT_ID $SCHEMA_OWNER $MODEL_TYP_CD 
             print `date`"======db2 MDA_Allocation_DISCNT_pre_allocation_sql020.ksh ==START======" >> $LOG_FILE
             db2 -stvxf $SQL_FILE_NAME >> $LOG_FILE
             SQLCD020=$?
             print "SQLCD020 is :" $SQLCD020 >> $LOG_FILE
             print `date`"======db2 MDA_Allocation_DISCNT_pre_allocation_sql020.ksh ==END======" >> $LOG_FILE
             if [[ $SQLCD020 != 1 ]]; then
                print "Script " $SCRIPTNAME "found records or failed in execution of SQL from MDA_Allocation_DSCNT_pre_allocation_sql020.ksh." >> $LOG_FILE
                print "Return code is : <" $SQLCD020 ">" >> $LOG_FILE
             fi
             print "====================================================================" >> $LOG_FILE
             print "Building SQL MDA_Allocation_DISCNT_pre_allocation_sql030.ksh" >> $LOG_FILE
             print "====================================================================" >> $LOG_FILE
             . $SCRIPT_PATH/MDA_Allocation_DISCNT_pre_allocation_sql030.ksh $SQL_FILE_NAME $LOG_FILE $PERIOD_ID $CNTRCT_ID $RPT_ID $SCHEMA_OWNER $MODEL_TYP_CD
             print `date`"======db2 MDA_Allocation_DISCNT_pre_allocation_sql030.ksh ==START======" >> $LOG_FILE
             db2 -stvxf $SQL_FILE_NAME >> $LOG_FILE
             SQLCD030=$?
             print "SQLCD030 is :" $SQLCD030 >> $LOG_FILE
             print `date`"======db2 MDA_Allocation_DISCNT_pre_allocation_sql030.ksh ==END======" >> $LOG_FILE
             if [[ $SQLCD030 != 1 ]]; then
                print "Script " $SCRIPTNAME "found records or failed in execution of SQL from MDA_Allocation_DSCNT_pre_allocation_sql030.ksh." >> $LOG_FILE
                print "Return code is : <" $SQLCD030 ">" >> $LOG_FILE
             fi

             if [[ $SQLCD010 != 1 || $SQLCD020 != 1 || $SQLCD030 != 1 ]]; then
                print "=========================================================" >> $LOG_FILE
                print "Pre-allocation Failed for PERIOD_ID $PERIOD_ID " >> $LOG_FILE
                print "=========================================================" >> $LOG_FILE
                print "=Updating TALLOCATN_SCHEDULE to 'E'rror =" >> $LOG_FILE
                print "=========================================================" >> $LOG_FILE
                
                MAIL_RETCODE=0

                # Send email error message to pagers
                EMAIL_SUBJECT="$SYSTEM $MODEL Model PRE-Allocation Error Occurred "`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
                print "\nThe Allocation process for Rebate/Discount Reports for Period $PERIOD_ID has ERRORED." >> $EMAIL_TEXT
                print "\nLook in $LOG_ARCH/$LOG_FILE." >> $EMAIL_TEXT
                print "\nThis run was in $SYSTEM." >> $EMAIL_TEXT

                print " mail command is : " >> $LOG_FILE
                print " mailx -c $DSCNT_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $DSCNT_EMAIL_TO_LIST < $EMAIL_TEXT " >> $LOG_FILE
                mailx -r GDXITD@Caremark.com -c $ALLOC_ERROR_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $ALLOC_ERROR_EMAIL_TO_LIST < $EMAIL_TEXT >> $LOG_FILE
                

                MAIL_RETCODE=$?

                if [[ $MAIL_RETCODE != 0 ]]; then
                    print "There was an error when sending the abend email.  Return code from mailx command was $MAIL_RETCODE." >> $LOG_FILE
                fi


cat > $SQL_FILE_NAME << 99EOFSQLTEXT99
Update $TALLOCATN_OWNER.tallocatn_schedule 
Set REQ_STAT_CD = 'E' 
   ,END_DT = CURRENT DATE 
   ,END_TM = CURRENT TIME
   ,RUN_DESC_TX = 'PreAllocation Error'        
where REQ_STAT_CD = 'P'
  and PERIOD_ID = '$PERIOD_ID'
  and DISCNT_RUN_MODE_CD = '$DISCNT_RUN_MODE_CD'
  and ALOC_TYP_CD = '$ALOC_TYP_CD' 
  and CNTRCT_ID = $CNTRCT_ID 
  and RPT_ID = $RPT_ID 
  and REQ_DT = DATE('$REQ_DT')
  and REQ_TM = TIME('$REQ_TM')
  and MODEL_TYP_CD = '$MODEL_TYP_CD';
99EOFSQLTEXT99

              db2 -stvxf $SQL_FILE_NAME >> $LOG_FILE

              SQLCODE=$?

               if [[ $SQLCODE != 0 ]]; then
                  print "Script " $SCRIPTNAMEA "failed in Update TALLOCATN_SCHEDULE to REQ_STAT = 'E'." >> $LOG_FILE
                  print "db2 return code is : <" $SQLCODE ">" >> $LOG_FILE
                  RETCODE=$SQLCODE
                   fi
             else
               PREALLOC_RETCODE=0
             fi 

                 if [[ $PREALLOC_RETCODE = 0 ]]; then
                if [[ $CNTRCT_ID > 0 ]]; then
                   print "@@@@@@@@@@@@@@@@@ MDAALLOC_MM_0031J_DSCNT_Allocation_by_cntrc_id.ksh @@@@@@@@@@@@@@@@@" >> $LOG_FILE
                   $SCRIPT_PATH/MDAALLOC_MM_0031J_DSCNT_Allocation_by_cntrc_id.ksh $PERIOD_ID $DISCNT_RUN_MODE_CD $ALOC_TYP_CD $CNTRCT_ID $RPT_ID $REQ_DT $REQ_TM $REQ_STAT_CD $MODEL_TYP_CD 
                else 
                   if [[ $RPT_ID > 0 ]]; then
                      print "@@@@@@@@@@@@@@@@@ MDAALLOC_MM_0032J_DSCNT_Allocation_by_rpt_id.ksh @@@@@@@@@@@@@@@@@" >> $LOG_FILE
                      $SCRIPT_PATH/MDAALLOC_MM_0032J_DSCNT_Allocation_by_rpt_id.ksh $PERIOD_ID $DISCNT_RUN_MODE_CD $ALOC_TYP_CD $CNTRCT_ID $RPT_ID $REQ_DT $REQ_TM $REQ_STAT_CD $MODEL_TYP_CD
                   else
                      print "@@@@@@@@@@@@@@@@@ MDAALLOC_MM_0030J_DSCNT_Allocation.ksh @@@@@@@@@@@@@@@@@" >> $LOG_FILE
                      $SCRIPT_PATH/MDAALLOC_MM_0030J_DSCNT_Allocation.ksh $PERIOD_ID $DISCNT_RUN_MODE_CD $ALOC_TYP_CD $CNTRCT_ID $RPT_ID $REQ_DT $REQ_TM $REQ_STAT_CD $MODEL_TYP_CD
                   fi
                fi
                 fi

                 print "....Selecting again ...."   >> $LOG_FILE

                 db2 -xf $SELECT_SQL > $SNGL_SEL_OUTPUT_FILE


                 SQLCODE=$?

                 print "....SQLCODE is : " $SQLCODE " in next SELECT...."   >> $LOG_FILE
                 LOOPDONE='FALSE'
              else
                 LOOPDONE='TRUE'
              fi   

           done   

           RETCODE=$?   

           . $SCRIPT_PATH/MDA_Allocation_DSCNT_email_completed.ksh $LOG_FILE $MODEL_TYP_CD $PERIOD_ID

        ################end  main ############
        fi
fi

if [[ $RETCODE != 0 ]]; then
    print "Failure in Script " $SCRIPT_NAME >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
    cp -f $LOG_FILE $LOG_ARCH.`date +"%Y%j%H%M"`
else    
    print " " >> $LOG_FILE
    print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
    print `date` >> $LOG_FILE
    mv -f $LOG_FILE $LOG_ARCH.`date +"%Y%j%H%M"`
fi

exit $RETCODE

