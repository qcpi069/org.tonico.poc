#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MKTSHR_qtrly_post_alloc_sql010.ksh   
# Title         
#
# Description   : This script is post allocation validation sql for the  
#                   quarterly billed table, TMKTSHR_BILLED_SUM.
#                 ONLYPROD
#
# Parameters    : SQL_FILE_NAME=$1,LOG_FILE=$2,PERIOD_ID=$3,CONTRACT_ID=$4,REPORT_ID=$5,TEST_SCHEMA_OWNER=$6
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-20-2005  N. Tucker  Initial Creation.
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

select  distinct a.rpt_id
        ,a.drug_ndc_id
        ,a.period_id
        ,a.qual_rx_count    
        ,b.totcount 
        ,a.qual_units   
        ,b.totunits
        ,a.qual_ext_price
        ,b.maxprice
        ,b.minprice
        ,a.days_of_therapy 
        ,b.totdot
        ,a.days_of_therapy - b.totdot
        ,b.totdot - a.days_of_therapy 
from    vrap.tmktshr_claim_sum a,
    (select distinct r.period_parent_id as period_parent, q.rpt_id as rpt, q.drug_ndc_id as ndc,
        sum (q.qual_rx_count) as totcount, sum (q.qual_units) as totunits,
        max (q.qual_ext_price) as maxprice, min (q.qual_ext_price) as minprice,
        sum ( q.days_of_therapy )  as totdot
         from $SCHEMA_OWNER.tmktshr_billed_sum q
             ,vrap.tdiscnt_period r
         where q.period_id = r.period_id
                  and r.period_parent_id = '$PERIOD_ID'

--                for report specific if needed
--                and q.rpt_id in (&&)
-- examples
--                and r.period_parent_id = 'Q0404'
--                and q.rpt_id in (2545, 2645)
    group by r.period_parent_id, q.rpt_id, q.drug_ndc_id) b
where   a.period_id = b.period_parent
and a.rpt_id = b.rpt
and a.drug_ndc_id = b.ndc
and a.discnt_run_mode in ('PROD') 
and ( ( a.qual_units <> b.totunits ) or ( a.qual_rx_count <> b.totcount )  
    or ( b.maxprice <> b.minprice ) or ( a.qual_ext_price <> b.maxprice) 
    or ( a.days_of_therapy - b.totdot > 1) or (  b.totdot - a.days_of_therapy > 1) )
and  a.days_of_therapy > 0
order by a.rpt_id, a.drug_ndc_id;

99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_MKTSHR_qtrly_post_alloc_sql010.ksh " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

