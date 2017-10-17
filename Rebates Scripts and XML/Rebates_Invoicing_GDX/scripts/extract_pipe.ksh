#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GD_2300J_claims_extract_to_gdx.ksh   
# Title         : Claim extract from GPO to GDX..
#
# Description   : This script will pull claims from the GPO Oracle 
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
# 10-27-05   qcpi733     Added quarter cycle gid and changed GPO where 
#                        clause to use SCRC not VCSCRC.
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
        ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
    else
        # Running in Prod region
        ALTER_EMAIL_ADDRESS=""
        SCHEMA_OWNER="VRAP"
    fi
else
    # Running in Development region
    ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    SCHEMA_OWNER="VRAP"
fi

#############################################
## This prcs_val is here.
## If it is not supplied we will die at check.
#############################################

PRCS_VAL=$1

RETCODE=0
BKUP_RETCODE=0
SCHEDULE=
JOB="GD_2300J"
FILE_BASE="GDX"$SCHEDULE"_"$JOB"_claims_extract_to_gdx"
SCRIPTNAME=$FILE_BASE".ksh"
# LOG FILES
LOG_FILE_ARCH=$LOG_ARCH_PATH/$FILE_BASE"_"$PRCS_VAL".log"
LOG_FILE=$LOG_PATH/$FILE_BASE"_"$PRCS_VAL".log"
# Oracle and UDB SQL files
UDB_SQL_FILE=$SQL_PATH/$FILE_BASE"_"$PRCS_VAL"_udb.sql"
UDB_CONNECT_STRING="db2 -p connect to "$DATABASE" user "$CONNECT_ID" using "$CONNECT_PWD
# UDB Message files
UDB_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_"$PRCS_VAL"_udb_sql.msg"
UDB_IMPORT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_"$PRCS_VAL"_udb_imp.msg"
UDB_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_"$PRCS_VAL"_udb.msg"
# Output files
SQL_PIPE_FILE=$OUTPUT_PATH/$FILE_BASE"_"$PRCS_VAL"_pipe.lst"
SQL_DATA_CNTL_FILE=$OUTPUT_PATH/$FILE_BASE"_"$PRCS_VAL"_cntl.dat"
#Misc
QTR_CYCLE_GID=""

rm -f $LOG_FILE
rm -f $ORA_SQL_FILE
rm -f $UDB_SQL_FILE
rm -f $UDB_MSG_FILE
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_IMPORT_MSG_FILE
rm -f $SQL_PIPE_FILE

#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "Starting the script to load the Claims tables"                          >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

print "=================================================================="     >> $LOG_FILE


