#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_9420J_inv_load_pos1.ksh
# Title         : Invoice Load - RTMD RAC Reassignment Part1
# Description   : This script will send an RTMD extract to the mainframe for
#                 reassignment of RACs and rewriting of final FESUMC rows.
# 
# Abends        : 
#                                 
# Parameters    : Period Id (required), eg  2006Q1
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-18-06   is89501     Initial Creation.
# 10-24-13   qcpy987     Added EGWP_CLM_CD
# 06-04-15   qcpy987     ITPR009414 - added MED_PYBL_CD 
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR9400_KS_9420J_inv_load_pos1.ksh
JOB=ks9420j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log


RETCODE=0

TARGET_FILE=$HLQ.KSZ4065J.POSRERAC.INPUT
TARGET_CNTL=$HLQ.KSZ4065J.POSRERAC.CNTL

FTP_CMDS=$TMP_PATH/$JOBftp.cmd
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
DCSQL=$TMP_PATH"/"$JOB"extract.sql"
OUT_DATA_CNT=0

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

################################################################
# 1) examine Quarter parameter  yyyyQn
################################################################
print " input parm was: " $1   
print " input parm was: " $1   >> $LOG_FILE  
YEAR=""
QTR=""
QPARM=""
if [[ $# -eq 1 ]]; then
#   edit supplied parameter
    YEAR=`echo $1 |cut -c 1-4`
    QTR=`echo $1 |cut -c 6-6`
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
else
   export RETCODE=12
   print "aborting script - required parameter not supplied " 
   print "aborting script - required parameter not supplied "     >> $LOG_FILE  
fi
QPARM=$YEAR"Q"$QTR
print ' qparm is ' $QPARM
print ' year is ' $YEAR

POSBKP=$TMP_PATH"/"$JOB"_rtmdbkp_"$QPARM".dat"
DATAFILE=$TMP_PATH"/"$JOB"_posrerac_"$QPARM".out"
CNTLFILE=$TMP_PATH"/"$JOB"_posrerac_"$QPARM".ctl"
DATA2FTP=$INPUT_PATH"/"$JOB"_posrerac.out"
rm -f $DATA2FTP

################################################################
# connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "            >> $LOG_FILE  
   fi
fi

################################################################
# make a backup of the POS quarter
################################################################
if [[ $RETCODE == 0 ]]; then    
      print `date`" creating backup of RTMD for quarter to "$POSBKP
      print `date`" creating backup of RTMD for quarter to "$POSBKP   >> $LOG_FILE
      db2 -stvx "export to "$POSBKP" of del modified by coldel| select * from rps.vpos_claims where period_id = '"$QPARM"' "  >> $LOG_FILE 
      export RETCODE=$?
      if [[ $RETCODE != 0 ]]; then     
	print `date`" db2 export error creating backup - retcode: "$RETCODE
	print `date`" db2 export error creating backup - retcode: "$RETCODE   >> $LOG_FILE
      else
      	print `date`" db2 export of rtmd backup to "$POSBKP" was successful "
	print `date`" db2 export of rtmd backup to "$POSBKP" was successful "  >> $LOG_FILE
      fi
fi 


################################################################
# export a POS extract for RAC reassignment
################################################################
cat > $DCSQL << EOF
export to $DATAFILE of del modified by coldel|,nochardel messages $DBMSG_FILE 
select period_id, rbate_id, digits(tpos_seq), ext_source_cd, ext_client_lvl1, ext_client_lvl2, ext_client_lvl3, 
 ext_client_lvl4, ext_client_lvl5,  
 value(copay_src_cd,' '), delivery_system_cd, value(spcl_drug_cd,' '), value(user_field6_flg,' '),  
 pos_rebate_member, pos_rebate_client, pos_rebate_total, case when(days_supply < 0) then
 '-'||digits(days_supply) else '+'||digits(days_supply) end case 
 ,value(CLM_PMT_CD,' '), value(EGWP_CLM_CD,' '), value(MED_PYBL_CD,' ') 
 from rps.vpos_claims 
 where period_id = '$QPARM'
  order by ext_source_cd, ext_client_lvl1, ext_client_lvl2, ext_client_lvl3, ext_client_lvl4, ext_client_lvl5, 
    copay_src_cd, delivery_system_cd, spcl_drug_cd, user_field6_flg, rbate_id; 
EOF

if [[ $RETCODE == 0 ]]; then    
      print `date`" creating extract of RTMD for quarter to "$DATAFILE
      print `date`" creating extract of RTMD for quarter to "$DATAFILE     >> $LOG_FILE
#      print " *** sql being used is: "                                     >> $LOG_FILE  
#      print `cat $DCSQL`                                                   >> $LOG_FILE  
#      print " *** end of sql display.                   "                  >> $LOG_FILE  
      db2 -tvf $DCSQL 
      export RETCODE=$?
      if [[ $RETCODE != 0 ]]; then     
	print `date`" db2 export error creating extract - retcode: "$RETCODE
	print `date`" db2 export error creating extract - retcode: "$RETCODE   >> $LOG_FILE
      else
      	print `date`" db2 export of rtmd extract to "$DATAFILE" was successful "
	print `date`" db2 export of rtmd extract to "$DATAFILE" was successful "   >> $LOG_FILE
      fi
fi 


#################################################################
# count the records
#################################################################
if [[ $RETCODE == 0 ]]; then    
   OUT_DATA_CNT=$(wc -l < $DATAFILE)
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $DATAFILE  
     print `date` ' *** word count returned ' $RETCODE ' on wc command using ' $DATAFILE  >> $LOG_FILE
   fi
fi


#################################################################
# create a trailer with period and reccount
#################################################################
if [[ $RETCODE == 0 ]]; then    
    print $QPARM" "$OUT_DATA_CNT" "`date`  > $CNTLFILE
fi


#################################################################
# ftp the extract to the mainframe
# PCS.P.KSZ4060J.POSRERAC.INPUT  Width = 254 bytes
#     print 'put ' $CNTLFILE " '"$TARGET_CNTL"' " ' (replace'   >> $FTP_CMDS
#   print 'put ' $DATAFILE " '"$TARGET_FILE"' " ' (replace'               >> $FTP_CMDS

#################################################################

# wip - stubbed out, mainframe will do a GET
#if [[ $RETCODE == 77 ]]; then 
#   chmod 777 $DATAFILE
#   print `date` 'FTP starting '                                          >> $LOG_FILE
#   print 'quote site lrecl=187 blksize=0 recfm=fb '                      >  $FTP_CMDS
#   print 'put ' $DATAFILE " '"$TARGET_FILE"' " ' (replace'               >> $FTP_CMDS
#   print 'quit'                                                          >> $FTP_CMDS
#   cat $FTP_CMDS                                                         >> $LOG_FILE 
#   ftp -i -v $FTP_MF_IP < $FTP_CMDS                                      >> $LOG_FILE 
#   export RETCODE=$?
#   if [[ $RETCODE != 0 ]]; then     
#      print `date`" ftp error - retcode: "$RETCODE
#      print `date`" ftp error - retcode: "$RETCODE   >> $LOG_FILE
#   else
#      print `date`" ftp appears successful "
#      print `date`" ftp appears successful "   >> $LOG_FILE
#    fi
#fi

# move to FTP directory
if [[ $RETCODE == 0 ]]; then 
   chmod 777 $DATAFILE
   mv $DATAFILE $DATA2FTP
fi

################################################################
# disconnect from udb
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

rm -f $FTP_CMDS 
rm -f $DBMSG_FILE* 
rm -f $DCSQL
rm -f $CNTLFILE

print "return_code =" $RETCODE
exit $RETCODE
