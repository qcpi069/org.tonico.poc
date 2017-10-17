#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDAALLOC_MM_0010J_MKTSHR_Allocation.ksh 
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
#                                 for the TALLOCATN_SCHEDULE table.
# 01-13-2005 K. Gries             Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark MDA Allocation Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/MDA_Allocation_env.ksh

#Retrieve the passed parameters
PERIOD_IDA=$1
DISCNT_RUN_MODE_CDA=$2
ALOC_TYP_CDA=$3
CNTRCT_IDA=$4
RPT_IDA=$5
REQ_DTA=$6
REQ_TMA=$7
REQ_STAT_CDA=$8
MODEL_TYP_CDA=$9

#the variables needed for the source file location and the NT Server
SCHEDULEA="MDAALLOC"
JOBA="MM_0010J"
FILE_BASEA=$SCHEDULEA"_"$JOBA"_""MKTSHR_Allocation_"$PERIOD_IDA"_"$CNTRCT_IDA"_"$RPT_IDA
SCRIPTNAMEA=$FILE_BASEA".ksh"
LOG_FILEA=$LOG_PATH/$FILE_BASEA"_"$MODEL_TYP_CD".log"
LOG_ARCHA=$LOG_ARCH_PATH/$FILE_BASEA"_"$MODEL_TYP_CD".log"
SQL_FILE_NAMEA=$SQL_PATH/$FILE_BASEA".sql"
TRG_FILEA=$LOG_PATH/$FILE_BASEA".trg"
COUNT_FILEA=$LOG_PATH/$FILE_BASEA"_count.dat"
PERIOD_FILEA=$LOG_PATH/$FILE_BASEA"_Period.dat"
OUTPUT_FILEA=$LOG_PATH/$FILE_BASEA"_Output.dat"
OUTPUT_FILEB=$LOG_PATH/$FILE_BASEA"_OutputB.dat"

##SCHEMA_OWNER="QCPU70Z"
##TALLOCATN_OWNER="VACTUATE"
SCHEMA_OWNER="VRAP"
TALLOCATN_OWNER="VRAP"

rm -f $LOG_FILEA
print "Starting " $SCRIPTNAMEA                            >> $LOG_FILEA
chmod 666 $LOG_FILEA

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
print "             MODEL_TYP_CDA = " $MODEL_TYP_CDA     >> $LOG_FILEA
print "  "                                               >> $LOG_FILEA
print `date`                                             >> $LOG_FILEA

DESC_TEXTA="MKSH10J $DISCNT_RUN_MODE_CDA C$CNTRCT_IDA R$RPT_IDA"

cat > $SQL_FILE_NAMEA << 99EOFSQLTEXT99
Update $TALLOCATN_OWNER.tallocatn_schedule 
Set REQ_STAT_CD = 'R' 
   ,STRT_DT = CURRENT DATE 
   ,STRT_TM = CURRENT TIME
   ,RUN_DESC_TX = '$DESC_TEXTA'       
where REQ_STAT_CD = 'P'
  and PERIOD_ID = '$PERIOD_IDA'
  and DISCNT_RUN_MODE_CD = '$DISCNT_RUN_MODE_CDA'
  and ALOC_TYP_CD = '$ALOC_TYP_CDA' 
  and CNTRCT_ID = $CNTRCT_IDA 
  and RPT_ID = $RPT_IDA 
  and REQ_DT = DATE('$REQ_DTA')
  and REQ_TM = TIME('$REQ_TMA')
  and MODEL_TYP_CD = '$MODEL_TYP_CDA';
99EOFSQLTEXT99

db2 -stvxf $SQL_FILE_NAMEA >> $OUTPUT_FILEA

SQLCODE=$?

if [[ $SQLCODE != 0 ]]; then
      print "Script " $SCRIPTNAMEA "failed in Update TALLOCATN_SCHEDULEA to REQ_STAT = 'P'." >> $LOG_FILEA
      print "#db2 return code is : <" $SQLCODE ">" >> $LOG_FILEA
      return $SQLCODE   
fi

RETCODE=0

