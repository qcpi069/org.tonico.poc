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

#=================================================================
#GETS FILE NAME FROM FTP STAGING DIRECTORY
#FILE NAME FORMAT IS (in lower case):
#      <client name>.<monyyyy>.<mmddyyyy>.dat.<yyyymmddhhmmss>
#=================================================================

  export OLD_DATAFILE=`head -1 $DATA_FILE_NAME_FILE`
  echo "old_datafile " $OLD_DATAFILE >>$LOG_FILE

  export DATE_OF_FILE="`echo $OLD_DATAFILE | cut -f3 -d "."`"  
  echo "Date of file " $DATE_OF_FILE >>$LOG_FILE

  export DATAFILE="`echo $OLD_DATAFILE | cut -f1-2 -d "."`"
  echo "datafile " $DATAFILE >>$LOG_FILE


#===================================================================
#SORT CLAIMS RECORD BY NABP ID/FILL DATE/NEW REFILL CODE/RX NUMBER
#IN ASCENDING ORDER
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$STAGING_DIR/$OLD_DATAFILE"
  export OUT_DATA_FILE="$TEMP_DATA_DIR/claims.srtbypbid"

  echo "sort file "  >> $LOG_FILE
  echo OUT_DATA_FILE >> $LOG_FILE

  $SCRIPT_DIR/MDA_sortby_pbid_frlyid_filldt.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally..." >>$LOG_FILE
     exit 6
  fi


#===================================================================
# Incentive Type Code addition PROCESS AND CREATE LOAD FILE 
# TO BE LOADED INTO INTERNAL CLAIMS TABLE (TCLAIMS)
#===================================================================

  echo "\n" >> $LOG_FILE

  export IN_DATA_FILE="$TEMP_DATA_DIR/claims.srtbypbid"
  export BILLG_END_DT_OVERRIDE_FILE="$OVERRIDE_DIR/billg_end_dt.ref"
  export LOAD_FILE="$TEMP_DATA_DIR/crteload.load"
  export ERROR_FILE="$TEMP_DATA_DIR/claims.errpt"
  export NON_REBATEABLE_CLAIMS="$TEMP_DATA_DIR/psvnrbt.dat"

  $SCRIPT_DIR/MDA_dwmda069.ksh >>$LOG_FILE 2>&1

  if [[ $? != 0 ]] then
     echo "Process terminated abnormally" >>$LOG_FILE
     exit 9
  fi

#===================================================================

  echo "\n" >> $LOG_FILE

  TIMESTAMP=`date +"%Y%m%d%H%M%S"`
  export DATA_LOAD_FILE="mda.$SCHEMA.tclaims.dat.$THIS_TIMESTAMP$THIS_PROCESS_NO"
#wjptest
###  DATA_LOAD_FILE="mda.vrap.tclaims.dat.T20040518174715"
  typeset -i Load_Return_Code=0
  export Load_Return_Code

  cp -p "$TEMP_DATA_DIR/psvnrbt.dat" $HOME_DIR/nonrebateable_claims/psvnrbt.dat.$DATE_OF_FILE
  if [[ $? != 0 ]] then
         echo "problems moving $TEMP_DATA_DIR/psvnrbt.dat " >> $LOG_FILE

         print "problems moving $TEMP_DATA_DIR/psvnrbt.dat " \
               "to $HOME_DIR/psvnrbt.dat.$DATE_OF_FILE" > $MAILFILE
         
         MAIL_SUBJECT="MDA claims load process problem saving nrbt claims"
         $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>$1  
  fi

  $SCRIPT_DIR/MDA_load.ksh

#wjptest
####    FTP_STATUS=169

  $SCRIPT_DIR/MDA_ftp_to_tsmnim1.ksh >>$LOG_FILE 2>&1

  FTP_STATUS=$?

# 222 is a good return from FTP kornshell... test for dba load script status
  if (($FTP_STATUS==222)); then

      #   informative email to track progress
      echo    "Load Processing for $RUN_MODE claims intake is starting:"   \
              "\nftp of load file to tsmnim1 was good."                   \
              "\nfollow progress in $LOG_FILE" > $MAILFILE
 
      MAIL_SUBJECT="MDA db load PROCESS"
      $SCRIPT_DIR/mailto_IS_group.ksh

      $SCRIPT_DIR/MDA_load_tclaims.ksh >>$LOG_FILE 
     
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
# store dir for this run for cleanup before next run
  print "${TEMP_DIR}"> $CLAIMS_DIR/last_temp_dir
####################exit 0
  $SCRIPT_DIR/MDA_compress_file.ksh $TEMP_DATA_DIR/claims.srtbypbid >>$LOG_FILE 2>&1
  $SCRIPT_DIR/MDA_compress_file.ksh $TEMP_DATA_DIR/crteload.load >>$LOG_FILE 2>&1
  $SCRIPT_DIR/MDA_compress_file.ksh $DATA_LOAD_DIR/$DATA_LOAD_FILE >>$LOG_FILE 2>&1

  echo "\n***********************************************"   >> $LOG_FILE
  echo "TCLAIMS $RUN_MODE claims intake processing ENDED."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

#  cat $LOG_FILE >> $MASTER_LOG

#  if [[ $? = 0 ]] then
#     rm -f $LOG_FILE
#  fi
   return
