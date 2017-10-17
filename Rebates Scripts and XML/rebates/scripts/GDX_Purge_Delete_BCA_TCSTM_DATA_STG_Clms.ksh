#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_Purge_Delete_BCA_TCSTM_DATA_STG_Clms.ksh
# Title         : Delete Claims data from tables BCA Or TCSTM_DATA_STG.
#
# Parameters    :
#                 -t table name <Name of the table which need to be purged>
#                 -s Step Number <optional - Step Number to Restart>
#                 -m table name <Optional - Additional Email if needed>
#
# Description   : The script will purge data from the tables TCSTM_DATA_STG
#               : OR RCIT_BASE_CLM_APC.
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 08-01-17   CVS437      ITPR019305 Rebates System Archiving
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# function to Connect DB
#-------------------------------------------------------------------------#
function connect_db 
{
    db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"
    RETCODE=$?  
  
    if [[ $RETCODE -ne 0 ]]; then
       print "aborting script - Error connecting to DB - $DATABASE"                                                                      >> $LOG_FILE
       print " "                                                                                                                         >> $LOG_FILE
       exit_error
    fi
}

#-------------------------------------------------------------------------#
# Execute SQL
#-------------------------------------------------------------------------#
function ExecSQL 
{
    print "\nSQL STATEMENT TO EXECUTE"                                                                                                     >> $LOG_FILE
    print "${EXEC_SQL}"                                                                                                                    >> $LOG_FILE
    db2 -c "${EXEC_SQL}"                                                                                                                   >> $LOG_FILE
    RETCODE=$?

    if [[ ${RETCODE} -ne 0 ]]; then
       ERROR=" ERROR: Error executing SQL Statement"
       print "\n ${ERROR} "                                                                                                              >> $LOG_FILE
       exit_error
    fi
}

#-------------------------------------------------------------------------#
# Execute SQL with Output
#-------------------------------------------------------------------------#
function ExecSQLOP 
{
    print "\n    SQL STATEMENT with Output TO EXECUTE"                                                                                   >> $LOG_FILE
    print "      $EXEC_SQL"                                                                                                              >> $LOG_FILE
    db2 -stx "$EXEC_SQL" > $1
    RETCODE=$?

    if [[ ${RETCODE} -ne 0 ]]; then
       ERROR=" ERROR: Error executing SQL Statement"
       print "\n ${ERROR} "                                                                                                              >> $LOG_FILE
       exit_error
    fi
}

#-------------------------------------------------------------------------#
# Function to exit the script on Success
#-------------------------------------------------------------------------#
function exit_success 
{
  if [[ ${upd_stus} -eq 1 ]]; then
     EXEC_SQL="UPDATE VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD = 100, UPDT_USR_ID = '${SCRIPTNAME}', UPDT_TS = CURRENT TIMESTAMP WHERE PURG_EVNT_ID = ${evnt_id}"
     ExecSQL
  fi

    print "\n********************************************"                                                                               >> $LOG_FILE
    print "....Completed executing  $SCRIPTNAME  ...."                                                                                 >> $LOG_FILE
    print `date '+%D %r %Z'`                                                                                                             >> $LOG_FILE
    print "\n********************************************"                                                                               >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH

    exit 0
}

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error
{
   EMAIL_SUBJECT="${SCRIPTNAME} Abended in $REGION `date`"

   ERR_MSG="\n !!! Aborting !!! \nReturn_code = ${RETCODE} \nCheck the Log file ${LOG_FILE} to identify issue \n\nRerun Instructions:\n${rerun} \n\n---- Ending script ${SCRIPT} `date`"
   print "${ERR_MSG}"                                                                                                                     >> ${LOG_FILE}

  if [[ ${upd_stus} -eq 1 ]]; then
     EXEC_SQL="UPDATE VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD = 92, UPDT_USR_ID = '${SCRIPTNAME}', UPDT_TS = CURRENT TIMESTAMP WHERE PURG_EVNT_ID = ${evnt_id}"
     ExecSQL
  fi

   cp -f $LOG_FILE $LOG_FILE_ARCH

(echo "${ERR_MSG}\n" ; uuencode ${LOG_FILE} ${LOG_FILE}) | /bin/mailx -s "${EMAIL_SUBJECT}" "${TO_MAIL}"

   exit 1
}

