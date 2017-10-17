#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_create_dcl_pair_sql020.ksh   
# Title         
#
# Description   : This script is the second step of the process that creates
#               drug class pairs.
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

insert into VACTUATE.TMKTSHR_DCL_PAIR_TEMP
(select distinct
  0 
, A.DRUG_CLS_CMPTR
, A.DRUG_CLS_VNDR
,(rtrim(char(A.DRUG_CLS_VNDR)) ||'-'|| rtrim(char(A.DRUG_CLS_CMPTR)))
, 1
from $SCHEMA_OWNER.TRPT_REQMT A,

  (select max ((rtrim(char(A.DRUG_CLS_VNDR)) ||'-'|| rtrim(char(A.DRUG_CLS_CMPTR)))) as max_label 
     from $SCHEMA_OWNER.TRPT_REQMT AS A
    where A.DRUG_CLS_CMPTR Is Not Null
      and A.DRUG_CLS_VNDR Is Not Null
      and (rtrim(char(A.DRUG_CLS_VNDR)) ||'-'|| rtrim(char(A.DRUG_CLS_CMPTR))) 
          NOT in 
             (SELECT MDA_DCL_PAIR_LBL FROM  $SCHEMA_OWNER.TMKTSHR_DCL_PAIR )) as PART1

where max_label=(rtrim(char(A.DRUG_CLS_VNDR)) ||'-'|| rtrim(char(A.DRUG_CLS_CMPTR))) );

99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME >> $LOG_FILE
    print "script MDA_Allocation_create_dcl_pair_sql020.ksh " >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
else    
    print " " >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."   >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date` >> $LOG_FILE
fi
return $RETCODE

