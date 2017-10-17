#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GD_1021J_TFRMLY_DRUG_PHC_load.ksh 
# Title         : vrap.TDRUG import process
#
# Description   : Loads vrap.TFRMLY_DRUG_PHC data file from PHC formulary file     
#
# Parameters    : None. 
#  
# Input         : TFRMLY_DRUG_PHC_LOAD.dat
# 
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 08-16-2007  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

SUBDIR="QLdata"
LOG_FILE="$LOG_PATH/GDX_GD_1021J_TFRMLY_DRUG_PHC_load.log"
SCRIPT=$(basename $0)
cp -f $LOG_FILE $LOG_ARCH_PATH/GDX_GD_1021J_TFRMLY_DRUG_PHC_load.log.`date +"%Y%j%H%M"`
rm -f $LOG_FILE

CALLED_SCRIPT="GDX_GD_1021J_TFRMLY_DRUG_PHC_load.ksh"
print "Starting " $CALLED_SCRIPT                    >> $LOG_FILE

prcs_id=$(. $SCRIPT_PATH/Common_Prcs_Log_Message.ksh "$0" "VRAP.TFRMLY_DRUG_PHC table load" "Starting $SCRIPT_PATH/GDX_GD_1021J_TFRMLY_DRUG_PHC_load.ksh UDB Load of VRAP.TFRMLY_DRUG_PHC table ") 
if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi

#OK_FILE="$INPUT_PATH/TFRMLY_DRUG_PHC_LOAD.ok"
DAT_FILE="$INPUT_PATH/TFRMLY_DRUG_PHC_LOAD.dat"
TRIGGER_FILE="$INPUT_PATH/TFRMLY_DRUG_PHC_LOAD.trigger"

ARCH_FILE=$INPUT_PATH/TFRMLY_DRUG_PHC_LOAD.old.`date +"%Y%j%H%M"`

print ".............Starting script $SCRIPT........  "     >> $LOG_FILE
print "  "     >> $LOG_FILE
print "Copying  $DAT_FILE to $ARCH_FILE  "     >> $LOG_FILE
cp -f $DAT_file $ARCH_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "  "     >> $LOG_FILE
   print "..The copy failed continuing to load" >> $LOG_FILE
   print "  "     >> $LOG_FILE
fi   


rm -f $TRIGGER_FILE

#################################################################################
#
# 1.  Check for File Existance 
#
#################################################################################


if [[ ! -s $DAT_FILE ]]; then         # is $myfile a regular file?
  print "Something wrong with/or missing input file $DAT_FILE  "     >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "Something wrong with/or missing input file $DAT_FILE "
     if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
  RETCODE=1
  return $RETCODE   
fi
  
#################################################################################
#
# ?.  empty the database table 
#
#################################################################################

SQL_STRING="import from /dev/null of del replace into VRAP.TFRMLY_DRUG_PHC "

print $SQL_STRING  >> $LOG_FILE 
db2 -stvxw $SQL_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the VRAP.TFRMLY_DRUG_PHC EMPTY step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the VRAP.TFRMLY_DRUG_PHC EMPTY step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi 
  
#################################################################################
#
# ?.  Set up the SQL and Connect to the Database 
#
#################################################################################

SQL_STRING="import from $DAT_FILE of del modified by coldel|,usedefaults commitcount 1000 warningcount 1 replace into VRAP.TFRMLY_DRUG_PHC "

###################################################################################
#
# Import PHC Formulary data with replace option into table 
# VRAP.TFRMLY_DRUG_PHC
#
#    NOTE:  Please note there is not SQL connect step.  The calls to the common process
#           logging establishes the DB2 connection for this process.  
#
###################################################################################

print $SQL_STRING  >> $LOG_FILE 
db2 -p $SQL_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the VRAP.TFRMLY_DRUG_PHC import step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the VRAP.TFRMLY_DRUG_PHC import step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi   

. $SCRIPT_PATH/Common_Prcs_End_Message.ksh "$prcs_id" ""
if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi

rm -f $DAT_FILE

print "....Completed executing " $CALLED_SCRIPT " ...."   >> $LOG_FILE

return $RETCODE
