#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        :GDX_tdiscnt_export.ksh 
#
# Description   : Export data by year from vrap.TDISCNT_BILLED_SUM and  
#                vrap.TDISCNT_PROCD_SUM tables.  
#           
#
# Parameters    : Two Digit Year Number   e.g.   03  or 04 or 05 or 06  
# 
# 
# Output        :2 files Delimited files to be used in a DB2 load: 
#							    	/GDX/prod/input/tdiscnt_billed$YEAR_NUM.del
#								    /GDX/prod/input/tdiscnt_procd$YEAR_NUM.del
#
# Log File      :  /GDX/prod/log/GDX_tdiscnt_billed_export.ksh.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-01-2006  S.  Hull    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
 . `dirname $0`/Common_GDX_Environment.ksh
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
       export ALTER_EMAIL_ADDRESS="Scott.Hull@caremark.com"
    else
    # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="scott.Hull@caremark.com"
fi

JOB=""
DFLT_FILE_BASE="GDX_tdiscnt_export"
SCRIPTNAME=$DFLT_FILE_BASE".ksh"
LOG_FILE="$LOG_PATH/$DFLT_FILE_BASE.log"
SCRIPT=$(basename $0)
rm -f $LOG_FILE
print "Starting " $SCRIPT                    >> $LOG_FILE
PERIOD_IN="M__"