#-------------------------------------------------------------------------#
# Wrapper Function for STEP 10
# Get the CLM_GIDS from BCI Table and Insert into VRAP.RCIT_BASE_CLM_APC_ARCHIVE_WRK
#-------------------------------------------------------------------------#
function STEP10
{

print "\n *****************************  Starting STEP 10"                                                                          >> ${LOG_FILE}
print `date +"%D %r %Z"`                                                                                                            >> $LOG_FILE
print "     Load CLM_GID From RCIT_BASE_CLM_INV table to RCIT_BASE_CLM_APC_ARCHV_WRK Table"                                         >> ${LOG_FILE}

upd_stmt="Update VRAP.TRBAT_PURG_EVNT SET PURG_STUS_CD = 20,UPDT_TS = current date - ${del_days} days WHERE PURG_EVNT_ID = ${evnt_id}"

rerun="\nError at STEP 10. \n${upd_stmt} \nRerun the job from maestro or from command line  Ex: GDX_Purge_Delete_BCA_TCSTM_DATA_STG_Clms.ksh -t TCSTM_DATA_STG" 

##--- Get Period Begin Date for Current Open Period
EXEC_SQL="select TO_CHAR(min(qtr_period_begin_dt),'YYYY-MM-DD') bgn_dt from VRAP.VRCIT_MODEL_PRD_STUS where APC_STAT_CD = 'O' with ur"
ExecSQLOP ${TMP_FILE}

read Begin_Dt < ${TMP_FILE}

##--- Get Exclusive lock on RCIT_BASE_CLM_APC_ARCHV_WRK Table
EXEC_SQL="LOCK TABLE VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK IN EXCLUSIVE MODE"
ExecSQL

##--- Execute Declare Cursor Statement to load into TMP Table
EXEC_SQL="DECLARE C1 CURSOR FOR SELECT CLM_GID,INV_ELIG_DT,MODEL_TYP_CD,9,'${SCRIPTNAME}' Ins_User,CURRENT DATE FROM VRAP.RCIT_BASE_CLM_INV WHERE INV_ELIG_DT >= '${Begin_Dt}' WITH UR"
ExecSQL

##--- Execute Load From Cursor Statement to load into TMP Table
EXEC_SQL="LOAD FROM C1 OF CURSOR REPLACE INTO VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK nonrecoverable"
ExecSQL

print "\n End STEP 10 `date`"                                                                                                                >> ${LOG_FILE}

##--- Executing STEP20 from here.
STEP20

}

#-------------------------------------------------------------------------#
# Wrapper Function for STEP 20
# Get the CLM_GIDS from BCI Table and Insert into VRAP.RCIT_BASE_CLM_APC_ARCHIVE_WRK
#-------------------------------------------------------------------------#
function STEP20
{

print "\n  *****************************  Starting STEP 20"                                                                         >> ${LOG_FILE}
print `date +"%D %r %Z"`                                                                                                            >> $LOG_FILE

rerun="\nError at STEP 20. \n${upd_stmt} \nRerun the script from command prompt passing in the step number as a parameter. Ex: GDX_Purge_Delete_BCA_TCSTM_DATA_STG_Clms.ksh -t TCSTM_DATA_STG -s 20"

##--- Get Exclusive lock on Operational Table
EXEC_SQL="LOCK TABLE VRAP.${TBLNM} IN EXCLUSIVE MODE"
ExecSQL

##--- Get Exclusive lock on WRK Table
EXEC_SQL="LOCK TABLE VRAP.${TBLNM}_WRK IN EXCLUSIVE MODE"
ExecSQL

##--- Execute Declare Cursor Statement to load into WRK Table
EXEC_SQL="DECLARE C2 CURSOR FOR SELECT * FROM VRAP.${TBLNM} WHERE CLM_GID IN (SELECT CLM_GID FROM VRAP.RCIT_BASE_CLM_APC_ARCHV_WRK WHERE PRCS_STUS_CD = 9) WITH UR"
ExecSQL

##--- Execute Load From Cursor Statement to load into WRK Table
EXEC_SQL="LOAD FROM C2 OF CURSOR REPLACE INTO VRAP.${TBLNM}_WRK nonrecoverable"
ExecSQL

print "\n End STEP 20 `date`"                                                                                                                >> ${LOG_FILE}
##--- Executing STEP30 from here.
STEP30

}


