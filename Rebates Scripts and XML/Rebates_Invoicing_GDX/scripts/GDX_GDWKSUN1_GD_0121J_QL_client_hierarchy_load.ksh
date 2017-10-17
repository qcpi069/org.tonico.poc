#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDWKSUN1_GD_0121J_QL_client_hierarchy_load.ksh
# Title         : Client data information load.
#
# Description   : Loads drug class data file from QL mainframe into the tables
#									VARP.TQL_CLT_PLAN_PB 
#									VRAP.TQL_PLAN_BNFT_LISt
#           
#
# Parameters    : None. 
# 
# Input         : gdx.vrap.tql_clt_plan_pb.dat                
# 
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-01-2006  S.  Hull    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

 . `dirname $0`/Common_GDX_Environment.ksh

SUBDIR="QLdata"
LOG_FILE="$LOG_PATH/GDX_GDWKSUN1_GD_0121J_QL_client_hierarchy_load.log"
SCRIPT=$(basename $0)

CALLED_SCRIPT=$SUBSYSTEM"QL_Client_Hierarchy_load.ksh"


prcs_id=$(./Common_Prcs_Log_Message.ksh "$0" "Client Hierarchy load"  "Starting $SCRIPT_PATH/GDX_GDWKSUN1_GD_0121J_QL_client_hierarchy_load.ksh UDB Load of vrap.TQL_plan_bnft_list vrap.tql_clt_plan_pb tables ")
if [[ $? != 0 ]]; then echo "Error: $LINENO  $?"; exit 1; fi


DAT_FILE="$INPUT_PATH/$SUBDIR/gdx.vrap.tql_clt_plan_pb.dat"
LOAD_FILE="$INPUT_PATH/$SUBDIR/LOADFILE.dat" 
TRAILER_REC="$INPUT_PATH/$SUBDIR/Trailer_Rec.dat" 
ARCH_DAT_FILE="$INPUT_PATH/$SUBDIR/gdx.vrap.tql_clt_plan_pb.old"

rm -f $LOAD_FILE
rm -f $TRAILER_REC
cp -f $LOG_FILE $LOG_ARCH_PATH/GDX_GDWKSUN1_GD_0121J_QL_client_hierarchy_load.log.`date +"%Y%j%H%M"`
rm -f $LOG_FILE
# copy input file to archive file.  
print "Archive Data file           " $ARCH_DAT_FILE  >> $LOG_FILE
print " " >>$LOG_FILE
print "Starting " $CALLED_SCRIPT                    >> $LOG_FILE



#################################################################################
#
# 1.  Check for File Existance 
#
#################################################################################

if [[ ! -s $DAT_FILE ]]; then         # is $myfile a regular file?
  print "Something wrong with/or missing input file $DAT_FILE  "     >> $LOG_FILE
   ./Common_Prcs_Error_Message.ksh "$prcs_id" "Something wrong with/or missing input file $DAT_FILE "
     if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
  RETCODE=1
  return $RETCODE   
fi


#################################################################################
#
# 2.  Split input file into input data and trailer files. 
#
#################################################################################

#echo `tail -0 $DAT_FILE > Trailer_Rec.dat`  #  use if no crlf at end of input file. 
echo `tail -1 $DAT_FILE > $TRAILER_REC`

#################################################################################
#
# 3.  Verify that the trailer record is present. 
#
#################################################################################

TRAILER_IND=`cut -c1-1 $TRAILER_REC`

if [[ $TRAILER_IND != "T" ]];then
   print "No Trailer record was found or was invalid .  Exiting Script" >> LOG_FILE
   RETCODE=1
   ./Common_Prcs_Error_Message.ksh "$prcs_id" "No Trailer record was found or was invalid .  Exiting Script "
    if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi   

#################################################################################
#
# 4.  Split input file into input data and trailer files. 
#
#################################################################################

integer flength=`cut -c51-61 $TRAILER_REC`
head -$flength  $DAT_FILE > $LOAD_FILE

#################################################################################
#
# 3.  Verify Trailer record counts against input data file record count. 
#
#################################################################################
integer LOADFILELENGTH=`wc -l $DAT_FILE | cut -f1 -d '/'` 
((LOADFILELENGTH = $LOADFILELENGTH - 1))   #  used to strip off carraige return line feed need to test with real ftp file!? 
echo "Length from control file: "  $flength     >> $LOG_FILE
echo "Length of Load file:    : "  $LOADFILELENGTH   >> $LOG_FILE
if (($flength != $LOADFILELENGTH ))then 
    print "Number or recs on input file length Does not match trailer record count "   >> $LOG_FILE
    ./Common_Prcs_Error_Message.ksh "$prcs_id" "Number or recs on input file length Does not match trailer record count. from control file:  $flength   Length of Load file:     $LOADFILELENGTH    "
    if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
    RETCODE=1
    return $RETCODE
fi    

#################################################################################
#
# 4.  Set up the SQL and Connect to the Database 
#
#################################################################################

SQL_STRING="import from $LOAD_FILE of asc "
SQL_STRING=$SQL_STRING"method L (1 9,10 18,19 27,68 71) " 
SQL_STRING=$SQL_STRING"commitcount 10000 "
SQL_STRING=$SQL_STRING" replace into vrap.tql_clt_plan_pb " 
SQL_STRING=$SQL_STRING"(CLT_ID, "
SQL_STRING=$SQL_STRING"PLAN_BNFT_LIST_ID, "
SQL_STRING=$SQL_STRING"PB_ID, "
SQL_STRING=$SQL_STRING"DLVRY_SYS_CD) " 

SQL_STRING1="import from $LOAD_FILE of asc "
SQL_STRING1=$SQL_STRING1"method L (10 18,28 67) " 
SQL_STRING1=$SQL_STRING1"commitcount 10000 "
SQL_STRING1=$SQL_STRING1" insert_update into vrap.TQL_plan_bnft_list " 
SQL_STRING1=$SQL_STRING1"(PLAN_BNFT_LIST_ID, "
SQL_STRING1=$SQL_STRING1"PLAN_BNFT_LIST_NM)" 


###################################################################################
#
# 5.  Import drug class data with replace option into table  vrap.TQL_plan_bnft_list
#    
#
#    NOTE:  Please note there is not SQL connect step.  The calls to the common process
#           logging establishes the DB2 connection for this process.   
###################################################################################

print $SQL_STRING  >> $LOG_FILE 
db2 -p $SQL_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the 1st import step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   ./Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the 1st import step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi   

###################################################################################
#
# 6.  Import drug class data with replace option into staging/work table vrap.tql_clt_plan_pb
#     
#
###################################################################################

print $SQL_STRING1  >> $LOG_FILE 
db2 -p $SQL_STRING1 >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in 2nd the import step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   ./Common_Prcs_Error_Message.ksh "$prcs_id" "$CALLED_SCRIPT  failed in the 2nd import step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   return $RETCODE
fi   

print "....Completed executing " $CALLED_SCRIPT " ...."   >> $LOG_FILE


./Common_Prcs_End_Message.ksh "$prcs_id" ""
if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi

cp $DAT_FILE $ARCH_DAT_FILE
if [[ $? == 0 ]]; then 
    rm -f $DAT_FILE  
fi

return $RETCODE
