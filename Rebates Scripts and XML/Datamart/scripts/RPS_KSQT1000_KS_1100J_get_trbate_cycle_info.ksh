#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSQT1000_KS_1100J_get_trbate_cycle_info.ksh
# Title         : get the current dma_rbate2.t_rbate_cycle table from Silver. 
#                 
# Description   : This script will build 
#                 1. rps.TRBATE_CYCLE table
#                
#
# Abends        : None
#
# Parameters    : None
#
# Output        : Log file as .$TIME_STAMP.log
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-04-2008  is31701     Initial Creation.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=$0
JOB=RPS_KSQT1000_KS_1100J_get_trbate_cycle_info
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
RETCODE=0

print " Starting script " $SCRIPT `date`
print " Starting script " $SCRIPT `date`                               >> $LOG_FILE


# connect to udb
#
if [[ $RETCODE == 0 ]]; then
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!! aborting  - cant connect to udb "
      print "!!! aborting  - cant connect to udb "                     >> $LOG_FILE
   fi
fi


#################################################################
# clean up the tables
#################################################################

db2 import from /dev/null of del replace into rps.TRBATE_CYCLE      	>> $LOG_FILE
export RETCODE=$?

#################################################################
# build the tables
#################################################################

if [[ $RETCODE == 0 ]]; then
	print " start building TRBATE_CYCLE " `date`            	>> $LOG_FILE
        sqml  $XML_PATH/get_trbate_cycle_info.xml			>> $LOG_FILE
        export RETCODE=$?
else
   print "aborting script - clean up tables error  "     		>> $LOG_FILE
   exit $RETCODE
fi

#################################################################
# cleanup from successful run
#################################################################

if [[ $RETCODE == 0 ]]; then
	print " Script " $SCRIPT " completed successfully on " `date`
	print " Script " $SCRIPT " completed successfully on " `date`    >> $LOG_FILE
	print "return_code =" $RETCODE					 >> $LOG_FILE
	mv $LOG_FILE           $LOG_ARCH_PATH/
	
else
   export $RETCODE
   print "aborting script - error loading TRBATE_CYCLE "     	 	 >> $LOG_FILE
   exit $RETCODE
fi

exit $RETCODE

