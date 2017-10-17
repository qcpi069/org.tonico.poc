#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MKTSHR_procd_post_alloc_sql020.ksh   
# Title         
#
# Description   : This script is post allocation validation sql for the  
#                   claim sum mnthly Table, TMKTSHR_PROCD_SUM.
#
# Parameters    : SQL_FILE_NAME=$1,LOG_FILE=$2,PERIOD_ID=$3,CONTRACT_ID=$4,REPORT_ID=$5,TEST_SCHEMA_OWNER=$6
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-18-2005 J.Tedeschi  Added  AND A.DISCNT_RUN_MODE = 'MKSH'
# 01-20-2005 N. Tucker   Initial Creation.
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

SELECT   PART1.CNTRCT_ID   AS SUM_CNTRCT_ID
    ,PART1.RPT_ID  AS SUM_RPT_ID
    ,PART1.DRUG_NDC_ID AS SUM_DRUG_NDC_ID
    ,PART1.PERIOD_ID  AS SUM_PERIOD_ID
    ,PART1.DISCNT_RUN_MODE AS SUM_DISCNT_RUN_MODE
    ,PART1.QUAL_RX_COUNT AS SUM_QUAL_RX_COUNT
    ,PART1.QUAL_UNITS  AS SUM_QUAL_UNITS
FROM 
 (SELECT A.CNTRCT_ID
    ,A.RPT_ID
    ,A.PERIOD_ID
    ,A.DRUG_NDC_ID
    ,A.DISCNT_RUN_MODE  
    ,A.QUAL_RX_COUNT          AS QUAL_RX_COUNT
    ,A.QUAL_UNITS             AS QUAL_UNITS
   FROM VRAP.TMKTSHR_CLAIM_SUM A
       ,VRAP.TMKTSHR_DCL_PAIR D
       ,VRAP.TRPT_REQMT E
  where a.period_id = '$PERIOD_ID'
    AND A.MDA_DCL_ID =
        CASE
             WHEN A.MDA_DCL_TYPE    = 'C'  
             THEN E.DRUG_CLS_CMPTR
             ELSE E.DRUG_CLS_VNDR
        END
    AND A.DISCNT_RUN_MODE = 'MKSH'
    AND A.RPT_ID         = E.RPT_ID 
    AND E.DRUG_CLS_CMPTR = D.MDA_CMPTR_DCL_ID   
    AND E.DRUG_CLS_VNDR  = D.MDA_VNDR_DCL_ID ) AS PART1
WHERE NOT EXISTS 
      (SELECT 1
      FROM $SCHEMA_OWNER.TMKTSHR_PROCD_SUM  B   
     where part1.period_id = B.period_id
       and PART1.CNTRCT_ID =  B.CNTRCT_ID
           AND PART1.RPT_ID =  B.RPT_ID
           AND PART1.DRUG_NDC_ID =  B.DRUG_NDC_ID)

    AND PART1.RPT_ID NOT IN
    (SELECT X.TMP_RPT_ID FROM VACTUATE.TMP_RPT_DLVRY_SYS  X
      WHERE X.TMP_PERIOD_ID     =    '$PERIOD_ID'
        AND X.TMP_DLVRY_SYS_CD  <>  5
        AND (
         (EXISTS (SELECT 1
                        FROM VACTUATE.TMP_RPT_DLVRY_SYS  Y
                   WHERE Y.TMP_PERIOD_ID    =   X.TMP_PERIOD_ID     
                     AND Y.TMP_CNTRCT_ID    =   X.TMP_CNTRCT_ID 
                     AND Y.TMP_VNDR_ID      =   X.TMP_VNDR_ID
                     AND Y.TMP_DRUG_CLS_VNDR    =   X.TMP_DRUG_CLS_VNDR
                     AND Y.TMP_DRUG_CLS_CMPTR   =   X.TMP_DRUG_CLS_CMPTR
                     AND Y.TMP_DLVRY_SYS_CD =   5) 
            )
    ))
ORDER BY PART1.CNTRCT_ID
    ,PART1.RPT_ID
    ,PART1.DRUG_NDC_ID
    ,PART1.PERIOD_ID;
99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_MKTSHR_procd_post_alloc_sql020.ksh " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

