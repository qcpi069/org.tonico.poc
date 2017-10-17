#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDAALLOC_MM_0010JA_MKTSHR_Allocation.ksh 
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
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-13-2005  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark MDA Allocation Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/MDA_Allocation_env.ksh

SCRIPTNAMA="MDAALLOC_MM_0010JA_MKTSHR_Allocation.ksh"

print "Starting " $SCRIPTNAMA                            >> $LOG_FILEA
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
print "  "                                               >> $LOG_FILEA
print `date`                                             >> $LOG_FILEA
print ' ' >> $LOG_FILEA
print "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&  CONTRACT is zero" >> $LOG_FILEA
print "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&  REPORT ID is zero" >> $LOG_FILEA
print ' ' >> $LOG_FILEA


print "====================================================================" >> $LOG_FILEA
print "Building SQL MDA_Allocation_MKTSHR_procd_sum_sql010.ksh with PARMS: " >> $LOG_FILEA
print $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER >> $LOG_FILEA
print "====================================================================" >> $LOG_FILEA
$SCRIPT_PATH/MDA_Allocation_MKTSHR_procd_sum_sql010.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql011.ksh ==START======" >> $LOG_FILEA
db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
SQLCODE=$?
print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql011.ksh ==END======" >> $LOG_FILEA
if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
   print "====================================================================" >> $LOG_FILEA
   print "Building SQL MDA_Allocation_MKTSHR_procd_sum_sql011.ksh " >> $LOG_FILEA
   print "====================================================================" >> $LOG_FILEA
   . $SCRIPT_PATH/MDA_Allocation_MKTSHR_procd_sum_sql011.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql011.ksh ==START======" >> $LOG_FILEA
   db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
   SQLCODE=$?
   print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql011.ksh ==END======" >> $LOG_FILEA
fi
if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
   print "====================================================================" >> $LOG_FILEA
   print "Building SQL MDA_Allocation_MKTSHR_procd_sum_sql020.ksh " >> $LOG_FILEA
   print "====================================================================" >> $LOG_FILEA
   . $SCRIPT_PATH/MDA_Allocation_MKTSHR_procd_sum_sql020.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql020.ksh ==START======" >> $LOG_FILEA
   db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
   SQLCODE=$?
   print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql020.ksh ==END======" >> $LOG_FILEA
fi
if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
      SQLCODE=0
      while [[ $SQLCODE = 0 ]]; do
         print "====================================================================" >> $LOG_FILEA
         print "Building SQL MDA_Allocation_MKTSHR_create_dcl_pair_sql010.ksh " >> $LOG_FILEA
         print "====================================================================" >> $LOG_FILEA
         . $SCRIPT_PATH/MDA_Allocation_MKTSHR_create_dcl_pair_sql010.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
         print `date`"======db2 MDA_Allocation_MKTSHR_create_dcl_pair_sql010.ksh ==START======" >> $LOG_FILEA
         db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
         SQLCODE=$?
         print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
         print `date`"======db2 MDA_Allocation_MKTSHR_create_dcl_pair_sql010.ksh ==END======" >> $LOG_FILEA
         if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
            print "====================================================================" >> $LOG_FILEA
            print "Building SQL MDA_Allocation_MKTSHR_create_dcl_pair_sql011.ksh " >> $LOG_FILEA
            print "====================================================================" >> $LOG_FILEA
            . $SCRIPT_PATH/MDA_Allocation_MKTSHR_create_dcl_pair_sql011.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
            print `date`"======db2 MDA_Allocation_MKTSHR_create_dcl_pair_sql011.ksh ==START======" >> $LOG_FILEA
            db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
            SQLCODE=$?
            print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
            print `date`"======db2 MDA_Allocation_MKTSHR_create_dcl_pair_sql011.ksh ==END======" >> $LOG_FILEA
         fi
         if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
            print "====================================================================" >> $LOG_FILEA
            print "Building SQL MDA_Allocation_MKTSHR_create_dcl_pair_sql020.ksh " >> $LOG_FILEA
            print "====================================================================" >> $LOG_FILEA
            . $SCRIPT_PATH/MDA_Allocation_MKTSHR_create_dcl_pair_sql020.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
            print `date`"======db2 MDA_Allocation_MKTSHR_create_dcl_pair_sql020.ksh ==START======" >> $LOG_FILEA
            db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
            SQLCODE=$?
            print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
            print `date`"======db2 MDA_Allocation_MKTSHR_create_dcl_pair_sql020.ksh ==END======" >> $LOG_FILEA
         fi
         if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
            print "====================================================================" >> $LOG_FILEA
            print "Building SQL MDA_Allocation_MKTSHR_create_dcl_pair_sql030.ksh " >> $LOG_FILEA
            print "====================================================================" >> $LOG_FILEA
            . $SCRIPT_PATH/MDA_Allocation_MKTSHR_create_dcl_pair_sql030.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
            print `date`"======db2 MDA_Allocation_MKTSHR_create_dcl_pair_sql030.ksh ==START======" >> $LOG_FILEA
            db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
            SQLCODE=$?
            print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
            print `date`"======db2 MDA_Allocation_MKTSHR_create_dcl_pair_sql030.ksh ==END======" >> $LOG_FILEA
         fi
      done
      if [[ $SQLCODE != 1 ]]; then
         SQLCODE=$SQLCODE
      else
         SQLCODE=0
      fi
   fi
if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
   print "====================================================================" >> $LOG_FILEA
   print "Building SQL MDA_Allocation_MKTSHR_procd_sum_sql030.ksh " >> $LOG_FILEA
   print "====================================================================" >> $LOG_FILEA
   . $SCRIPT_PATH/MDA_Allocation_MKTSHR_procd_sum_sql030.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql030.ksh ==START======" >> $LOG_FILEA
   db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
   SQLCODE=$?
   print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql030.ksh ==END======" >> $LOG_FILEA
fi         
if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
   print "====================================================================" >> $LOG_FILEA
   print "Building SQL MDA_Allocation_MKTSHR_procd_sum_sql040.ksh  " >> $LOG_FILEA
   print "====================================================================" >> $LOG_FILEA
   . $SCRIPT_PATH/MDA_Allocation_MKTSHR_procd_sum_sql040.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql040.ksh  ==START======" >> $LOG_FILEA
   db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
   SQLCODE=$?
   print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql040.ksh  ==END======" >> $LOG_FILEA
fi         
if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
   print "====================================================================" >> $LOG_FILEA
   print "Building SQL MDA_Allocation_MKTSHR_procd_sum_sql050.ksh " >> $LOG_FILEA
   print "====================================================================" >> $LOG_FILEA
   . $SCRIPT_PATH/MDA_Allocation_MKTSHR_procd_sum_sql050.ksh $SQL_FILE_NAMEA $LOG_FILEA $PERIOD_IDA $CNTRCT_IDA $RPT_IDA $SCHEMA_OWNER 
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql050.ksh ==START======" >> $LOG_FILEA
   db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA
   SQLCODE=$?
   print "SQLCODE is :" $SQLCODE >> $LOG_FILEA
   print `date`"======db2 MDA_Allocation_MKTSHR_procd_sum_sql050.ksh ==END======" >> $LOG_FILEA
fi   
if [[ $SQLCODE = 0 || $SQLCODE = 1 ]]; then
   RETCODE=0
else   
   RETCODE=$SQLCODE
fi

print "Ending " $SCRIPTNAMA                            >> $LOG_FILEA
  
return $RETCODE

