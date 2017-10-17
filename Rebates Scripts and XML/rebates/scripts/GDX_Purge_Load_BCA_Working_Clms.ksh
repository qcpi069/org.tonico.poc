#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_Purge_Load_BCA_Working_Clms.ksh
# Title         : Loads VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK table. 
#
# Parameters    : -s StepNumber <optional> 
#               : -m Email-ID   <optional> 
#
# Description   : Purpose of this script is to load VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK table. 
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Restart Instruction: On Failure
#          If any event record is already processed then 
#              a) Update the errored event record purg status code from 99 to 05
#              b) Restart the script by passing StepNumber e.g. GDX_Purge_Load_BCA_Working_Clms.ksh -s 99 
#                 (If the step number is 99, then VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK table will not be truncated)
#          If it fails while processing the first event record then 
#              a) Update the errored event record purg status code from 99 to 05
#              b) Restart the script without parameters e.g. GDX_Purge_Load_BCA_Working_Clms.ksh
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 08-04-17   qcpvf03s    ITPR019305 Rebates System Archiving 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_RCI_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error 
{
         RETCODE=$1
         ERROR=$2
         EMAIL_SUBJECT=$SCRIPTNAME" Abended in "$REGION" "`date`

         if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
            RETCODE=1
         fi

# Update event table status to 99(Generic Error) on error.
         UPD_ERR_SQL="UPDATE VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD=99, UPDT_USR_ID='$SCRIPTNAME', UPDT_TS = CURRENT TIMESTAMP WHERE PURG_EVNT_ID = $purg_evnt_id "
         print "\n Update PURG_STUS_CD to 99(Generic Error) for Event ID:$purg_evnt_id on TRBAT_PURG_EVNT table"                            >> $LOG_FILE
         db2 -c "$UPD_ERR_SQL"                                                                                                              >> $LOG_FILE
	       RETCODE=$?
	 
         if [[ $RETCODE -ne 0 ]]; then
            print "ERROR: Error executing SQL Statement to Update UPD_STUS_CD to 99 on TRBAT_PURG_EVNT table"                               >> $LOG_FILE
            print "Return Code is: <$RETCODE>"                                                                                              >> $LOG_FILE
            exit $RETCODE
         fi

        {
          print " "
          print $ERROR
          print " !!! Aborting !!!"
          print " "
          print "Return_code = " $RETCODE
          print " "
          print "PURG_STUS_CD is Updated to 99(Generic Error) for Event ID: $purg_evnt_id on TRBAT_PURG_EVNT table"
          print " "
          print "UPDATE VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD = 05, UPDT_USR_ID='SD Team', UPDT_TS = CURRENT DATE - $del_days DAYS WHERE PURG_EVNT_ID = $purg_evnt_id"
          print " "
          print "Rerun the job from maestro OR from command line "
          print " "
          print " ------ Ending script " $SCRIPT `date`
         }                                                                                                                                  >> $LOG_FILE

# Check if error message needs to be CCed (when email ID is passed)
         if [[ $CC_EMAIL_LIST = '' ]]; then
            mailx -s "$EMAIL_SUBJECT" $TO_MAIL  < $LOG_FILE
            echo ''
         else
            mailx -s "$EMAIL_SUBJECT" -c $CC_EMAIL_LIST $TO_MAIL  < $LOG_FILE
	          echo ''
         fi
   
         cp -f $LOG_FILE $LOG_FILE_ARCH
         exit $RETCODE
}


#-------------------------------------------------------------------------#
# Function to exit the script on Success
#-------------------------------------------------------------------------#

function exit_success 
{
         print " "                                                                                                                          >> $LOG_FILE
         print "*********************************************************************************************"                              >> $LOG_FILE
         print "....Completed executing " $SCRIPTNAME " ...."                                                                               >> $LOG_FILE
         print "All the CLM_GIDs are loaded into RCIT_BASE_CLM_APC_ARCHV_WRK Table "                                                        >> $LOG_FILE
         print `date +"%D %r %Z"`                                                                                                           >> $LOG_FILE
         print "*********************************************************************************************"                              >> $LOG_FILE
         
         cp -f $LOG_FILE $LOG_FILE_ARCH
         exit 0
}


#-------------------------------------------------------------------------#
# function to Connect DB
#-------------------------------------------------------------------------#
function connect_db 
{
         db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"
         RETCODE=$?  
  
         if [[ $RETCODE -ne 0 ]]; then
            print "aborting script - Error connecting to DB - $DATABASE"                                                                    >> $LOG_FILE
            print " "                                                                                                                       >> $LOG_FILE
            exit_error $RETCODE 
         fi
}


