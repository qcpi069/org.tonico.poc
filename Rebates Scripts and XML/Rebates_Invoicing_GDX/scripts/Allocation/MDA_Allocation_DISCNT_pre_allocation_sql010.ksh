#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_DISCNT_pre_allocation_sql010.ksh   
# Title         
#
# Description   : This script builds the first sql for the pre-allocation checking process.
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

print "============================================================================= "  >> $LOG_FILE
print "Starting build of SQL for MDA_Allocation_MKTSHR_pre_allocation_sql010"  >> $LOG_FILE
print `date` >> $LOG_FILE

cat > $SQL_FILE_NAME << 99EOFSQLTEXT99

SELECT             PART1.CNTRCT_ID      AS EXT_CNTRCT_ID
                      ,PART1.RPT_ID     AS EXT_RPT_ID
                      ,PART1.DRUG_NDC_ID    AS EXT_DRUG_NDC_ID
                      ,PART1.PERIOD_ID      AS EXT_PERIOD_ID
                      ,PART1.DISCNT_RUN_MODE    AS EXT_DISCNT_RUN_MODE
                      ,PART1.QUAL_RX_COUNT  AS EXT_QUAL_RX_COUNT
                      ,PART1.QUAL_UNITS     AS EXT_QUAL_UNITS
FROM 
    (SELECT        A.CNTRCT_ID
                      ,A.RPT_ID
                  ,A.PERIOD_ID
                      ,A.DRUG_NDC_ID
                      ,A.DISCNT_RUN_MODE
                      ,SUM(A.ITEM_COUNT_QY)     AS QUAL_RX_COUNT
                      ,SUM(A.DSPNSD_QTY)        AS QUAL_UNITS
           FROM VRAP.TDISCNT_EXT_CLAIM$MODEL A
           WHERE PERIOD_ID            IN ('$PERIOD_ID')
     GROUP BY A.CNTRCT_ID
                 ,A.RPT_ID
                 ,A.DRUG_NDC_ID
                 ,A.PERIOD_ID
     ,A.DISCNT_RUN_MODE
                        )   AS PART1
    WHERE NOT EXISTS 

         (SELECT 1
            FROM VRAP.TDISCNT_CLAIM_SUM$MODEL  B   
           WHERE  PART1.CNTRCT_ID           =  B.CNTRCT_ID
             AND  PART1.RPT_ID              =  B.RPT_ID
             AND  PART1.DRUG_NDC_ID     =  B.DRUG_NDC_ID
             AND  PART1.DISCNT_RUN_MODE     =  B.DISCNT_RUN_MODE
             AND  PART1.PERIOD_ID           =  B.PERIOD_ID)
             AND   (    PART1.QUAL_RX_COUNT > 0
                OR  PART1.QUAL_UNITS    > 0 )

ORDER BY PART1.CNTRCT_ID
        ,PART1.RPT_ID
    ,PART1.DRUG_NDC_ID
    ,PART1.PERIOD_ID;


99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_DISCNT_pre_allocation_sql010.ksh " >> $LOG_FILE
    print "Return Code is :  " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for MDA_Allocation_DISCNT_pre_allocation_sql010.ksh"   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
print "============================================================================= "  >> $LOG_FILE

return $RETCODE

