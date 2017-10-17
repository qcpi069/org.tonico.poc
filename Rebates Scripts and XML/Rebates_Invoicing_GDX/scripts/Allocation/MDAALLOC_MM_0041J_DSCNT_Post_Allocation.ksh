#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDAALLOC_MM_0041J_DSCNT_Post_Allocation.ksh 
# Title         : Clonable BASE module.
#
# Description   : For use in creating new scripts from a common look.
#
# Parameters    : N/A
#
# Output        : Log file as $LOG_FILEA
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 10-14-05   qcpi733    6004155   Added logic to call pagers in case of 
#                                 post allocation error.
# 04-18-05   qcpi733    5998083   Changed code to include input MODEL_TYP_CD 
#                                 and to use this field and pass it to other
#                                 scripts.
# 01-13-2005 K. Gries             Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark MDA Allocation Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/MDA_Allocation_env.ksh
SCRIPTNAMEPOSTALLOCA="MDAALLOC_MM_0041J_DSCNT_Post_Allocation.ksh"
POST_ALLOC_FILE=$LOG_PATH/"MDAALLOC_MM_0041J_DSCNT_Post_Allocation_"$DISCNT_RUN_MODE_CDA"_"$CNTRCT_IDA"_"$RPT_IDA".dat"
 
MODEL_TYP_CD=$1
if [[ -z MODEL_TYP_CD ]]; then 
    print "No MODEL_TYP_CD was passed in, aborting."                           >> $LOG_FILE
    return 1
fi

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
        ALLOC_ERROR_EMAIL_TO_LIST="8478780604@messaging.nextel.com,8884302503@archwireless.net"
        ALLOC_ERROR_EMAIL_CC_LIST="GDXITD@caremark.com"
#	 ALLOC_ERROR_EMAIL_TO_LIST="nandini.namburi@caremark.com"
#	 ALLOC_ERROR_EMAIL_CC_LIST="nandini.namburi@caremark.com"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        ALLOC_ERROR_EMAIL_TO_LIST="8478780604@messaging.nextel.com,8884302503@archwireless.net"
        ALLOC_ERROR_EMAIL_CC_LIST="GDXITD@caremark.com"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="nandini.namburi@caremark.com"
    ALLOC_ERROR_EMAIL_TO_LIST="nandini.namburi@caremark.com"
    ALLOC_ERROR_EMAIL_CC_LIST="nandini.namburi@caremark.com"
fi

if [[ $MODEL_TYP_CD = "D" || $MODEL_TYP_CD = "G" || $MODEL_TYP_CD = "X"  ]]; then
    if [[ $MODEL_TYP_CD = "D" ]]; then
        MODEL="DSC"
    elif [[ $MODEL_TYP_CD = "G" ]]; then 
        MODEL="GPO"
    else
       MODEL="XMD"
    fi
fi

#ERROR EMAIL INFO
EMAIL_SUBJECT=""
EMAIL_TEXT=$LOG_PATH/"MDA_Allocation_DSCNT_error_email_"$MODEL".txt"

rm -rf $EMAIL_TEXT

