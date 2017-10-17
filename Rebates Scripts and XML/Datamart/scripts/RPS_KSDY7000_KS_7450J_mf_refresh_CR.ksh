#!/usr/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_7450J_mf_refresh_views.ksh
# Title         : Refresh Mainframe KSCC tables from datamart 
#
# Description   : This script will refresh the Mainframe KSCC tables 
#                 from datamart local CR tables and views.
# 
# Abends        : If count parm does not match insert results then set bad 
#                 return code.
#                 
#
# Parameters    : None 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09-22-09   qcpi03o     Initial Creation.
# 09-01-12   qcpi0rb     Rebate changes CTID RPSDM
#                        to add new TABLES    
#                        KSCC100_CT_ID and KSCC105_RBAT_ID_CT_ID_ASSC      
# 
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

  cd $SCRIPT_PATH

#####################################################
# begin script functions
#
function Refresh_Table
#   usage: Refresh_Table |tablename|, returns return code 
{       
   typeset RC

   print "start mf_refresh_$1 "  `date` 
   print "start mf_refresh_$1 "  `date`                               >> $LOG_FILE 

   sqml $XML_PATH/mf_refresh_$1.xml                                    >> $LOG_FILE 
   RC=$?
   print "sqml retcode from mf_refresh_$1 was " $RC "   "`date` 
   print "sqml retcode from mf_refresh_$1 was " $RC "   "`date`        >> $LOG_FILE 
   return $RC
}

#
# end script functions
#####################################################

SCRIPT=RPS_KSDY7000_KS_7450J_mf_refresh_views
JOB=ks7450j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
RETCODE=0

echo $SCRIPT " start time: "`date` 
echo $SCRIPT " start time: "`date`                                     > $LOG_FILE


# refresh kscc030
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc030"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc031
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc031"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc040
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc040"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc041
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc041"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc042
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc042"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc043
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc043"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc044
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc044"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc045
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc045"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc046
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc046"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc047
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc047"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc200
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc200"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc213
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc213"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc214
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc214"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc215
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc215"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc218
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc218"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc220
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc220"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc210
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc210"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc100
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc100"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# refresh kscc105_rbat_id_ct_id_assc
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc105_rbat_id_ct_id_assc"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

echo $SCRIPT " end time: "`date`                                      
echo $SCRIPT " end time: "`date`                                       >> $LOG_FILE 

#
# send email for script errors
#
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                          >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   exit $RETCODE
fi


mv $LOG_FILE       $LOG_ARCH_PATH/ 
exit $RETCODE
