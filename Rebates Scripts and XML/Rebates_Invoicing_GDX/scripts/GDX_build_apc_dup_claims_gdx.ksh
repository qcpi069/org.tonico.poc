#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_build_apc_dup_claims_gdx.ksh
#
# Description   : Load APC Duplicate Claims within GDX. 
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
# 8-08-12   qcpi0rb     Initial Creation.
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
        print "\n ******* Sending email notification with the following parameters *****"
        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"
        print "****** end of email parameters ******"
        
    }  >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    #Call function to update table TAPC_QTR_PRCS_EVENT
    update_TAPC_QTR_PRCS_EVENT "Error-IT Investigating"

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`

    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Function to update status in VRAP.TAPC_QTR_PRCS_EVENT
#-------------------------------------------------------------------------#
function update_TAPC_QTR_PRCS_EVENT
#usage: update_TAPC_QTR_PRCS_EVENT | Type of Update - Running/Error-IT Investigating/Successful | 
{
   print "\n Running update_TAPC_QTR_PRCS_EVENT function" >> $LOG_FILE
   
   PRCS_STAT_TXT=$1
   print "Starting => Update GDX APC process status = " ${PRCS_STAT_TXT}>> $LOG_FILE
   UPDT_STMNT="UPDATE VRAP.TAPC_QTR_PRCS_EVENT"
   UPDT_STMNT="$UPDT_STMNT SET PRCS_ERR_TS = CURRENT TIMESTAMP"
   UPDT_STMNT="$UPDT_STMNT ,PRCS_STAT_TXT= '${PRCS_STAT_TXT}'"
   UPDT_STMNT="$UPDT_STMNT WHERE PRCS_ID = 100"

   db2 -px "$UPDT_STMNT" >> $LOG_FILE
   RETCODE=$?
   
   if [[ $RETCODE != 0 ]]; then
      print "ERROR: TAPC_QTR_PRCS_EVENT Update failed " >> $LOG_FILE
      print "Return code is : <" $RETCODE ">" >> $LOG_FILE
   else 
      print "Completed => Update GDX APC process status " >> $LOG_FILE
   fi
   print "Returning from update_TAPC_QTR_PRCS_EVENT function" >> $LOG_FILE
   return $RETCODE
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
      print "********************************************\n"
   } > $LOG_FILE

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

   print "\nConnecting to GDX database......" >> $LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" >> $LOG_FILE
   RETCODE=$?
   print "Connect to $DATABASE: RETCODE=<" $RETCODE ">" >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......">> $LOG_FILE
      exit_error $RETCODE
   fi
   
#-------------------------------------------------------------------------#
# Decide QUARTER_ID. Check if its passed as argument else fetch from DB
#-------------------------------------------------------------------------#
   print "\n Checking QUARTER_ID values ...."  >> $LOG_FILE

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
        print "QUARTER_ID info found in VRAP.TCUR_INV_PRD. " >> $LOG_FILE
        print "QUARTER_ID being used is " $QUARTER_ID >> $LOG_FILE
      else
        print "QUARTER_ID information not available for further processing. " >> $LOG_FILE
        exit_error $RETCODE
      fi
   else
      print "QUARTER_ID = $QUARTER_ID passed as argument. "  >> $LOG_FILE
   fi

#-------------------------------------------------------------------------#
# Update the GDX APC process status.
#-------------------------------------------------------------------------#
  
   #Call function to update table
   update_TAPC_QTR_PRCS_EVENT "Running"
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "ERROR: update_TAPC_QTR_PRCS_EVENT call failed" >> $LOG_FILE
      print "Return code is : <" $RETCODE ">" >> $LOG_FILE
      exit_error $RETCODE
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

         #***********************************************
         # Delete existing records from VRAP.TAPC_DUP_CLAIMS
         #***********************************************

         print "\nDelete records from GDX VRAP.TAPC_DUP_CLAIMS" >> $LOG_FILE
         
         SQL_STMT="DELETE FROM VRAP.TAPC_DUP_CLAIMS"
         SQL_STMT="$SQL_STMT where QUARTER_ID ='$QUARTER_ID'"
         SQL_STMT="$SQL_STMT AND MODEL_TYP_CD='$model_typ_cd'"
         
         echo "$SQL_STMT" >> $LOG_FILE
         SQL_STMT=$(echo "$SQL_STMT" | tr '\n' ' ')
         db2 -px "$SQL_STMT"  >> $LOG_FILE
         RETCODE=$?
         
         if [[ $RETCODE -gt 1 ]]; then
            print " " >> $LOG_FILE
            print "ERROR: Delete query failed "  >> $LOG_FILE
            print "Return code is : <$RETCODE>"  >> $LOG_FILE
            exit_error $RETCODE
         fi
            
         print "Deletion completed" >> $LOG_FILE
   
         print "\nInsert records into VRAP.TAPC_DUP_CLAIMS for " >> $LOG_FILE
         print "QUARTER_ID = $QUARTER_ID ">> $LOG_FILE 
         print "MODEL_TYP_CD = $model_typ_cd ">> $LOG_FILE 
         print "MODEL = $model ">> $LOG_FILE
         
         #***********************************************
         # Insert records into TAPC_DUP_CLAIMS
         #***********************************************     
         sql="INSERT INTO VRAP.TAPC_DUP_CLAIMS
              (
                 QUARTER_ID,
                 CLAIM_ID ,
                 MODEL_TYP_CD,
                 HVST_ID,
                 ALLW_IN_APC
              )
             SELECT '$QUARTER_ID' AS QUARTER_ID,
              CLAIM_ID,
              '$model_typ_cd' AS MODEL_TYP_CD,
              HVST_ID,
              CAST(NULL AS VARCHAR(1)) AS ALLW_IN_APC
             FROM VRAP.TAPC_CLAIMS_${model}
             WHERE QUARTER_ID = '$QUARTER_ID'
                AND CLAIM_ID IN (
                                  SELECT CLAIM_ID
                                  FROM VRAP.VAPC_CLAIMS_ALL
                                  WHERE QUARTER_ID = '${QUARTER_ID}'
                                  AND MODEL_TYP_CD <> '${model_typ_cd}'
                              ) WITH UR"
         echo "$sql" >>$LOG_FILE
         sql=$(echo "$sql" | tr '\n' ' ')

         db2 -px "$sql"
         RETCODE=$?
       
         if [[ $RETCODE > 1 ]]; then
            print " " >> $LOG_FILE
            print "Error: Insert for duplicate claims failed"  >> $LOG_FILE
            
            #Call function to update table
            update_TAPC_QTR_PRCS_EVENT "Error-IT Investigating"
            RETCODE=$?
            if [[ $RETCODE != 0 ]]; then
               print "ERROR: update_TAPC_QTR_PRCS_EVENT call failed" >> $LOG_FILE
               print "Return code is : <" $RETCODE ">" >> $LOG_FILE
               exit_error $RETCODE
            fi
            
            exit_error $RETCODE
         fi

         print "\nEnd insert for Duplicates claims " >> $LOG_FILE
         
      done <$TEMP_MODEL_REC

      #Call function to update table
      update_TAPC_QTR_PRCS_EVENT "Successful"
      RETCODE=$?
      
      if [[ $RETCODE != 0 ]]; then
         print "ERROR: update_TAPC_QTR_PRCS_EVENT call failed" >> $LOG_FILE
         print "Return code is : <" $RETCODE ">" >> $LOG_FILE
         exit_error $RETCODE
      fi
      
   else
     print "\nERROR: Model not found in VRAP.TCORP_MODEL_TYP_CD for processing. " >> $LOG_FILE
     exit_error $RETCODE
   fi

rm -f $TEMP_MODEL_REC

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
{
   print "*************************************************************"
   print `date +"%D %r %Z"` " - Finishing the script $SCRIPTNAME ......"
   print "Final return code is : <" $RETCODE ">"
   print "*************************************************************"
}  >> $LOG_FILE

exit $RETCODE