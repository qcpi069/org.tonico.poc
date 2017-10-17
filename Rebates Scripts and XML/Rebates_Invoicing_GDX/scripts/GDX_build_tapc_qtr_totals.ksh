#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_build_tapc_qtr_totals.ksh
#
# Description   : Loads VRAP.TAPC_QTR_TOTALS information for a specific quarter 
#                 Quarter ID can be passed in as parameter, 
#                 or will query TCUR_INV_PRD table to find out the current 
#                 processing quarter.
#                                 
# Parameters    : Optional, has year and quarter info. format: "YYYY0Q"  
#                 'YYYY': 4 digit year,
#                 'Q':quarter number ('1', '2', '3', '4'). 
#                 Example: 201202, 
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 or more = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 8-08-12   qcpi0rb      Initial Creation.
# 6-27-13   qcpuk218     Changed to correct updation logic for TAPC_QTR_PRCS_EVENT
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_GDX_Environment.ksh
  
#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error
#   usage: exit_error |Error Code| 
{
    RETCODE=$1
    EMAILPARM4='  '
    EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print '\n******* Sending email notification with the following parameters *****'
        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"
        print '****** end of email parameters ******'
        
    }  >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    #Call Common_GDX_APC_Status_update 
    . `dirname $0`/Common_GDX_APC_Status_update.ksh 90 ERR >> $LOG_FILE

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`

    exit $RETCODE
}


#-------------------------------------------------------------------------#
# Set EMAIL Address for notification as per region.
#-------------------------------------------------------------------------#
   if [[ $REGION = "prod" ]];   then
       if [[ $QA_REGION = "true" ]];   then
       # Running in the QA region
          SYSTEM="QA"
          export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
       else
       # Running in Prod region
           SYSTEM="PRODUCTION"
           export ALTER_EMAIL_ADDRESS=""
       fi
   else
       # Running in Development region
       SYSTEM="DEVELOPMENT"
       export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
   fi

#-------------------------------------------------------------------------#
# Setting initial value of Variables
#-------------------------------------------------------------------------#

   RETCODE=0
   QUARTER_ID=$1 
   FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
   SCRIPTNAME=$FILE_BASE".ksh"
   JOBNAME=$FILE_BASE
   TEMP_MODEL_REC=$SQL_PATH/${FILE_BASE}.dat
   
   rm -f $TEMP_MODEL_REC
   
   # LOG FILES
   LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log."`date +"%Y%m%d_%H%M%S"`
   LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"
   
   #If log file exists then archive it.
   if [ -s $LOG_FILE ]; then
      mv $LOG_FILE $LOG_FILE_ARCH
   fi
   
#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "\n********************************************"
      print `date +"%D %r %Z"` " - Starting the script $SCRIPTNAME ......"
      print "Running in SYSTEM = $SYSTEM"
      print "********************************************"
   } > $LOG_FILE

#-------------------------------------------------------------------------#
# Update the GDX APC process status.
#-------------------------------------------------------------------------#
      
   #Call Common_GDX_APC_Status_update
   . `dirname $0`/Common_GDX_APC_Status_update.ksh 90 STRT >> $LOG_FILE
   
#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

   print "\nConnecting to GDX database......"                                  >> $LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >> $LOG_FILE
   RETCODE=$?
   print "Connect to $DATABASE: RETCODE=<" $RETCODE ">"                        >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......">> $LOG_FILE
      exit_error $RETCODE
   fi
   
#-------------------------------------------------------------------------#
# Decide QUARTER_ID. Check if its passed as argument else fetch from DB
#-------------------------------------------------------------------------#
   print "\nChecking QUARTER_ID values ...."  >> $LOG_FILE
  
   if [[ -z $QUARTER_ID ]]; then
      #Query database to fetch QUARTER_ID   
      print "QUARTER_ID not passed as argument.  "  >> $LOG_FILE
      print "Querying database to fetch QUARTER_ID.... "  >> $LOG_FILE
      
      sql="SELECT CAST(QUARTER_ID AS CHAR(6)) FROM VRAP.TCUR_INV_PRD WITH UR"
      echo "$sql"  >>$LOG_FILE
      sql=$(echo "$sql" | tr '\n' ' ')
      
      db2 -px "$sql" | read QUARTER_ID
      RETCODE=$?
      print ' RETCODE=<'$RETCODE'>'>> $LOG_FILE
      
      if [[ $RETCODE = 0 ]]; then
        print " " >> $LOG_FILE
        print "QUARTER_ID info found in VRAP.TCUR_INV_PRD. " >> $LOG_FILE
        print "QUARTER_ID being used is " $QUARTER_ID >> $LOG_FILE
        print " " >> $LOG_FILE
      else
        print " " >> $LOG_FILE
        print "QUARTER_ID information not available for further processing. " >> $LOG_FILE
        exit_error $RETCODE
        print " " >> $LOG_FILE
      fi
   else
      print "QUARTER_ID = $QUARTER_ID passed as argument. "  >> $LOG_FILE
   fi

    
#***********************************************
# Distinct Model type cd and Models avilaible
#************************************************
   print "\nSelect distinct Model and Model Type Code" >> $LOG_FILE
   sql="select distinct A.MODEL_TYP_CD as model_typ_cd ,B.CD_NM as model 
   from VRAP.TCORP_MODEL_TYP_CD A ,vrap.TVNDR_REBT_CD B 
   where B.CD_NMON_TXT = A.MODEL_TYP_CD and B.typ_cd = 139 WITH UR "
   
   echo "$sql"  >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   
   db2 -px "$sql">$TEMP_MODEL_REC
   RETCODE=$?
   print ' RETCODE=<'$RETCODE'>'>> $LOG_FILE
        
   if [[ $RETCODE = 0 ]]; then
      #****************************************************************
      # Continue below logic to insert records for each model type code
      #****************************************************************  
      while read model_typ_cd model; do     
         print "\nStart processing for  " >> $LOG_FILE
         print "MODEL_TYP_CD = " $model_typ_cd  >> $LOG_FILE
         print "MODEL = " ${model} >> $LOG_FILE


         #**************************************************
         # Delete existing records from VRAP.TAPC_QTR_TOTALS
         #**************************************************

         print "\nDelete records from GDX VRAP.TAPC_QTR_TOTALS" >> $LOG_FILE
         
         SQL_STMT="DELETE FROM VRAP.TAPC_QTR_TOTALS"
         SQL_STMT="$SQL_STMT where QUARTER_ID ='$QUARTER_ID'"
         SQL_STMT="$SQL_STMT AND MODEL_TYP_CD='$model_typ_cd'"
         
         echo "$SQL_STMT" >> $LOG_FILE
         SQL_STMT=$(echo "$SQL_STMT" | tr '\n' ' ')
         db2 -px "$SQL_STMT"  >> $LOG_FILE
         RETCODE=$?
         
         if [[ $RETCODE -gt 1 ]]; then
            print " " >> $LOG_FILE
            print "ERROR: Delete Query failed "  >> $LOG_FILE
            print "Return code is : <$RETCODE>"  >> $LOG_FILE
            exit_error $RETCODE
         fi
            
         print "Deletion completed" >> $LOG_FILE
         
         print "\nInsert records into VRAP.TAPC_QTR_TOTALS for " >> $LOG_FILE
         print "QUARTER_ID = $QUARTER_ID ">> $LOG_FILE 
         print "MODEL_TYP_CD = $model_typ_cd ">> $LOG_FILE 
         print "MODEL = $model ">> $LOG_FILE
         
         #***********************************************
         # Insert records into TAPC_DUP_CLAIMS
         #***********************************************     
         sql="INSERT INTO VRAP.TAPC_QTR_TOTALS
	      (
	       QUARTER_ID,
	       PRD_ID,
	       MODEL_TYP_CD,
	       AP_COMPNY_CD,
	       PICO_NO,
	       PMT_SYS_ELIG_CD,
	       ALLW_IN_APC,
	       GRS_CLM_CNT_RBAT,
	       GRS_CLM_CNT_SBMD,
	       NET_CLM_CNT_RBAT,
	       NET_CLM_CNT_SBMD,
	       NET_CLM_CNT,
	       GRS_CLM_CNT,
	       RBAT_ACC_DISCNT_AMT,
	       RBAT_PRFMC_DISCNT_AMT,
	       RBAT_ADMN_DISCNT_AMT,
	       RBAT_DISCNT_AMT,
	       DSPNSD_QTY_RBAT,
	       DSPNSD_QTY_SBMD,
	       DSPNSD_QTY,
	       CREATE_TS
	      )
	      SELECT
	        C.QUARTER_ID,
	        C.PRD_ID,
	        '$model_typ_cd' as MODEL_TYP_CD,
	        AP_COMPNY_CD,
	        PICO_NO,
	        '1' as PMT_SYS_ELIG_CD,
	        (CASE WHEN UPPER(DC.ALLW_IN_APC) IS NULL THEN
	              (CASE WHEN DC.CLAIM_ID IS NOT NULL THEN 'Z' END)
	              ELSE UPPER(DC.ALLW_IN_APC)
	         END) AS ALLW_IN_APC,
	        SUM(CASE
	            WHEN MDA_EXCPT_ID IN (90, 91, 92) THEN 1
	            ELSE 0
	            END) AS GRS_CLM_CNT_RBAT ,
	        SUM(CASE
	            WHEN MDA_EXCPT_ID IN (90, 91, 92) THEN 0
	            ELSE 1
	            END) AS GRS_CLM_CNT_SBMD,
	        SUM(CASE
	            WHEN MDA_EXCPT_ID IN (90, 91, 92) THEN ITEM_COUNT_QY
	            ELSE 0
	            END) AS NET_CLM_CNT_RBAT,
	        SUM(CASE
	            WHEN MDA_EXCPT_ID IN (90, 91, 92) THEN 0
	            ELSE ITEM_COUNT_QY
	            END) AS NET_CLM_CNT_SBMD,
	        SUM(ITEM_COUNT_QY) AS NET_CLM_CNT,
	        COUNT(*) AS GRS_CLM_CNT,
	        SUM(PMT_ACC_DISCNT_AMT) AS RBAT_ACC_DISCNT_AMT,
	        SUM(PMT_PRFMC_DISCNT_AMT) AS RBAT_PRFMC_DISCNT_AMT,
	        SUM(PMT_ADMN_DISCNT_AMT) AS  RBAT_ADMN_DISCNT_AMT ,
	        SUM(PMT_ACC_DISCNT_AMT+PMT_PRFMC_DISCNT_AMT+PMT_ADMN_DISCNT_AMT) AS RBAT_DISCNT_AMT,
	        SUM(CASE
	            WHEN MDA_EXCPT_ID IN (90, 91, 92) THEN DSPNSD_QTY
	            ELSE 0
	            END) AS DSPNSD_QTY_RBAT ,
	        SUM(CASE
	            WHEN MDA_EXCPT_ID IN (90, 91, 92) THEN 0
	            ELSE DSPNSD_QTY
	            END) AS DSPNSD_QTY_SBMD,
	        SUM(DSPNSD_QTY) AS DSPNSD_QTY
	        ,CURRENT TIMESTAMP
	      FROM VRAP.TAPC_CLAIMS_${model} C LEFT JOIN VRAP.TAPC_DUP_CLAIMS DC
	      ON (C.QUARTER_ID = DC.QUARTER_ID AND C.CLAIM_ID = DC.CLAIM_ID AND 
	        DC.MODEL_TYP_CD = '$model_typ_cd')
	      WHERE C.QUARTER_ID = '$QUARTER_ID'
	      GROUP BY
	        C.QUARTER_ID,
	        C.PRD_ID,
	        AP_COMPNY_CD,
	        PICO_NO,
	        (CASE WHEN UPPER(DC.ALLW_IN_APC) IS NULL THEN
	                 (CASE WHEN DC.CLAIM_ID IS NOT NULL THEN 'Z' END)
	              ELSE UPPER(DC.ALLW_IN_APC)
	        END)
	 WITH UR"
	 
         echo "$sql" >>$LOG_FILE
         sql=$(echo "$sql" | tr '\n' ' ')

         db2 -px "$sql"
         RETCODE=$?
       
         if [[ $RETCODE > 1 ]]; then
            print " " >> $LOG_FILE
            print "Error: Insert for duplicate claims failed" >> $LOG_FILE
            
            #Call Common_GDX_APC_Status_update
            . `dirname $0`/Common_GDX_APC_Status_update.ksh 90 ERR >> $LOG_FILE

            print "Error: insert for duplicate claims" $QUARTER
            exit_error $RETCODE
         else 
            RETCODE=0   # Set return code to success when db2 return code is either 0 (success) or 1 (no record)
         fi

         print "\nEnd insert for Duplicates claims " >> $LOG_FILE

      done <$TEMP_MODEL_REC
      
   else
     print "ERROR: Model not found in VRAP.TCORP_MODEL_TYP_CD for processing. " >> $LOG_FILE
     exit_error $RETCODE
   fi

rm -f $TEMP_MODEL_REC

#Call Common_GDX_APC_Status_update
. `dirname $0`/Common_GDX_APC_Status_update.ksh 90 END  >> $LOG_FILE
RETCODE=$?
      
#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
{
   print "\n*************************************************************"
   print `date +"%D %r %Z"` " - Finishing the script $SCRIPTNAME ......"
   print "Final return code is : <" $RETCODE ">"
   print "*************************************************************"
}  >> $LOG_FILE

exit $RETCODE  
