#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GD_2430J_Db_claim_load_validation.ksh   
# Title         : Claim load from GPO to GDX validation.
#
# Description   : This script will validate the claim loads from the GPO Oracle 
#                 environment for processing into GDX.
#
# Abends        : 
#                 
# Maestro Job   : GD_2300J
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09-14-05   Gries       Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#
. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh

 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        REGION_NME="Production GDX"
        ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
        UDB_SCHEMA_OWNER='DBA' 
        UDB_MSG_DIR_REGION="gdxprd"
    else
        # Running in Prod region
        REGION_NME="Production GDX"
        ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
        UDB_SCHEMA_OWNER='DBA' 
        UDB_MSG_DIR_REGION="gdxprd"
    fi
else
    # Running in Development region
    REGION_NME="Development GDX"
    export ALTER_EMAIL_ADDRESS="scott.hull@caremark.com"
    SCHEMA_OWNER="VRAP"
    UDB_SCHEMA_OWNER='DBA' 
    UDB_MSG_DIR_REGION="gdxdev"
fi

RETCODE=0
BKUP_RETCODE=0
SCHEDULE=
JOB="GD_2430J"
export FILE_BASE="GDX"$SCHEDULE"_"$JOB"_Db_claim_load_validation"
export SCRIPTNAME=$FILE_BASE".ksh"
export FILE_BASE=$FILE_BASE"_$1"
# LOG FILES
export LOG_FILE_ARCH=$LOG_ARCH_PATH/$FILE_BASE".log"
export LOG_FILE=$LOG_PATH/$LOG_FILE".log"
# Oracle and UDB SQL files
UDB_SQL_FILE=$SQL_PATH/$FILE_BASE"_udb.sql"
UDB_CONNECT_STRING="db2 -p connect to "$DATABASE" user "$CONNECT_ID" using "$CONNECT_PWD
# UDB Message files
UDB_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb_sql.msg"
UDB_IMPORT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb_imp.msg"
UDB_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb.msg"
DBA_LOAD_MSG_DIR="/home/user/"$UDB_MSG_DIR_REGION"/loadtest/out"
DBA_LOAD_MSG_OUT_FILE_QTRLY=""
DBA_LOAD_MSG_OUT_FILE_MNTHLY=""
UDB_ERR_MSG_FILE_MNTHLY=""
UDB_ERR_MSG_FILE_QTRLY=""
# Output files
SQL_PIPE_FILE=$OUTPUT_PATH/$FILE_BASE"_pipe.lst"
SQL_DATA_CNTL_FILE=$OUTPUT_PATH/$FILE_BASE"_cntl.dat"
MNTH_CNT_OUTPUT_FILE=$OUTPUT_PATH/$FILE_BASE"_mnth_rec_cnt.dat"
SNGLMNTH_CNT_OUTPUT_FILE=$OUTPUT_PATH/$FILE_BASE"_snglmnth_rec_cnt.dat"
QTR_CNT_OUTPUT_FILE=$OUTPUT_PATH/$FILE_BASE"_qtr_rec_cnt.dat"
#Count and Table Variables 
let MNTH_REC_CNT=0
let MNTH_REC_CNT_NUM=0
let QTR_REC_CNT=0
let QTR_REC_CNT_NUM=0
let LOAD_ISRT_CNT=0
let DATA_FILE_LINE_COUNT=0
CYCLE_MONTH=""
STAGE_TBL_1=""
STAGE_TBL_2=""
STAGE_TBL_3=""
MONTH_ABRV_1=""
MONTH_ABRV_2=""
MONTH_ABRV_3=""
QTR_TABLE_NB=""
QTR_TABLE_NME=""
#Email variables
LOAD_EMAIL_BODY=$INPUT_PATH/$FILE_BASE"_email.txt"
LOAD_EMAIL_SUBJECT="GDX Claims Loaded for $1 - validated counts"
cat $INPUT_PATH/$FILE_BASE"_CC_list.txt"|read LOAD_EMAIL_CC_GROUP
LOAD_EMAIL_FROM_GROUP=$LOAD_EMAIL_CC_GROUP
cat $INPUT_PATH/$FILE_BASE"_TO_list.txt"|read LOAD_EMAIL_TO_GROUP

. $SCRIPT_PATH/Common_GDX_Env_File_Names.ksh