print "Starting " $SCRIPTNAMEPOSTALLOCA                            >> $LOG_FILEA
print "  "                                               >> $LOG_FILEA
print "Running for the following passed values: "        >> $LOG_FILEA
print "  "                                               >> $LOG_FILEA
print "                PERIOD_IDA = " $PERIOD_IDA          >> $LOG_FILEA
print "       DISCNT_RUN_MODE_CDA = " $DISCNT_RUN_MODE_CDA >> $LOG_FILEA
print "              ALOC_TYP_CDA = " $ALOC_TYP_CDA        >> $LOG_FILEA
print "                CNTRCT_IDA = " $CNTRCT_IDA          >> $LOG_FILEA
print "                   RPT_IDA = " $RPT_IDA             >> $LOG_FILEA
print "                   REQ_DTA = " $REQ_DTA             >> $LOG_FILEA
print "                   REQ_TMA = " $REQ_TMA             >> $LOG_FILEA
print "              REQ_STAT_CDA = " $REQ_STAT_CDA        >> $LOG_FILEA
print "              MODEL_TYP_CD = " $MODEL_TYP_CD        >> $LOG_FILEA
print "  "                                               >> $LOG_FILEA
print `date`                                             >> $LOG_FILEA

  print "POST ALLOCATION" >> $LOG_FILEA
  POST_ALLOC_FAIL=0
  if [[ $DISCNT_RUN_MODE_CDA = 'ACCL' ]]; then
     print "====================================================================" >> $LOG_FILEA
     print "Building SQL MDA_Allocation_DISCNT_procd_post_alloc_sql010.ksh with PARMS: " >> $LOG_FILEA
     print $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER >> $LOG_FILEA
     print "====================================================================" >> $LOG_FILEA
     . $SCRIPT_PATH/MDA_Allocation_DISCNT_procd_post_alloc_sql010.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
     print `date`"======db2 MDA_Allocation_DISCNT_procd_post_alloc_sql010.ksh ==START======" >> $LOG_FILEA
     db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA > $POST_ALLOC_FILE
     SQLCODE=$?
     if [[ $SQLCODE = 0 ]]; then
        POST_ALLOC_FAIL=1
     fi  
     print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
     print `date`"======db2 MDA_Allocation_DISCNT_procd_post_alloc_sql010.ksh ==END======" >> $LOG_FILEA
     if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
    print "====================================================================" >> $LOG_FILEA
        print "Building SQL MDA_Allocation_DISCNT_procd_post_alloc_sql020.ksh " >> $LOG_FILEA
        print "====================================================================" >> $LOG_FILEA
        . $SCRIPT_PATH/MDA_Allocation_DISCNT_procd_post_alloc_sql020.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
        print `date`"======db2 MDA_Allocation_DISCNT_procd_post_alloc_sql020.ksh ==START======" >> $LOG_FILEA
        db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA >> $POST_ALLOC_FILE
        SQLCODE=$?
        if [[ $SQLCODE = 0 ]]; then
           POST_ALLOC_FAIL=1
        fi  
        print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
        print `date`"======db2 MDA_Allocation_DISCNT_procd_post_alloc_sql020.ksh ==END======" >> $LOG_FILEA
     fi
     if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
    print "====================================================================" >> $LOG_FILEA
        print "Building SQL MDA_Allocation_DISCNT_procd_post_alloc_sql030.ksh " >> $LOG_FILEA
        print "====================================================================" >> $LOG_FILEA
        . $SCRIPT_PATH/MDA_Allocation_DISCNT_procd_post_alloc_sql030.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
        print `date`"======db2 MDA_Allocation_DISCNT_procd_post_alloc_sql030.ksh ==START======" >> $LOG_FILEA
        db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA >> $POST_ALLOC_FILE
        SQLCODE=$?
        if [[ $SQLCODE = 0 ]]; then
           POST_ALLOC_FAIL=1
        fi  
        print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
        print `date`"======db2 MDA_Allocation_DISCNT_procd_post_alloc_sql030.ksh ==END======" >> $LOG_FILEA
     fi
     if [[ $POST_ALLOC_FAIL = 1 ]]; then
        SQLCODE=9999
     else  
        if [[ $SQLCODE = 1 ]]; then
       SQLCODE=0
        else    
       SQLCODE=$SQLCODE
        fi
     fi 
  fi   

  if [[ $DISCNT_RUN_MODE_CDA = 'MPRD' ]]; then
     print "====================================================================" >> $LOG_FILEA
     print "Building SQL MDA_Allocation_DISCNT_mnthly_post_alloc_sql010.ksh with PARMS: " >> $LOG_FILEA
     print $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER >> $LOG_FILEA
     print "====================================================================" >> $LOG_FILEA
     . $SCRIPT_PATH/MDA_Allocation_DISCNT_mnthly_post_alloc_sql010.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
     print `date`"======db2 MDA_Allocation_DISCNT_mnthly_post_alloc_sql010.ksh ==START======" >> $LOG_FILEA
     db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA > $POST_ALLOC_FILE
     SQLCODE=$?
     if [[ $SQLCODE = 0 ]]; then
        POST_ALLOC_FAIL=1
     fi  
     print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
     print `date`"======db2 MDA_Allocation_DISCNT_mnthly_post_alloc_sql010.ksh ==END======" >> $LOG_FILEA
     if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
    print "====================================================================" >> $LOG_FILEA
        print "Building SQL MDA_Allocation_DISCNT_mnthly_post_alloc_sql020.ksh " >> $LOG_FILEA
        print "====================================================================" >> $LOG_FILEA
        . $SCRIPT_PATH/MDA_Allocation_DISCNT_mnthly_post_alloc_sql020.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
        print `date`"======db2 MDA_Allocation_DISCNT_mnthly_post_alloc_sql020.ksh ==START======" >> $LOG_FILEA
        db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA >> $POST_ALLOC_FILE
        SQLCODE=$?
        if [[ $SQLCODE = 0 ]]; then
           POST_ALLOC_FAIL=1
        fi  
        print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
        print `date`"======db2 MDA_Allocation_DISCNT_mnthly_post_alloc_sql020.ksh ==END======" >> $LOG_FILEA
     fi
     if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
    print "====================================================================" >> $LOG_FILEA
        print "Building SQL MDA_Allocation_DISCNT_mnthly_post_alloc_sql030.ksh " >> $LOG_FILEA
        print "====================================================================" >> $LOG_FILEA
        . $SCRIPT_PATH/MDA_Allocation_DISCNT_mnthly_post_alloc_sql030.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
        print `date`"======db2 MDA_Allocation_DISCNT_mnthly_post_alloc_sql030.ksh ==START======" >> $LOG_FILEA
        db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA >> $POST_ALLOC_FILE
        SQLCODE=$?
        if [[ $SQLCODE = 0 ]]; then
           POST_ALLOC_FAIL=1
        fi  
        print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
        print `date`"======db2 MDA_Allocation_DISCNT_mnthly_post_alloc_sql030.ksh ==END======" >> $LOG_FILEA
     fi
     if [[ $POST_ALLOC_FAIL = 1 ]]; then
        SQLCODE=9999
     else  
        if [[ $SQLCODE = 1 ]]; then
       SQLCODE=0
        else    
       SQLCODE=$SQLCODE
        fi
     fi 
  fi   

  if [[ $DISCNT_RUN_MODE_CDA = 'PROD' ]]; then
