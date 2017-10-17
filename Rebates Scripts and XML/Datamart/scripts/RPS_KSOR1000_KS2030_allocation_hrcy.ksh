#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR1000_KS2030_allocation_hrcy.ksh
# Title         : back end job for distribution reporting
#                 Rebate Distribution Summary By Client Hierarchy
#
# Description   : This script will load ms_rpt_% tables for reporting:
#                 1. ms_chkln		(working table)
#                 2. ms_rpt_hierarchy	(report table)
#                 3. ms_rpt_hrcy_lkp	(report table)
#
# Abends        : None
#
# Parameters    : prcs_nb to be reported
#
# Dependency    : RPS_KSOR1000_KS2010_allocation_rule.ksh
#
# Output        : Log file as RPS_KSOR1000_KS2030_allocation_hrcy.log.$TIME_STAMP
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

SCRIPT=RPS_KSOR1000_KS2030_allocation_hrcy.ksh
JOB=RPS_KSOR1000_KS2030_allocation_hrcy
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
APPSCHEMA=rps
RETCODE=0

print " Starting script " $SCRIPT `date`
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

if [[ $# -eq 1 ]]; then
#   read prcs_nb to be reported
	PRCS_NB=$1 
else
   export RETCODE=12
   print "aborting script - required parameter not supplied "
   print "usage: RPS_KSOR1000_KS2030_allocation_hrcy.ksh prcs_nb"
   print "aborting script - required parameter not supplied "          >> $LOG_FILE
   exit $RETCODE
fi

print '*** prcs_nb to be reported is ' $PRCS_NB
print '*** prcs_nb to be reported is ' $PRCS_NB     >> $LOG_FILE

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
# clean up the working table 
#################################################################
if [[ $RETCODE == 0 ]]; then
      print "*** clean up the working table "
      print "*** clean up the working table "            >> $LOG_FILE

	if [[ $RETCODE == 0 ]]; then
		db2 import from /dev/null of del replace into $APPSCHEMA.ms_chkln  >> $LOG_FILE
		export RETCODE=$?
	fi

   if [[ $RETCODE != 0 ]]; then
      print "!!! aborting  - having problem clean up ms_chkln "
      print "!!! aborting  - having problem clean up ms_chkln "                    >> $LOG_FILE
	exit $RETCODE
   fi
fi

#################################################################
# build the working table ms_chkln
#################################################################
if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_chkln " `date`  
	print "*** start building ms_chkln " `date`            >> $LOG_FILE
	sqml --prcs_nb $PRCS_NB $XML_PATH/ms_build_chkln.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_chkln "
   print "!!!aborting - having problem to build ms_chkln "     >> $LOG_FILE
   exit $RETCODE
fi

#################################################################
# load into distribution hierarchy tables ms_rpt_%
#################################################################
if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_rpt_hierarchy " `date`  
	print "*** start building ms_rpt_hierarchy " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_rpt_hierarchy.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_rpt_hierarchy "
   print "!!!aborting - having problem to build ms_rpt_hierarchy "     >> $LOG_FILE
   exit $RETCODE
fi

if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_rpt_hrchy_lkp " `date`  
	print "*** start building ms_rpt_hrchy_lkp " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_rpt_hrchy_lkp.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_rpt_hrchy_lkp "
   print "!!!aborting - having problem to build ms_rpt_hrchy_lkp "     >> $LOG_FILE
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

