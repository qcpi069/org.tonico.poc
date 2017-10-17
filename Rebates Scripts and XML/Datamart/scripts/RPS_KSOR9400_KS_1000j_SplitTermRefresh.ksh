#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_1000j_SplitTermRefresh.ksh
# Title         : ondemand Split Term tables refresh
# Description   : This script will refresh the following datamart tables
#		  from Client Reg:
#			rbate_reg.rebate_splits
#			rbate_reg.split_tier_assign
#			rbate_reg.split_level
#		  then the following Payments split term tables
#		  will be refreshed:
#                       kscc013
#                       kscc017
#                       kscc012
#                 This script will be kicked off through Unix request.
#			the refresh is a full replace.
#
# Abends        :
#
# Parameters    : none
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-08-08   qcpi03o     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=$0
JOB=$(echo $0|awk -F. '{print $1}')
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0


print " Starting script " $SCRIPT `date`
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

################################################################
# 1) connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!! terminating script - cant connect to udb "
      print "!!! terminating script - cant connect to udb "            >> $LOG_FILE
        exit $RETCODE
   fi
fi


################################################################
# 2) truncate datamart split term tables
################################################################

if [[ $RETCODE == 0 ]]; then
   db2 "import from /dev/null of del replace into rbate_reg.rebate_splits" 	>> $LOG_FILE
   export RETCODE=$?
fi

if [[ $RETCODE == 0 ]]; then
   db2 "import from /dev/null of del replace into rbate_reg.split_tier_assign"	>> $LOG_FILE
   export RETCODE=$?
fi

if [[ $RETCODE == 0 ]]; then
   db2 "import from /dev/null of del replace into rbate_reg.split_level"	>> $LOG_FILE
   export RETCODE=$?
fi


################################################################
# 3) Refresh datamart split term tables
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting refresh rbate_reg.rebate_splits " `date`                                >> $LOG_FILE

   sqml $XML_PATH/dm_refresh_rebate_splits.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error refresh table rbate_reg.rebate_splits "                 >> $LOG_FILE
   fi
fi

if [[ $RETCODE == 0 ]]; then
   print " Starting refresh rbate_reg.split_tier_assign " `date`                                >> $LOG_FILE

   sqml $XML_PATH/dm_refresh_split_level.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error refresh table rbate_reg.split_tier_assign "                 >> $LOG_FILE
   fi
fi

if [[ $RETCODE == 0 ]]; then
   print " Starting refresh rbate_reg.split_level " `date`                                >> $LOG_FILE

   sqml $XML_PATH/dm_refresh_split_tier_assign.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error refresh table rbate_reg.split_level "                 >> $LOG_FILE
   fi
fi


################################################################
# 4) Refresh Payments split term tables
################################################################

if [[ $RETCODE == 0 ]]; then
   print " Starting refresh kscc013 " `date`                                >> $LOG_FILE

   sqml $XML_PATH/mf_refresh_kscc013.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error refresh table kscc013 "                 >> $LOG_FILE
   fi
fi

if [[ $RETCODE == 0 ]]; then
   print " Starting refresh kscc017 " `date`                                >> $LOG_FILE

   sqml $XML_PATH/mf_refresh_kscc017.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error refresh table kscc017 "                 >> $LOG_FILE
   fi
fi

if [[ $RETCODE == 0 ]]; then
   print " Starting refresh kscc012 " `date`                                >> $LOG_FILE

   sqml $XML_PATH/mf_refresh_kscc012.xml
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error refresh table kscc012 "                 >> $LOG_FILE
   fi
fi


################################################################
# zz) disconnect from udb
################################################################
db2 -stvx connect reset                                                >> $LOG_FILE
db2 -stvx quit                                                         >> $LOG_FILE



#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then
   print "aborting $SCRIPT due to errors "
   print "aborting $SCRIPT due to errors "                               >> $LOG_FILE
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE
      exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE

#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/

exit $RETCODE