#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

  if [[ $# != 1 ]] then
     echo "Usage GDX_tdiscnt_export.ksh <year number  e.g. 06,  05  or 04 or 03 ...>"
     exit 1
  fi

  export YEAR_NUM=$1 

  echo "parameter YEAR_NUM : " ${YEAR_NUM}  >> $LOG_FILE
  SQL_PERIOD=$PERIOD_IN$YEAR_NUM'%'
  echo $SQL_PERIOD  >>  $LOG_FILE
  


#################################################################################
#
# 4.  Set up the SQL and Connect to the Database 
#
#################################################################################

SQL_STRING="export to /GDX/$REGION/input/tdiscnt_billed$YEAR_NUM.del of del"
SQL_STRING=$SQL_STRING" select a.model_typ_cd             "
SQL_STRING=$SQL_STRING" ,a.VNDR_ID                        "
SQL_STRING=$SQL_STRING" ,a.CNTRCT_ID                      "
SQL_STRING=$SQL_STRING" ,a.RPT_ID                         "
SQL_STRING=$SQL_STRING" ,a.PERIOD_ID                      "
SQL_STRING=$SQL_STRING" ,0                                "
SQL_STRING=$SQL_STRING" ,a.DISCNT_BASIS_TYP               "
SQL_STRING=$SQL_STRING" ,a.DRUG_NDC_ID                    "
SQL_STRING=$SQL_STRING" ,a.NHU_TYP_CD                     "
SQL_STRING=$SQL_STRING" ,a.CLT_ID                         "
SQL_STRING=$SQL_STRING" ,a.FRMLY_SRC_CD                   "
SQL_STRING=$SQL_STRING" ,a.FORMULARY_ID                   "
SQL_STRING=$SQL_STRING" ,a.INP_SRC_ID                     "
SQL_STRING=$SQL_STRING" ,a.DLVRY_SYS_CD                   "
SQL_STRING=$SQL_STRING" ,a.QUAL_RX_COUNT                  "
SQL_STRING=$SQL_STRING" ,a.DISCNT_RX_COUNT                "
SQL_STRING=$SQL_STRING" ,a.QUAL_UNITS                     "
SQL_STRING=$SQL_STRING" ,a.DISCNT_UNITS                   "
SQL_STRING=$SQL_STRING" ,0                                "
SQL_STRING=$SQL_STRING" ,a.BASE_DISCNT_FCTR               "
SQL_STRING=$SQL_STRING" ,a.PRFMC_DISCNT_FCTR              "
SQL_STRING=$SQL_STRING" ,a.FORMLY_DISCNT_FCTR             "
SQL_STRING=$SQL_STRING" ,a.GRWTH_DISCNT_FCTR              "
SQL_STRING=$SQL_STRING" ,0                                "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                 "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                 "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                 "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                 "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                 "
SQL_STRING=$SQL_STRING" ,a.CONTRACT_PRICE                 "
SQL_STRING=$SQL_STRING" ,0                                "
SQL_STRING=$SQL_STRING" ,COALESCE(a.BASE_DISCNT_AMT, 0)   "
SQL_STRING=$SQL_STRING" ,COALESCE(a.PRFMC_DISCNT_AMT, 0)  "
SQL_STRING=$SQL_STRING" ,COALESCE(a.FORMLY_DISCNT_AMT, 0) "
SQL_STRING=$SQL_STRING" ,COALESCE(a.CNTRCT_DISCNT_AMT, 0) "
SQL_STRING=$SQL_STRING" ,0                                "
SQL_STRING=$SQL_STRING" ,COALESCE(a.GRWTH_DISCNT_AMT, 0)  "            
SQL_STRING=$SQL_STRING" from 	vrap.TDISCNT_BILLED_SUM a   "
SQL_STRING=$SQL_STRING" where period_id LIKE '$SQL_PERIOD' "


SQL_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" 
# print $SQL_CONNECT_STRING 

db2 -p $SQL_CONNECT_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script  $SCRIPT failed in the DB CONNECT." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">"                >> $LOG_FILE
   exit $RETCODE
fi   

db2 -p $SQL_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script  $SCRIPT failed to execute." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">"                >> $LOG_FILE
   exit $RETCODE
fi   

SQL_STRING="export to /GDX/$REGION/input/tdiscnt_procd$YEAR_NUM.del of del"
SQL_STRING=$SQL_STRING" select a.model_typ_cd             "
SQL_STRING=$SQL_STRING" ,a.VNDR_ID                       "
SQL_STRING=$SQL_STRING" ,a.CNTRCT_ID                     "
SQL_STRING=$SQL_STRING" ,a.RPT_ID                        "
SQL_STRING=$SQL_STRING" ,a.PERIOD_ID                     "
SQL_STRING=$SQL_STRING" ,1                               "
SQL_STRING=$SQL_STRING" ,a.DISCNT_BASIS_TYP              "
SQL_STRING=$SQL_STRING" ,a.DRUG_NDC_ID                   "
SQL_STRING=$SQL_STRING" ,a.NHU_TYP_CD                    "
SQL_STRING=$SQL_STRING" ,a.CLT_ID                        "
SQL_STRING=$SQL_STRING" ,a.FRMLY_SRC_CD                  "
SQL_STRING=$SQL_STRING" ,a.FORMULARY_ID                  "
SQL_STRING=$SQL_STRING" ,a.INP_SRC_ID                    "
SQL_STRING=$SQL_STRING" ,a.DLVRY_SYS_CD                  "
SQL_STRING=$SQL_STRING" ,a.QUAL_RX_COUNT                 "
SQL_STRING=$SQL_STRING" ,a.DISCNT_RX_COUNT               "
SQL_STRING=$SQL_STRING" ,a.QUAL_UNITS                    "
SQL_STRING=$SQL_STRING" ,a.DISCNT_UNITS                  "
SQL_STRING=$SQL_STRING" ,0                               "
SQL_STRING=$SQL_STRING" ,a.BASE_DISCNT_FCTR              "
SQL_STRING=$SQL_STRING" ,a.PRFMC_DISCNT_FCTR             "
SQL_STRING=$SQL_STRING" ,a.FORMLY_DISCNT_FCTR            "
SQL_STRING=$SQL_STRING" ,a.GRWTH_DISCNT_FCTR             "
SQL_STRING=$SQL_STRING" ,0                               "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                "
SQL_STRING=$SQL_STRING" ,a.QUAL_EXT_PRICE                "
SQL_STRING=$SQL_STRING" ,a.CONTRACT_PRICE                "
SQL_STRING=$SQL_STRING" ,0                               "
SQL_STRING=$SQL_STRING" ,COALESCE(a.BASE_DISCNT_AMT, 0)   "
SQL_STRING=$SQL_STRING" ,COALESCE(a.PRFMC_DISCNT_AMT, 0)  "
SQL_STRING=$SQL_STRING" ,COALESCE(a.FORMLY_DISCNT_AMT, 0) "
SQL_STRING=$SQL_STRING" ,COALESCE(a.CNTRCT_DISCNT_AMT, 0) "
SQL_STRING=$SQL_STRING" ,0                                "
SQL_STRING=$SQL_STRING" ,COALESCE(a.GRWTH_DISCNT_AMT, 0)  "
SQL_STRING=$SQL_STRING" from 	vrap.tdiscnt_procd_SUM a    "
SQL_STRING=$SQL_STRING" where period_id LIKE '$SQL_PERIOD' "

db2 -p $SQL_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script  $SCRIPT  failed to in 2nd unload" >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">"                >> $LOG_FILE
   exit $RETCODE
else   
   print "Script  $SCRIPT  completed successfully" >> $LOG_FILE
   print "Script  $SCRIPT  completed successfully" 
fi   

exit $RETCODE