#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDQT7777_GD_7777J_tclaim_gpo_table_status_update.ksh   
# Title         : Update table status code on the TCLAIM_GPO table.
#
# Description   : This script will Update the table status code on the TCLAIM_GPO 
#                 table based on the trigger values passed from source (ORACLE) 
#                 whenever the quarterly cycle status on the source is modified 
#                 to in Process (changed to "P" from "A" on T_Rbate_cycle table).
#
# Parameters    : None.
#                
#
# Output        : Log file as $OUTPUT_PATH/$FILE_BASE.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-10-2005 G.Jayaraman Initial Creation.
#-------------------------------------------------------------------------#
###########################################################################
# Caremark GDX Environment variables
###########################################################################

. `dirname $0`/Common_GDX_Environment.ksh

SCHEDULE="GDQT7777"
JOB="GD_7777J"
FILE_BASE="GDX_"$SCHEDULE"_"$JOB"_tclaim_gpo_table_status_update"

###########################################################################
# This script call create the common variables:
###########################################################################

. $SCRIPT_PATH/Common_GDX_Env_File_Names.ksh

###########################################################################
# Create Local variables  :
###########################################################################     

if [[ $REGION = 'prod' ]];   then
    if [[ $QA_REGION = 'true' ]];   then
        # Running in the QA region
        ALTER_EMAIL_ADDRESS=''    
	  UDB_SCHEMA_OWNER='VRAP'    
    else
        # Running in Prod region        
        ALTER_EMAIL_ADDRESS=''    
	  UDB_SCHEMA_OWNER='VRAP'       
    fi
else
    # Running in Development region
     ALTER_EMAIL_ADDRESS='Ganapathi.jayaraman@caremark.com'   
     UDB_SCHEMA_OWNER='VRAP'    
fi

FTP_TRG_FILE=$INPUT_PATH/"rbate_RIQT7000_RI_7000J_gdx_tclaim_statupdt_dtls"
UDB_RSLTS_FILE=$OUTPUT_PATH/$FILE_BASE"_SQLOUT.DAT"
UDB_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE"_udb_sql.msg"

rm -rf $UDB_RSLTS_FILE

print 'date' 'executing base script name :' $SCRIPTNAME           >> $LOG_FILE
print ' *** log file is    ' $LOG_FILE                            >> $LOG_FILE
print ' *** now calling FTP validation script **** '              >> $LOG_FILE

###########################################################################
# validate FTP  by calling the common validation script
###########################################################################     

. $SCRIPT_PATH/Common_Ftp_Validation.ksh

RETCODE=$?
if [[ $RETCODE != 0 ]] ; then
    print 'date' 'common_ftp_validation script failed'                   >> $LOG_FILE
    print `date` ' *** common_ftp_validation.ksh return code ' $RETCODE  >> $LOG_FILE   
else
    if [[ $FTP_VALIDATED != 'Y' ]] ; then
	  print ' *** FTP Counts Mismatch '                         >> $LOG_FILE
        print ' *** ftp_validation switch is ' $FTP_VALIDATED    	>> $LOG_FILE  
        RETCODE=1        
    else
        print ' *** FTP validation completed ....... *** '        >> $LOG_FILE            
        print ' *** starting oracle data read ...... *** '        >> $LOG_FILE
	  print ' Oracle data file is : ' $FTP_DATA_FILE            >> $LOG_FILE
	  print ' Oracle Trigger file is : ' $FTP_TRG_FILE          >> $LOG_FILE
    fi
fi

if [[ $RETCODE  = 0 ]] ; then

###########################################################################
# Read data file to get the update parameters:
###########################################################################     

   export FIRST_READ=1
   while read cycl_gid  cycl_typ  status  beg_dt  endg_dt  isrt_dt  updt_dt ; do
      if [[ $FIRST_READ != 1 ]]; then
         print 'Finishing trigger file read'                           >> $LOG_FILE    
      else
         export FIRST_READ=0
         print 'read record from trigger file'                         >> $LOG_FILE
         print 'Cycle updated is ' $cycl_gid                           >> $LOG_FILE  
         print 'Cycle Type is ' $cycl_typ                              >> $LOG_FILE 
         export cycl_gid=$cyc_gid
         export status=$cycl_stat
         export start_dt=$beg_dt
         export end_dt=$endg_dt    
      fi
   done < $FTP_DATA_FILE