#-------------------------------------------------------------------------#
# RUN Following SQL
#-------------------------------------------------------------------------#
function RunSQL 
{
         db2 -csv "$RUN_SQL"                                                                                                                >> $LOG_FILE
         RETCODE=$?  
   
         if [[ $RETCODE -ne 0 ]]; then
            print "\n ERROR: Error executing SQL Statement: "                                                                               >> $LOG_FILE
            print " $RUN_SQL"                                                                                                               >> $LOG_FILE
            print "\n Return Code is: <$RETCODE>"                                                                                           >> $LOG_FILE
            exit_error $RETCODE
         fi
}


function SubProcess
{

print "\n Starting SubProcess"                                                                                                              >> $LOG_FILE
#-------------------------------------------------------------------------#
# Check if there are any event records to process.
#-------------------------------------------------------------------------#
# get the count of total event records marked as ARCHIVE WAIT (PURG_STUS_CD = 05) for VRAP.RCIT_BASE_CLM_APC_ARCHIVE table.
# If there are no event records to process, then script ends here with an appropriate message.
# If there are event records, event records are exported and written to the workfile.
#-------------------------------------------------------------------------#

 rec_cnt_sql="SELECT count(1) FROM VRAP.VRBAT_PURG_RULE_EVNT WHERE TBL_NM = 'RCIT_BASE_CLM_APC_ARCHIVE' AND PURG_STUS_CD = '05' WITH UR "
 print "\n Get the Event Table Record Count using below SQL Statement:"                                                                     >> $LOG_FILE
 print " $rec_cnt_sql"                                                                                                                      >> $LOG_FILE
	
 typeset -i rec_cnt=`db2 -x $rec_cnt_sql`
 print "\nTotal Event Record Count: $rec_cnt "                                                                                               >> $LOG_FILE

 if [[ $rec_cnt -gt 0 ]]; then
    export evnt_select="SELECT purg_evnt_id, TO_CHAR(DATE(TO_DATE(SUBSTR(PURG_RANGE_HIGH_VAL_TX,6,10),'YYYY-MM-DD')) - 1 DAYS,'YYYY-MM-DD') AS end_dt,SUBSTR(PURG_RANGE_LOW_VAL_TX,2,1) AS model_typ,DELETE_DELAY_DAYS+1 AS del_days FROM VRAP.VRBAT_PURG_RULE_EVNT WHERE TBL_NM = 'RCIT_BASE_CLM_APC_ARCHIVE' AND PURG_STUS_CD = '05' order by PURG_EVNT_ID WITH UR "
    print "\n Export Event records using below SQL Statement:"                                                                              >> $LOG_FILE
    print " $evnt_select"                                                                                                                   >> $LOG_FILE
 else 
    print "\n Ending script $SCRIPTNAME - No Event records to process "                                                                      >> $LOG_FILE
    exit_success 
 fi

 db2 -stxw $evnt_select > $WRK_FILE
 
      if [[ $RETCODE -ne 0 ]]; then
         print "\n ERROR: Error executing SQL Statement: "                                                                                  >> $LOG_FILE
         print " $evnt_select"                                                                                                              >> $LOG_FILE
         print "\n Return Code is: <$RETCODE>"                                                                                              >> $LOG_FILE
         exit_error $RETCODE
      fi
 
 print "\n All the Exported Event records are written to below work file:"                                                                  >> $LOG_FILE
 print " $WRK_FILE"                                                                                                                         >> $LOG_FILE
 print "****************************************************************************************************************"                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# If the step number is 99, then VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK table will not be truncated.
# If the step number is NOT 99, then Truncates RCIT_BASE_CLM_APC_ARCHV_WRK table.
#-------------------------------------------------------------------------#

if [[ ${STEP} -ne 99 ]]; then
   RUN_SQL="TRUNCATE TABLE VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK  immediate "
   print "\nTruncate VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK table before new run "                                                                >> $LOG_FILE
   RunSQL
fi

#-------------------------------------------------------------------------#
# Using cursor, Based on the archive rules - All the claims from BCI table are loaded to VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK Table
#-------------------------------------------------------------------------#

 while read purg_evnt_id end_dt model_typ del_days
 do
   print "\n****************************************************************************************************************"               >> $LOG_FILE
   print "\nProcessing event id: $purg_evnt_id for MODEL_TYP_CD: $model_typ, INV_ELIG_DT: $end_dt and DELETE_DELAY_DAYS: $del_days "        >> $LOG_FILE

# Declare a cursor to get claims from BCI Table  		  		
   print "\nDeclaring Cursor C1 to fetch CLM_GID, INV_ELIG_DT, MODEL_TYP_CD from BCI table where INV_ELIG_DT=$end_dt and MODEL_TYP_CD=$model_typ from the event table\n"   >> $LOG_FILE
   RUN_SQL="DECLARE C1 CURSOR FOR SELECT CLM_GID, INV_ELIG_DT, MODEL_TYP_CD, 0 PRCS_STUS_CD, '$SCRIPTNAME' CRTE_USR_ID, CURRENT TIMESTAMP CRTE_TS FROM VRAP.RCIT_BASE_CLM_INV WHERE INV_ELIG_DT = '$end_dt' and MODEL_TYP_CD = '$model_typ' WITH UR "
   RunSQL
    				
# Load cursor to load RCIT_BASE_CLM_APC_ARCHV_WRK table
   print "\nLoad CLM_GID, INV_ELIG_DT, MODEL_TYP_CD, PRCS_STUS_CD, CRTE_USR_ID, CRTE_TS to RCIT_BASE_CLM_APC_ARCHV_WRK table using Cursor C1 "   >> $LOG_FILE
   RUN_SQL="LOAD FROM C1 OF CURSOR INSERT INTO VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK nonrecoverable "
   db2 -csv "$RUN_SQL"                                                                                                                       >> $LOG_FILE
   RETCODE=$?  
   
   if [[ $RETCODE -ne 0 ]]; then
      print "\n ERROR: Error executing SQL Statement: "                                                                                     >> $LOG_FILE
      print " $RUN_SQL"                                                                                                                     >> $LOG_FILE
      print "\n Return Code is: <$RETCODE>"                                                                                                 >> $LOG_FILE
   
      db2 -csv "LOAD FROM /dev/null of del TERMINATE INTO VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK nonrecoverable "                                   >> $LOG_FILE
            
      exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Update Event table record to 10 (ARCHIVE READY) status
#-------------------------------------------------------------------------#        

   RUN_SQL="UPDATE VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD=10, UPDT_USR_ID='$SCRIPTNAME', UPDT_TS = CURRENT TIMESTAMP WHERE PURG_EVNT_ID = $purg_evnt_id "
   print "****************************************************************************************************************"                 >> $LOG_FILE
   print "PURG_STUS_CD is Updated to 10 (Archive Ready) for Event ID: $purg_evnt_id on TRBAT_PURG_EVNT Table "                              >> $LOG_FILE
   RunSQL
        
 done < $WRK_FILE

print "\nEnd SubProcess"                                                                                                                    >> $LOG_FILE

}



