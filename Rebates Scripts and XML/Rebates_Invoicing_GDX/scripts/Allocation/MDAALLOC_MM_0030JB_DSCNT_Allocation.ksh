#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDAALLOC_MM_0030JB_DSCNT_Allocation.ksh 
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

SCRIPTNAMEB="MDAALLOC_MM_0030JB_DSCNT_Allocation.ksh"

MODEL_TYP_CD=$1
if [[ -z MODEL_TYP_CD ]]; then 
    print "No MODEL_TYP_CD was passed in, aborting."                           >> $LOG_FILE
    return 1
fi

print "Starting " $SCRIPTNAMEB                            >> $LOG_FILEA
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


#if [[ $DISCNT_RUN_MODE_CDA = 'MPRD' ]]; then
   print "====================================================================" >> $LOG_FILEA
   print "Building SQL MDA_Allocation_DISCNT_mnthly_bill_sql010.ksh with PARMS: " >> $LOG_FILEA
   print $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER >> $LOG_FILEA
   print "====================================================================" >> $LOG_FILEA
   . $SCRIPT_PATH/MDA_Allocation_DISCNT_mnthly_bill_sql010.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
   print `date`"======db2 MDA_Allocation_DISCNT_mnthly_bill_sql010.ksh ==START======" >> $LOG_FILEA
   db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
   SQLCODE=$?
   print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
   print `date`"======db2 MDA_Allocation_DISCNT_mnthly_bill_sql010.ksh ==END======" >> $LOG_FILEA
   if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
      print "====================================================================" >> $LOG_FILEA
      print "Building SQL MDA_Allocation_DISCNT_mnthly_bill_sql020.ksh " >> $LOG_FILEA
      print "====================================================================" >> $LOG_FILEA
      . $SCRIPT_PATH/MDA_Allocation_DISCNT_mnthly_bill_sql020.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
      print `date`"======db2 MDA_Allocation_DISCNT_mnthly_bill_sql020.ksh ==START======" >> $LOG_FILEA
      db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
      SQLCODE=$?
      print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
      print `date`"======db2 MDA_Allocation_DISCNT_mnthly_bill_sql020.ksh ==END======" >> $LOG_FILEA
   fi
   if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
      print "====================================================================" >> $LOG_FILEA
      print "Building SQL MDA_Allocation_DISCNT_mnthly_bill_sql030.ksh " >> $LOG_FILEA
      print "====================================================================" >> $LOG_FILEA
      . $SCRIPT_PATH/MDA_Allocation_DISCNT_mnthly_bill_sql030.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
      print `date`"======db2 MDA_Allocation_DISCNT_mnthly_bill_sql030.ksh ==START======" >> $LOG_FILEA
      db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
      SQLCODE=$?
      print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
      print `date`"======db2 MDA_Allocation_DISCNT_mnthly_bill_sql030.ksh ==END======" >> $LOG_FILEA
   fi
   if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
      print "====================================================================" >> $LOG_FILEA
      print "Building SQL MDA_Allocation_DISCNT_mnthly_bill_sql040.ksh  " >> $LOG_FILEA
      print "====================================================================" >> $LOG_FILEA
      . $SCRIPT_PATH/MDA_Allocation_DISCNT_mnthly_bill_sql040.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER $MODEL_TYP_CD
      print `date`"======db2 MDA_Allocation_DISCNT_mnthly_bill_sql040.ksh ==START======" >> $LOG_FILEA
      db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
      SQLCODE=$?
      print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
      print `date`"======db2 MDA_Allocation_DISCNT_mnthly_bill_sql040.ksh ==END======" >> $LOG_FILEA
   fi
   if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
      RETCODE=0
   else   
      RETCODE=$SQLCODE
   fi
#fi

print "Ending " $SCRIPTNAMEB                            >> $LOG_FILEA

return $RETCODE