if [ $# -lt 1 ] 
then
    print "************* S E V E R E  ***  E R R O R *********************"     >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"     >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"     >> $LOG_FILE
    print "                                                               "     >> $LOG_FILE
    print "The Processing Value, PRCS_VAL, was not supplied to the script."     >> $LOG_FILE
    print "This is a major issue. We do not know what to process."              >> $LOG_FILE
    print "                                                               "     >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"     >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"     >> $LOG_FILE
    print "************* S E V E R E  ***  E R R O R *********************"     >> $LOG_FILE
    RETCODE=999
else    
    PRCS_VAL=$1
    print "                                                               "     >> $LOG_FILE
    print "The Processing Value, PRCS_VAL,                                "     >> $LOG_FILE
    print "supplied to thee script is $PRCS_VAL.                          "     >> $LOG_FILE
    print "                                                               "     >> $LOG_FILE

    #################################################################################
    ####
    #### ORA_SQL_FILE_PV is a stored sql member specific to the Process Value
    #### ORA_SQL_FILE uses the value to build the name
    ####
    #################################################################################
    ORA_SQL_FILE_PV=$SQL_PATH/$FILE_BASE"_"$PRCS_VAL".sql"
    ORA_SQL_FILE=$SQL_PATH/$FILE_BASE"_"$PRCS_VAL"_ora.sql"
    print "The Oracle SQL file to be used for this process is $ORA_SQL_FILE_PV." >> $LOG_FILE
    print "                                                               "     >> $LOG_FILE

fi

if [[ $RETCODE = 0 ]]; then 
    #-------------------------------------------------------------------------#
    # Rebate ID Extract
    # Set up the Pipe file, then build and EXEC the new SQL.               
    # Get the record count from the input for validation of rows
    #-------------------------------------------------------------------------#
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Begin building Oracle SQL file for CLAIM Extract TEST"           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    #-------------------------------------------------------------------------#
    # Oracle userid/password
    #-------------------------------------------------------------------------#

    ORACLE_DB_USER_PASSWORD=`cat $SCRIPT_PATH/ora_user.fil`

    cat > $ORA_SQL_FILE << EOF
    set LINESIZE 200
    set TERMOUT OFF
    set PAGESIZE 0
    set NEWPAGE 0
    set SPACE 0
    set ECHO OFF
    set FEEDBACK OFF
    set HEADING OFF
    set WRAP off
    set verify off
    whenever sqlerror exit 1
    SPOOL $SQL_DATA_CNTL_FILE
    alter session enable parallel dml; 

    SELECT 
           MIN(a.rbate_cycle_gid)
          ,' '
          ,MAX(a.rbate_cycle_gid)
          ,' '
          ,b.rbate_cycle_gid qtrly_cycle_gid
          ,' '
          ,TO_CHAR(MIN(a.cycle_start_date),'YYYY-MM-DD')
          ,' '
          ,TO_CHAR(MAX(a.cycle_end_date),'YYYY-MM-DD')
          ,' '
          ,SUBSTRB(MIN(a.rbate_cycle_gid),5,2)
          ,' '
          ,TO_CHAR(MIN(b.cycle_start_date),'YYYY-MM-DD')
          ,' '
          ,TO_CHAR(MAX(b.cycle_end_date),'YYYY-MM-DD')
    FROM dma_rbate2.t_rbate_cycle a
        ,dma_rbate2.t_rbate_cycle b
    WHERE a.rbate_cycle_type_id = '1'
      AND a.rbate_cycle_status = 'A'
      AND a.cycle_start_date BETWEEN b.cycle_start_date AND b.cycle_end_date
      AND a.cycle_end_date BETWEEN b.cycle_start_date AND b.cycle_end_date
      AND b.rbate_cycle_type_id = '2'
    GROUP BY b.rbate_cycle_gid    ;

    quit;
EOF

    print "********* SQL File for Control dates is **********"  >> $LOG_FILE
    cat $ORA_SQL_FILE                       >> $LOG_FILE
    print "********* SQL File for Control dates end *********"  >> $LOG_FILE
    
    $ORACLE_HOME/sqlplus -s $ORACLE_DB_USER_PASSWORD @$ORA_SQL_FILE

    RETCODE=$?
    if [[ $RETCODE != 0 ]] ; then
        print 'CYCLE SELECTION SQL FAILED - error message is: ' >> $LOG_FILE 
        print ' '                                               >> $LOG_FILE 
        tail -20 $SQL_DATA_CNTL_FILE                    >> $LOG_FILE
    else
        print 'CYCLE SELECTION SUCCESSFUL: '            >> $LOG_FILE 
        FIRST_READ=1
        while read cycle_min cycle_max qtrly_cycle_gid cycle_start_dt cycle_end_dt cycle_month_in qtr_cycle_start_dt_in qtr_cycle_end_dt_in; do

            if [[ $FIRST_READ = 0 ]]; then
                print 'Finishing control file read'                     >> $LOG_FILE
            else
                FIRST_READ=0
                print 'read record from control file'                   >> $LOG_FILE
                if [[ -z $cycle_min || -z $cycle_max || -z $cycle_start_dt || -z $cycle_end_dt || -z $cycle_month_in || -z $qtr_cycle_start_dt_in || -z $qtr_cycle_end_dt_in ]] ; then
                    RETCODE=1
                    print ' '                                                   >> $LOG_FILE
                    print `date`                                                >> $LOG_FILE
                    print 'No cycle data returned from Oracle.'                 >> $LOG_FILE
                    print ' '                                                   >> $LOG_FILE
                    print 'min cycle Gid from Oracle is      >'$cycle_min'<'        >> $LOG_FILE
                    print 'max cycle Gid from Oracle is      >'$cycle_max'<'        >> $LOG_FILE
                    print 'Start Date from Oracle is     >'$cycle_start_dt'<'   >> $LOG_FILE
                    print 'End Date from  Oracle is          >'$cycle_end_dt'<'     >> $LOG_FILE
                    print 'Cycle Month from Oracle is        >'$cycle_month_in'<'   >> $LOG_FILE
                    print 'QTR Start Date from Oracle is     >'$qtr_cycle_start_dt_in'<' >> $LOG_FILE
                    print 'QTR End Date from  Oracle is      >'qtr_$cycle_end_dt_in'<' >> $LOG_FILE
                    begin_date=$cycle_start_dt
                    end_date=$cycle_end_dt  
                    cycle_low=$cycle_min
                    cycle_high=$cycle_max
                    cycle_month=$cycle_month_in
                    qtr_start_date=$qtr_cycle_start_dt_in
                    qtr_end_date=$qtr_cycle_end_dt_in
                    print ' '                                                   >> $LOG_FILE
                else 
                    print 'Oracle Cycle data read completed.'               >> $LOG_FILE
                    print 'min cycle gid is' $cycle_min             >> $LOG_FILE
                    print 'max cycle gid is' $cycle_max             >> $LOG_FILE
                    print 'min cycle start date is' $cycle_start_dt         >> $LOG_FILE
                    print 'max cycle end date is' $cycle_end_dt         >> $LOG_FILE
                    print 'min cycle month is' $cycle_month             >> $LOG_FILE
                    print 'QTR Start Date is ' $qtr_cycle_start_dt_in       >> $LOG_FILE
                    print 'QTR End Date  is  ' $qtr_$cycle_end_dt_in        >> $LOG_FILE
                    begin_date=$cycle_start_dt
                    end_date=$cycle_end_dt  
                    cycle_low=$cycle_min
                    cycle_high=$cycle_max
                    export QTR_CYCLE_GID=$qtrly_cycle_gid
                    cycle_month=$cycle_month_in
                    qtr_start_date=$qtr_cycle_start_dt_in
                    qtr_end_date=$qtr_cycle_end_dt_in
                fi                  
            fi 
        done < $SQL_DATA_CNTL_FILE          

    #################################################################################
    ####
    #### output data and trigger files needed the parm as well in the build of the name
    ####
    #################################################################################
    
    SQL_DATA_FILE=$FILE_BASE"_"$PRCS_VAL"_"$cycle_month".dat"
    TRIGGER_FILE=$OUTPUT_PATH/$FILE_BASE"_"$PRCS_VAL".trg"
    
    print "SQL_DATA_FILE is:" $SQL_DATA_FILE                            >> $LOG_FILE
    print "TRIGGER_FILE is:" $TRIGGER_FILE                              >> $LOG_FILE
    
    
    #-------------------------------------------------------------------------#
    # Create Oracle SQL file
    #-------------------------------------------------------------------------#

    rm -f $SQL_PIPE_FILE
    mkfifo $SQL_PIPE_FILE
    dd if=$SQL_PIPE_FILE of=$OUTPUT_PATH/$SQL_DATA_FILE bs=100k &

    cat > $ORA_SQL_FILE << EOF
        set LINESIZE 700
        set trimspool on
        set arraysize 100
        set TERMOUT OFF
        set PAGESIZE 0
        set NEWPAGE 0
        set SPACE 0
        set ECHO OFF
        set FEEDBACK OFF
        set HEADING OFF 
        set WRAP off
        set serveroutput off
        set verify off
        whenever sqlerror exit 1
        set timing off
        SPOOL $SQL_PIPE_FILE
        alter session enable parallel dml;
EOF

    cat $ORA_SQL_FILE_PV >> $ORA_SQL_FILE 

    if [[ $PRCS_VAL = 'GPO' ]]; then
         
        cat >> $ORA_SQL_FILE << EOF
        FROM  dwcorp.mv_frmly mf
             ,dma_rbate2.s_claim_rbate_cycle scrc
             ,dma_rbate2.v_phmcy vp
             ,dma_rbate2.v_combined_scr vcs
        WHERE scrc.cycle_gid  = $QTR_CYCLE_GID
        AND   scrc.batch_date BETWEEN TO_DATE ('$begin_date','YYYY-MM-DD')
                              AND     TO_DATE ('$end_date'  ,'YYYY-MM-DD')
        AND   scrc.claim_status_flag IN (0, 24, 26)
        AND   scrc.batch_date = vcs.batch_date
        AND   scrc.claim_gid  = vcs.claim_gid
        AND   scrc.frmly_gid  = mf.drug_list_gid
        AND   scrc.phmcy_gid  = vp.phmcy_gid
        ;
        quit;
EOF
        
        else
        
            cat >> $ORA_SQL_FILE << EOF
        FROM DMA_RBATE2.s_claim_refresh_dsc scrd
        ;
        quit;

EOF

    fi

    print " "                           >> $LOG_FILE
    print "********* SQL File for Claims Extract is **********" >> $LOG_FILE
    cat $ORA_SQL_FILE                       >> $LOG_FILE
    print "********* SQL File for Claims Extract end *********" >> $LOG_FILE
    print " "                           >> $LOG_FILE

    print " "                                                                  >> $LOG_FILE
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Finished building Oracle SQL file, start extracting data "          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    START_DATE=`date +"%D %r %Z"`

    RETCODDE2=0

    $ORACLE_HOME/sqlplus -s $ORACLE_DB_USER_PASSWORD @$ORA_SQL_FILE

    RETCODE2=$?

    END_DATE=`date +"%D %r %Z"`

    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "Completed extract of $PRCS_VAL clms"                                >> $LOG_FILE
    print "Started at $START_DATE and completed at $END_DATE"                  >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Start-$START_DATE"                                                  >> $LOG_FILE
    print "End  -$END_DATE"                                                    >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

    fi
fi


print 'RETCODE=<'$RETCODE'>'>> $LOG_FILE
print 'RETCODE2=<'$RETCODE2'>'>> $LOG_FILE


if [[ $RETCODE = 0 && $RETCODE2 = 0 ]] ; then

    ### create the database load file name without the path as part of it.
    DATABASE_LOAD_FILE=$FILE_BASE"_"$cycle_month".dat"

    if [[ $PRCS_VAL = 'GPO' ]]; then
        model_type="G"
    else
        model_type="D"
    fi

        ### create and populate the trigger file with the file name month and model type.   
    print $SQL_DATA_FILE" "$cycle_month" "$model_type" "$qtr_start_date" "$qtr_end_date     > $TRIGGER_FILE
else
    print "Error when extracting DSC claims from SILVER. "                     >> $LOG_FILE
    tail -20 $OUTPUT_PATH/$SQL_DATA_FILE                                       >> $LOG_FILE
fi

if [[ $RETCODE != 0 || $RETCODE2 != 0 ]] ; then   
    JOBNAME=$JOB/$SCHEDULE 
    SCRIPTNAME=$SCRIPTNAME
    LOGFILE=$LOG_FILE
    EMAILPARM4='  '
    EMAILPARM5='  '      

    print 'Sending email notification with the following parameters' >> $LOG_FILE

    print 'JOBNAME is '  $JOB/$SCHEDULE                              >> $LOG_FILE 
    print 'SCRIPTNAME is ' $SCRIPTNAME                               >> $LOG_FILE
    print 'LOGFILE is ' $LOGFILE                                     >> $LOG_FILE
    print 'EMAILPARM4 is ' $EMAILPARM4                               >> $LOG_FILE
    print 'EMAILPARM5 is ' $EMAILPARM5                               >> $LOG_FILE

    print '****** end of email parameters ******'                    >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                           >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE 
fi

print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`

exit $RETCODE

