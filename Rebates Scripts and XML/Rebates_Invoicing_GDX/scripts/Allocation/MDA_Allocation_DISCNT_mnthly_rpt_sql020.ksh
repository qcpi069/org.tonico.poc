#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_DISCNT_mnthly_rpt_sql020.ksh   
# Title         
#
# Description   : This script builds the sql discount monthly billed table,
#           TDISCNT_BILLED_SUM$MODEL by report id.
#                 ONLYMPRD
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
# 10-14-05   qcpi733    6004155   Added /100 on PART1.PRFMC_DISCNT_FCTR
#                                 when RT_BASIS_TYP_CD = 4 as per Anand
#                                 Arabati.
# 08-30-05   qcpi733    6004155   Added join for Phizer on 
#                                 TDISCNT_CLAIM_CLT_SUM.
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

INSERT INTO $SCHEMA_OWNER.TDISCNT_BILLED_SUM$MODEL
 SELECT     PART1.CNTRCT_ID
           ,PART1.RPT_ID
           ,PART1.DRUG_NDC_ID
           ,PART1.NHU_TYP_CD
           ,PART1.INP_SRC_ID
           ,PART1.CLT_ID
           ,PART1.DLVRY_SYS_CD
           ,PART1.PERIOD_ID
           ,C.QUAL_EXT_PRICE
           ,0                                               AS RX_COUNT
           ,PART1.QUAL_RX_COUNT 
           ,PART1.QUAL_RX_COUNT                         AS DISCNT_RX_COUNT
           ,0                                               AS UNITS
           ,PART1.QUAL_UNITS
           ,PART1.DISCNT_UNITS
           ,SUM(   CASE  
        
        WHEN RT_BASIS_TYP_CD  = 1 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
            THEN  C.BASE_DISCNT_FCTR  * DECIMAL(PART1.QUAL_UNITS,18,5)  

        WHEN RT_BASIS_TYP_CD  = 2 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
            THEN  C.BASE_DISCNT_FCTR  * DECIMAL(PART1.QUAL_RX_COUNT,18,5)

        WHEN RT_BASIS_TYP_CD  = 4 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
                THEN  C.BASE_DISCNT_FCTR  * DECIMAL(PART1.QUAL_UNITS,18,5) *  C.QUAL_EXT_PRICE
        
        ELSE   0
                
--          WHEN RPT_TYP_CD = 11
--                  THEN    DECIMAL(PART1.QUAL_UNITS,18,5) * ((C.QUAL_EXT_PRICE - C.CONTRACT_PRICE) 
--                       + (C.BASE_DISCNT_FCTR  * DECIMAL(PART1.QUAL_UNITS,18,5)) )

           END )  AS BASE_DISCOUNT_AMT   

            ,SUM(   
             CASE  

        WHEN RT_BASIS_TYP_CD  = 1 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
--prephizer THEN  C.PRFMC_DISCNT_FCTR  * DECIMAL(PART1.QUAL_UNITS,18,5)  
            THEN  (CASE WHEN PART1.PRFMC_DISCNT_FCTR IS NULL THEN C.PRFMC_DISCNT_FCTR 
                        ELSE PART1.PRFMC_DISCNT_FCTR END) * DECIMAL(PART1.QUAL_UNITS,18,5)  

        WHEN RT_BASIS_TYP_CD  = 2 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
--prephizer THEN  C.PRFMC_DISCNT_FCTR  * DECIMAL(PART1.QUAL_RX_COUNT,18,5)
            THEN  (CASE WHEN PART1.PRFMC_DISCNT_FCTR IS NULL THEN C.PRFMC_DISCNT_FCTR 
                        ELSE PART1.PRFMC_DISCNT_FCTR END) * DECIMAL(PART1.QUAL_RX_COUNT,18,5)

        WHEN RT_BASIS_TYP_CD  = 4 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
--prephizer     THEN  C.PRFMC_DISCNT_FCTR  * DECIMAL(PART1.QUAL_UNITS,18,5) *  C.QUAL_EXT_PRICE
                THEN  (CASE WHEN PART1.PRFMC_DISCNT_FCTR IS NULL THEN C.PRFMC_DISCNT_FCTR * 100
                        ELSE PART1.PRFMC_DISCNT_FCTR END) * DECIMAL(PART1.QUAL_UNITS,18,5) *  C.QUAL_EXT_PRICE /100
        
        ELSE   0
                
--          WHEN RPT_TYP_CD = 11
--          THEN    DECIMAL(PART1.QUAL_UNITS,18,5) * ((C.QUAL_EXT_PRICE - C.CONTRACT_PRICE) 
--                       + (C.PRFMC_DISCNT_FCTR  * DECIMAL(PART1.QUAL_UNITS,18,5)) )
           END 
        )  AS PRFMC_DISCOUNT_AMT    
            ,SUM(    
             CASE  

        WHEN RT_BASIS_TYP_CD  = 1 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
--            THEN  C.FORMLY_DISCNT_FCTR * DECIMAL(PART1.QUAL_UNITS,18,5)  
            THEN  (CASE WHEN PART1.FORMLY_DISCNT_FCTR IS NULL THEN C.FORMLY_DISCNT_FCTR 
                      ELSE PART1.FORMLY_DISCNT_FCTR END) * DECIMAL(PART1.QUAL_UNITS,18,5)  

        WHEN RT_BASIS_TYP_CD  = 2 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
--prephizer THEN  C.PRFMC_DISCNT_FCTR  * DECIMAL(PART1.QUAL_RX_COUNT,18,5)
            THEN  (CASE WHEN PART1.PRFMC_DISCNT_FCTR IS NULL THEN C.PRFMC_DISCNT_FCTR 
                        ELSE PART1.PRFMC_DISCNT_FCTR END) * DECIMAL(PART1.QUAL_RX_COUNT,18,5)

        WHEN RT_BASIS_TYP_CD  = 4 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
--                THEN  C.FORMLY_DISCNT_FCTR * DECIMAL(PART1.QUAL_UNITS,18,5) *  C.QUAL_EXT_PRICE
                THEN  (CASE WHEN PART1.FORMLY_DISCNT_FCTR IS NULL THEN C.FORMLY_DISCNT_FCTR 
                          ELSE PART1.FORMLY_DISCNT_FCTR END) * DECIMAL(PART1.QUAL_UNITS,18,5) *  C.QUAL_EXT_PRICE
        
        ELSE   0
                
--          WHEN RPT_TYP_CD = 11
--          THEN    DECIMAL(PART1.QUAL_UNITS,18,5) * ((C.QUAL_EXT_PRICE - C.CONTRACT_PRICE) 
--                       + (C.FORMLY_DISCNT_FCTR  * DECIMAL(PART1.QUAL_UNITS,18,5)) )
           END 

        )  AS FORMLY_DISCOUNT_AMT       
        ,SUM(    
             CASE  
        WHEN RT_BASIS_TYP_CD  = 1 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
            THEN  C.GRWTH_DISCNT_FCTR * DECIMAL(PART1.QUAL_UNITS,18,5)  

        WHEN RT_BASIS_TYP_CD  = 2 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
            THEN  C.GRWTH_DISCNT_FCTR  * DECIMAL(PART1.QUAL_RX_COUNT,18,5)

        WHEN RT_BASIS_TYP_CD  = 4 AND (RPT_TYP_CD = 10 OR RPT_TYP_CD = 12 OR RPT_TYP_CD = 24)
                THEN  C.GRWTH_DISCNT_FCTR * DECIMAL(PART1.QUAL_UNITS,18,5) *  C.QUAL_EXT_PRICE
        
        ELSE   0
                
--          WHEN RPT_TYP_CD = 11
--          THEN   DECIMAL(PART1.QUAL_UNITS,18,5) * ((C.QUAL_EXT_PRICE - C.CONTRACT_PRICE) 
--                  + (C.GRWTH_DISCNT_FCTR  * DECIMAL(PART1.QUAL_UNITS,18,5)) )
           END  
        )  AS GRWTH_DISCOUNT_AMT
        
       ,PART1.VNDR_ID
       ,PART1.FORMULARY_ID
           ,DISCNT_BASIS_TYP
           ,C.CONTRACT_PRICE
       ,C.BASE_DISCNT_FCTR
