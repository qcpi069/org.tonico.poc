#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MKTSHR_mnthly_rpt_sql040.ksh   
# Title         
#
# Description   : This script is for reallocating contracts in the 
#                   billed Monthly table, TMKTSHR_BILLED_SUM by contract and report.
#                 ONLYNOMPRD
#
# Parameters    : SQL_FILE_NAME=$1,LOG_FILE=$2,PERIOD_ID=$3,CONTRACT_ID=$4,REPORT_ID=$5,TEST_SCHEMA_OWNER=$6
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 04-18-05   qcpi733    5998083   Changed code to include input MODEL_TYP_CD 
#                                 and to use this field and pass it to other
#                                 scripts.
# 01-13-2005 N. Tucker            Initial Creation.
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

INSERT INTO $SCHEMA_OWNER.TMKTSHR_BILLED_SUM
SELECT          PART1.CNTRCT_ID
               ,PART1.RPT_ID
               ,D.MDA_DCL_PAIR_ID
               ,C.MDA_DCL_ID
               ,PART1.DRUG_NDC_ID
               ,PART1.NHU_TYP_CD
               ,PART1.INP_SRC_ID
               ,PART1.CLT_ID
               ,PART1.DLVRY_SYS_CD
               ,PART1.PERIOD_ID
               ,PART1.VNDR_ID
               ,PART1.FORMULARY_ID
               ,C.MDA_DCL_TYPE
               ,C.QUAL_EXT_PRICE
               ,PART1.QUAL_RX_COUNT 
               ,PART1.QUAL_UNITS                      
               ,CASE WHEN C.QUAL_UNITS > 0
                THEN DECIMAL((C.DAYS_OF_THERAPY * (DECIMAL(PART1.QUAL_UNITS,18,5)/C.QUAL_UNITS)),18,5)
                 ELSE 0
         END    AS DAYS_OF_THERAPY
               ,PART1.MODEL_TYP_CD
               ,PART1.FRMLY_SRC_CD
FROM
    ( SELECT        B.CNTRCT_ID                     AS CNTRCT_ID
                   ,B.RPT_ID                        AS RPT_ID
                   ,B.DRUG_NDC_ID                   AS DRUG_NDC_ID
                   ,B.NHU_TYP_CD                    AS NHU_TYP_CD
                   ,B.INP_SRC_ID                    AS INP_SRC_ID
                   ,B.CLT_ID                    AS CLT_ID
                   ,B.MODEL_TYP_CD                  AS MODEL_TYP_CD
                   ,B.VNDR_ID           AS VNDR_ID
                   ,B.FORMULARY_ID          AS FORMULARY_ID
                   ,B.FRMLY_SRC_CD                  AS FRMLY_SRC_CD
                   ,B.DLVRY_SYS_CD              AS DLVRY_SYS_CD
                   ,B.PERIOD_ID                     AS PERIOD_ID
                   ,B.DISCNT_RUN_MODE           AS DISCNT_RUN_MODE
                   ,SUM(B.ITEM_COUNT_QY)        AS QUAL_RX_COUNT 
                   ,SUM(B.DSPNSD_QTY)               AS QUAL_UNITS
                   ,SUM(B.DSPNSD_QTY)       AS DISCNT_UNITS

         FROM    VRAP.TMKTSHR_EXT_CLAIM   B
        WHERE B.PERIOD_ID                       =   '$PERIOD_ID'
                AND B.RPT_ID IN ($REPORT_ID)
---  UNCOMMENT THE FOLLOWING 2 LINES IF PROCESS TAKES TOO LONG TO RUN.  RUN QUERY IN GROUPS OF REPORT IDS.
--            AND B.RPT_ID                 BETWEEN    0
--                                                 AND 9999
                  AND B.RPT_ID      NOT IN
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

                       )  )

    GROUP BY 
                B.CNTRCT_ID
               ,B.RPT_ID
               ,B.DRUG_NDC_ID
               ,B.NHU_TYP_CD
               ,B.INP_SRC_ID 
               ,B.CLT_ID
               ,B.MODEL_TYP_CD
               ,B.VNDR_ID
               ,B.FORMULARY_ID
               ,B.FRMLY_SRC_CD
               ,B.DLVRY_SYS_CD
               ,B.PERIOD_ID 
               ,B.DISCNT_RUN_MODE ) AS PART1
   ,VRAP.TMKTSHR_CLAIM_SUM C
   ,$SCHEMA_OWNER.TMKTSHR_DCL_PAIR D
   ,$SCHEMA_OWNER.TRPT_REQMT E
    WHERE PART1.CNTRCT_ID                       =   C.CNTRCT_ID
      AND PART1.RPT_ID                          =   C.RPT_ID
      AND PART1.DRUG_NDC_ID                     =   C.DRUG_NDC_ID
      AND PART1.PERIOD_ID                       =   C.PERIOD_ID
      AND PART1.DISCNT_RUN_MODE         =   C.DISCNT_RUN_MODE 
      AND C.DISCNT_RUN_MODE                     NOT IN ('MPRD')
      AND C.MDA_DCL_ID              =   
                        CASE
                        WHEN C.MDA_DCL_TYPE = 'C'  THEN E.DRUG_CLS_CMPTR
                        ELSE E.DRUG_CLS_VNDR
                    END                     
      AND C.RPT_ID              =   E.RPT_ID 
      AND E.DRUG_CLS_CMPTR          =   D.MDA_CMPTR_DCL_ID  
      AND E.DRUG_CLS_VNDR           =   D.MDA_VNDR_DCL_ID
      AND E.RPT_ID  IN ($REPORT_ID) ;


99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_MKTSHR_mnthly_rpt_sql040.ksh " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

