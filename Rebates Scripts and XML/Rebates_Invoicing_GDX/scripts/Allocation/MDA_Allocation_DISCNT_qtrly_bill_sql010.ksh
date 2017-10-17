#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_DISCNT_qtrly_bill_sql010.ksh   
# Title         
#
# Description   : This script builds the sql for quarterly discount table,
#           TDISCNT_BILLED_SUM$MODEL. This query allocates quarterly 
#           numbers back into the months that make up a quarter.
#                 ONLYPROD
#
# Parameters    : SQL_FILE_NAME=$1,LOG_FILE=$2,PERIOD_ID=$3,CONTRACT_ID=$4,REPORT_ID=$5,TEST_SCHEMA_OWNER=$6
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 12-15-05   is00084    6005148   Modified to include Medicare-D changes
# 04-18-05   qcpi733    5998083   Changed code to include input MODEL_TYP_CD 
#                                 and to use this field and pass it to other
#                                 scripts.
# 01-24-2005 N. Tucker            Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark MDA Allocation Environment variables
#-------------------------------------------------------------------------#

SQL_FILE_NAME=$1
LOG_FILE=$2
PERIOD_ID=$3
CONTRACT_ID=$4
REPORT_ID=$5
TEST_SCHEMA_OWNER=$6
MODEL_TYP_CD=$7
if [[ -z MODEL_TYP_CD ]]; then 
    print "No MODEL_TYP_CD was passed in, aborting."                           >> $LOG_FILE
    return 1
else
    if [[ $MODEL_TYP_CD = 'G' ]]; then
        MODEL="_GPO"
    elif [[ $MODEL_TYP_CD = 'X' ]]; then
        MODEL="_XMD"    
    else
        MODEL=""
    fi
fi

if [[ $TEST_SCHEMA_OWNER > "" ]]; then
    SCHEMA_OWNER=$TEST_SCHEMA_OWNER
else
    SCHEMA_OWNER="VRAP"
fi    

print "Starting build of SQL for " $SQL_FILE_NAME  >> $LOG_FILE
print `date` >> $LOG_FILE

cat > $SQL_FILE_NAME << 99EOFSQLTEXT99

DELETE FROM $SCHEMA_OWNER.TDISCNT_BILLED_SUM$MODEL
 WHERE    ('Q' || 
              CASE 
        WHEN SUBSTR(PERIOD_ID,2,2) BETWEEN   '01' AND '03'
            THEN '01'
        WHEN SUBSTR(PERIOD_ID,2,2) BETWEEN   '04' AND '06'
            THEN '02'
        WHEN SUBSTR(PERIOD_ID,2,2) BETWEEN   '07' AND '09'
            THEN '03'
        WHEN SUBSTR(PERIOD_ID,2,2) BETWEEN   '10' AND '12'
            THEN '04'
                          END
       || SUBSTR(PERIOD_ID,4,2))  = '$PERIOD_ID'       
   AND RPT_ID IN (SELECT RPT_ID 
                    FROM VRAP.TDISCNT_CLAIM_SUM$MODEL
                    WHERE PERIOD_ID      = '$PERIOD_ID'
                       AND DISCNT_RUN_MODE = 'PROD'
                 );


99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_DISCNT_qtrly_bill_sql010.ksh  " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