--prephizer  ,C.PRFMC_DISCNT_FCTR
--       ,(CASE WHEN PART1.PRFMC_DISCNT_FCTR IS NULL THEN C.PRFMC_DISCNT_FCTR 
--                        ELSE PART1.PRFMC_DISCNT_FCTR END)
        ,(CASE WHEN PART1.PRFMC_DISCNT_FCTR IS NULL 
                    THEN C.PRFMC_DISCNT_FCTR 
                    ELSE (CASE WHEN RT_BASIS_TYP_CD  = 4 
                               THEN PART1.PRFMC_DISCNT_FCTR/100
                               ELSE PART1.PRFMC_DISCNT_FCTR
                          END)
               END)      	AS PRFMC_DISCNT_FCTR                          
--       ,C.FORMLY_DISCNT_FCTR
       ,(CASE WHEN PART1.FORMLY_DISCNT_FCTR IS NULL THEN C.FORMLY_DISCNT_FCTR 
                        ELSE PART1.FORMLY_DISCNT_FCTR END)
       ,C.GRWTH_DISCNT_FCTR
           ,CASE
        WHEN C.CONTRACT_PRICE > 0
            THEN (C.QUAL_EXT_PRICE - C.CONTRACT_PRICE) * DECIMAL(PART1.QUAL_UNITS,18,5)
        ELSE   0
            END AS CNTRCT_DISCNT_AMT
       ,PART1.MODEL_TYP_CD
       ,PART1.FRMLY_SRC_CD
