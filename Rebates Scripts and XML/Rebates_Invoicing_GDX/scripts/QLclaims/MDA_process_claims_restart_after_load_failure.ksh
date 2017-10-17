#!/usr/bin/ksh

#############################################################################
#SCRIPT NAME : MDA_process_claims                                           #
#                                                                           #
#PURPOSE     :                                                              #
#                                                                           #
#INSTRUCTIONS: This script runs the main MDA claims intake process.  The    #
#              file is sorted then is input into a MicroFocus Cobol program #
#              where the incentive type code is added to the program.       #
#                                                                           #
#CALLS       :                                                              #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  04/01/2004  Initial Release                    #
#                                                                           #
#############################################################################

  . /vracobol/prod/script/MDA_prod_profile_restart 

export DATA_LOAD_FILE="mda.vrap.tclaims.dat.T20050503083114"
  typeset -i Load_Return_Code=0
  export Load_Return_Code

   FTP_STATUS=222

###  $SCRIPT_DIR/MDA_ftp_to_tsmnim1.ksh >>$LOG_FILE 2>&1

###  FTP_STATUS=$?

# 222 is a good return from FTP kornshell... test for dba load script status
  if (($FTP_STATUS==222)); then

      #   informative email to track progress
      echo    "Load Processing for $RUN_MODE claims intake is starting:"   \
              "\nftp of load file to tsmnim1 was good."                   \
              "\nfollow progress in $LOG_FILE" > $MAILFILE
 
      MAIL_SUBJECT="MDA db load PROCESS"
      $SCRIPT_DIR/mailto_IS_group.ksh

      $SCRIPT_DIR/MDA_load_tclaims_restart.ksh >>$LOG_FILE 
     
      DBA_AUTOLOAD_RETURN_CD=$?
      echo "global Load_Return_Code: " $Load_Return_Code >>$LOG_FILE 
  
      echo "dba load ksh return code: ${DBA_AUTOLOAD_RETURN_CD} " >>$LOG_FILE
      
      #  return code values and meanings for "MDA_load_tclaims.ksh"
      #  
      #  140 series are 'good' return codes
      #
      #  140 = claims loaded successfully without any duplicates
      #
      #  150 series are 'bad' return codes
      #
      #  150 = non-zero return code on DBA.LOADS table for given load data set
      #  152 = SQL error of some sort
      #  151 = We never got a row in DBA.LOADS for the load of the given   
      #        load data set.  Manual investigation needed  
      #  154 = Multiple rows in DBA.LOADS for given load data set, further
      #        manual investigation is needed to determine if there are problems
      #  155 = claims loaded but with duplicates in TCLAIMS_EXCP table
      #  

      if (($DBA_AUTOLOAD_RETURN_CD<150)); then
#        send SBO audit email if tclaims load was good.

         MAIL_SUBJECT="MDA $RUN_MODE claims intake process auditing info"
         print "`cat $MAILFILE_SBO`" > $MAILFILE
         $SCRIPT_DIR/mailto_MDA_SBO_group.ksh

         ## lets check out the claims sum rebuild processing

         $SCRIPT_DIR/MDA_check_tclaims_sum_build.ksh >>$LOG_FILE 
     
         DBA_REBUILD_RETURN_CD=$?
         echo "global Load_Return_Code: " $Load_Return_Code >>$LOG_FILE 

         if (($DBA_REBUILD_RETURN_CD<150)); then
            ## everything is done with claims sum rebuild processing!

            echo "email notifying Actuate support to restart reports" >> $LOG_FILE
             
            print "Please start the report generation. MDA is done loading"  \
                  "\nfor $RUN_MODE claims load" > $MAILFILE
            MAIL_SUBJECT="MDA $RUN_MODE claims load needs report generation restarted"

            $SCRIPT_DIR/mailto_ACTUATE_group.ksh > /dev/null 2>&1

#           only if DBA load process has no errors will we get here

#           notify the MDA support pager that processing complete for client

            echo "email notifying MDA support claims sum rebuild completed" >> $LOG_FILE               
            print "CLAIMS_SUM rebuild Processing for $RUN_MODE claims processing has finished. " > $MAILFILE

            MAIL_SUBJECT="MDA PROCESS TCLAIMS_SUM rebuild ended"
            $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1

#           clean up the ftp staging area since we're done, we no longer need the input
#           file, anyways analystics team has a copy if needed
#            rm $FTP_STAGING_DIR/$OLD_DATAFILE
#            if [[ $? != 0 ]] then
#               echo "problems removing $STAGING_DIR " >> $LOG_FILE
#            fi
                  
#           clean up the processing staging area since we're done, we no longer need the input
#           file, anyways analystics team has a copy if needed
            rm $STAGING_DIR/*claims*
            if [[ $? != 0 ]] then
               echo "problems removing $STAGING_DIR/*claims* file " >> $LOG_FILE
            fi
#           clean up the processing staging area since we're done, we no longer need the input
#           file, anyways analystics team has a copy if needed
            rm $FTP_STAGING_DIR/*control.$DATE_OF_FILE*
            if [[ $? != 0 ]] then
               echo "problems removing $FTP_STAGING_DIR/control.$DATE_OF_FILE* " >> $LOG_FILE
            fi
         fi

#        update the status for the client for this current process run, regardless of claims sum rebuild 
         print "completed" > $RUN_STATUS
                    
     else 
         echo "problems in DBA loading of claims " >> $LOG_FILE
         print "investigate dba load process... problems" \
               "for $RUN_MODE claims load " > $MAILFILE
         
         MAIL_SUBJECT="DBA autoloader has problems"
         $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>$1  
   
     fi
   fi      

  echo "\n***********************************************"   >> $LOG_FILE
  echo "TCLAIMS $RUN_MODE claims intake processing ENDED."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

   return
