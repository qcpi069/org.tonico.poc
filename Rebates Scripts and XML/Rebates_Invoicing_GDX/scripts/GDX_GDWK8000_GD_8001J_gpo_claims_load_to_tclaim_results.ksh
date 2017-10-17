#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDWK8000_GD_8001J_gpo_claims_load_to_tclaim_results.ksh   
# Title         : email load results to business.
#
# Description   : This script will generate an Email notification to the business 
#                 with the gpo claims load results.
#
# Parameters    : N/A.
#                
# Output        : Log file as $OUTPUT_PATH/$FILE_BASE.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-08-2005 G.Jayaraman Initial Creation.
#-------------------------------------------------------------------------#
###########################################################################
# Caremark GDX Environment variables
###########################################################################

. `dirname $0`/Common_GDX_Environment.ksh

SCHEDULE='GDWK8000'
JOB='GD_8001J'
FILE_BASE="GDX_"$SCHEDULE'_'$JOB'_gpo_claims_load_to_tclaim_results'


###########################################################################
# Create the common variables:
###########################################################################

. $SCRIPT_PATH/Common_GDX_Env_File_Names.ksh

if [[ $REGION = 'prod' ]];   then
    if [[ $QA_REGION = 'true' ]];   then
        # Running in the QA region
          ALTER_EMAIL_ADDRESS=''  	
	  export EMAIL_SUBJECT='GDX TCLAIM GPO QA Load Results Notification'
	  UDB_SCHEMA_OWNER='DBA' 
	  DBA_TRG_PATH=$INPUT_PATH
    else
        # Running in Prod region        
          ALTER_EMAIL_ADDRESS=''   
	  export EMAIL_SUBJECT='GDX TCLAIM GPO PROD Load Results Notification' 
	  UDB_SCHEMA_OWNER='DBA'  
	  DBA_TRG_PATH=$INPUT_PATH
    fi
else
    # Running in Development region
      ALTER_EMAIL_ADDRESS='Ganapathi.jayaraman@caremark.com'   
      export EMAIL_SUBJECT='GDX TCLAIM GPO TEST Load Results Notification'
      UDB_SCHEMA_OWNER='DBA'  
      DBA_TRG_PATH=/datar1/test
      #export orig_file=${load_file##/*/}    
fi


###########################################################################
# Create the Local variables:
###########################################################################

MAILFILE=$OUTPUT_PATH/$FILE_BASE'_email.txt'
BUS_EMAIL_ADDRESS='GDXGPOOps@caremark.com'
DBA_TRG_FILE=$DBA_TRG_PATH/'GDX_load_rbate_claims_extract.trg.complete'
UDB_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE'_udb_sql.msg'
   
print 'executing base script name :' $SCRIPTNAME              	>> $LOG_FILE
print ' *** log file is    ' $LOG_FILE                        	>> $LOG_FILE
print ' DBA Trigger file is : ' $DBA_TRG_FILE                 	>> $LOG_FILE

rm -f $MAILFILE

###########################################################################
# Read the trigger file to get the Input data count:
###########################################################################

export FIRST_READ=1
while read dat_cnt model beg_dt endg_dt load_fil load_stat  ; do
  if [[ $FIRST_READ != 1 ]]; then
    print 'Finishing trigger file read'                      	       >> $LOG_FILE    
  else
    export FIRST_READ=0
    print 'read from trigger file completed '                          >> $LOG_FILE    
    print 'Data file is : '      $load_fil                  	       >> $LOG_FILE    
    export data_cnt=$dat_cnt
    export model_typ=$model
    export start_dt=$beg_dt
    export end_dt=$endg_dt  
    export orig_file=$load_fil
    export chk_stat=$load_stat             
  fi
done < $DBA_TRG_FILE

###################################################################################
#
# Establish SQL connection 
#
###################################################################################

print `date` >> $LOG_FILE
print '**********************************************************' >>$LOG_FILE 
export SQL_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" >> $LOG_FILE
print '**********************************************************' >>$LOG_FILE 

db2 -p $SQL_CONNECT_STRING       >  $UDB_OUTPUT_MSG_FILE  >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print 'date' 'Script ' $SCRIPTNAME 'failed in the DB CONNECT.'       >> $LOG_FILE 
   print ' Return Code = '$RETCODE                                      >> $LOG_FILE
   print 'Check DB2 error log: '$UDB_OUTPUT_MSG_FILE                    >> $LOG_FILE
   print 'Here are last 20 lines of that file - '                       >> $LOG_FILE
   print ' '                                                            >> $LOG_FILE
   print ' '                                                            >> $LOG_FILE
   tail -20 $UDB_OUTPUT_MSG_FILE                                        >> $LOG_FILE
   print ' '                                                            >> $LOG_FILE
   print ' '                                                            >> $LOG_FILE   
else

