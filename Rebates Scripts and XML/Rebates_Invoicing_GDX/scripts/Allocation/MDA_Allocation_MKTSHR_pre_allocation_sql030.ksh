#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MKTSHR_pre_allocation_sql030.ksh   
# Title         
#
# Description   : This script builds the third sql for the pre-allocation checking process.
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

print "Starting build of SQL for MDA_Allocation_MKTSHR_pre_allocation_sql030.ksh "  >> $LOG_FILE
print `date` >> $LOG_FILE

cat > $SQL_FILE_NAME << 99EOFSQLTEXT99

SELECT         B.CNTRCT_ID
              ,B.RPT_ID
              ,B.DRUG_NDC_ID
              ,B.PERIOD_ID
              ,B.DISCNT_RUN_MODE
              ,B.QUAL_RX_COUNT
              ,B.QUAL_UNITS
              ,PART1.QUAL_RX_COUNT  AS EXT_CLAIM_QUAL_RX_COUNT
              ,PART1.QUAL_UNITS     AS EXT_CLAIM_QUAL_UNITS

  FROM VRAP.TMKTSHR_CLAIM_SUM  B
      ,(SELECT  CNTRCT_ID
               ,RPT_ID
               ,DRUG_NDC_ID
               ,PERIOD_ID
               ,DISCNT_RUN_MODE
               ,SUM(ITEM_COUNT_QY)  AS QUAL_RX_COUNT
               ,SUM(DSPNSD_QTY)         AS QUAL_UNITS
          FROM  VRAP.TMKTSHR_EXT_CLAIM
         WHERE PERIOD_ID            IN ('$PERIOD_ID')

         GROUP BY CNTRCT_ID
                 ,RPT_ID
                 ,DRUG_NDC_ID
                 ,PERIOD_ID
         ,DISCNT_RUN_MODE          )    AS PART1
WHERE PART1.CNTRCT_ID           = B.CNTRCT_ID
  AND PART1.RPT_ID              = B.RPT_ID
  AND PART1.DRUG_NDC_ID     = B.DRUG_NDC_ID
  AND PART1.PERIOD_ID           = B.PERIOD_ID
  AND PART1.DISCNT_RUN_MODE = B.DISCNT_RUN_MODE
  AND (   PART1.QUAL_RX_COUNT  <> B.QUAL_RX_COUNT
       OR PART1.QUAL_UNITS     <> B.QUAL_UNITS)
ORDER BY B.RPT_ID
        ,B.DRUG_NDC_ID
    ,B.PERIOD_ID
    ,B.DISCNT_RUN_MODE;

99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_MKTSHR_pre_allocation_sql030.ksh " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for MDA_Allocation_MKTSHR_pre_allocation_sql030.ksh "   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

