#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : /GDX/prod/scripts/GDX_GDHR8010_GD_8012J_discnt_mktshr_exclusion_claim_procs.ksh         
# Title         : Exclusion Claim Processing - Discount Model Rebate Report
#
# Description   : This script build exclusion sum claims for discount market share 
#                 reports.                  
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
# 05-10-2005 G.Jayaraman Initial Creation.
#-------------------------------------------------------------------------#
###########################################################################
# Caremark GDX Environment variables
###########################################################################

. `dirname $0`/Common_GDX_Environment.ksh

SCHEDULE="GDHR8010"
JOB="GD_8012J"
FILE_BASE="GDX_"$SCHEDULE"_"$JOB"_discnt_mktshr_exclusion_claim_procs"

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
        ##ALTER_EMAIL_ADDRESS=''  
	ALTER_EMAIL_ADDRESS='Ganapathi.jayaraman@caremark.com' 
	  UDB_SCHEMA_OWNER='VRAP'    
    else
        # Running in Prod region        
        ##ALTER_EMAIL_ADDRESS='' 	
	ALTER_EMAIL_ADDRESS='Ganapathi.jayaraman@caremark.com' 
	  UDB_SCHEMA_OWNER='VRAP'       
    fi
else
    # Running in Development region
     ALTER_EMAIL_ADDRESS='Ganapathi.jayaraman@caremark.com'   
     UDB_SCHEMA_OWNER='VRAP'      
fi

export SCRIPTNAME=$FILE_BASE'.ksh'
export OLOG=$LOG_PATH/$FILE_BASE'.dat'
export OLOG_ARCH=/GDX/prod/log/archive/$FILE_BASE'.dat'
export DDMEA_FILE=$LOG_PATH/".$FILE_BASE'.DDMEA'"
export EXE_DIR="/GDX/prod/cobol/aixexec"

##########################################################################
# CLEAN OLD FILES AND START THE PROCESS
#
##########################################################################

rm -rf $OLOG
rm -rf $DDMEA_FILE
#rm -rf $LOG_FILE

print `date` '....Started executing ' $SCRIPTNAME       >> $LOG_FILE
print ' '						>> $LOG_FILE
print 'Log file is    '    $LOG_FILE			>> $LOG_FILE
print ' '						>> $LOG_FILE
print 'COBOL program created log file is '  $OLOG	>> $LOG_FILE
print ' '						>> $LOG_FILE

#############################
# set variables for db login
#############################

export DBNAME=$DATABASE 
export DBUSER=$CONNECT_ID
export DBPSWD=$CONNECT_PWD  

print  "DB name is  " $DBNAME				>> $LOG_FILE
print  "DB User is  " $DBUSER				>> $LOG_FILE


###################################################################
# get parm variables for process.. 
###################################################################

if [ $# -lt 1 ] 
then
    print ' '						>> $LOG_FILE
    print 'Insufficient arguments passed to script.'	>> $LOG_FILE
    print ' '						>> $LOG_FILE
    print 'Defaulting values "D" & "M" to script.'	>> $LOG_FILE
    export MODEL='D'
    export RPTTYP='M'
else 
    export MODEL=$1
    export RPTTYP=$2
fi


print ' '						>> $LOG_FILE
print 'Model type code is  :' $MODEL			>> $LOG_FILE
print ' '						>> $LOG_FILE
print 'Report type is  :' $RPTTYP			>> $LOG_FILE


###################################################################
# EXECUTE COBOL PROGRAM 
###################################################################

print ' '						>> $LOG_FILE
print `date` '....Started executing Cobol Program'      >> $LOG_FILE
print ' '						>> $LOG_FILE


$EXE_DIR/exclclms   

RETCODE=$?

print '********************************************* '  >> $LOG_FILE
print `date` '....Completed executing Cobol Program'    >> $LOG_FILE
print '********************************************* '	>> $LOG_FILE
print ' '						>> $LOG_FILE
print 'COBOL RETCODE IS :' $RETCODE			>> $LOG_FILE
print ' '						>> $LOG_FILE

###################################################################################
#
# Send Email notification to EBS if the process failed with a bad return code              
#
###################################################################################
 if [[ $RETCODE != 0 ]] ; then
        
	print 'Cobol program execution set a bad return code '           >> $LOG_FILE
	print 'please review cobol log file for actual errors'           >> $LOG_FILE
	print 'Return Code is : '    $RETCODE                            >> $LOG_FILE	
   	print ' '							 >> $LOG_FILE
	print 'COBOL program created log file is '  $OLOG	         >> $LOG_FILE
	print ' '							 >> $LOG_FILE
	print 'Sending email notification with the following parameters' >> $LOG_FILE
  	print ' '							 >> $LOG_FILE
	print 'JOBNAME is '  $JOB/$SCHEDULE                              >> $LOG_FILE 
 	print 'SCRIPTNAME is ' $SCRIPTNAME                               >> $LOG_FILE
	print 'LOGFILE is '    $LOG_FILE                                 >> $LOG_FILE
	print 'EMAILPARM4 is ' $EMAILPARM4                               >> $LOG_FILE
	print 'EMAILPARM5 is ' $EMAILPARM5                               >> $LOG_FILE
   	print ' '							 >> $LOG_FILE
	print '****** end of email parameters ******'                    >> $LOG_FILE
   
   	. $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

   	cp -f $LOG_FILE $LOG_FILE_ARCH.`date +"%Y%j%H%M"`
	cp -f $OLOG $OLOG_ARCH".`date +"%Y%j%H%M"`"   
   	exit $RETCODE	
fi

print `date` '....Completed executing ' $SCRIPTNAME                   >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH".`date +"%Y%j%H%M"`"
mv -f $OLOG $OLOG_ARCH".`date +"%Y%j%H%M"`"   
exit $RETCODE