#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_Purge_Delete_BCA_Archive.ksh
# Title         : Deletes archive records from RCIT_BASE_CLM_APC_ARCHIVE table.
#
# Parameters    : -l Parameter file (looplimitfile.txt) <Mandatory> 
#               : -m email id <optional> 
#
# Description   : The Purpose of the script is to delete archive records from RCIT_BASE_CLM_APC_ARCHIVE table.
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Restart Instruction: On Failure
#          If it fails while processing the event record then 
#              a) Update the errored event record purg status code from 92 to 20 and prcs stus cd to 0 in RCIT_BASE_CLM_APC_ARCHV_WRK table
#              b) Restart the script
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 07-28-17   qcpvf03s    ITPR019305 Rebates System Archiving 
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

        {
           print " "
           print $ERROR
           print " !!! Aborting !!!"
           print " "
           print "Return_code = " $RETCODE
           print " "
           print "Rerun the job from maestro OR from command line "
           print " "
           print " ------ Ending script " $SCRIPT `date`
        }                                                                                                                                   >> $LOG_FILE


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
         db2 -mpx "$RUN_SQL"                                                                                                                >> $LOG_FILE
         RETCODE=$?  
         if [[ $RETCODE -ne 0 ]]; then
            print "\n ERROR: Error executing SQL Statement: "                                                                               >> $LOG_FILE
            print " $RUN_SQL"                                                                                                               >> $LOG_FILE
            print "\n Return Code is: <$RETCODE>"                                                                                           >> $LOG_FILE
            upd_Err
            exit_error $RETCODE
         fi
}

#-------------------------------------------------------------------------#
# Update event table status to 92(Delete Process Error) on error.
#-------------------------------------------------------------------------#
function upd_Err 
{
        print "PURG_STUS_CD is Updated to 92(Delete Process Error) for Event ID: $purg_evnt_id on TRBAT_PURG_EVNT table"
        print " "
        print "UPDATE VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD = 20, UPDT_USR_ID='SD Team', UPDT_TS = CURRENT DATE - $del_days DAYS WHERE PURG_EVNT_ID = $purg_evnt_id"
        print " "
        
        UPD_ERR_SQL="UPDATE VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD=92, UPDT_USR_ID='$SCRIPTNAME', UPDT_TS = CURRENT TIMESTAMP WHERE PURG_EVNT_ID = $purg_evnt_id "
        db2 -c "$UPD_ERR_SQL"                                                                                                               >> $LOG_FILE
        
        RETCODE=$?
	 
        if [[ $RETCODE -ne 0 ]]; then
           print "ERROR: Error executing SQL Statement to Update UPD_STUS_CD to 92 on TRBAT_PURG_EVNT table"                                >> $LOG_FILE
           print "Return Code is: <$RETCODE>"                                                                                               >> $LOG_FILE
          exit $RETCODE
        fi
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
WRK_FILE=$WRK_DIR/WRK_FILE"_DeleteBCAArchive.wrk"


#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "*********************************************************************************************"                                       > $LOG_FILE
print "Starting the script $SCRIPTNAME ............"                                                                                        >> $LOG_FILE
print `date +"%D %r %Z"`                                                                                                                    >> $LOG_FILE
print "*********************************************************************************************"                                       >> $LOG_FILE


#--- Assign values to variable from arguments passed
while getopts l:m: argument
do
  case $argument in
    l)LOOPLMTFILE=$OPTARG;;
    m)EMAILID1=$OPTARG@caremark.com;;
    *)
       echo "\n Usage: $SCRIPTNAME [-l] [-m] -- Refer the parameter usage below"                                                            >> $LOG_FILE
       echo "\n Example2: $SCRIPTNAME -l LoopLmtFile "                                                                                      >> $LOG_FILE
       echo "\n Example3: $SCRIPTNAME -m firsname.lastname OR"                                                                              >> $LOG_FILE
       echo "\n Example4: $SCRIPTNAME -l LoopLmtFile -m firsname.lastname OR"                                                               >> $LOG_FILE
       echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"                                  >> $LOG_FILE
       exit_error ${RETCODE} "Incorrect arguments passed"
       exit
       ;;
  esac
done


print "\nParameters passed for current run"                                                                                                 >> $LOG_FILE
print "Loop Limit File: ${LOOPLMTFILE}"                                                                                                     >> $LOG_FILE
print "Email      : ${EMAILID1}"                                                                                                            >> $LOG_FILE
print "\n*********************************************************************************************"                                     >> $LOG_FILE

connect_db

