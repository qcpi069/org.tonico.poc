#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_2000_GN_estimate.ksh
# Title         : back end job for PHC reporting
#                 Rebate Guarantee Calculation By Client Hierarchy
#
# Description   : This script will build ms_% tables for reporting:
#                 1. ms_gn_pricing_all	(pricing rules table)
#                 2. ms_rpt_gn_estimate (report table)
#
# Abends        : None
#
#
# Parameters    : inv_qtr - yyyyQQ
#
# Output        : Log file as RPS_KSOR9400_KS_2000_GN_estimate.$TIME_STAMP.log
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-30-2008   qcpi03o     Initial Creation.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR9400_KS_2000_GN_estimate.ksh
JOB=RPS_RPS_KSOR9400_KS_2000_GN_estimate
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
APPSCHEMA=rps
RETCODE=0

print " Starting script " $SCRIPT `date`
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

#   read inv_qtr to be reported
read INQPARM < $SCRIPT_PATH/APC.init
   export RETCODE=$?
print " input parm was: " $INQPARM
print " input parm was: " $INQPARM   >> $LOG_FILE

if [[ $RETCODE == 0 ]]; then
#   edit supplied parameter
    YEAR=`echo $INQPARM |cut -c 1-4`
    QTR=`echo $INQPARM |cut -c 6-6`
    if (( $YEAR > 1990 && $YEAR < 2050 )); then
      print ' using parameter YEAR of ' $YEAR
    else
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is yyyyQn.  Terminating script '
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is yyyyQn.  Terminating script '  >> $LOG_FILE
      export RETCODE=12
    fi
    if (( $QTR > 0 && $QTR < 5 )); then
      print ' using parameter QUARTER of ' $QTR
    else
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is yyyyQn. Terminating script '
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is yyyyQn. Terminating script ' >> $LOG_FILE
      export RETCODE=12
    fi

INQPARM=$YEAR"Q"$QTR

print ' build qparm ' $INQPARM                                             >> $LOG_FILE

else
   export RETCODE=12
   print "aborting script - having problem with APC.init file "
   print "usage: RPS_KSOR9400_KS_2000_GN_estimate.ksh (need APC.inti file)"
   print "aborting script - having problem with APC.init file "          >> $LOG_FILE
   exit $RETCODE
fi

print '*** collection quarter to be reported is ' $INQPARM
print '*** collection quarter to be reported is ' $INQPARM     >> $LOG_FILE

#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!! aborting  - cant connect to udb "
      print "!!! aborting  - cant connect to udb "   	               >> $LOG_FILE
   	exit $RETCODE
   fi
fi

if [[ $RETCODE == 0 ]]; then
	REPORTED=`db2 -x "select count(*) from $APPSCHEMA.ms_rpt_gn_estimate where INV_QTR='"$INQPARM"'"`
	if [[ $REPORTED -gt 0 ]]; then
		export RETCODE=12
      		print "!!! aborting  - collection quarter already reported "
      		print "!!! aborting  - collection quarter already reported "   	               >> $LOG_FILE
		exit $RETCODE
	fi
fi

#################################################################
# clean up the working table and rules tables
#################################################################
if [[ $RETCODE == 0 ]]; then
      print "*** clean up the pricing rules table "
      print "*** clean up the pricing rules table "            >> $LOG_FILE

	if [[ $RETCODE == 0 ]]; then
		db2 import from /dev/null of del replace into $APPSCHEMA.ms_gn_pricing_all >> $LOG_FILE
		export RETCODE=$?
	fi


   if [[ $RETCODE != 0 ]]; then
      print "!!! aborting  - having problem clean up pricing table "
      print "!!! aborting  - having problem clean up pricing table "            >> $LOG_FILE
	exit $RETCODE
   fi
fi

#################################################################
# build the invoice estimate table
#################################################################

if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_gn_pricing_all " `date`  
	print "*** start building ms_gn_pricing_all " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_gn_pricing_all.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_gn_pricing_all "
   print "!!!aborting - having problem to build ms_gn_pricing_all "     >> $LOG_FILE
   exit $RETCODE
fi


if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_rpt_gn_estimate " `date`  
	print "*** start building ms_rpt_gn_estimate " `date`            >> $LOG_FILE
	sqml --INQPARM $INQPARM $XML_PATH/ms_rpt_gn_estimate.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_rpt_gn_estimate "
   print "!!!aborting - having problem to build ms_rpt_gn_estimate "     >> $LOG_FILE
   exit $RETCODE
fi


#################################################################
# cleanup from successful run
#################################################################

print " Script " $SCRIPT " completed successfully on " `date`
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE

mv $LOG_FILE       $LOG_ARCH_PATH/

print "return_code =" $RETCODE
exit $RETCODE

