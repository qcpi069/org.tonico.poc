#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MKTSHR_mnthly_cntrc_sql050.ksh   
# Title         
#
# Description   : This script is for reallocating contract in the 
#                   Monthly billed table, TMKTSHR_BILLED_SUM.
#
# Parameters    : SQL_FILE_NAME=$1,LOG_FILE=$2,PERIOD_ID=$3,CONTRACT_ID=$4,REPORT_ID=$5,TEST_SCHEMA_OWNER=$6
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-13-2005  N. Tucker  Initial Creation.
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

if [[ $TEST_SCHEMA_OWNER > "" ]]; then
    SCHEMA_OWNER=$TEST_SCHEMA_OWNER
else
    SCHEMA_OWNER="VRAP"
fi    

print "Starting build of SQL for " $SQL_FILE_NAME  >> $LOG_FILE
print `date` >> $LOG_FILE

cat > $SQL_FILE_NAME << 99EOFSQLTEXT99

INSERT INTO $SCHEMA_OWNER.TDRUG_MDA_AGG_RULE
SELECT   DISTINCT DRUG_NDC_ID
             ,NHU_TYP_CD  
             ,'UNKNOWN'  
             ,'UNKNOWN'
             ,CURRENT TIMESTAMP      
             ,99
             ,USER
             ,99
             ,CURRENT TIMESTAMP      
             ,USER
 FROM $SCHEMA_OWNER.TMKTSHR_BILLED_SUM
WHERE PERIOD_ID   = '$PERIOD_ID'    
  AND RPT_ID          IN    (SELECT C.RPT_ID 
                   FROM $SCHEMA_OWNER.TRPT_REQMT C
                  WHERE C.CNTRCT_ID IN ($CONTRACT_ID))

AND NOT EXISTS
    (SELECT 1 
           FROM $SCHEMA_OWNER.TDRUG_MDA_AGG_RULE
          WHERE $SCHEMA_OWNER.TDRUG_MDA_AGG_RULE.DRUG_NDC_ID   =  $SCHEMA_OWNER.TMKTSHR_BILLED_SUM.DRUG_NDC_ID
        AND $SCHEMA_OWNER.TDRUG_MDA_AGG_RULE.NHU_TYP_CD    =  $SCHEMA_OWNER.TMKTSHR_BILLED_SUM.NHU_TYP_CD );


99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_MKTSHR_mnthly_cntrc_sql050.ksh " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

