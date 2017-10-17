#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_DrugClass_load_and_report_counts.ksh   
# Title         : Drug class import process
#
# Description   : Loads drug class data file from QL mainframe into the staging 
#                 table VRAP.TWORK_DRUG_CLS_GPO(DSC).
#                 Sends an email to the users with counts in the control report 
#                 from QL mainframe and counts from table VRAP.TWORK_DRUG_CLS_GDO(DSC).
#                 Even though it does not require explicit parameters, it expects the
#                 calling scripts to set & export variables SCHEDULE, JOB, FILE_BASE & MODEL
#          
#
# Parameters    : None. 
#                 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 08-31-2012 QCPI0N7      Removed the group of EMAIL ID's for Update Drug Class Details
#			    GDXGPOOps@caremark.com, GDXXMDOps@caremark.com, dennis.render@caremark.com
#			    carol.brennan@caremark.com, elizabeth.alaimo@caremark.com
# 08-14-2012 QCPI0N7      Removed the Hardcoded global variables
#                         i.e) CONNECT_ID, CONNECT_PWD AND EMAIL_ADDRESS
# 03-05-2005  S. Antari   Initial Creation.
#                         Even though this script is buit for both models,
#                         initially it will be used only for GPO model.
#
#-------------------------------------------------------------------------#

CALLED_SCRIPT=$SUBSYSTEM"load_and_report_counts.ksh"
print "Starting " $CALLED_SCRIPT                    >> $LOG_FILE

DAT_FILE="$INPUT_PATH/$SUBDIR/vrap.twork_drug_cls_$MODEL.dat"
print "Data file                   " $DAT_FILE       >> $LOG_FILE

ARCH_DAT_FILE="$INPUT_ARCH_PATH/$SUBDIR/vrap.twork_drug_cls_$MODEL.dat.$TIME_STAMP"
print "Archive Data file           " $ARCH_DAT_FILE  >> $LOG_FILE

CTRL_FILE="$INPUT_PATH/$SUBDIR/drug_class_control_$MODEL.dat"
print "Control totals file         " $CTRL_FILE      >> $LOG_FILE

ARCH_CTRL_FILE="$INPUT_ARCH_PATH/$SUBDIR/drug_class_control.dat.$TIME_STAMP"
print "Archive Control totals file " $ARCH_CTRL_FILE >> $LOG_FILE

TRG_FILE="$INPUT_PATH/$SUBDIR/vrap.twork_drug_cls_$MODEL.trg"
print "Trigger file                " $TRG_FILE       >> $LOG_FILE

TMP_DIR="$OUTPUT_PATH/$SUBDIR/tmp"
print "Temporary files directory   " $TMP_DIR        >> $LOG_FILE

UDB_MSG_FILE="$TMP_DIR/vrap.twork_drug_cls_$MODEL.msg"
print "UDB message file            " $UDB_MSG_FILE   >> $LOG_FILE

if [[ $REGION = "prod" ]];   then
   MAILTO="GDXITD@caremark.com, jim.dixon@caremark.com, pete.catsaros@caremark.com, jeff.fanale@caremark.com "
   SOX_ARCH_DIR="/mda/Sarbanes_Oxley_ControlReports"
else
   MAILTO="shyam.antari@caremark.com, trish.moloney@caremark.com"
   SOX_ARCH_DIR="/user/qcpi567/mda/Sarbanes_Oxley_ControlReports"
fi 


rm -f $UDB_MSG_FILE
rm -f $TRG_FILE

print '**********************************************************' >>$LOG_FILE 
export SQL_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" >> $LOG_FILE
print '**********************************************************' >>$LOG_FILE 

db2 -p $SQL_CONNECT_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the DB CONNECT." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">"                >> $LOG_FILE
   exit	
fi   

###################################################################################
#
# Import drug class data with replace option into staging/work table 
# vrap.twork_drug_cls_$MODEL
#
###################################################################################
SQL_STRING="import from $DAT_FILE of asc "
SQL_STRING=$SQL_STRING"method L (1 11,14 43,46 55,58 87,90 94,96 102) " 
SQL_STRING=$SQL_STRING"commitcount 10000 "
SQL_STRING=$SQL_STRING"messages $UDB_MSG_FILE " 
SQL_STRING=$SQL_STRING"replace into vrap.twork_drug_cls_$MODEL " 
SQL_STRING=$SQL_STRING"(DRUG_NDC_ID, "
SQL_STRING=$SQL_STRING"DRUG_NM, "      
SQL_STRING=$SQL_STRING"DRUG_CLASS_ID, "     
SQL_STRING=$SQL_STRING"DRUG_CLASS_NM, "    
SQL_STRING=$SQL_STRING"NHU_TYP_CD, "   
SQL_STRING=$SQL_STRING"DRUG_PKG_SIZE_QTY)"

print $SQL_STRING  >> $LOG_FILE 
db2 -p $SQL_STRING >> $LOG_FILE

RETCODE=$?
cat $UDB_MSG_FILE  >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the import step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   return $RETCODE
fi   

####################################################################
#
#  After the staging table is loaded, an email is sent to the users
#  with the counts from the staging table and the counts from 
#  drug class control report file from mainframe
#
####################################################################

WORK_TBL_CTRL_FILE="$OUTPUT_PATH/$SUBDIR/work_table_control_$MODEL"
ARCH_WORK_TBL_CTRL_FILE="$OUTPUT_ARCH_PATH/$SUBDIR/work_table_control_$MODEL.$TIME_STAMP"