###### This sql010 is a balancing SQL - rows are FOUND (SQLCODE=0), ROWS ARE OUT OF BALANCE.
     print "====================================================================" >> $LOG_FILEA
     print "Building SQL MDA_Allocation_DISCNT_qtrly_post_alloc_sql010.ksh with PARMS: " >> $LOG_FILEA
     print $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER >> $LOG_FILEA
     print "====================================================================" >> $LOG_FILEA
     . $SCRIPT_PATH/MDA_Allocation_DISCNT_qtrly_post_alloc_sql010.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
     print `date`"======db2 MDA_Allocation_DISCNT_qtrly_post_alloc_sql010.ksh ==START======" >> $LOG_FILEA
     db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA > $POST_ALLOC_FILE
     SQLCODE=$?

     if [[ $SQLCODE = 0 ]]; then
        POST_ALLOC_FAIL=1
     fi  
     print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
     print `date`"======db2 MDA_Allocation_DISCNT_qtrly_post_alloc_sql010.ksh ==END======" >> $LOG_FILEA
     if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
    print "====================================================================" >> $LOG_FILEA
        print "Building SQL MDA_Allocation_DISCNT_qtrly_post_alloc_sql020.ksh " >> $LOG_FILEA
        print "====================================================================" >> $LOG_FILEA
        . $SCRIPT_PATH/MDA_Allocation_DISCNT_qtrly_post_alloc_sql020.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
        print `date`"======db2 MDA_Allocation_DISCNT_qtrly_post_alloc_sql020.ksh ==START======" >> $LOG_FILEA
        db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA >> $POST_ALLOC_FILE
        SQLCODE=$?
     if [[ $SQLCODE = 0 ]]; then
           POST_ALLOC_FAIL=1
        fi  
        print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
        print `date`"======db2 MDA_Allocation_DISCNT_qtrly_post_alloc_sql020.ksh ==END======" >> $LOG_FILEA
     fi
     if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
    print "====================================================================" >> $LOG_FILEA
        print "Building SQL MDA_Allocation_DISCNT_qtrly_post_alloc_sql030.ksh " >> $LOG_FILEA
        print "====================================================================" >> $LOG_FILEA
        . $SCRIPT_PATH/MDA_Allocation_DISCNT_qtrly_post_alloc_sql030.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
        print `date`"======db2 MDA_Allocation_DISCNT_qtrly_post_alloc_sql030.ksh ==START======" >> $LOG_FILEA
        db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA >> $POST_ALLOC_FILE
        SQLCODE=$?
        if [[ $SQLCODE = 0 ]]; then
           POST_ALLOC_FAIL=1
        fi  
        print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
        print `date`"======db2 MDA_Allocation_DISCNT_qtrly_post_alloc_sql030.ksh ==END======" >> $LOG_FILEA
     fi
  fi   

if [[ $POST_ALLOC_FAIL = 1 ]]; then
    SQLCODE=9999
    # Send email error message to pagers
    EMAIL_SUBJECT="$SYSTEM $MODEL Model POST-Allocation Error Occurred "`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
    print "\nThe Allocation process for Rebate/Discount Reports for Period $PERIOD_ID has ERRORED." >> $EMAIL_TEXT
    print "\nLook in $LOG_FILEA" >> $EMAIL_TEXT
    print "\nThis run was in $SYSTEM." >> $EMAIL_TEXT

    print " mail command is : " >> $LOG_FILE
    print " mailx -r GDXITD@Caremark.com -c $ALLOC_ERROR_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $ALLOC_ERROR_EMAIL_TO_LIST < $EMAIL_TEXT " >> $LOG_FILE
    mailx -r GDXITD@Caremark.com -c $ALLOC_ERROR_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $ALLOC_ERROR_EMAIL_TO_LIST < $EMAIL_TEXT
else  
    if [[ $SQLCODE = 1 ]]; then
        SQLCODE=0
    else    
        SQLCODE=$SQLCODE
    fi
fi 

RETCODE=$SQLCODE

print "Ending " $SCRIPTNAMEPOSTALLOCA                            >> $LOG_FILEA

return $RETCODE