#-------------------------------------------------------------------------#
# Main Processing starts 
#-------------------------------------------------------------------------#

# Set Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")

# Set file path and names
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}').log
WRK_DIR=$REBATES_HOME/TgtFiles/Data_Archive/Work_Dir
WRK_FILE=$WRK_DIR/WRK_FILE"_LoadBCA_Archv_Wrk.wrk"

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "*****************************************************************************************************************"                   > $LOG_FILE
print "Starting the script $SCRIPTNAME ............"                                                                                        >> $LOG_FILE
print `date +"%D %r %Z"`                                                                                                                    >> $LOG_FILE
print "*****************************************************************************************************************"                   >> $LOG_FILE


#--- Assign values to variable from arguments passed
while getopts s:m: argument
do
  case $argument in
    s)STEP=$OPTARG;;
    m)EMAILID1=$OPTARG@caremark.com;;
    *)
       echo "\n Usage: $SCRIPTNAME [-s] [-m] -- Refer the parameter usage below"                                                            >> $LOG_FILE
       echo "\n Example1: $SCRIPTNAME "                                                                                                     >> $LOG_FILE
       echo "\n Example2: $SCRIPTNAME -s Step Number "                                                                                      >> $LOG_FILE
       echo "\n Example3: $SCRIPTNAME -m firsname.lastname OR"                                                                              >> $LOG_FILE
       echo "\n Example4: $SCRIPTNAME -s Step Number -m firsname.lastname OR"                                                               >> $LOG_FILE
       echo "\n -s <StepNumber> Determines the Step Number to be Restart from"                                                              >> $LOG_FILE
       echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"                                  >> $LOG_FILE
       exit_error ${RETCODE} "Incorrect arguments passed"
       exit
       ;;
  esac
done

print "\nParameters passed for current run"                                                                                                 >> $LOG_FILE
print "Step Number: ${STEP}"                                                                                                                >> $LOG_FILE
print "Email      : ${EMAILID1}"                                                                                                            >> $LOG_FILE
print "\n*********************************************************************************************"                                     >> $LOG_FILE

## Connect to GDX Database
connect_db
print "\nConnected to database"                                                                                                             >> $LOG_FILE

SubProcess

exit_success