#-------------------------------------------------------------------------#
# Wrapper Function for STEP 30
#-------------------------------------------------------------------------#
function STEP30
{

print "\n  *****************************  Starting STEP 30"                                                                         >> ${LOG_FILE}
print `date +"%D %r %Z"`                                                                                                            >> $LOG_FILE

rerun="Error at STEP 30. \n${upd_stmt} \nRerun the script from command prompt passing in the step number as a parameter. Ex: GDX_Purge_Delete_BCA_TCSTM_DATA_STG_Clms.ksh -t TCSTM_DATA_STG -s 30"

##--- Get Exclusive lock on Operational Table
EXEC_SQL="LOCK TABLE VRAP.${TBLNM} IN EXCLUSIVE MODE"
ExecSQL

##--- Get Exclusive lock on WRK Table
EXEC_SQL="LOCK TABLE VRAP.${TBLNM}_WRK IN EXCLUSIVE MODE"
ExecSQL

##--- Execute Declare Cursor Statement to load into Operational Table
EXEC_SQL="DECLARE C3 CURSOR FOR SELECT * FROM VRAP.${TBLNM}_WRK WITH UR"
ExecSQL

##--- Execute Load From Cursor Statement to load into Operational Table
EXEC_SQL="LOAD FROM C3 OF CURSOR REPLACE INTO VRAP.${TBLNM} nonrecoverable"
ExecSQL

print "\n End STEP 30 `date`"                                                                                                               >> ${LOG_FILE}

}


#-------------------------------------------------------------------------#
# Main Processing starts 
#-------------------------------------------------------------------------#

#--- Caremark Rebates Environment variables
  . `dirname $0`/Common_RCI_Environment.ksh


#--- Set Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")
FILEBASE=$(echo $SCRIPTNAME|awk -F. '{print $1}')

##-- This upd_stus variable is used to identify whether an update is needed for evnt_id
upd_stus=0

#--- Set file path and names
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILEBASE}.log.`date '+%Y%m%d_%H%M%S'`"
LOG_FILE=${LOG_DIR}/"${FILEBASE}.log"
TMP_FILE=${LOG_DIR}/"${FILEBASE}.tmp"

#--- Starting the script and log the starting time.
print "*********************************************************************************************"                                  > $LOG_FILE
print "Starting the script $SCRIPTNAME ............"                                                                                   >> $LOG_FILE
print `date +"%D %r %Z"`                                                                                                               >> $LOG_FILE
print "*********************************************************************************************"                                  >> $LOG_FILE


#--- Assign values to variable from arguments passed
rerun="Check the arguments passed. Please see USAGE. Rerun the job from maestro or from command line  Ex: GDX_Purge_Delete_BCA_TCSTM_DATA_STG_Clms.ksh -t TCSTM_DATA_STG"
while getopts t:s:m: argument
do
  case $argument in
    t)TBLNM=$OPTARG;;
    s)STEP=$OPTARG;;
    m)EMAILID1=$OPTARG@caremark.com;;
    *)
       echo "\n Usage: $SCRIPTNAME -t [-s] [-m] -- Refer the parameter usage below"                                                    >> $LOG_FILE
       echo "\n Example1: $SCRIPTNAME -t tablename -s Step Number -m firsname.lastname OR"                                             >> $LOG_FILE
       echo "\n Example2: $SCRIPTNAME -t tablename -s Step Number "                                                                    >> $LOG_FILE
       echo "\n Example2: $SCRIPTNAME -t tablename "                                                                                   >> $LOG_FILE
       echo "\n -s <StepNumber> Determines the Step Number to be Restart from"                                                         >> $LOG_FILE
       echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"                             >> $LOG_FILE
       RETCODE=1
       exit_error
       ;;
  esac
done

