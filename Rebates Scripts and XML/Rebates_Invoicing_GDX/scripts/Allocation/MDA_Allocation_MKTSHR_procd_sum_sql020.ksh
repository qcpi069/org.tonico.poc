#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MKTSHR_procd_sum_sql020.ksh   
# Title         
#
# Description   : This script builds the second sql for the Market Share
#                   accural Monthly table, TMKTSHR_PROCD_SUM.
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

INSERT INTO VACTUATE.TMP_RPT_DLVRY_SYS 
SELECT   DISTINCT A.RPT_ID        ,A.PERIOD_ID      ,B.CNTRCT_ID ,D.VNDR_ID 
                 ,B.DRUG_CLS_VNDR ,B.DRUG_CLS_CMPTR ,A.DLVRY_SYS_CD

  FROM   VRAP.TMKTSHR_CLAIM_SUM A
        ,$SCHEMA_OWNER.TRPT_REQMT B
        ,VRAP.TRPT_DLVRY_SYS_CD C
        ,VRAP.TCNTRCT D
WHERE A.PERIOD_ID       =   '$PERIOD_ID'
  AND A.RPT_ID          =   C.RPT_ID
  AND A.RPT_ID          =   B.RPT_ID
  AND B.CNTRCT_ID       =   D.CNTRCT_ID ;



99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_MKTSHR_procd_sum_sql020.ksh " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