FROM
(SELECT  B.CNTRCT_ID                                AS CNTRCT_ID
           ,B.RPT_ID                            AS RPT_ID
           ,B.DRUG_NDC_ID                       AS DRUG_NDC_ID
           ,B.NHU_TYP_CD                        AS NHU_TYP_CD
           ,B.INP_SRC_ID                        AS INP_SRC_ID
           ,B.CLT_ID                            AS CLT_ID
           ,B.MODEL_TYP_CD                      AS MODEL_TYP_CD
           ,B.VNDR_ID                   AS VNDR_ID
           ,B.FORMULARY_ID              AS FORMULARY_ID
           ,B.FRMLY_SRC_CD                      AS FRMLY_SRC_CD
           ,B.DLVRY_SYS_CD                  AS DLVRY_SYS_CD
           ,B.PERIOD_ID                                 AS PERIOD_ID
           ,B.DISCNT_RUN_MODE                       AS DISCNT_RUN_MODE
           ,SUM(B.ITEM_COUNT_QY)                AS QUAL_RX_COUNT 
           ,SUM(B.DSPNSD_QTY)                       AS QUAL_UNITS
           ,SUM(B.ITEM_COUNT_QY)                AS DISCNT_RX_COUNT
           ,SUM(B.DSPNSD_QTY)                       AS DISCNT_UNITS
           ,TCCS.PRFMC_DISCNT_FCTR
           ,TCCS.FORMLY_DISCNT_FCTR

--prephizer   FROM    VRAP.TDISCNT_EXT_CLAIM$MODEL B
   FROM    VRAP.TDISCNT_EXT_CLAIM$MODEL B LEFT OUTER JOIN VRAP.TDISCNT_CLAIM_CLT_SUM TCCS
             ON B.CNTRCT_ID = TCCS.CNTRCT_ID AND B.RPT_ID = TCCS.RPT_ID AND B.PERIOD_ID = TCCS.PERIOD_ID
             AND B.DISCNT_RUN_MODE = TCCS.DISCNT_RUN_MODE AND B.CLT_ID = TCCS.CLT_ID 
             AND B.DRUG_NDC_ID = TCCS.DRUG_NDC_ID AND B.NHU_TYP_CD = TCCS.NHU_TYP_CD

  WHERE    B.PERIOD_ID                       in ('$PERIOD_ID') 
    AND    B.RPT_ID     IN ($REPORT_ID)

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
           ,B.DISCNT_RUN_MODE
--postphizer
           ,TCCS.PRFMC_DISCNT_FCTR 
           ,TCCS.FORMLY_DISCNT_FCTR )     AS PART1
        
        ,$SCHEMA_OWNER.TDISCNT_CLAIM_SUM$MODEL C 
        ,$SCHEMA_OWNER.TRPT_REQMT D 

   WHERE  PART1.CNTRCT_ID                           =   C.CNTRCT_ID
         AND PART1.RPT_ID                           =   C.RPT_ID
         AND PART1.RPT_ID                               =       D.RPT_ID
         AND PART1.DRUG_NDC_ID                      =   C.DRUG_NDC_ID
     AND PART1.PERIOD_ID                            =   C.PERIOD_ID
         AND PART1.DISCNT_RUN_MODE          =   C.DISCNT_RUN_MODE
         AND C.DISCNT_RUN_MODE                          IN ('MPRD')

  GROUP BY  PART1.CNTRCT_ID
                ,PART1.RPT_ID
             ,PART1.DRUG_NDC_ID
             ,PART1.NHU_TYP_CD
             ,PART1.INP_SRC_ID
             ,PART1.CLT_ID
             ,PART1.MODEL_TYP_CD
             ,PART1.DLVRY_SYS_CD
             ,PART1.PERIOD_ID
             ,C.QUAL_EXT_PRICE
             ,PART1.QUAL_RX_COUNT 
             ,PART1.QUAL_UNITS
             ,PART1.DISCNT_UNITS
             ,C.BASE_DISCNT_FCTR
--prephizer  ,C.PRFMC_DISCNT_FCTR
--             ,(CASE WHEN PART1.PRFMC_DISCNT_FCTR IS NULL THEN C.PRFMC_DISCNT_FCTR 
--                                                         ELSE PART1.PRFMC_DISCNT_FCTR END)
             ,(CASE WHEN PART1.PRFMC_DISCNT_FCTR IS NULL 
                    THEN C.PRFMC_DISCNT_FCTR 
                    ELSE (CASE WHEN RT_BASIS_TYP_CD  = 4 
                               THEN PART1.PRFMC_DISCNT_FCTR/100
                               ELSE PART1.PRFMC_DISCNT_FCTR
                          END)
               END)                                                         
--             ,C.FORMLY_DISCNT_FCTR
             ,(CASE WHEN PART1.FORMLY_DISCNT_FCTR IS NULL THEN C.FORMLY_DISCNT_FCTR 
                                                         ELSE PART1.FORMLY_DISCNT_FCTR END)
             ,C.GRWTH_DISCNT_FCTR
             ,PART1.VNDR_ID
             ,PART1.FORMULARY_ID
             ,PART1.FRMLY_SRC_CD
             ,DISCNT_BASIS_TYP
             ,C.CONTRACT_PRICE

 ;


99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_DISCNT_mnthly_rpt_sql020.ksh   " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

