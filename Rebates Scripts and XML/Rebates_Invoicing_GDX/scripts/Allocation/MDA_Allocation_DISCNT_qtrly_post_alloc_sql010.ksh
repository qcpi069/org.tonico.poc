#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_DISCNT_qtrly_post_alloc_sql010.ksh   
# Title         
#
# Description   : This script is post allocation validation sql for the  
#                   quarterly discount table, TDISCNT_BILLED_SUM$MODEL.
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
# 09-15-05   qcpi733    6004155   Removed validation of PRFMC_DISCNT_FCTR
#                                 because of new Client Level Marketshare.
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

select  distinct a.period_id
        ,a.rpt_id
        ,a.drug_ndc_id
        ,a.qual_rx_count    
        ,a.qual_units   
        ,a.base_discnt_fctr
        ,a.formly_discnt_fctr
        ,a.prfmc_discnt_fctr
        ,a.grwth_discnt_fctr
        ,a.contract_price
        ,b.totcount 
        ,b.totunits
        ,b.maxbase
        ,b.minbase
--        ,b.maxform 6005148
--        ,b.minform 6005148
--        ,b.maxperf 6004155
--        ,b.minperf 6004155
        ,b.maxgwth
        ,b.mingwth
        ,b.maxcprice
        ,b.mincprice
from    vrap.TDISCNT_CLAIM_SUM$MODEL a,
    (select distinct r.period_parent_id as period_parent, q.rpt_id as rpt, q.drug_ndc_id as ndc,
        sum (q.qual_rx_count) as totcount, sum (q.qual_units) as totunits,
        max ( base_discnt_fctr ) as maxbase, min (base_discnt_fctr ) as minbase,
        max ( grwth_discnt_fctr ) as maxgwth, min (grwth_discnt_fctr ) as mingwth,
--        max ( FORMLY_discnt_fctr ) as maxform, min (FORMLY_discnt_fctr ) as minform, 6005148
--        max ( prfmc_discnt_fctr ) as maxperf, min (prfmc_discnt_fctr ) as minperf, 6004155
        max (contract_price) as maxcprice, min (contract_price) as mincprice
         from $SCHEMA_OWNER.TDISCNT_BILLED_SUM$MODEL q
             ,vrap.tdiscnt_period r
         where q.period_id = r.period_id
           and r.period_parent_id = '$PERIOD_ID'
    group by r.period_parent_id, q.rpt_id, q.drug_ndc_id) b
where   a.period_id = b.period_parent
and a.rpt_id = b.rpt
and a.drug_ndc_id = b.ndc
and a.discnt_run_mode in ('PROD')
and ( ( a.qual_units <> b.totunits ) or ( a.qual_rx_count <> b.totcount )  
    or ( b.maxbase <> b.minbase ) or ( a.base_discnt_fctr <> b.maxbase)
    or ( b.maxgwth <> b.mingwth ) or ( a.grwth_discnt_fctr <> b.maxgwth)
--    or ( b.maxform <> b.minform ) or ( a.formly_discnt_fctr <> b.maxform) 6005148
--    or ( b.maxperf <> b.minperf ) or ( a.prfmc_discnt_fctr <> b.maxperf) 6004155
    or ( b.maxcprice <> b.mincprice ) or ( a.contract_price <> b.maxcprice) )
order by a.period_id
    ,a.rpt_id
    ,a.drug_ndc_id;

99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_DISCNT_qtrly_post_alloc_sql010.ksh " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