#--- Validate Input Parameter

if [[ ${LOOPLMTFILE} = '' ]]; then
      RETCODE=1
            echo "\n ERROR: MISSING PARAMETER FILE: looplimitfile.txt"                                                                      >> $LOG_FILE
            echo "\n Please see below for Script running Instructions:"                                                                     >> $LOG_FILE
            echo "\n        Usage: $SCRIPTNAME -l <Compulsory> -m <optional email> "                                                        >> $LOG_FILE
            echo "\n        Example: $SCRIPTNAME -l looplimitfile.txt"                                                                      >> $LOG_FILE
            echo "\n        -l <input File> input file name with extension"                                                                 >> $LOG_FILE
            echo "\n        -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"                      >> $LOG_FILE
      exit_error ${RETCODE} "Incorrect arguments passed \n"
fi


# Set the input paramter file path
 Loop_limit_file=$REBATES_HOME/SrcFiles/ParmFiles/${LOOPLMTFILE}
 print " Loop limit file: $Loop_limit_file"                                                                                                 >> $LOG_FILE
 MaxLoopCnt=`cat $Loop_limit_file`
 print " Loop limit file count: $MaxLoopCnt "                                                                                               >> $LOG_FILE

#-------------------------------------------------------------------------#
# STEP#1: Check if there are any event records to process.
#-------------------------------------------------------------------------#
# get the count of total event records marked as DELETE READY (PURG_STUS_CD = 20) for RCIT_BASE_CLM_APC_ACRHIVE table.
# If there are no event records to process, then script ends here with an appropriate message.
# If there are event records, event records are exported and written to a workfile.
#-------------------------------------------------------------------------#

 rec_cnt_sql="SELECT count(1) FROM VRAP.VRBAT_PURG_RULE_EVNT WHERE TBL_NM = 'RCIT_BASE_CLM_APC_ARCHIVE' AND PURG_STUS_CD = 20 WITH UR "
 print "\n Get the Event Table Record Count using below SQL Statement:"                                                                     >> $LOG_FILE
 print " $rec_cnt_sql"                                                                                                                      >> $LOG_FILE
	
 typeset -i rec_cnt=`db2 -x $rec_cnt_sql`
 print " Total Event Record Count: $rec_cnt "                                                                                               >> $LOG_FILE

 if [[ $rec_cnt -ne 0 ]]; then
    export evnt_select="SELECT purg_evnt_id, TO_CHAR(DATE(TO_DATE(SUBSTR(PURG_RANGE_HIGH_VAL_TX,6,10),'YYYY-MM-DD')) - 1 DAYS,'YYYY-MM-DD') AS end_dt,SUBSTR(PURG_RANGE_LOW_VAL_TX,2,1) AS model_typ,DELETE_DELAY_DAYS+1 AS del_days,DEL_ROW_LIMIT,DEL_STMNT_TX FROM VRAP.VRBAT_PURG_RULE_EVNT WHERE TBL_NM = 'RCIT_BASE_CLM_APC_ARCHIVE' AND PURG_STUS_CD = 20 ORDER BY PURG_EVNT_ID FETCH FIRST $MaxLoopCnt ROWS ONLY WITH UR "
    print "\n Export Event records using below SQL Statement:"                                                                              >> $LOG_FILE
    print " $evnt_select"                                                                                                                   >> $LOG_FILE
 else 
    print "\n Ending script $SCRIPTNAME - No Purge Event records to process"                                                                >> $LOG_FILE
    print " "                                                                                                                               >> $LOG_FILE
    exit_success 
 fi

 db2 -stxw $evnt_select > $WRK_FILE
      
      RETCODE=$?
      if [[ $RETCODE -ne 0 ]]; then
         print "\n ERROR: Error executing SQL Statement: "                                                                                  >> $LOG_FILE
         print " $evnt_select"                                                                                                              >> $LOG_FILE
         print "\n Return Code is: <$RETCODE>"                                                                                              >> $LOG_FILE
         upd_Err
         exit_error $RETCODE
      fi


 print "\n All the Exported Event records are written to below work file:"                                                                  >> $LOG_FILE
 print " $WRK_FILE"                                                                                                                         >> $LOG_FILE
 print "*********************************************************************************************"                                      >> $LOG_FILE