print "====================================================================" >> $LOG_FILEA
print "====================================================================" >> $LOG_FILEA
print "====================================================================" >> $LOG_FILEA
print "SQL_FILE_NAMEA= "$SQL_FILE_NAMEA  >> $LOG_FILEA
print "LOG_FILEA= "$LOG_FILEA >> $LOG_FILEA
print "PERIOD_IDA= "$PERIOD_IDA >> $LOG_FILEA
print "CNTRCT_IDA= "$CNTRCT_IDA >> $LOG_FILEA
print "RPT_IDA= "$RPT_IDA >> $LOG_FILEA
print "SCHEMA_OWNER= "$SCHEMA_OWNER >> $LOG_FILEA
print "MODEL_TYP_CDA= "$MODEL_TYP_CDA >> $LOG_FILEA
print "====================================================================" >> $LOG_FILEA
print "====================================================================" >> $LOG_FILEA
print "====================================================================" >> $LOG_FILEA

print "&&&&++++++++++++++++++++++++++++++&&&&&&&  CONTRACT is NOT zero" >> $LOG_FILEA
if [[ $DISCNT_RUN_MODE_CDA = 'MKSH' ]]; then
   print " " >> $LOG_FILEA
   print " " >> $LOG_FILEA
   print "!!!!!! Running MDAALLOC_MM_0010JA_MKTSHR_Allocation.ksh" >> $LOG_FILEA
   print " " >> $LOG_FILEA
   print " " >> $LOG_FILEA
   . $SCRIPT_PATH/MDAALLOC_MM_0010JA_MKTSHR_Allocation.ksh 
   RETCODE=$?
fi

if [[ $DISCNT_RUN_MODE_CDA = 'MPRD' ]]; then
   print " " >> $LOG_FILEA
   print " " >> $LOG_FILEA
   print "!!!!!! Running MDAALLOC_MM_0010JB_MKTSHR_Allocation.ksh" >> $LOG_FILEA
   print " " >> $LOG_FILEA
   print " " >> $LOG_FILEA
   . $SCRIPT_PATH/MDAALLOC_MM_0010JB_MKTSHR_Allocation.ksh 
   RETCODE=$?
fi

if [[ $DISCNT_RUN_MODE_CDA = 'PROD' ]]; then
   print " " >> $LOG_FILEA
   print " " >> $LOG_FILEA
   print "!!!!!! Running MDAALLOC_MM_0010JC_MKTSHR_Allocation.ksh" >> $LOG_FILEA
   print " " >> $LOG_FILEA
   print " " >> $LOG_FILEA
   . $SCRIPT_PATH/MDAALLOC_MM_0010JC_MKTSHR_Allocation.ksh 
   RETCODE=$?
fi
  # check SQLCODE - if bad set RETCODE = to SQLCODE

print "Prior to Post Alloc SQLCODE is :" $SQLCODE >> $LOG_FILEA
   
if [[ $RETCODE = 0 ]]; then
  # POST ALLOCATION
  print "POST ALLOCATION" >> $LOG_FILEA
  . $SCRIPT_PATH/MDAALLOC_MM_0021J_MKTSHR_Post_Allocation.ksh 
  RETCODE=$?
else
  # Update to Error
  print "Update to Error - RETCODE is : " $RETCODE >> $LOG_FILEA
fi 

print "Prior to Update SQLCODE is :" $SQLCODE >> $LOG_FILEA

if [[ $RETCODE = 0 ]]; then
   
   DESC_TEXTA="MKSH10J COMP $DISCNT_RUN_MODE_CDA C$CNTRCT_IDA R$RPT_IDA"
   
   print "=========================================================" >> $LOG_FILEA
   print "=Updating TALLOCATN_SCHEDULE to 'C'omplete =" >> $LOG_FILEA
   print "=========================================================" >> $LOG_FILEA
   
cat > $SQL_FILE_NAMEA << 99EOFSQLTEXT99
Update $TALLOCATN_OWNER.tallocatn_schedule 
Set REQ_STAT_CD = 'C' 
   ,END_DT = CURRENT DATE 
   ,END_TM = CURRENT TIME 
   ,RUN_DESC_TX = '$DESC_TEXTA' 