###################################################################################
# Establish DB2UDB connection 
###################################################################################

    print `date` 'Starting DB2 Connection'                            >> $LOG_FILE
    print '*********************************************************' >>$LOG_FILE 
    export SQL_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" >> $LOG_FILE
    print '*********************************************************' >>$LOG_FILE 

    db2 -p $SQL_CONNECT_STRING            >> $LOG_FILE	>  $UDB_OUTPUT_MSG_FILE

    RETCODE=$?

    if [[ $RETCODE != 0 ]]; then
      print 'date' "Script " $SCRIPTNAME "failed in the DB CONNECT."       >> $LOG_FILE 
   	print " Return Code = "$RETCODE                                      >> $LOG_FILE
   	print "Check DB2 error log: "$UDB_OUTPUT_MSG_FILE                    >> $LOG_FILE
   	print "Here are last 20 lines of that file - "                       >> $LOG_FILE
   	print " "                                                            >> $LOG_FILE
   	print " "                                                            >> $LOG_FILE
   	tail -20 $UDB_OUTPUT_MSG_FILE                                        >> $LOG_FILE
   	print " "                                                            >> $LOG_FILE
   	print " "                                                            >> $LOG_FILE   
    else
###################################################################################
#      SQL execution via sql string to update table status code to "C" (Closed)
###################################################################################
	 SQL_STRING="Update $UDB_SCHEMA_OWNER.TCLAIM_LOAD_CNTL set tbl_stat_cd = 'C' where tbl_nm = (Select tbl_nm from VRAP.TCLAIM_LOAD_CNTL where Model_typ_cd = 'G' and inv_elig_min_dt = '$start_dt' and inv_elig_max_dt = '$end_dt') "
       print $SQL_STRING >> $LOG_FILE 

       db2 -px $SQL_STRING 	>> $UDB_RSLTS_FILE	>	$UDB_OUTPUT_MSG_FILE
       
       RETCODE=$?
           if [[ $RETCODE != 0 ]]; then
                  print "Script " $SCRIPTNAME "failed in the update step." 	>> $LOG_FILE                  
         		print "Return code is : <" $RETCODE ">"              		>> $LOG_FILE 
	   		print "Check DB2 error log: "$UDB_OUTPUT_MSG_FILE              >> $LOG_FILE
   	   		print "Here are last 20 lines of that file - "                 >> $LOG_FILE
         		print " "                                                      >> $LOG_FILE
         		print " "                                                      >> $LOG_FILE
         		tail -20 $UDB_OUTPUT_MSG_FILE                                  >> $LOG_FILE
         		print " "                                                      >> $LOG_FILE                     
           else
                  print "DB2 return code is : <" $RETCODE ">"              >> $LOG_FILE 
			print "DB2 Update completed."                            >> $LOG_FILE     
			export FIRST_READ=1
                  while read result_set ; do
                     if [[ $FIRST_READ != 1 ]]; then
                       print "'Reading SQL output line :' $FIRST_READ "    >> $LOG_FILE    
                     else
                       export FIRST_READ=0
                       print "read record from SQL output file"            >> $LOG_FILE
                       print $result_set                                   >> $LOG_FILE                        
                     fi
                  done < $UDB_RSLTS_FILE 
           fi
    fi
fi
###################################################################################
#
# Send Email notification to EBS if the process failed with a bad return code              
#
###################################################################################
if [[ $RETCODE != 0 ]] ; then
   	print 'Sending email notification with the following parameters' >> $LOG_FILE
   	print 'JOBNAME is '  $JOB/$SCHEDULE                              >> $LOG_FILE 
   	print 'SCRIPTNAME is ' $SCRIPTNAME                               >> $LOG_FILE
   	print 'LOGFILE is ' $LOG_FILE                                    >> $LOG_FILE
   	print 'EMAILPARM4 is ' $EMAILPARM4                               >> $LOG_FILE
   	print 'EMAILPARM5 is ' $EMAILPARM5                               >> $LOG_FILE
   	print '****** end of email parameters ******'                    >> $LOG_FILE
   
   	. $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

   	cp -f $LOG_FILE $LOG_FILE_ARCH.`date +"%Y%j%H%M"`	
   	exit $RETCODE	
fi
     
print 'date' '....Completed executing ' $SCRIPTNAME                   >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH.`date +"%Y%j%H%M"`
rm -f $FTP_TRG_FILE
   
exit $RETCODE