print "\n    Parameters passed for current run"                                                                                         >> $LOG_FILE
print "        Table Name : ${TBLNM}"                                                                                                   >> $LOG_FILE
print "        Step Number: ${STEP}"                                                                                                    >> $LOG_FILE
print "        Email      : ${EMAILID1}"                                                                                                >> $LOG_FILE


if [[ ${STEP} = '' ]]; then
  STEP=10
fi

#--- Validate Input Parameter

rerun="Check the Table name passed in. Rerun the job from maestro or from command line  Ex: GDX_Purge_Delete_BCA_TCSTM_DATA_STG_Clms.ksh -t TCSTM_DATA_STG"
if ! [[ ${TBLNM} == "RCIT_BASE_CLM_APC" || ${TBLNM} == "TCSTM_DATA_STG" ]]; then
print "Table Name passed in is ${TBLNM}    ............"                                                                               >> $LOG_FILE
  print "*********************************************************************************************"                                >> $LOG_FILE
  print "INVALID INPUT TABLE NAME PASSED ............"                                                                                 >> $LOG_FILE
  print "*********************************************************************************************"                                >> $LOG_FILE
  RETCODE=1
  exit_error
fi

rerun="Check the Step Number passed in. Rerun the job from maestro or from command line  Ex: GDX_Purge_Delete_BCA_TCSTM_DATA_STG_Clms.ksh -t TCSTM_DATA_STG"
if ! [[ ${STEP} == 10 || ${STEP} == 20 || ${STEP} == 30 ]]; then
print "STEP Number passed in is ${STEP}    ............"                                                                               >> $LOG_FILE
  print "*********************************************************************************************"                                >> $LOG_FILE
  print "INVALID INPUT STEP NUMBER PASSED ............"                                                                                >> $LOG_FILE
  print "*********************************************************************************************"                                >> $LOG_FILE
  RETCODE=1
  exit_error
fi

print "\n    Input Parameters are Validated"                                                                                           >> $LOG_FILE

rerun="\nError Error Error.\nRerun the job from maestro or from command line  Ex: GDX_Purge_Delete_BCA_TCSTM_DATA_STG_Clms.ksh -t TCSTM_DATA_STG" 

## Connect to GDX Database
connect_db

print "\n    Connected to database"                                                                                                    >> $LOG_FILE

##--- Get Number of Event Records with Delete Ready Status for Table $TBLNM
EXEC_SQL="SELECT COUNT(*) FROM VRAP.VRBAT_PURG_RULE_EVNT WHERE tbl_nm = '${TBLNM}' AND PURG_STUS_CD = 20 with ur"
ExecSQLOP ${TMP_FILE}

read rec_cnt < ${TMP_FILE}
print "Delete Event Records found for Table ${TBLNM} is : ${rec_cnt}"                                                               >> ${LOG_FILE}

if [[ $rec_cnt -eq 0 ]]; then
   print "\n --- No Events Found to Process so Exiting the script\n"                                                                >> ${LOG_FILE}
   RETCODE=0
   exit_success
elif [[ ${rec_cnt} -gt 1 ]]; then
   print "\n --- More than one Event Found to Process so Exiting the script with ERROR"                                             >> ${LOG_FILE}
   RETCODE=1
   exit_error
fi


##--- Get Event ID with Delete Ready Status for Table $TBLNM
EXEC_SQL="SELECT PURG_EVNT_ID, DELETE_DELAY_DAYS+1 DEL_DAYS FROM VRAP.VRBAT_PURG_RULE_EVNT WHERE tbl_nm = '${TBLNM}' AND PURG_STUS_CD = 20 with ur"
ExecSQLOP ${TMP_FILE}

read evnt_id del_days < ${TMP_FILE}
print "\n --- PURG_EVNT_GID IS : ${evnt_id}"                                                                                        >> ${LOG_FILE}
print "\n --- DELETE_DELAY_DAYS IS : ${del_days}"                                                                                   >> ${LOG_FILE}

upd_stus=1

if [[ ${STEP} = 10 ]]; then
  STEP10
elif [[ ${STEP} = 20 ]]; then
  STEP20
elif [[ ${STEP} = 30 ]]; then
  STEP30
fi

exit_success

