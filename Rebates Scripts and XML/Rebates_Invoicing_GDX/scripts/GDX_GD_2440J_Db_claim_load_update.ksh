#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GD_2440J_Db_claim_load_update.ksh   
# Title         : Updating NHU Type code and Delivery Status code in claim Tables
#
# Description   : This script will Update NHU Type in monthy claim table
#                 and Quarterly table into GDX.
#
# Abends        : 
#                 
# Maestro Job   : GD_2440J
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 08-15-05   Sunil       Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4='Sunil.Patel@caremark.com'
    EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi
    
    {
        print 'Sending email notification with the following parameters'
    
        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"
    
        print '****** end of email parameters ******'
    } >> $LOG_FILE
    
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
    else
        # Running in Prod region
        ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
    fi
else
    # Running in Development region
    REGION_NME="Development GDX"
    export ALTER_EMAIL_ADDRESS="Sunil.Patel@caremark.com"
    SCHEMA_OWNER="VRAP"
fi
RETCODE=0
JOB="GD_2440J"
export FILE_BASE="GDX_"$JOB"_Db_claim_load_update"
export SCRIPTNAME=$FILE_BASE".ksh"
export FILE_BASE=$FILE_BASE
UDB_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb_sql.msg"
SQL_DATA_CNTL_FILE=$OUTPUT_PATH/$FILE_BASE"_cntl.dat"
PRCS_VAL=$1
#export FILE_BASE=$FILE_BASE"_"$PRCS_VAL
CNTL_FILE=$OUTPUT_PATH/"GDX_GD_2300J_claims_extract_to_gdx_"$PRCS_VAL"_cntl.dat"
#TEMP_TABLE_FILE="TEMP_TABLE_FILE.dat"
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
print `date +"%D %r %Z"`                                                           >> $LOG_FILE
print "Starting the script to Update NHU Type in the Claims tables"                >> $LOG_FILE
print " "                                                                          >> $LOG_FILE
print " "                                                                          >> $LOG_FILE
print "=================================================================="         >> $LOG_FILE
if [ $# -lt 1 ] 
then
    print "************* S E V E R E  ***  E R R O R *********************"        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"        >> $LOG_FILE
    print "                                                               "        >> $LOG_FILE
    print "The Processing Value/Model Type was not supplied to the script."        >> $LOG_FILE
    print "This is a major issue. We do not know what to process."                 >> $LOG_FILE
    print "                                                               "        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"        >> $LOG_FILE
    exit_error 999
else 
    MODEL_TYPE_CD=$(echo "$PRCS_VAL" | cut -c 1)
    export LOG_FILE_ARCH=$LOG_ARCH_PATH/$FILE_BASE"_"$PRCS_VAL".log"
    export LOG_FILE=$LOG_PATH/$FILE_BASE"_"$PRCS_VAL".log"
    print 'Log files are : '$LOG_FILE																							 >>$LOG_FILE
    print 'Archieve Log files : '$LOG_FILE_ARCH											 							 >>$LOG_FILE
    print 'The MODEL TYPE Supplied is '$MODEL_TYPE_CD															 >> $LOG_FILE
    #-------------------------------------------------------------------------#
    # UPDATING the Quarterly Tables
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                        >> $LOG_FILE
    print " "                                                                       >> $LOG_FILE
		print "Processing for Model :" $PRCS_VAL																				>>$LOG_FILE
    print " "                                                                                       		>> $LOG_FILE
    print "***** Updating the NHU Type code & Delivery System code for Quarterly TCLAIM_% table *******">> $LOG_FILE
    print "***** Updating the NHU Type code & Delivery System code for Quarterly TCLAIM_% table *******">> $LOG_FILE
    print "***** Updating the NHU Type code & Delivery System code for Quarterly TCLAIM_% table *******">> $LOG_FILE
    print " "                                                                                       		>> $LOG_FILE
    print '**********************************************************'                              		>> $LOG_FILE 
    export SQL_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           	 		>> $LOG_FILE
    print '**********************************************************'                              		>> $LOG_FILE 
    db2 -p $SQL_CONNECT_STRING   >  $UDB_OUTPUT_MSG_FILE                                            		>> $LOG_FILE
    RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
       print 'date' 'Script ' $SCRIPTNAME 'failed in the DB CONNECT.'               >> $LOG_FILE 
       print ' Return Code = '$RETCODE                                              >> $LOG_FILE
       print 'Check DB2 error log: '$UDB_OUTPUT_MSG_FILE                            >> $LOG_FILE
       print ' '                                                                    >> $LOG_FILE
    	 exit_error $RETCODE
    else
       # ----------------------------------------------------------------#
       # GET the current month based on that determine quartertly tables
       #-----------------------------------------------------------------#
       #-----------------------------------------------------------------#
       # Get the File from which identify which table to update
       # Read GDX_GD_2300J_claims_extract_to_gdx_$1_cntl.dat file to get
       # run month that ran
       #-----------------------------------------------------------------#
       read cycle_low cycle_high QTR_CYCLE_GID begin_date end_date cycle_month qtr_start_date qtr_end_date < $CNTL_FILE
       { # output parameters to log file
       print
         date
         print 'Cycle data returned from Run.'
         print
         print "  cycle_low      = [$cycle_low]"
         print "  cycle_high     = [$cycle_high]"
         print "  QTR_CYCLE_GID  = [$QTR_CYCLE_GID]"
         print "  begin_date     = [$begin_date]"
         print "  end_date       = [$end_date]"
         print "  cycle_month    = [$cycle_month]"
         print "  qtr_start_date = [$qtr_start_date]"
         print "  qtr_end_date   = [$qtr_end_date]"
       }                                                                                    >> $LOG_FILE
#       sql_string="select TBL_NM from vrap.TCLAIM_LOAD_CNTL where inv_elig_min_dt ='$qtr_start_date' and INV_ELIG_MAX_DT='$qtr_end_date' and MODEL_TYP_CD='$MODEL_TYPE_CD'"
        sql_string="select TBL_NM from vrap.TCLAIM_LOAD_CNTL where MODEL_TYP_CD='$MODEL_TYPE_CD' and inv_elig_min_dt between '$qtr_start_date' and '$qtr_end_date'"
       #====================================================================
       #  GET the Quarterly Table name from vrap.TCLAIM_LOAD_CNTL table
       #====================================================================
       print $sql_string 																				  			>>$LOG_FILE
       db2 -px $sql_string | read TABLE_NAME
       print "Table to update :" $TABLE_NAME														>>$LOG_FILE
       RETCODE=$?
       if [[ $RETCODE != 0 ]]; then
         print "Script " $SCRIPTNAME "failed to retrieve Table name from vrap.TCLAIM_LOAD_CNTL."	>> $LOG_FILE
         print "DB2 return code 	 : <" $RETCODE ">"					    				>> $LOG_FILE
         exit_error $RETCODE
       else
         #========================================================================
         #  Checking for existence of an invalid NHU Type
         #========================================================================
         sql_string="SELECT count(*) FROM vrap.$TABLE_NAME a, vrap.TDRUG b WHERE a.DRUG_NDC_ID=b.DRUG_NDC_ID and a.NHU_TYP_CD<>b.NHU_TYP_CD"
         print $sql_string 																		  										>>$LOG_FILE
         db2 -px $sql_string | read COUNT
         if [[ $COUNT > 0 ]]; then
           print "******************UPDATING******************************"		>> $LOG_FILE
           print " Numbers of invalid NHU count are: "$COUNT 									>> $LOG_FILE
           print "Updating :"$TABLE_NAME																			>> $LOG_FILE
           print "********************************************************"		>> $LOG_FILE
           sql_string="update vrap.$TABLE_NAME a set a.nhu_typ_cd = (select b.nhu_typ_cd from vrap.tdrug b where a.drug_ndc_id = b.drug_ndc_id) where exists (SELECT 1 from vrap.tdrug b where a.drug_ndc_id = b.drug_ndc_id and a.nhu_typ_cd <> b.nhu_typ_cd)"
           print $sql_string 																	  							>>$LOG_FILE
           db2 -p $sql_string																		    	  			>> $LOG_FILE
           RETCODE=$?
           if [[ $RETCODE != 0 ]]; then
              print "Script " $SCRIPTNAME "failed in the update step of Table $TABLE_NAME."		>> $LOG_FILE
              print "DB2 return code is : <" $RETCODE ">"					    												>> $LOG_FILE
              exit_error $RETCODE
           fi   
         else
           print "*********INFORMATIONAL**********************************************"	>> $LOG_FILE
           print " WARNING : Unable to find INVALID NHU in vrap."$TABLE_NAME						>> $LOG_FILE
           print "No Updates are necessary at this time"																>> $LOG_FILE
           print "************END OF MESSAGE******************************************"	>> $LOG_FILE
         fi
         print "================================================================="		>> $LOG_FILE
         print "  Now updating Delivery System code for vrap."$TABLE_NAME							>> $LOG_FILE
         print "================================================================="		>> $LOG_FILE
         #======================================================================
         # Checking an Existence of an invalid Delivery System code
         #======================================================================
         sql_string="SELECT count(*) FROM vrap.$TABLE_NAME where dlvry_sys_cd = 3 and NABP_ID IN ('1002295','4583034','1069334','0326911','0326644','3980958','4598225','4576902','0129292','6300177','1473898')"
         print $sql_string 																										  		>>$LOG_FILE
         db2 -px $sql_string | read DLVY_SYS_COUNT
         if [[ $DLVY_SYS_COUNT > 0 ]]; then
           print "******************UPDATING******************************"					>> $LOG_FILE
           print " Numbers of invalid Delivery System code are: "$DLVY_SYS_COUNT 		>> $LOG_FILE
           print "Updating :"$recline																								>> $LOG_FILE
           print "********************************************************"					>> $LOG_FILE
           sql_string="update vrap.$TABLE_NAME set dlvry_sys_cd = 2 where dlvry_sys_cd = 3 and NABP_ID IN ('1002295','4583034','1069334','0326911','0326644','3980958','4598225','4576902','0129292','6300177','1473898')"
           print $sql_string 																>>$LOG_FILE
           db2 -p $sql_string								    						>> $LOG_FILE
           RETCODE=$?
           if [[ $RETCODE != 0 ]]; then
              print "Script " $SCRIPTNAME "failed in the update delivery system code of Table $recline."	>> $LOG_FILE
              print "DB2 return code is : <" $RETCODE ">"		 >> $LOG_FILE
              exit_error $RETCODE
           fi
         else
           print "****************INFORMATIONAL***************************************"					>> $LOG_FILE
           print " WARNING : Unable to find INVALID Delivery System code in vrap."$TABLE_NAME		>> $LOG_FILE
           print "No Updates are necessary at this time"																				>> $LOG_FILE
           print "************END OF MESSAGE******************************************"					>> $LOG_FILE
         fi
       fi
print "=================================================================="               	 	>> $LOG_FILE
    #-------------------------------------------------------------------------#
    # UPDATING the Monthly Claim Table
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                            >> $LOG_FILE
    print " "                                                                           >> $LOG_FILE
    print " "                                                                           >> $LOG_FILE
    print "***** Updating the NHU Type code & Delivery System code for monthly  TCLAIM_STAGE table *******"	>> $LOG_FILE
    print "***** Updating the NHU Type code & Delivery System code for monthly  TCLAIM_STAGE table *******"	>> $LOG_FILE
    print "***** Updating the NHU Type code & Delivery System code for monthly  TCLAIM_STAGE table *******"	>> $LOG_FILE
    print " "                                                                           >> $LOG_FILE
    print '**********************************************************'                  >> $LOG_FILE 
    # ------------------------------------------------------------------------------#
    # GET the month for which Claim load was ran on that determine Monthly tables
    # $cycle_month from the file is the month for which load was ran
    #-------------------------------------------------------------------------------#
    #========================================================================
    #  Checking for existence of an invalid NHU Type
    #========================================================================
    sql_string="SELECT count(*) FROM vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month" a, vrap.TDRUG b WHERE a.DRUG_NDC_ID=b.DRUG_NDC_ID and a.NHU_TYP_CD<>b.NHU_TYP_CD"
    print $sql_string 																										  					 	>>$LOG_FILE
    db2 -px $sql_string | read COUNT2
    if [[ $COUNT2 > 0 ]]; then
       print "******************UPDATING******************************"						>> $LOG_FILE
       print " Numbers of invalid NHU count are: "$COUNT2 												>> $LOG_FILE
       print "Updating :vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month								>> $LOG_FILE
       print "********************************************************"						>> $LOG_FILE
       sql_string="update vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month" a set a.nhu_typ_cd = (select b.nhu_typ_cd from vrap.tdrug b where a.drug_ndc_id = b.drug_ndc_id) where exists (SELECT 1 from vrap.tdrug b where a.drug_ndc_id = b.drug_ndc_id and a.nhu_typ_cd <> b.nhu_typ_cd)"
       print $sql_string                                                          >> $LOG_FILE 
       db2 -p $sql_string								    						>> $LOG_FILE
       RETCODE=$?
       if [[ $RETCODE != 0 ]]; then
          print "Script " $SCRIPTNAME "failed in the update step of Table tclaim_stage_dsc_$_date_m."			    											>> $LOG_FILE
          print "DB2 return code is : <" $RETCODE ">"		>> $LOG_FILE
          exit_error $RETCODE
       fi
    else
       print "*********INFORMATIONAL**********************************************"			>> $LOG_FILE
       print " WARNING : Unable to find INVALID NHU  in vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month >> $LOG_FILE
       print "No Updates are necessary at this time"							>> $LOG_FILE
       print "************END OF MESSAGE******************************************"			>> $LOG_FILE
    fi
    print "================================================================="					>> $LOG_FILE
    print "  Now updating Delivery System code for vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month >> $LOG_FILE
    print "================================================================="					>> $LOG_FILE
    #======================================================================
    # Checking an Existence of an invalid Delivery System code
    #======================================================================
    sql_string="SELECT count(*) FROM vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month" where dlvry_sys_cd = 3 and NABP_ID IN ('1002295','4583034','1069334','0326911','0326644','3980958','4598225','4576902','0129292','6300177','1473898')"
    print $sql_string 										>>$LOG_FILE
    db2 -px $sql_string | read DLVY_SYS_COUNT2
    if [[ $DLVY_SYS_COUNT2 > 0 ]]; then
       print "******************UPDATING******************************							>> $LOG_FILE
       print " Numbers of invalid Delivery System code are: "$DLVY_SYS_COUNT2 			>> $LOG_FILE
       print "Updating :vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month 								>> $LOG_FILE
       print "********************************************************							>> $LOG_FILE
       sql_string="update vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month" set dlvry_sys_cd = 2 where dlvry_sys_cd = 3 and NABP_ID IN ('1002295','4583034','1069334','0326911','0326644','3980958','4598225','4576902','0129292','6300177','1473898')"
       print $sql_string 																	>>$LOG_FILE
       db2 -p $sql_string								    				>> $LOG_FILE
       RETCODE=$?
       if [[ $RETCODE != 0 ]]; then
          print "Script " $SCRIPTNAME "failed in the update delivery system code of Table $recline."	>> $LOG_FILE
          print "DB2 return code is : <" $RETCODE ">"					    									>> $LOG_FILE
          exit_error $RETCODE
       fi
    else
       print "****************INFORMATIONAL***************************************"		>> $LOG_FILE
       print " WARNING : Unable to find INVALID Delivery System code in vrap.tclaim_stage_"$PRCS_VAL"_"$cycle_month	>> $LOG_FILE
       print "No Updates are necessary at this time"																								>> $LOG_FILE
       print "************END OF MESSAGE******************************************"		>> $LOG_FILE
    fi
    print "=================================================================="       	>> $LOG_FILE
    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    rm -f $TEMP_TABLE_FILE
    rm -f $LOG_FILE
  fi
fi		
exit $RETCODE