#-------------------------------------------------------------------------#
# STEP#2: Delete Claims from VRAP.RCIT_BASE_CLM_APC_ARCHIVE table.
#-------------------------------------------------------------------------# 
# Below two while loops are used to DELETE claims from VRAP.RCIT_BASE_CLM_APC_ARCHIVE table.
# Outer while loop contains logic to read each event record marked as DELETE READY for VRAP.RCIT_BASE_CLM_APC_ARCHIVE table from the VRBAT_PURG_RULE_EVNT
# 	    Inner while loop contains logic to loop thru claims in BCA_ARCHV_WRK table and deletes claims from BCA_ARCHIVE table based on DEL_ROW_LIMIT value, a value set in Rule table 
#       Inner while loop ends after deleting claims for that particular event record. 
# Outer while loop ends once it processes all event records from the workfile.
#-------------------------------------------------------------------------# 

 while read purg_evnt_id end_dt model_typ del_days DEL_ROW_LIMIT DEL_STMNT_TX  
 do
   BCA_cnt=1
   print "\n Processing event id: $purg_evnt_id for MODEL_TYP_CD: $model_typ and INV_ELIG_DT: $end_dt and row limit: $DEL_ROW_LIMIT" >> $LOG_FILE
  		
   while [[ $BCA_cnt -ne 0 ]]
   do
     print "\n Update PRCS_STUS_CD to 1 (InProgress) for first $DEL_ROW_LIMIT rows in RCIT_BASE_CLM_APC_ARCHV_WRK Table "                   >> $LOG_FILE
     RUN_SQL="UPDATE VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK SET PRCS_STUS_CD=1 WHERE CLM_GID IN (SELECT CLM_GID FROM VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK WHERE PRCS_STUS_CD=0 AND INV_ELIG_DT='$end_dt' AND MODEL_TYP_CD='$model_typ' FETCH FIRST $DEL_ROW_LIMIT ROWS ONLY WITH UR ) "
     RunSQL
  
         				
# This Delete statement comes directly from the event table. It delete rows from RCIT_BASE_CLM_APC_ARCHIVE table where clm_gid in (clm_gid from RCIT_BASE_CLM_APC_ARCHV_WRK table where PRCS_STUS_CD is 1)
     print "\n Execute below Delete SQL Statement: "   >> $LOG_FILE
     print " $DEL_STMNT_TX "                                                                                                                >> $LOG_FILE
     db2 -ctv "$DEL_STMNT_TX"                                                                                                               >> $LOG_FILE
     
     RETCODE=$?
     if [[ $RETCODE -ne 0 ]]; then
        print "\n ERROR: Error executing SQL Statement: "                                                                                   >> $LOG_FILE
        print "$DEL_STMNT_TX"                                                                                                               >> $LOG_FILE
        print "\n Return Code is: <$RETCODE>"                                                                                               >> $LOG_FILE
        upd_Err
        exit_error $RETCODE
     fi
         				    		
     print "\n Update PRCS_STUS_CD to 2 (Complete) where PRCS_STUS_CD =1 in RCIT_BASE_CLM_APC_ARCHV_WRK Table "                             >> $LOG_FILE
     RUN_SQL="UPDATE VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK SET PRCS_STUS_CD=2 WHERE PRCS_STUS_CD=1 "
     RunSQL
     print "*********************************************************************************************"                                  >> $LOG_FILE
						
     bca_cnt_sql="SELECT COUNT(1) AS BCA_CNT FROM VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK WHERE PRCS_STUS_CD=0 and INV_ELIG_DT = '$end_dt' and MODEL_TYP_CD = '$model_typ' WITH UR "  
     print "\n Get the Total Record Count from RCIT_BASE_CLM_APC_ARCHV_WRK table where PRCS_STUS_CD=0 using below SQL Statement: "          >> $LOG_FILE
     print " $bca_cnt_sql"                                                                                                                  >> $LOG_FILE
     typeset -i BCA_cnt=`db2 -x $bca_cnt_sql`
     print " Total Record Count from RCIT_BASE_CLM_APC_ARCHV_WRK Table: $BCA_cnt "                                                          >> $LOG_FILE
    				
     if [[ $BCA_cnt = 0 ]]; then 
        RUN_SQL="UPDATE VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD=100, UPDT_USR_ID='$SCRIPTNAME', UPDT_TS = CURRENT TIMESTAMP WHERE PURG_EVNT_ID = $purg_evnt_id "
        print "\n PURG_STUS_CD is Updated to 100 (Event Complete) for Event ID: $purg_evnt_id on TRBAT_PURG_EVNT Table "                    >> $LOG_FILE
        RunSQL
        print "*********************************************************************************************"                               >> $LOG_FILE
     fi   				
   done   
 done < $WRK_FILE
	
exit_success