rm -f $LOG_FILE
rm -f $ORA_SQL_FILE
rm -f $UDB_SQL_FILE
rm -f $UDB_MSG_FILE
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_IMPORT_MSG_FILE
rm -f $SQL_PIPE_FILE
rm -f $LOAD_EMAIL_BODY

#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
print `date +"%D %r %Z"`                                                                           >> $LOG_FILE
print "Starting the script to validate the load of the Claims tables"                              >> $LOG_FILE
print " "                                                                                          >> $LOG_FILE
print " "                                                                                          >> $LOG_FILE

print "=================================================================="                         >> $LOG_FILE

if [ $# -lt 1 ] 
then
    print "************* S E V E R E  ***  E R R O R *********************"                        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"                        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"                        >> $LOG_FILE
    print "                                                               "                        >> $LOG_FILE
    print "The Processing Value, PRCS_VAL, was not supplied to the script."                        >> $LOG_FILE
    print "This is a major issue. We do not know what to process."                                 >> $LOG_FILE
    print "                                                               "                        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"                        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"                        >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"                        >> $LOG_FILE
    RETCODE=999
else    
    PRCS_VAL=$1
    print "                                                               "                        >> $LOG_FILE
    print "The Processing Value, PRCS_VAL,                                "                        >> $LOG_FILE
    print "supplied to the script is $PRCS_VAL                        "                            >> $LOG_FILE
    print "                                                               "                        >> $LOG_FILE
    if [ $# -lt 2 ] 
    then
        print "******** Process Type not supplied  -- Using DEFAULT **********"                    >> $LOG_FILE
        print "                                                               "                    >> $LOG_FILE
        print "The Processing Type was not supplied. We will thus default     "                    >> $LOG_FILE    
        print "to ALL. This will validate both Month and Quarterly loads      "                    >> $LOG_FILE
        print "                                                               "                    >> $LOG_FILE
        print "******** Process Type not supplied  -- Using DEFAULT **********"                    >> $LOG_FILE
        PRCS_TYPE="ALL"
        PRCS_MTH="TRUE"
        PRCS_QTR="TRUE"
    else
        PRCS_TYPE=$2
        print "************* Process Type is supplied    *********************"                    >> $LOG_FILE
        print "                                                               "                    >> $LOG_FILE
        print "The Processing Type is supplied. We will use this value        "                    >> $LOG_FILE    
        print "to process.                                                    "                    >> $LOG_FILE
        print "The process Type supplied is : $PRCS_TYPE                      "                    >> $LOG_FILE
        if [[ $PRCS_TYPE = 'MTH' ]]; then
            print "We will validate the Month loads ONLY!!!!!!!           "                        >> $LOG_FILE
            PRCS_MTH="TRUE"
            PRCS_QTR="FALSE"
        else
            print "We will validate the Quarter loads ONLY!!!!!!!         "                        >> $LOG_FILE
            PRCS_MTH="FALSE"
            PRCS_QTR="TRUE"
        fi
        print "                                                               "                    >> $LOG_FILE
        print "************* Process Type is supplied    *********************"                    >> $LOG_FILE
    fi

    #################################################################################
    ####
    #### VALID_FILE is a data file to be validated
    ####
    #################################################################################
    VALID_FILE=$OUTPUT_PATH/"GDX_GD_2300J_claims_extract_to_gdx_"$PRCS_VAL".trg.complete"
    VALID_FILE_ARCH=$OUTPUT_PATH/archive/"GDX_GD_2300J_claims_extract_to_gdx_"$PRCS_VAL".trg.complete"
    print "                                                               "                        >> $LOG_FILE
    read DATA_FILE_TO_VALIDATE CYCLE_MONTH model_type START_DATE END_DATE QTR_DATA_FILE_TO_VALIDATE < $VALID_FILE
    
    print "************************************************"                                       >> $LOG_FILE
    print "***** TRIGGER File values are as follows *******"                                       >> $LOG_FILE
    
    
    export QTR_START_DATE=$START_DATE
    export QTR_END_DATE=$END_DATE
    print "DATA_FILE_TO_VALIDATE is     : " $DATA_FILE_TO_VALIDATE                                 >> $LOG_FILE
    print "CYCLE_MONTH is               : " $CYCLE_MONTH                                           >> $LOG_FILE
    print "model_type is                : " $model_type                                            >> $LOG_FILE
    print "QTR_START_DATE is            : " $QTR_START_DATE                                        >> $LOG_FILE
    print "QTR_END_DATE is              : " $QTR_END_DATE                                          >> $LOG_FILE
    print "QTR_DATA_FILE_TO_VALIDATE is : " $QTR_DATA_FILE_TO_VALIDATE                             >> $LOG_FILE
    print "***** TRIGGER File values END            *******"                                       >> $LOG_FILE
    print "************************************************"                                       >> $LOG_FILE

fi

if [[ $RETCODE = 0 && $PRCS_MTH = 'TRUE' ]]; then 

    #-------------------------------------------------------------------------#
    # Validating the Month Load
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                                       >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE
    print "***** Balancing the Monthly file against the TCLAIM_STAGE table *******"                >> $LOG_FILE
    print "***** Balancing the Monthly file against the TCLAIM_STAGE table *******"                >> $LOG_FILE
    print "***** Balancing the Monthly file against the TCLAIM_STAGE table *******"                >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE

    DATA_FILE_PASSED=$OUTPUT_PATH/$DATA_FILE_TO_VALIDATE

    print `date`                                                                                   >> $LOG_FILE
    print '**********************************************************'                             >> $LOG_FILE 
    export SQL_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >> $LOG_FILE
    print '**********************************************************'                             >> $LOG_FILE 

    db2 -p $SQL_CONNECT_STRING   >  $UDB_OUTPUT_MSG_FILE                                           >> $LOG_FILE
    RETCODE=$?
    
    if [[ $RETCODE != 0 ]]; then
       print 'date' 'Script ' $SCRIPTNAME 'failed in the DB CONNECT.'                              >> $LOG_FILE 
       print ' Return Code = '$RETCODE                                                             >> $LOG_FILE
       print 'Check DB2 error log: '$UDB_OUTPUT_MSG_FILE                                           >> $LOG_FILE
       print 'Here are last 20 lines of that file - '                                              >> $LOG_FILE
       print ' '                                                                                   >> $LOG_FILE
       print ' '                                                                                   >> $LOG_FILE
       tail -20 $UDB_OUTPUT_MSG_FILE                                                               >> $LOG_FILE
       print ' '                                                                                   >> $LOG_FILE
       print ' '                                                                                   >> $LOG_FILE   
    else

    ###################################################################################
    #  SQL execution via sql string 
    ###################################################################################
    
       SQL_STRING="Select  inserted - (rejected + deleted + skipped) as inserted, ' ', table  from $UDB_SCHEMA_OWNER.LOADS  where TABLE LIKE 'TCLAIM_STAGE%' AND DATA_FILE='$DATA_FILE_TO_VALIDATE' AND DATA_FILE != '' and LOAD_DATE = (select max(LOAD_DATE) from $UDB_SCHEMA_OWNER.LOADS  where TABLE LIKE 'TCLAIM_STAGE%' AND DATA_FILE='$DATA_FILE_TO_VALIDATE' AND DATA_FILE != '' )"
       print $SQL_STRING                                                                           >> $LOG_FILE 

       db2 -px $SQL_STRING  > $SNGLMNTH_CNT_OUTPUT_FILE 2>  $UDB_OUTPUT_MSG_FILE
       RETCODE=$?
    
       if [[ $RETCODE != 0 ]]; then      
             print 'Script ' $SCRIPTNAME 'failed in the select step.'                              >> $LOG_FILE
             print 'Return code is : <' $RETCODE '>'                                               >> $LOG_FILE 
           print 'Check DB2 error log: '$UDB_OUTPUT_MSG_FILE                                       >> $LOG_FILE
           print 'Here are last 20 lines of that file - '                                          >> $LOG_FILE
             print ' '                                                                             >> $LOG_FILE
             print ' '                                                                             >> $LOG_FILE
             tail -20 $UDB_OUTPUT_MSG_FILE                                                         >> $LOG_FILE
             print ' '                                                                             >> $LOG_FILE                         
       else
             print `date` 'Script ' $SCRIPTNAME 'completed.'                                       >> $LOG_FILE
             print 'DB2 return code is : <'  $RETCODE  '>'                                         >> $LOG_FILE   
             export FIRST_READ=1         
             while read inserted table ; do
              if [[ $FIRST_READ != 1 ]]; then
             print 'Finishing db2 results file read'                                               >> $LOG_FILE 
              else   
             export FIRST_READ=0            
                 print 'Inserted count :' $inserted                                                >> $LOG_FILE 
                 LOAD_ISRT_CNT=$inserted
                 STAGE_TABLE_NME=$table
                 print 'Inserted Into Table :' $table                                              >> $LOG_FILE 
              fi
              done < $SNGLMNTH_CNT_OUTPUT_FILE
       fi       
    fi   ## end if the trigger file is valid
    
    ######################################
    #  Count the line of the data file
    if [[ $RETCODE = 0 ]]; then
        if [[ -r $DATA_FILE_PASSED ]]; then
            DATA_FILE_LINE_COUNT=`wc -l  $DATA_FILE_PASSED|read count name;print $count`           >> $LOG_FILE    
            print 'Data File Record Count : '$DATA_FILE_LINE_COUNT                                 >> $LOG_FILE
        else
            print 'Data file does not exist or not readable: '$DATA_FILE_PASSED                    >> $LOG_FILE
            RETCODE=2
        fi
    fi
    
    ###################################################################################
    #   Validate monthly counts
    ###################################################################################
    
    print "----------------------------------------------------------"                             >> $LOG_FILE  
    print "Source Data File is    :  $data_file_name "                                             >> $LOG_FILE  
    print "Read by load script    :  "                                                             >> $LOG_FILE
    print "Date File Record Count :  $DATA_FILE_LINE_COUNT "                                       >> $LOG_FILE
    print "Loaded to table        :  $LOAD_ISRT_CNT  "                                             >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE
    print "DBA Load information:"                                                                  >> $LOG_FILE
    DBA_LOAD_MSG_OUT_FILE_MNTHLY=$DBA_LOAD_MSG_DIR"/load.vrap.TCLAIM_STAGE_"$PRCS_VAL"_"$CYCLE_MONTH".out"
    cat $DBA_LOAD_MSG_OUT_FILE_MNTHLY                                                              >> $LOG_FILE
    print "----------------------------------------------------------"                             >> $LOG_FILE  

    print "**********************************************************"                             >> $LOG_FILE
    if [[ ($RETCODE = 0) && ($DATA_FILE_LINE_COUNT = $LOAD_ISRT_CNT) ]]; then
        print "*** Month and Month loaded counts BALANCE.               ***"                       >> $LOG_FILE
    else    
        print "*** Month and Month loaded counts >>DO NOT<< balance.    ***"                       >> $LOG_FILE
        print "*** Month and Month loaded counts >>DO NOT<< balance.    ***"                       >> $LOG_FILE
        print "*** Month and Month loaded counts >>DO NOT<< balance.    ***"                       >> $LOG_FILE
        print " "                                                                                  >> $LOG_FILE
        # NOTE that the ls -1t is using the number ONE, not the letter L, and no r, we want the most recent first
        #ls -1t $DBA_LOAD_MSG_DIR"/vrap.tclaim_stage_"$PRCS_VAL"_"$CYCLE_MONTH".msg.load."*|read UDB_ERR_MSG_FILE_MNTHLY
        UDB_ERR_MSG_FILE_MNTHLY=$(ls -1t "${DBA_LOAD_MSG_DIR}/vrap.TCLAIM_STAGE_${PRCS_VAL}_${CYCLE_MONTH}.msg."* | head -1)

        print "Sampling of error message from the load:"                                           >> $LOG_FILE
        sed -n 1,20P $UDB_ERR_MSG_FILE_MNTHLY                                                      >> $LOG_FILE
        RETCODE=999
    fi
    print "**********************************************************"                             >> $LOG_FILE
 
    print " "                                                                                      >> $LOG_FILE
    print "***** Checking RETURN CODE *******"                                                     >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE
    
fi

if [[ $RETCODE = 0 && $PRCS_QTR = 'TRUE' ]]; then 
    #-------------------------------------------------------------------------#
    # Validating the Month Load vs Quarterly
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                                       >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE
    print "***** Balancing the Quarterly Table against the sum of the TCLAIM_STAGE tables for the quarter *****" >> $LOG_FILE
    print "***** Balancing the Quarterly Table against the sum of the TCLAIM_STAGE tables for the quarter *****" >> $LOG_FILE
    print "***** Balancing the Quarterly Table against the sum of the TCLAIM_STAGE tables for the quarter *****" >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE

    print '**********************************************************'                             >> $LOG_FILE 
    export SQL_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >> $LOG_FILE
    print '**********************************************************'                             >>$LOG_FILE 

    db2 -p $SQL_CONNECT_STRING       >  $UDB_OUTPUT_MSG_FILE                                       >> $LOG_FILE
    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
        print 'date' 'Script ' $SCRIPTNAME 'failed in the DB CONNECT.'                             >> $LOG_FILE 
        print ' Return Code = '$RETCODE                                                            >> $LOG_FILE
        print 'Check DB2 error log: '$UDB_OUTPUT_MSG_FILE                                          >> $LOG_FILE
        print 'Here are last 20 lines of that file - '                                             >> $LOG_FILE
        print ' '                                                                                  >> $LOG_FILE
        print ' '                                                                                  >> $LOG_FILE
        tail -20 $UDB_OUTPUT_MSG_FILE                                                              >> $LOG_FILE
        print ' '                                                                                  >> $LOG_FILE
        print ' '                                                                                  >> $LOG_FILE   
    else
 
        ###################################################################################
        #  Get the QTR Load count 
        ###################################################################################

        SQL_STRING="Select  inserted - (rejected + deleted + skipped) as inserted, ' ', table, substr(table,12,2) table_num  from $UDB_SCHEMA_OWNER.LOADS  where TABLE='$QTR_DATA_FILE_TO_VALIDATE' and LOAD_DATE = (select max(load_date) from $UDB_SCHEMA_OWNER.LOADS  where TABLE='$QTR_DATA_FILE_TO_VALIDATE')"
        print $SQL_STRING                                                                          >> $LOG_FILE 

        db2 -px $SQL_STRING  > $QTR_CNT_OUTPUT_FILE 2> $UDB_OUTPUT_MSG_FILE
        RETCODE=$?
        print " "                                                                                  >> $LOG_FILE
        print "***** RETURN_CODE is $RETCODE ********"                                             >> $LOG_FILE
        print " "                                                                                  >> $LOG_FILE
        print "***** UBD Message File QTR is $UDB_OUTPUT_MSG_FILE ********"                        >> $LOG_FILE
        cat $UDB_OUTPUT_MSG_FILE                                                                   >> $LOG_FILE
        print "***** UBD Message File END                         ********"                        >> $LOG_FILE
        print " "                                                                                  >> $LOG_FILE
        print "***** QTR Count File is $UDB_OUTPUT_MSG_FILE ********"                              >> $LOG_FILE
        cat $QTR_CNT_OUTPUT_FILE                                                                   >> $LOG_FILE
        print "***** QTR Count File END                         ********"                          >> $LOG_FILE
        print " "                                                                                  >> $LOG_FILE
        if [[ $RETCODE = 0 ]]; then     
            print " "                                                                              >> $LOG_FILE
            print "***** Reading $QTR_CNT_OUTPUT_FILE ********"                                    >> $LOG_FILE
            print " "                                                                              >> $LOG_FILE
            
            read QTR_REC_CNT QTR_TABLE_NME QTR_TABLE_NB < $QTR_CNT_OUTPUT_FILE

            export QTR_TABLE_NB
            print " "                                                                              >> $LOG_FILE
            print "***** Values are   ********"                                                    >> $LOG_FILE
            print "QTR_REC_CNT is $QTR_REC_CNT"                                                    >> $LOG_FILE
            print "QTR_TABLE_NME is $QTR_TABLE_NME"                                                >> $LOG_FILE
            print " "                                                                              >> $LOG_FILE

            print "----------------------------------------------------------"                     >> $LOG_FILE  
            print "DBA Load information:"                                                          >> $LOG_FILE
            DBA_LOAD_MSG_OUT_FILE_QTRLY=$DBA_LOAD_MSG_DIR"/load.vrap.TCLAIM_"$PRCS_VAL"_"$QTR_TABLE_NB".out"
            cat $DBA_LOAD_MSG_OUT_FILE_QTRLY                                                       >> $LOG_FILE
            print "----------------------------------------------------------"                     >> $LOG_FILE  

            ###################################################################################
            #  Determine by month and get the Month Load count 
            ###################################################################################
        
            print " "                                                                              >> $LOG_FILE
            if [[ $CYCLE_MONTH = '01' || $CYCLE_MONTH = '02' || $CYCLE_MONTH = '03' ]]; then
                print "***** Processing for Months 1,2 and 3  ********"                            >> $LOG_FILE
                MONTH_ABRV_1='Jan'
                MONTH_ABRV_2='Feb'
                MONTH_ABRV_3='Mar'
                STAGE_TBL_1="TCLAIM_STAGE_"$PRCS_VAL"_01"
                STAGE_TBL_2="TCLAIM_STAGE_"$PRCS_VAL"_02"
                STAGE_TBL_3="TCLAIM_STAGE_"$PRCS_VAL"_03"
            fi

        
            if [[ $CYCLE_MONTH = '04' || $CYCLE_MONTH = '05' || $CYCLE_MONTH = '06' ]]; then
                print "***** Processing for Months 4,5 and 6  ********"                            >> $LOG_FILE
                MONTH_ABRV_1='Apr'
                MONTH_ABRV_2='May'
                MONTH_ABRV_3='Jun'
                STAGE_TBL_1="TCLAIM_STAGE_"$PRCS_VAL"_04"
                STAGE_TBL_2="TCLAIM_STAGE_"$PRCS_VAL"_05"
                STAGE_TBL_3="TCLAIM_STAGE_"$PRCS_VAL"_06"
            fi

        
            if [[ $CYCLE_MONTH = '07' || $CYCLE_MONTH = '08' || $CYCLE_MONTH = '09' ]]; then
                print "***** Processing for Months 7,8 and 9  ********"                            >> $LOG_FILE
                MONTH_ABRV_1='Jul'
                MONTH_ABRV_2='Aug'
                MONTH_ABRV_3='Sep'
                STAGE_TBL_1="TCLAIM_STAGE_"$PRCS_VAL"_07"
                STAGE_TBL_2="TCLAIM_STAGE_"$PRCS_VAL"_08"
                STAGE_TBL_3="TCLAIM_STAGE_"$PRCS_VAL"_09"
            fi

        
            if [[ $CYCLE_MONTH = '10' || $CYCLE_MONTH = '11' || $CYCLE_MONTH = '12' ]]; then
                print "***** Processing for Months 10,11 and 12  ********"                         >> $LOG_FILE
                MONTH_ABRV_1='Oct'
                MONTH_ABRV_2='Nov'
                MONTH_ABRV_3='Dec'
                STAGE_TBL_1="TCLAIM_STAGE_"$PRCS_VAL"_10"
                STAGE_TBL_2="TCLAIM_STAGE_"$PRCS_VAL"_11"
                STAGE_TBL_3="TCLAIM_STAGE_"$PRCS_VAL"_12"
            fi
             
            #NOTE:  When model is DSC (Discount) then the DFO staging claims table must be counted as well, for the period being covered.
            
            #Check the balances
            if [[ $RETCODE = 0 ]]; then     
                if [[ $PRCS_VAL = "DSC" ]]; then
                    SQL_STRING="select ((select count(*) from $SCHEMA_OWNER.$STAGE_TBL_1)+(select count(*) from $SCHEMA_OWNER.$STAGE_TBL_2)+(select count(*) from $SCHEMA_OWNER.$STAGE_TBL_3)+(select count(*) from $SCHEMA_OWNER.TCLAIM_STAGE_DFO WHERE inv_elig_dt BETWEEN '$QTR_START_DATE' and '$QTR_END_DATE')) as REC_CNT_FRM_MNTHS, (select count(*) from $SCHEMA_OWNER.TCLAIM_STAGE_DFO WHERE inv_elig_dt BETWEEN '$QTR_START_DATE' and '$QTR_END_DATE') as DFO_CLM_CNTS_FRM_MNTHS from SYSIBM.SYSDUMMY1"
                    DFO_SQL_STRING="select count(*) from $SCHEMA_OWNER.TCLAIM_STAGE_DFO WHERE inv_elig_dt BETWEEN '$QTR_START_DATE' and '$QTR_END_DATE'"
                else
                    SQL_STRING="select ((select count(*) from $SCHEMA_OWNER.$STAGE_TBL_1)+(select count(*) from $SCHEMA_OWNER.$STAGE_TBL_2)+(select count(*) from $SCHEMA_OWNER.$STAGE_TBL_3)) as REC_CNT_FRM_MNTHS from SYSIBM.SYSDUMMY1"
                fi
                 
                print $SQL_STRING                                                                  >> $LOG_FILE 

                db2 -px $SQL_STRING  > $MNTH_CNT_OUTPUT_FILE 2> $UDB_OUTPUT_MSG_FILE
                RETCODE=$?
                print "***** UBD Message File QTR ********"                                        >> $LOG_FILE
                cat $UDB_OUTPUT_MSG_FILE                                                           >> $LOG_FILE
                print "***** UBD Message File END ********"                                        >> $LOG_FILE

                if [[ $RETCODE = 0 ]]; then 
                    if [[ $PRCS_VAL = "DSC" ]]; then
                        read MNTH_REC_CNT DFO_QTR_REC_CNT < $MNTH_CNT_OUTPUT_FILE
                        export MNTH_REC_CNT_NUM=$MNTH_REC_CNT
                        export DFO_QTR_REC_CNT_NUM=$DFO_QTR_REC_CNT
                        export QTR_REC_CNT_NUM=$QTR_REC_CNT
                    else
                        read MNTH_REC_CNT JUNK < $MNTH_CNT_OUTPUT_FILE
                        export MNTH_REC_CNT_NUM=$MNTH_REC_CNT
                        export QTR_REC_CNT_NUM=$QTR_REC_CNT
                    fi

                    print " "                                                                      >> $LOG_FILE

                    if [[ $MNTH_REC_CNT_NUM = $QTR_REC_CNT_NUM ]]; then
                        print "**********************************************************"         >> $LOG_FILE
                        print "*** Month and Quarter counts balance for Quarter          "         >> $LOG_FILE
                        print "*** Month count is       $MNTH_REC_CNT_NUM "                    >> $LOG_FILE
                        if [[ $PRCS_VAL = "DSC" ]]; then
                            print "*** DFO QUARTER count is $DFO_QTR_REC_CNT_NUM "                     >> $LOG_FILE
                        fi
                        print "*** Quarter count is     $QTR_REC_CNT_NUM "                         >> $LOG_FILE
                        print "**********************************************************"         >> $LOG_FILE
                    else 
                        print "**********************************************************"         >> $LOG_FILE
                        print "*** Month and Quarter counts DO NOT balance for Quarter   "         >> $LOG_FILE
                        print "*** Month count is $MNTH_REC_CNT_NUM "                          >> $LOG_FILE
                        if [[ $PRCS_VAL = "DSC" ]]; then
                            print "*** DFO QUARTER count is $DFO_QTR_REC_CNT_NUM "                     >> $LOG_FILE
                        fi
                        print "*** Quarter count is $QTR_REC_CNT_NUM "                             >> $LOG_FILE
                        print "**********************************************************"         >> $LOG_FILE
                        RETCODE=999
                        #Cat in the DBA Load message file errors
                        # NOTE that the ls -1t is using the number ONE, not the letter L, and no r, we want the most recent first
                        UDB_ERR_MSG_FILE_QTRLY=$(ls -1t "${DBA_LOAD_MSG_DIR}/vrap.TCLAIM_${PRCS_VAL}_${QTR_TABLE_NB}.msg."* | head -1)

                        print "Sampling of error message from the QUATERLY load:"                  >> $LOG_FILE
                        sed -n 1,20P $UDB_ERR_MSG_FILE_QTRLY                                       >> $LOG_FILE
                    fi  
                else
                    print "Error during query of counts. SQL was: "                                >> $LOG_FILE
                    print $SQL_STRING                                                              >> $LOG_FILE
                fi
                print " "                                                                          >> $LOG_FILE
            fi
        fi

    fi
fi

#EMAIL logic
if [[ $RETCODE = 0 ]] ; then   
    #Send out email to business telling them which model was loaded, and how many claims went to 
    # the monthly and the quarterly table.
    print "The $PRCS_VAL claims have been loaded into the Monthly Staging table $STAGE_TABLE_NME." >> $LOAD_EMAIL_BODY
    print "Next, the three months of claims ($MONTH_ABRV_1, $MONTH_ABRV_2, $MONTH_ABRV_3) "        >> $LOAD_EMAIL_BODY
    print "within the quarter were loaded to the GDX Claim table $QTR_TABLE_NME."                  >> $LOAD_EMAIL_BODY
    print "\nThe counts to the Monthly staging tables, and the Quarterly table, have been "        >> $LOAD_EMAIL_BODY
    print "validated against their source."                                                        >> $LOAD_EMAIL_BODY
    print "\n\t\tCount Summary"                                                                    >> $LOAD_EMAIL_BODY
    print "\t\t----------------------- "                                                           >> $LOAD_EMAIL_BODY
    print "\tExtracted data from SILVER -\t\t\t\t\t\t$DATA_FILE_LINE_COUNT"                        >> $LOAD_EMAIL_BODY
    print "\tInserted into Monthly Staging table -\t\t\t\t$LOAD_ISRT_CNT"                          >> $LOAD_EMAIL_BODY
    if [[ $PRCS_VAL = "DSC" ]]; then
        print "\n\tTotal DFO for Quarter -\t\t\t\t\t\t\t$DFO_QTR_REC_CNT_NUM"                        >> $LOAD_EMAIL_BODY
        print "\tTotal from 3 months of Monthly Staging Tables (and DFO) -\t$MNTH_REC_CNT_NUM" >> $LOAD_EMAIL_BODY
    else
        print "\n\tTotal from 3 months of Monthly Staging Tables -\t\t\t$MNTH_REC_CNT_NUM"       >> $LOAD_EMAIL_BODY
    fi
    print "\tInserted into Quarterly Claims table -\t\t\t\t$QTR_REC_CNT_NUM"                       >> $LOAD_EMAIL_BODY
    print "\n\nThis run occurred in $REGION_NME.  Replying to this email will send it to the "     >> $LOAD_EMAIL_BODY
    print "GDXITD team."                                                                           >> $LOAD_EMAIL_BODY
    mailx -r $LOAD_EMAIL_FROM_GROUP -c $LOAD_EMAIL_CC_GROUP -s "$LOAD_EMAIL_SUBJECT" $LOAD_EMAIL_TO_GROUP < $LOAD_EMAIL_BODY

    RETCODE=$?
   
    if [[ $RETCODE != 0 ]] ; then   
        print "Error when sending Load Email.  Return code = $RETCODE."                            >> $LOG_FILE
    fi

fi


if [[ $RETCODE != 0 ]] ; then   
    JOBNAME=$JOB/$SCHEDULE 
    SCRIPTNAME=$SCRIPTNAME
    LOGFILE=$LOG_FILE
    EMAILPARM4="UDB Error messages for Monthly Load to be found in \n\t$DBA_LOAD_MSG_DIR/$UDB_ERR_MSG_FILE_MNTHLY"
    EMAILPARM5="UDB Error messages for Quarterly Load to be found in \n\t$DBA_LOAD_MSG_DIR/$UDB_ERR_MSG_FILE_QTRLY"
 
    print " "                                                                                      >> $LOG_FILE
    print "************************************"                                                   >> $LOG_FILE
    print "$VALID_FILE has been moved to archive"                                                  >> $LOG_FILE
    print "************************************"                                                   >> $LOG_FILE
    print " "                                                                                      >> $LOG_FILE

    print 'JOBNAME is '  $JOB/$SCHEDULE                                                            >> $LOG_FILE 
    print 'SCRIPTNAME is ' $SCRIPTNAME                                                             >> $LOG_FILE
    print 'LOGFILE is ' $LOGFILE                                                                   >> $LOG_FILE
    print 'EMAILPARM4 is ' $EMAILPARM4                                                             >> $LOG_FILE
    print 'EMAILPARM5 is ' $EMAILPARM5                                                             >> $LOG_FILE

    print '****** end of email parameters ******'                                                  >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                                         >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    cp -f $VALID_FILE $VALID_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE 
fi
 
mv $VALID_FILE $VALID_FILE_ARCH.`date +'%Y%j%H%M'`
rm -f DSC_DFO_CNTL_FILE

#clean up last months claim extract file
if [[ $CYCLE_MONTH -gt 1 ]]; then
    let PREV_CYCLE_MONTH=$CYCLE_MONTH-1
else 
    let PREV_CYCLE_MONTH=12
fi

rm -f "$OUTPUT_PATH/GDX_GD_2300J_claims_extract_to_gdx_"$PRCS_VAL"_"$(printf '%02d' $PREV_CYCLE_MONTH)".dat"

print "Clean up last months extract dat file - $OUTPUT_PATH/GDX_GD_2300J_claims_extract_to_gdx_"$PRCS_VAL"_"$(printf '%02d' $PREV_CYCLE_MONTH)".dat" >> $LOG_FILE

print " "                                                                                          >> $LOG_FILE
print " "                                                                                          >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                                               >> $LOG_FILE
mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`

exit $RETCODE