#################################################################################
#
#   queries for counts from vrap.twork_drug_cls_$MODEL  
#
#################################################################################
SQL_DRUG_CLASS_COUNT="select count(distinct drug_class_id) as TOTAL_DRUG_CLASSES from vrap.twork_drug_cls_$MODEL "
print "SQL_DRUG_CLASS_COUNT " $SQL_DRUG_CLASS_COUNT               >> $LOG_FILE

SQL_ROW_COUNT="select count(*) as TOTAL_ROW_COUNT from vrap.twork_drug_cls_$MODEL " 
print "SQL_ROW_COUNT " $SQL_ROW_COUNT                             >> $LOG_FILE

SQL_DRUG_CLASSES="select distinct drug_class_id as DRUG_CLASSES_PULLED from vrap.twork_drug_cls_$MODEL " 
print "SQL_DRUG_CLASSES " $SQL_DRUG_CLASSES                       >> $LOG_FILE

SQL_ROW_COUNT_BY_DRUG_CLASS="select drug_class_id, count(*) as drug_count from vrap.twork_drug_cls_$MODEL group by drug_class_id " 
print "SQL_ROW_COUNT_BY_DRUG_CLASS " $SQL_ROW_COUNT_BY_DRUG_CLASS >> $LOG_FILE

#################################################################################
#
#   Run queries to obtain counts from vrap.twork_drug_cls_$MODEL
#
#################################################################################
db2 $SQL_DRUG_CLASS_COUNT         > $TMP_DIR/totdrgcls_$MODEL
cat $TMP_DIR/totdrgcls_$MODEL    >> $LOG_FILE

db2 $SQL_ROW_COUNT                > $TMP_DIR/rowcount_$MODEL
cat $TMP_DIR/rowcount_$MODEL     >> $LOG_FILE

db2 $SQL_DRUG_CLASSES             > $TMP_DIR/drug_classes_$MODEL
cat $TMP_DIR/drug_classes_$MODEL >> $LOG_FILE

db2 $SQL_ROW_COUNT_BY_DRUG_CLASS  > $WORK_TBL_CTRL_FILE
cat $WORK_TBL_CTRL_FILE          >> $LOG_FILE

db2 "terminate"                  >> $LOG_FILE


#################################################################################
#
#   Grab Counts from last line of Control Report
#
#################################################################################
   tail -1 $CTRL_FILE|cut -f1 -d","|read drgclscnt
   echo "drgclscnt: " $drgclscnt >> $LOG_FILE

   tail -1 $CTRL_FILE|cut -f2 -d","|read drugcount
   echo "drugcount: " $drugcount >> $LOG_FILE

#################################################################################
#
#   Create message to be sent via email containing Control Report Counts versus 
#   Counts obtained from vrap.twork_drug_cls_$MODEL table.
#
#################################################################################
EMAIL_BODY=$TMP_DIR/email_body_$MODEL

   echo "******************************************************" >  $EMAIL_BODY
   echo "*MAINFRAME to GDX `echo $MODEL |tr [a-z] [A-Z]` DRUG CLASS LOAD RECONCILIATION *" >> $EMAIL_BODY
   echo "*                                                    *" >> $EMAIL_BODY
   echo "*                Counts must Balance                 *" >> $EMAIL_BODY
   echo "*                                                    *" >> $EMAIL_BODY
   echo "******************************************************" >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   echo "These are the counts from the DRVEB020 control report extracted from MAINFRAME:" >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   echo "TOTAL_DRUG_CLASSES"                                     >> $EMAIL_BODY
   echo "------------------"                                     >> $EMAIL_BODY
   echo "             " $drgclscnt                               >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   echo "TOTAL_ROW_COUNT"                                        >> $EMAIL_BODY
   echo "---------------"                                        >> $EMAIL_BODY
   echo "       " $drugcount                                     >> $EMAIL_BODY

   echo ""                                                       >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   echo "These are the counts from the VRAP.TWORK_DRUG_CLASS_`echo $MODEL |tr [a-z] [A-Z]` table loaded to GDX:" >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   head -4 $TMP_DIR/totdrgcls_$MODEL                             >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   head -4 $TMP_DIR/rowcount_$MODEL                              >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   echo ""                                                       >> $EMAIL_BODY
   cat $TMP_DIR/drug_classes_$MODEL                              >> $EMAIL_BODY
  
   cat $EMAIL_BODY                                               >> $LOG_FILE


#################################################################################
#
#   Mail to GDX users
#
#################################################################################
   mail -s "`echo $REGION |tr [a-z] [A-Z]`: `echo $MODEL |tr [a-z] [A-Z]` Drug Class Counts" $MAILTO < $EMAIL_BODY


#################################################################################
#
#   Add timestamp to data, drug class control & work control file 
#   and move them to archive directory.           
#
#################################################################################
   mv $DAT_FILE           $ARCH_DAT_FILE 
   mv $CTRL_FILE          $ARCH_CTRL_FILE 
   mv $WORK_TBL_CTRL_FILE $ARCH_WORK_TBL_CTRL_FILE

   
#################################################################################
#
#   Copy control report from Mainframe and staging table contents to 
#   Sarbanes Oxley Control reports directory.
#
#################################################################################
   cp $ARCH_CTRL_FILE          $SOX_ARCH_DIR 
   cp $ARCH_WORK_TBL_CTRL_FILE $SOX_ARCH_DIR
   

#################################################################################
#
#    Compress data and Control Report files in archive directory
#
#################################################################################
   compress $ARCH_DAT_FILE           >> $LOG_FILE
   compress $ARCH_CTRL_FILE          >> $LOG_FILE
   compress $ARCH_WORK_TBL_CTRL_FILE >> $LOG_FILE


print "....Completed executing " $CALLED_SCRIPT " ...."   >> $LOG_FILE

return $RETCODE


