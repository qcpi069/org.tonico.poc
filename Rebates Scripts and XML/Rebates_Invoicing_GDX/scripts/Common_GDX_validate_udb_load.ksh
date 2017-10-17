#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_GDX_validate_udb_load.ksh   
# Title         : email load failure message to business.
#
# Description   : This script will generate an Email notification to the business 
#                 with the load results when failed, will write to the log file
#		  when success.
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
#-------------------------------------------------------------------------#
# Title         : email load results to business.

. `dirname $0`/Common_GDX_Environment.ksh


SCHEDULE=''
JOB=''
FILE_BASE='Common_GDX_validate_udb_load'

. $SCRIPT_PATH/Common_GDX_Env_File_Names.ksh

###########################################################################
# Create the common variables:
###########################################################################

if [[ $REGION = 'prod' ]];   then
    if [[ $QA_REGION = 'true' ]];   then
        # Running in the QA region
          ALTER_EMAIL_ADDRESS=''  	
	  export EMAIL_SUBJECT='GDX UDB Load Results Notification'
	  UDB_SCHEMA_OWNER='DBA' 
	  DBA_TRG_PATH=$INPUT_PATH
    else
        # Running in Prod region        
          ALTER_EMAIL_ADDRESS=''   
	  export EMAIL_SUBJECT='GDX UDB PROD Load Results Notification' 
	  UDB_SCHEMA_OWNER='DBA'  
	  DBA_TRG_PATH=$INPUT_PATH
    fi
else
    # Running in Development region
      ALTER_EMAIL_ADDRESS=''
      export EMAIL_SUBJECT='GDX UDB Load Results Notification'
      UDB_SCHEMA_OWNER='DBA'  
      DBA_TRG_PATH=/datar1/test
      #export orig_file=${load_file##/*/}    
fi
##############################################################################
#parse input parameter and set data file name and dir
############################################################################

## check to see if the input trigger fileis good
if [[ -r $1 ]]; then
	parm1=$1  
	RETCODE=0
else
	RETCODE=2
	print 'Input trigger file does not exit or not readable' >>$LOG_FILE
fi

#if input file does exist
if [[ $RETCODE = 0 ]]; then
	data_file_path=${parm1%/*}
	full_data_file=`cat $1`
	data_file_name=${full_data_file##*/}	


###########################################################################
# Create the Local variables:
###########################################################################

MAILFILE=$OUTPUT_PATH/$FILE_BASE'_email.txt'
BUS_EMAIL_ADDRESS='GDXGPOOps@caremark.com'
DBA_TRG_FILE=$1
UDB_OUTPUT_MSG_FILE=$OUTPUT_PATH/$FILE_BASE'_udb_sql.msg'
   
print 'executing base script name :' $SCRIPTNAME              	>> $LOG_FILE
print ' *** log file is    ' $LOG_FILE                        	>> $LOG_FILE
print ' DBA Trigger file is : ' $DBA_TRG_FILE                	>> $LOG_FILE
print ' Data file is : ' $data_file_path'/'$data_file_name                	>> $LOG_FILE

rm -f $MAILFILE

##################################################################################
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

  SQL_STRING="Select  inserted,' ', table  from $UDB_SCHEMA_OWNER.LOADS  where DATA_FILE='$data_file_name' order by LOAD_DATE desc "
   print $SQL_STRING >> $LOG_FILE 

   db2 -px $SQL_STRING  > $OUTPUT_FILE		>  $UDB_OUTPUT_MSG_FILE
   RETCODE=$?

   if [[ $RETCODE != 0 ]]; then      
         print 'Script ' $SCRIPTNAME 'failed in the select step.' 	>> $LOG_FILE
         print 'Return code is : <' $RETCODE '>'              		>> $LOG_FILE 
	   print 'Check DB2 error log: '$UDB_OUTPUT_MSG_FILE            >> $LOG_FILE
   	   print 'Here are last 20 lines of that file - '               >> $LOG_FILE
         print ' '                                                      >> $LOG_FILE
         print ' '                                                      >> $LOG_FILE
         tail -20 $UDB_OUTPUT_MSG_FILE                                  >> $LOG_FILE
         print ' '                                                       >> $LOG_FILE                         
   else
         print date 'Script ' $SCRIPTNAME 'completed.'          	>> $LOG_FILE
         print 'DB2 return code is : <'  $RETCODE  '>'              	>> $LOG_FILE   
         export FIRST_READ=1         
         while read inserted table ; do
          if [[ $FIRST_READ != 1 ]]; then
             print 'Finishing db2 results file read'                   	>> $LOG_FILE 
          else   
          	 export FIRST_READ=0    		
    	 	 print 'Inserted count :' $inserted  		>> $LOG_FILE 
    	 	 export load_isrt_cnt=$inserted
		 export tablename=$table
                 print 'Inserted Into Table :' $table  		>> $LOG_FILE 
          fi
	  done < $UDB_OUTPUT_MSG_FILE
   fi      	
fi   ## end if the trigger file is valid

######################################
#  Count the line of the data file
if [[ $RETCODE = 0 ]]; then
	if [[ -r $data_file_path'/'$data_file_name ]]; then
		data_file_line_count=`wc -l  $data_file_path'/'$data_file_name|read count name;print $count` >>$LOG_FILE	
		print 'Date File Record Count : '$data_file_line_count   >>$LOG_FILE
	else
		print 'Data file does not exist or not readable: '$data_file_path'/'$data_file_name  >>$LOG_FILE
		RETCODE=2
	fi
fi

fi

###################################################################################
# 	Send the results email to business                     
###################################################################################

if [[ ($RETCODE = 0) && ($data_file_line_count = $load_isrt_cnt) ]]; then

	print 'UDB load has just completed.'   >> $LOG_FILE
	print 'Following are the load details:'                       >> $LOG_FILE
	print ' '                                                     >> $LOG_FILE
	print '---------------------------------------------------'   >> $LOG_FILE
	print 'Source Data File is : ' $data_file_name		      >> $LOG_FILE	
	print 'Read by load script :  '        >> $LOG_FILE
	print 'loaded  :  ' $load_isrt_cnt                            >> $LOG_FILE
	print 'Date File Record Count :  ' $data_file_line_count      >> $LOG_FILE
	print 'Skipped :  '              >> $LOG_FILE
	print 'Deleted :  '                     >> $LOG_FILE
        print 'Rejected : '                  >> $LOG_FILE
	print 'Load status is :  '                                    >> $LOG_FILE
	print '---------------------------------------------------'   >> $LOG_FILE 	
else	

###################################################################################
#
# Send Email notification to EBS if the process failed with a bad return code              
#
###################################################################################
        
   	print 'Sending email notification with the following parameters' >> $LOG_FILE
   	print 'JOBNAME is '  $JOB/$SCHEDULE                              >> $LOG_FILE 
   	print 'SCRIPTNAME is ' $SCRIPTNAME                               >> $LOG_FILE
   	print 'LOGFILE is ' $LOG_FILE                                 	 >> $LOG_FILE
   	print 'EMAILPARM4 is '  $EMAILPARM4                              >> $LOG_FILE
   	print 'EMAILPARM5 is ' $EMAILPARM5				 >> $LOG_FILE
   	print '****** end of email parameters ******'                    >> $LOG_FILE
   
   	. $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

   	cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`	
   	exit $RETCODE	
fi
   
print 'date' '....Completed executing ' $SCRIPTNAME 			     >> $LOG_FILE
#rm -f $DBA_TRG_FILE
#rm -f $DBA_TRG_PATH/$data_file_name
mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
exit $RETCODE

