#!/usr/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSWK7000_KS_7300J_dm_refresh_client.ksh
# Title         : Weekly refresh of large Datamart tables
#
# Description   : This weekly script will refresh the Datamart client reg  
#                 and misc tables using various mechanisms.
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
# 11-01-05   qcpi768     Initial Creation.
# 09-23-09   qcpi03o     updated for CR rewrite project
#                        removed step for performance_rx refresh
#                        removed step for formulary refresh
#                        moved step for cg_lcm_assoc refresh to 7400J
#                        updated step for tdrug refresh to pull from EDW
#			 updated step for crt_enrl refresh from GDX to DM
#			 added step for kscc011 refresh from DM to Payments
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
   db2 -stvx import from /dev/null of del replace into $CLIENT_SCHEMA.$1  >> $LOG_FILE 
   RC=$?
   if [[ $RC != 0 ]]; then 
	print " db2 import error truncating table "$1 
	print " db2 import error truncating table "$1                  >> $LOG_FILE
	return $RC
   fi
   print "start dm_refresh_$1 "`date` 
   print "start dm_refresh_$1 "`date`                                  >> $LOG_FILE 
   sqml $XML_PATH/dm_refresh_$1.xml                                    >> $LOG_FILE 
   RC=$?
   print "retcode from dm_refresh_$1 " $RC "   "`date` 
   print "retcode from dm_refresh_$1 " $RC "   "`date`                 >> $LOG_FILE 
   return $RC
}


function Reload_Table
#   usage: Reload_Table |tablename| returns return code 
#    SEL_STMT=|select stmt|, LOD_STMT=|load stmt|
{       
   typeset RC
   print "start dm_reload_"$1" "`date` 
   print "start dm_reload_"$1" "`date`  >> $LOG_FILE 

#  export from oracle to file
   ORA_SQL_FILE=$TMP_PATH/$JOB.ora
   SQL_DATA_FILE=$TMP_PATH/$JOB.$1.dat
   cat > $ORA_SQL_FILE << EOF
   set LINESIZE 200
   set TERMOUT OFF
   set PAGESIZE 0
   set NEWPAGE 0
   set SPACE 0
   set ECHO OFF
   set FEEDBACK OFF
   set HEADING OFF
   set WRAP off
   set verify off
   whenever sqlerror exit 1
   SPOOL $SQL_DATA_FILE
   alter session enable parallel dml; 
   $SEL_STMT 
   quit;
EOF
   print "********* SQL File for "$1" is **********"  >> $LOG_FILE 
   cat $ORA_SQL_FILE                                  >> $LOG_FILE
   print "********* SQL File for "$1" end *********"  >> $LOG_FILE    
   $ORA_CONNECT_STRING @$ORA_SQL_FILE
   RC=$?
   if (( $RC != 0 )) ; then 
       print 'ORACLE SELECTION SQL FAILED - RC is ' $RC ' error message is: ' `tail -20 $SQL_DATA_FILE` 
       print 'ORACLE SELECTION SQL FAILED - RC is ' $RC ' error message is: '  >> $LOG_FILE 
       print ' '                                                >> $LOG_FILE 
       tail -20 $SQL_DATA_FILE                                  >> $LOG_FILE
   else
       print 'ORACLE SELECTION of '$1' successful RC = ' $RC `date`  
       print 'ORACLE SELECTION of '$1' successful RC = ' $RC `date`      >> $LOG_FILE 
   fi 
#  import to udb from file
   if [[ $RC == 0 ]]; then
      print " starting db2 load of "$1
      print " starting db2 load of "$1                   >> $LOG_FILE
      db2 -stvx load from $SQL_DATA_FILE $LOD_STMT  >> $LOG_FILE 
      RC=$?
      if [[ $RC != 0 ]]; then 
	print " db2 import error on "$1" - retcode: "$RC
	print " db2 import error on "$1" - retcode: "$RC   >> $LOG_FILE
      else
        rm -f $SQL_DATA_FILE
      fi
   fi
   print "end dm_reload_"$1" "`date` 
   print "end dm_reload_"$1" "`date`                            >> $LOG_FILE
   return $RC
}

#
# end script functions
#####################################################

SCRIPT=RPS_KSWK7000_KS_7300J_dm_refresh_client
JOB=ks7300j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
TBLNAME=
SEL_STMT=
LOD_STMT=
RETCODE=0

echo $SCRIPT " start time: "`date` 
echo $SCRIPT " start time: "`date`                                     > $LOG_FILE

#
# check status of source database before proceeding
#
sqml $XML_PATH/dm_refresh_chkstat.xml                                 >> $LOG_FILE
export RETCODE=$?
print "retcode from dm_refresh_chkstat " $RETCODE
print "retcode from dm_refresh_chkstat " $RETCODE             >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then 
   print "aborting dm_refresh due to errors " 
   print "aborting dm_refresh due to errors "                          >> $LOG_FILE 
   exit 12
fi


#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting dm_refresh - cant connect to udb " 
      print "aborting dm_refresh - cant connect to udb "               >> $LOG_FILE  
   fi
fi


#
# refresh crt_entl 
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="crt_enrl"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh kscc011_enrl        
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="kscc011"
   print "start mf_refresh_$TBLNAME "`date` 
   print "start mf_refresh_$TBLNAME "`date`                              >> $LOG_FILE 
   sqml $XML_PATH/mf_refresh_$TBLNAME.xml                                >> $LOG_FILE 
   RETCODE=$?
   print "retcode from mf_refresh_$TBLNAME " $RETCODE "   "`date` 
   print "retcode from mf_refresh_$TBLNAME " $RETCODE "   "`date`        >> $LOG_FILE 
fi

###################### begin misc tables ##########################3
#
# refresh manufacturers        
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="cpaa106"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                              >> $LOG_FILE 
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                >> $LOG_FILE 
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date` 
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`        >> $LOG_FILE 
fi


#
# refresh pharmacies       
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="pcyn004"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                              >> $LOG_FILE 
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                >> $LOG_FILE 
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date` 
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`        >> $LOG_FILE 
fi

#
# refresh drugs        
#    331,758 rows, using 6 threads
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="tdrug"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                              >> $LOG_FILE 
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                >> $LOG_FILE 
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date` 
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`        >> $LOG_FILE 
fi


#
# rebuild tdrug9
#
if [[ $RETCODE == 0 ]]; then  
   TBLNAME="tdrug9"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                              >> $LOG_FILE 
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                >> $LOG_FILE 
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date` 
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`        >> $LOG_FILE 
fi


 
#
# disconnect from udb
#                                                     
db2 -stvx connect reset                                                >> $LOG_FILE 
db2 -stvx quit                                                         >> $LOG_FILE 


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

rm -f $TMP_PATH/$JOB.ora
rm -f $DBMSG_FILE* 

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
