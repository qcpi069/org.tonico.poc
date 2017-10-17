#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSQT1000_KS_1110J_load_tdrug_finund_calc.ksh
# Title         : Get the EDW Drug information required for the 
#          TAPC_FINUND_RESULTS DM Table
#                 
# Description   : This script will build the
#                 1. TDRUG_FINUND_CALC table
#         2. TMAIL_SPCLTY_NABP table
#         3. TPHMCY_CHAIN_CODES table
#                
#
# Abends        : None
#
#
# Parameters    : The quarter end date + 1 day can be passed in to build this table 
#                 for a previous period. The format must be MM/DD/YYYY
#
# Output        : Log file as .$TIME_STAMP.log
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-29-09     qcpi733   Added GDX APC status update
# 03-05-2008   is31701   Initial Creation.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=$0
JOB=RPS_KSQT1000_KS_1110J_load_tdrug_finund_calc
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
RETCODE=0

print " Starting script " $SCRIPT `date`
print " Starting script " $SCRIPT `date`                                       >> $LOG_FILE

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 STRT                          >> $LOG_FILE

# If a previous period is requested, parameter should be end of the quarter + 1 day
# Format required is MM/DD/YYYY
if [[ $# -eq 1 ]]; then
    QTRENDDT=$1
    print "quarter end date + 1 day parameter supplied. It is " $QTRENDDT       >> $LOG_FILE 
else
    print "quarter end date parameter not supplied. It will be calculated "     >> $LOG_FILE
fi


##################################################################
# connect to udb
##################################################################

if [[ $RETCODE == 0 ]]; then
   $UDB_CONNECT_STRING                                                         >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!! aborting  - cant connect to udb "
      print "!!! aborting  - cant connect to udb "                             >> $LOG_FILE
   fi
fi


#################################################################
# clean up the tables
#################################################################

db2 import from /dev/null of del replace into rps.TDRUG_FINUND_CALC            >> $LOG_FILE
RETCODE=$?

#################################################################
# build the tables
#################################################################

if [[ $RETCODE == 0 ]]; then
  if [[ $# -eq 1 ]]; then
    print " start building TDRUG_FINUND_CALC with end date " $QTRENDDT         >> $LOG_FILE
    sqml --qtrenddt $QTRENDDT $XML_PATH/build_edw_drug_price_info.xml          >> $LOG_FILE
  else 
        print " start building TDRUG_FINUND_CALC without parm override "       >> $LOG_FILE     
        sqml  $XML_PATH/build_edw_drug_price_info.xml                          >> $LOG_FILE
  fi            
  RETCODE=$?
else
    print "aborting script - clean up tables error "
    print "aborting script - clean up tables error  "                          >> $LOG_FILE

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 ERR                        >> $LOG_FILE

    exit $RETCODE
fi

#################################################################
# now calculate the whn_calc_ratio
#################################################################
                    
 updtsql="MERGE INTO rps.TDRUG_FINUND_CALC tsc
        using
       (SELECT b.brand_name, coalesce((DECIMAL(a.whn,11,4) / DECIMAL(a.awp,11,4)),(8.3333)) as ratio
        FROM rps.TDRUG_FINUND_CALC b LEFT OUTER JOIN
       (SELECT brand_name, AVG(awp) AS awp, AVG(whn) AS whn
          FROM rps.TDRUG_FINUND_CALC
         WHERE awp != 0
           AND whn != 0
       GROUP BY brand_name) a
       ON   b.brand_name = a.brand_name
       GROUP BY b.brand_name, coalesce((DECIMAL(a.whn,11,4) / DECIMAL(a.awp,11,4)),(8.3333))) z
  on tsc.brand_name = z.brand_name
  WHEN MATCHED THEN
 UPDATE SET tsc.whn_calc_ratio =  z.ratio"


if [[ $RETCODE == 0 ]]; then    
   print `date`" Updating the whn_calc_ratio on TDRUG_FINUND_CALC "
   print `date`" Updating the whn_calc_ratio on TDRUG_FINUND_CALC "            >> $LOG_FILE
                             
   db2 -px $updtsql                                                            >> $LOG_FILE

   RETCODE=$?

   if [[ $RETCODE != 0 ]]; then     
    print `date`" db2 error Updating the whn_calc_ratio - retcode: "$RETCODE
    print `date`" db2 error Updating the whn_calc_ratio - retcode: "$RETCODE   >> $LOG_FILE
    #Call the APC status update
    . `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 ERR                       >> $LOG_FILE

    exit $RETCODE
   else
        print `date`" db2 Update to the whn_calc_ratio was successful "
    print `date`" db2 Update to the whn_calc_ratio was successful "            >> $LOG_FILE
   fi
fi 

#################################################################
# now load the TMAIL_SPCLTY_NABP table
#################################################################

   db2 import from /dev/null of del replace into rps.TMAIL_SPCLTY_NABP         >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then     
      print `date`" error truncating the TMAIL_SPCLTY_NABP table - retcode: "$RETCODE 
      print `date`" error truncating the TMAIL_SPCLTY_NABP table - retcode: "$RETCODE >> $LOG_FILE
      #Call the APC status update
      . `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 ERR                     >> $LOG_FILE

      exit $RETCODE
   else
      print `date`" truncation of the TMAIL_SPCLTY_NABP table was successful"  >> $LOG_FILE
      print " start building TMAIL_SPCLTY_NABP table "                         >> $LOG_FILE     
      sqml  $XML_PATH/get_tmail_spclty_nabp_info.xml                           >> $LOG_FILE
      RETCODE=$?
   fi


 if [[ $RETCODE != 0 ]]; then     
   print `date`" error refreshing the TMAIL_SPCLTY_NABP table - retcode: "$RETCODE 
   print `date`" error refreshing the TMAIL_SPCLTY_NABP table - retcode: "$RETCODE >> $LOG_FILE

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 ERR                        >> $LOG_FILE

   exit $RETCODE
else
   print `date`" refresh of the TMAIL_SPCLTY_NABP table was successful "
   print `date`" refresh of the TMAIL_SPCLTY_NABP table was successful "       >> $LOG_FILE
fi

#################################################################
# now load the TPHMCY_CHAIN_CODES table
#################################################################

   db2 import from /dev/null of del replace into rps.TPHMCY_CHAIN_CODES        >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then     
      print `date`" error truncating the TPHMCY_CHAIN_CODES table - retcode: "$RETCODE 
      print `date`" error truncating the TPHMCY_CHAIN_CODES table - retcode: "$RETCODE >> $LOG_FILE
      #Call the APC status update
      . `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 ERR                     >> $LOG_FILE

      exit $RETCODE
   else
      print `date`" truncation of the TPHMCY_CHAIN_CODES table was successful" >> $LOG_FILE
      print " start building TPHMCY_CHAIN_CODES table "                        >> $LOG_FILE     
      sqml  $XML_PATH/get_phmcy_chain_codes.xml                                >> $LOG_FILE
      RETCODE=$?
   fi

if [[ $RETCODE != 0 ]]; then     
   print `date`" error refreshing the TPHMCY_CHAIN_CODES table - retcode: "$RETCODE 
   print `date`" error refreshing the TPHMCY_CHAIN_CODES table - retcode: "$RETCODE >> $LOG_FILE

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 ERR                        >> $LOG_FILE

   exit $RETCODE
else
   print `date`" refresh of the TPHMCY_CHAIN_CODES table was successful "
   print `date`" refresh of the TPHMCY_CHAIN_CODES table was successful "      >> $LOG_FILE
fi

#################################################################
# cleanup from successful run
#################################################################

if [[ $RETCODE == 0 ]]; then
    print " Script " $SCRIPT " completed successfully on " `date`
    print " Script " $SCRIPT " completed successfully on " `date`              >> $LOG_FILE
    print "return_code =" $RETCODE                      >> $LOG_FILE
    
    #Call the APC status update
    . `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 END                       >> $LOG_FILE

    mv $LOG_FILE           $LOG_ARCH_PATH/
    
else
   print "aborting script - error loading TDRUG_SQLSUMMARY_CALC "              >> $LOG_FILE

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 290 ERR                        >> $LOG_FILE

   exit
fi

exit $RETCODE

