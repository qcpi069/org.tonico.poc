#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_TAPC_DETAIL_Set_Integrity.ksh 
# Title         : Set Integrity
# Description   : This script call the 'set integrity' command for the table listed
#         in the APC.init file.  This is to release any constaints that are on the table after 
#         the APC load
#                 quarterly invoice data.
# 
# Abends        : 
#                                 
# Output        : Log file as $LOGFILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-28-09   qcpi733     Added GDX APC status update
# 07-06-09   qcpi19v     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_BASE=$FILE_BASE".log"
LOG=$LOG_BASE"."`date +"%Y%j%H%M"`
LOGFILE="$LOG_PATH/$LOG"
ARCH_LOGFILE="$LOG_ARCH_PATH/$LOG"
QPARM=
RETCODE=0

APC_INIT=./APC.init

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOGFILE

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 210 STRT                          >> $LOG_FILE

################################################################
# 1) Read Quarter parameter  yyyyQn from APC.init file
################################################################
if [[ ! -f $APC_INIT ]]; then
      print "aborting script - required file " $APC_INIT " is not present " 
      print "aborting script - required file " $APC_INIT " is not present "    >> $LOGFILE  
      export RETCODE=12
else
    read QPARM < $APC_INIT
fi


################################################################
# 8) connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOGFILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "            >> $LOGFILE  
   fi
fi

################################################################
# 10) clear check constraint from load
################################################################
if [[ $RETCODE == 0 ]]; then    
      print " validating check constraint after load "
      print " validating check constraint after load "   >> $LOGFILE
      db2 -stvx set integrity for $SCHEMA.TAPC_DETAIL_$QPARM immediate checked    >> $LOGFILE 
      export RETCODE=$?
      if [[ $RETCODE != 0 ]]; then     
    print `date`" db2 constraint validation error - retcode: "$RETCODE
    print `date`" db2 constraint validation error - retcode: "$RETCODE   >> $LOGFILE
      else
        print `date`" db2 load constraint validation was successful "
    print `date`" db2 load constraint validation was successful "   >> $LOGFILE
      fi
fi


################################################################
# Z) disconnect from udb
################################################################
db2 -stvx connect reset                                                >> $LOGFILE 
db2 -stvx quit                                                         >> $LOGFILE 


#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                               >> $LOGFILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOGFILE
   print "return_code =" $RETCODE

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 210 ERR                  >> $LOG_FILE

   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOGFILE 

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 210 END                     >> $LOG_FILE

#################################################################
# cleanup from successful run
#################################################################
mv $LOGFILE       $ARCH_LOGFILE/ 

print "return_code =" $RETCODE

exit $RETCODE