where REQ_STAT_CD = 'R' 
  and PERIOD_ID = '$PERIOD_IDA'
  and DISCNT_RUN_MODE_CD = '$DISCNT_RUN_MODE_CDA'
  and ALOC_TYP_CD = '$ALOC_TYP_CDA' 
  and CNTRCT_ID = $CNTRCT_IDA 
  and RPT_ID = $RPT_IDA 
  and REQ_DT = DATE('$REQ_DTA') 
  and REQ_TM = TIME('$REQ_TMA') 
  and MODEL_TYP_CD = '$MODEL_TYP_CDA ';
   
99EOFSQLTEXT99

   db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA

   SQLCODE=$?

   if [[ $SQLCODE != 0 ]]; then
      print "Script " $SCRIPTNAMEA "failed in Update TALLOCATN_SCHEDULEA to REQ_STAT = 'C'." >> $LOG_FILEA
      print "db2 return code is : <" $SQLCODE ">" >> $LOG_FILEA
      RETCODE=$SQLCODE
   fi
else
   if [[ $RETCODE = '9999' ]]; then
    DESC_TEXTA="MKSH10J OOB $DISCNT_RUN_MODE_CDA C$CNTRCT_IDA R$RPT_IDA"
   else
        DESC_TEXTA="E10JMKSH $DISCNT_RUN_MODE_CDA C$CNTRCT_IDA R$RPT_IDA"
   fi     
   print "=========================================================" >> $LOG_FILEA
   print "=Updating TALLOCATN_SCHEDULE to 'E'rror =" >> $LOG_FILEA
   print "=========================================================" >> $LOG_FILEA

cat > $SQL_FILE_NAMEA << 99EOFSQLTEXT99
Update $TALLOCATN_OWNER.tallocatn_schedule 
Set REQ_STAT_CD = 'E' 
   ,END_DT = CURRENT DATE 
   ,END_TM = CURRENT TIME 
   ,RUN_DESC_TX = '$DESC_TEXTA' 
where REQ_STAT_CD = 'R' 
  and PERIOD_ID = '$PERIOD_IDA'
  and DISCNT_RUN_MODE_CD = '$DISCNT_RUN_MODE_CDA'
  and ALOC_TYP_CD = '$ALOC_TYP_CDA' 
  and CNTRCT_ID = $CNTRCT_IDA 
  and RPT_ID = $RPT_IDA 
  and REQ_DT = DATE('$REQ_DTA') 
  and REQ_TM = TIME('$REQ_TMA') 
  and MODEL_TYP_CD = '$MODEL_TYP_CDA';
   
99EOFSQLTEXT99

   db2 -stvxf $SQL_FILE_NAMEA >> $LOG_FILEA

   SQLCODE=$?
   
   if [[ $SQLCODE != 0 ]]; then
      print "Script " $SCRIPTNAMEA "failed in Update TALLOCATN_SCHEDULE to REQ_STAT = 'E'." >> $LOG_FILEA
      print "db2 return code is : <" $SQLCODE ">" >> $LOG_FILEA
      RETCODE=$SQLCODE
   fi
fi

if [[ $RETCODE != 0 ]]; then
    print "Failure in Script " $SCRIPT_NAMEA >> $LOG_FILEA
    print "TALLOCATN_SCHEDULE record REQ_STAT_CD is probably in limbo as 'R' " >> $LOG_FILEA 
    print "Return Code is : " $RETCODE >> $LOG_FILEA
    print `date` >> $LOG_FILEA
    cp -f $LOG_FILEA $LOG_ARCHA.`date +"%Y%j%H%M"`
else    
    print " " >> $LOG_FILEA
    print "....Completed executing " $SCRIPTNAMEA " ...."   >> $LOG_FILEA
    print `date` >> $LOG_FILEA
    mv -f $LOG_FILEA $LOG_ARCHA.`date +"%Y%j%H%M"`
fi

return $RETCODE