###################################################################################
#  SQL execution via sql string 
###################################################################################

  SQL_STRING="Select read, ' ', skipped, ' ', inserted, ' ', deleted, ' ', rejected from $UDB_SCHEMA_OWNER.LOADS where DATA_FILE='$orig_file' order by LOAD_DATE desc "
   print $SQL_STRING >> $LOG_FILE 

   db2 -px $SQL_STRING  	> $OUTPUT_FILE		>  $UDB_OUTPUT_MSG_FILE
   
   RETCODE=$?

   if [[ $RETCODE != 0 ]]; then      
         print 'Script ' $SCRIPTNAME 'failed in the select step.' 	>> $LOG_FILE
         print 'Return code is : <' $RETCODE '>'              		>> $LOG_FILE 
	   print 'Check DB2 error log: '$UDB_OUTPUT_MSG_FILE            >> $LOG_FILE
   	   print 'Here are last 20 lines of that file - '               >> $LOG_FILE
         print ' '                                                      >> $LOG_FILE
         print ' '                                                      >> $LOG_FILE
         tail -20 $UDB_OUTPUT_MSG_FILE                                  >> $LOG_FILE
         print ' '                                                      >> $LOG_FILE                         
   else
         print date 'Script ' $SCRIPTNAME 'completed.'          	>> $LOG_FILE
         print 'DB2 return code is : <'  $RETCODE  '>'              	>> $LOG_FILE   
         export FIRST_READ=1         
         while read tot_read_cnt skipped inserted deleted rejected ; do
          if [[ $FIRST_READ != 1 ]]; then
             print 'Finishing db2 results file read'                   	>> $LOG_FILE 
          else   
          	 export FIRST_READ=0    		
    	 	 print 'Total Read count_is :' $tot_read_cnt   		>> $LOG_FILE 
    	 	 export load_read_cnt=$tot_read_cnt    
    		 export load_skip_cnt=$skipped
    		 export load_isrt_cnt=$inserted
    		 export load_del_cnt=$deleted    
		 export load_rej_cnt=$rejected
          fi
	  done < $UDB_OUTPUT_MSG_FILE
   fi      	
fi   

RETCODE=$?

###################################################################################
# 	Send the results email to business                     
###################################################################################

if [[ $RETCODE = 0 ]]; then
	print 'GPO claims load to TCLAIM table has just completed.'   >> $MAILFILE
	print 'Following are the load details:'                       >> $MAILFILE
	print ' '                                                     >> $MAILFILE
	print '---------------------------------------------------'   >> $MAILFILE
	print 'Source Data File is : ' $orig_file		      >> $MAILFILE
	print 'Claims having model type : ' $model_typ                >> $MAILFILE
	print 'Claims Input for Load: ' $data_cnt                     >> $MAILFILE
	print 'Claims Batch start date: ' $start_dt                   >> $MAILFILE
	print 'Claims Batch end date: ' $end_dt                       >> $MAILFILE
	print 'Claims Read by load script :  ' $load_read_cnt         >> $MAILFILE 
	print 'Claims loaded  :  ' $load_isrt_cnt                     >> $MAILFILE 
	print 'Claims Skipped :  ' $load_skip_cnt                     >> $MAILFILE 
	print 'Claims Deleted :  ' $load_del_cnt                      >> $MAILFILE 
        print 'Claims Rejected : ' $load_rej_cnt                      >> $MAILFILE
	print 'Load status is :  ' $chk_stat                          >> $MAILFILE       
	print '---------------------------------------------------'   >> $MAILFILE
        
	if [[ $chk_stat != 0 ]]; then
            print 'Claims loaded  :  ' $load_isrt_cnt                 >> $LOG_FILE
	    print 'Claims Skipped :  ' $load_skip_cnt                 >> $LOG_FILE 
	    print 'Claims Deleted :  ' $load_del_cnt                  >> $LOG_FILE
            print 'Claims Rejected : ' $load_rej_cnt                  >> $LOG_FILE
	    print 'Load status is :  ' $chk_stat                      >> $LOG_FILE
            print 'Exceptions Exist. Please Contact DBA  OR Check TCLAIM_GPO_EXCEPTION table '    >> $LOG_FILE
	     
            . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    	     cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`	
   	     exit $RETCODE
        fi      

	chmod 777 $MAILFILE

	mailx -s "$EMAIL_SUBJECT" $BUS_EMAIL_ADDRESS	< $MAILFILE	 
   
	RETCODE=$?   

	if [[ $RETCODE != 0 ]]; then
   		print ' ' 						  >> $LOG_FILE
   		print '================== J O B  A B E N D E D ======='   >> $LOG_FILE
   		print '  Error sending email to Business ' 		  >> $LOG_FILE
   		print '  Look in ' $LOG_FILE             		  >> $LOG_FILE
   		print '==============================================='   >> $LOG_FILE
	else
   		print 'Email sucessfully sent to :' $BUS_EMAIL_ADDRESS    >> $LOG_FILE
		print ' ' 					  >> $LOG_FILE

	fi
else	

###################################################################################
#
# Send Email notification to EBS if the process failed with a bad return code              
#
###################################################################################
        
   	print 'Sending email notification with the following parameters' >> $LOG_FILE
   	print 'JOBNAME is '  $JOB/$SCHEDULE                              >> $LOG_FILE 
   	print 'SCRIPTNAME is ' $SCRIPTNAME                               >> $LOG_FILE
   	print 'LOGFILE is ' $LOGFILE                                     >> $LOG_FILE
   	print 'EMAILPARM4 is ' $EMAILPARM4                               >> $LOG_FILE
   	print 'EMAILPARM5 is ' $EMAILPARM5                               >> $LOG_FILE
   	print '****** end of email parameters ******'                    >> $LOG_FILE
   
   	. $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

   	cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`	
   	exit $RETCODE	
fi
   
print 'date' '....Completed executing ' $SCRIPTNAME 			     >> $LOG_FILE
rm -f $DBA_TRG_FILE
rm -f $DBA_TRG_PATH/$orig_file
mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
 
exit $RETCODE