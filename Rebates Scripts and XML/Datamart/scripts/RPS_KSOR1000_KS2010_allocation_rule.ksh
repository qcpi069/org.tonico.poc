#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR1000_KS2010_allocation_rule.ksh
# Title         : back end job for distribution reporting
#                 Rebate Distribution Summary By Client/RAC
#                 Rebate Distribution Summary By Client Hierarchy
#
# Description   : This script will build ms_% tables for pricing rules:
#                 1. ms_gn_pricing_all	(rules table)
#                 2. ms_adv_W_gn	(rules table)
#                 3. ms_adv_W_inv	(rules table)
#
# Abends        : None
#
#
# Parameters    : 
#
# Output        : Log file as RPS_KSOR1000_KS2010_allocation_rule.log.$TIME_STAMP
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-30-2008   qcpi03o     Initial Creation.
# 04-07-2010   qcpi03o     split one batch into 3 jobs -
#                              KS2010 - building the pricing rules
#                              KS2020 - load distribution summary tables
#                              KS2030 - load hierarchy tables
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR1000_KS2010_allocation_rule.ksh
JOB=RPS_KSOR1000_KS2010_allocation_rule
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
APPSCHEMA=rps
RETCODE=0

print " Starting script " $SCRIPT `date`
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

     PRICING_RULE=$LOG_PATH/ms_gn_pricing.$TIME_STAMP
     ADV_RULE=$LOG_PATH/ms_adv_qtr.$TIME_STAMP

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


#################################################################
# clean up the rules tables
#################################################################
if [[ $RETCODE == 0 ]]; then
      print "*** clean up the rule tables "
      print "*** clean up the rule tables "            >> $LOG_FILE


	if [[ $RETCODE == 0 ]]; then
		db2 import from /dev/null of del replace into $APPSCHEMA.ms_gn_pricing_all >> $LOG_FILE
		export RETCODE=$?
	fi


	if [[ $RETCODE == 0 ]]; then
		db2 import from /dev/null of del replace into $APPSCHEMA.ms_adv_W_gn   >> $LOG_FILE
		export RETCODE=$?
	fi


	if [[ $RETCODE == 0 ]]; then
		db2 import from /dev/null of del replace into $APPSCHEMA.ms_adv_W_inv   >> $LOG_FILE
		export RETCODE=$?
	fi

   if [[ $RETCODE != 0 ]]; then
      print "!!! aborting  - having problem clean up tables "
      print "!!! aborting  - having problem clean up tables "                    >> $LOG_FILE
	exit $RETCODE
   fi
fi

#################################################################
# build the ms_% tables for pricing rules
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
	print "*** start building ms_adv_W_gn " `date`  
	print "*** start building ms_adv_W_gn " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_adv_w_gn_pricing.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_adv_W_gn "
   print "!!!aborting - having problem to build ms_adv_W_gn "     >> $LOG_FILE
   exit $RETCODE
fi

if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_adv_W_inv " `date`  
	print "*** start building ms_adv_W_inv " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_adv_w_invoic.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_adv_W_inv "
   print "!!!aborting - having problem to build ms_adv_W_inv "     >> $LOG_FILE
   exit $RETCODE
fi


#################################################################
# backup the rules used for the report
#################################################################

db2 -stvx "export to $PRICING_RULE of del select * from $APPSCHEMA.ms_gn_pricing_all  "
db2 -stvx "export to $ADV_RULE of del select * from $APPSCHEMA.ms_adv_w_inv  "


#################################################################
# cleanup from successful run
#################################################################

print " Script " $SCRIPT " completed successfully on " `date`
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE

mv $LOG_FILE       $LOG_ARCH_PATH/
mv $PRICING_RULE   $LOG_ARCH_PATH/
mv $ADV_RULE       $LOG_ARCH_PATH/

print "return_code =" $RETCODE
exit $RETCODE

