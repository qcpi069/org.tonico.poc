#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR1000_allocation_rpt.ksh
# Title         : back end job for PHC reporting
#                 Rebate Distribution Summary By Client/RAC
#                 Rebate Distribution Summary By Client Hierarchy
#                 Rebate Guarantee Calculation By Client Hierarchy
#
# Description   : This script will build ms_% tables for reporting:
#                 1. ms_chkln		(working table)
#                 2. ms_gn_pricing_all	(rules table)
#                 3. ms_adv_W_gn	(rules table)
#                 4. ms_adv_W_inv	(rules table)
#                 5. ms_rpt_header	(report table)
#                 6. ms_rpt_section1	(report table)
#                 7. ms_rpt_section2	(report table)
#                 8. ms_rpt_section3	(report table)
#                 9. ms_rpt_hierarchy	(report table)
#                 10. ms_rpt_hrcy_lkp	(report table)
#                 11. ms_rpt_gn_estimate (report table)
#
# Abends        : None
#
#
# Parameters    : prcs_nb to be reported
#
# Output        : Log file as RPS_KSOR1000_allocation_rpt.log.$TIME_STAMP
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

SCRIPT=RPS_KSOR1000_allocation_rpt.ksh
JOB=RPS_KSOR1000_allocation_rpt
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
APPSCHEMA=rps
RETCODE=0

print " Starting script " $SCRIPT `date`
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

if [[ $# -eq 1 ]]; then
#   read prcs_nb to be reported
	PRCS_NB=$1 
        PRICING_RULE=$LOG_PATH/ms_gn_pricing_$PRCS_NB.$TIME_STAMP
        ADV_RULE=$LOG_PATH/ms_adv_qtr_$PRCS_NB.$TIME_STAMP
else
   export RETCODE=12
   print "aborting script - required parameter not supplied "
   print "usage: RPS_KSOR1000_allocation_rpt.ksh prcs_nb"
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

if [[ $RETCODE == 0 ]]; then
	REPORTED=`db2 -x "select prcs_nb from rps.reported_process where prcs_nb="$PRCS_NB""`
	if [[ $REPORTED -gt 0 ]]; then
		export RETCODE=12
      		print "!!! aborting  - prcs_nb already reported "
      		print "!!! aborting  - prcs_nb already reported "   	               >> $LOG_FILE
		exit $RETCODE
	fi
fi

#################################################################
# clean up the working table and rules tables
#################################################################
if [[ $RETCODE == 0 ]]; then
      print "*** clean up the working table and rules tables "
      print "*** clean up the working table and rules tables "            >> $LOG_FILE

	if [[ $RETCODE == 0 ]]; then
		db2 import from /dev/null of del replace into $APPSCHEMA.ms_chkln  >> $LOG_FILE
		export RETCODE=$?
	fi

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
# build the ms_% tables
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

if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_rpt_header " `date`  
	print "*** start building ms_rpt_header " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_rpt_header.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_rpt_header "
   print "!!!aborting - having problem to build ms_rpt_header "     >> $LOG_FILE
   exit $RETCODE
fi

if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_rpt_section1 " `date`  
	print "*** start building ms_rpt_section1 " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_rpt_section1.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_rpt_section1 "
   print "!!!aborting - having problem to build ms_rpt_section1 "     >> $LOG_FILE
   exit $RETCODE
fi

if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_rpt_section2 " `date`  
	print "*** start building ms_rpt_section2 " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_rpt_section2.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_rpt_section2 "
   print "!!!aborting - having problem to build ms_rpt_section2 "     >> $LOG_FILE
   exit $RETCODE
fi

if [[ $RETCODE == 0 ]]; then
	print "*** start building ms_rpt_section3 " `date`  
	print "*** start building ms_rpt_section3 " `date`            >> $LOG_FILE
	sqml $XML_PATH/ms_rpt_section3.xml
        export RETCODE=$?
else
   export RETCODE=12
   print "!!!aborting - having problem to build ms_rpt_section3 "
   print "!!!aborting - having problem to build ms_rpt_section3 "     >> $LOG_FILE
   exit $RETCODE
fi

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
# backup the rules used for the report
#################################################################

db2 -stvx "export to $PRICING_RULE of del select * from $APPSCHEMA.ms_gn_pricing_all  "
db2 -stvx "export to $ADV_RULE of del select * from $APPSCHEMA.ms_adv_w_inv  "


#################################################################
# insert into table reported_process
#################################################################

db2 -stvx "insert into rps.reported_process values($PRCS_NB, current timestamp)"

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

