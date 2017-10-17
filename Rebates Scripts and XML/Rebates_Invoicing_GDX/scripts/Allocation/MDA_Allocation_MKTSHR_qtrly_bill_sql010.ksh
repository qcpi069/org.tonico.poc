#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MKTSHR_qtrly_bill_sql010.ksh   
# Title         
#
# Description   : This script builds the first sql for the Market Share
#                   Quarterly Billed table, TMKTSHR_BILLED_SUM.
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
# 05-15-05   qcpi733     Changed inner select table from TDISCNT_CLAIM_SUM.
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

print "Starting build of SQL for " $SQL_FILE_NAME                              >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE

print "First determine which quarter is being processed (1-4) and select the"  >> $LOG_FILE
print "  appropriate months for that quarter."                                 >> $LOG_FILE

#----------------------------------------------
# Get the YEAR from PERIOD_ID
#----------------------------------------------

echo $PERIOD_ID | awk '{print substr($0,4,2)}' | read YEAR
print "YEAR is <" $YEAR ">"							>> $LOG_FILE

if [[ ${PERIOD_ID%${PERIOD_ID##Q01}} = "Q01" ]]; then
    print "Quarter is 1"                                                       >> $LOG_FILE
#    MONTH1="M0105"
#    MONTH2="M0205"
#    MONTH3="M0305"
     MONTH1="M01"$YEAR
     MONTH2="M02"$YEAR
     MONTH3="M03"$YEAR
else
    if [[ ${PERIOD_ID%${PERIOD_ID##Q02}} = "Q02" ]]; then
        print "Quarter is 2"                                                   >> $LOG_FILE
#        MONTH1="M0405"
#        MONTH2="M0505"
#        MONTH3="M0605"
         MONTH1="M04"$YEAR
         MONTH2="M05"$YEAR
         MONTH3="M06"$YEAR
    else
        if [[ ${PERIOD_ID%${PERIOD_ID##Q03}} = "Q03" ]]; then
            print "Quarter is 3"                                               >> $LOG_FILE
#            MONTH1="M0705"
#            MONTH2="M0805"
#            MONTH3="M0905"
             MONTH1="M07"$YEAR
             MONTH2="M08"$YEAR
             MONTH3="M09"$YEAR
        else
            if [[ ${PERIOD_ID%${PERIOD_ID##Q04}} = "Q04" ]]; then
                print "Quarter is 4"                                           >> $LOG_FILE
#                MONTH1="M1005"
#                MONTH2="M1105"
#                MONTH3="M1205"
                 MONTH1="M10"$YEAR
                 MONTH2="M11"$YEAR
                 MONTH3="M12"$YEAR
            else
                print "Input was not in quarter format"                        >> $LOG_FILE
            fi
        fi
    fi
fi

print "For $PERIOD_ID, monthly periods within it are:" $MONTH1 $MONTH2 $MONTH3 >> $LOG_FILE

print " "                                                                      >> $LOG_FILE

# Build DELETE statement using monthly periods

print "DELETE "                                                                >  $SQL_FILE_NAME
print "FROM $SCHEMA_OWNER.tmktshr_billed_sum tbs "                             >> $SQL_FILE_NAME
print "WHERE (tbs.cntrct_id,tbs.rpt_id) IN "                                   >> $SQL_FILE_NAME
print "    (SELECT DISTINCT tcs.cntrct_id, tcs.rpt_id "                        >> $SQL_FILE_NAME
print "         FROM  $SCHEMA_OWNER.tmktshr_claim_sum tcs "                    >> $SQL_FILE_NAME
print "         WHERE tcs.period_id       = '$PERIOD_ID'"                      >> $SQL_FILE_NAME
print "         AND   tcs.discnt_run_mode = 'PROD')  "                         >> $SQL_FILE_NAME
print "AND   tbs.period_id IN ('$MONTH1','$MONTH2','$MONTH3'); "               >> $SQL_FILE_NAME

# first attempt at rewriting - actually ran longer
#print "DELETE "                                                                >> $SQL_FILE_NAME
#print "FROM $SCHEMA_OWNER.tmktshr_billed_sum tbs "                             >> $SQL_FILE_NAME
#print "WHERE tbs.rpt_id IN "                                                   >> $SQL_FILE_NAME
#print "    (SELECT DISTINCT tcs.rpt_id "                                        >> $SQL_FILE_NAME
#print "         FROM  $SCHEMA_OWNER.tmktshr_claim_sum tcs "                     >> $SQL_FILE_NAME
#print "         WHERE tcs.period_id       = '$PERIOD_ID'"                       >> $SQL_FILE_NAME
#print "         AND   tcs.discnt_run_mode = 'PROD')  "                          >> $SQL_FILE_NAME
#print "AND   tbs.period_id IN ('$MONTH1','$MONTH2','$MONTH3'); "              >> $SQL_FILE_NAME

#old cat > $SQL_FILE_NAME << 99EOFSQLTEXT99

#old DELETE FROM $SCHEMA_OWNER.TMKTSHR_BILLED_SUM
#old   WHERE    ('Q' || 
#old               CASE 
#old         WHEN SUBSTR(PERIOD_ID,2,2) BETWEEN   '01' AND '03'
#old             THEN '01'
#old         WHEN SUBSTR(PERIOD_ID,2,2) BETWEEN   '04' AND '06'
#old             THEN '02'
#old         WHEN SUBSTR(PERIOD_ID,2,2) BETWEEN   '07' AND '09'
#old             THEN '03'
#old         WHEN SUBSTR(PERIOD_ID,2,2) BETWEEN   '10' AND '12'
#old             THEN '04'
#old                            END
#old        || SUBSTR(PERIOD_ID,4,2))  = '$PERIOD_ID'    
#old    AND RPT_ID IN (SELECT RPT_ID 
#old                     FROM VRAP.TMKTSHR_CLAIM_SUM
#old -- Changed in Integration testing
#old --                    FROM VRAP.TDISCNT_CLAIM_SUM
#old                     WHERE PERIOD_ID      = '$PERIOD_ID'
#old                        AND DISCNT_RUN_MODE = 'PROD'
#old                  );
#old 
#old 99EOFSQLTEXT99

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Failure in build of SQL for " $SQL_FILE_NAME                        >> $LOG_FILE
    print "script MDA_Allocation_MKTSHR_qtrly_bill_sql010.ksh "                >> $LOG_FILE
    print "Return Code is : " $RETCODE                                         >> $LOG_FILE
    print `date`                                                               >> $LOG_FILE
else    
    print " "                                                                  >> $LOG_FILE
    print "....Completed building of SQL for " $SQL_FILE_NAME " ...."          >> $LOG_FILE
    chmod 766 $SQL_FILE_NAME
    print `date`                                                               >> $LOG_FILE
fi
return $RETCODE

