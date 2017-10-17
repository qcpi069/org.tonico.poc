#!/usr/bin/ksh

echo "Process begins - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Getting file for $RUN_MODE claims load from ftp staging directory" \
     "$FTP_STAGING_DIR.."

SCRIPT_NAME=`basename $0`

#------------------------------------------------------------------
#CHECK IF FILE IN FTP-STAGING DIRECTORY IS STILL BEING FTP'D
#IF SO, WAIT TILL IT BECOMES INACTIVE
#------------------------------------------------------------------

  touch $TEMP_DIR/ftp_temp_new
  sleep 5
  
  
  find $FTP_STAGING_DIR -name "*claims*" \
        -newer $TEMP_DIR/ftp_temp_new         \
        > $TEMP_DIR/ftp_temp_newest

  while [[ -s $TEMP_DIR/ftp_temp_newest ]]
  do
  
     touch $TEMP_DIR/ftp_temp_new
     sleep 5
  
     find $FTP_STAGING_DIR -name "*claims*" \
           -newer $TEMP_DIR/ftp_temp_new         \
           > $TEMP_DIR/ftp_temp_newest
  
  done
  
#------------------------------------------------------------------
#CHECK FOR NO OF FILES STARTING WITH CLIENT NAME
#IF THERE ARE NO FILES OR MORE THAN ONE FILE PRESENT,
#E-MAIL TO IS GROUP AND CONTRACT ADMIN AS WELL AND STOP PROCESS
#------------------------------------------------------------------

  NO_OF_FILES=`ls -1 $FTP_STAGING_DIR/*claims* | wc -l`

  if [[ $NO_OF_FILES -eq 0 ]] then
  
#       This is no longer an error since the assumption when this         
#       script is run that a file MUST exist is not true... this 
#       script will be run multiple times via cron until we get a
#       file and initiate monthly processing

        echo "Did not find any file for $RUN_MODE processing yet"  >> $LOG_FILE
        
        return 1
  
  else
  
     if [[ $NO_OF_FILES -ne 1 ]] then
  
        echo "Script: $SCRIPT_NAME"                                   \
             "\nProcessing for $RUN_MODE claims intake Failed:"       \
             "\nFtp staging directory has more than one claims file"  \
             "\nLook for Log file $LOG_FILE" > $MAILFILE

        MAIL_SUBJECT="MDA claims intake PROCESS"
        $SCRIPT_DIR/mailto_IS_group.ksh

        exit 2
  
     fi
  
  fi
  
#------------------------------------------------------------------

  OLD_DATAFILE=`ls -1 $FTP_STAGING_DIR/*claims*`
  OLD_DATAFILE=`basename $OLD_DATAFILE`
  
  echo "File named $OLD_DATAFILE was obtained.."
  
  echo $OLD_DATAFILE > $DATA_FILE_NAME_FILE

#------------------------------------------------------------------

  echo "Moving file into MDA staging directory $STAGING_DIR.."

  mv $FTP_STAGING_DIR/$OLD_DATAFILE* $STAGING_DIR/$OLD_DATAFILE

  if [[ $? != 0 ]] then

     echo "ERROR: File could not be moved to MDA staging directory..." >>$LOG_FILE

     echo "Script: $SCRIPT_NAME"                                 \
          "\nProcessing for $RUN_MODE claims intake Failed:"                \
          "\nFile could not be moved to MDA staging directory"   \
          "\nLook for Log file $LOG_FILE" > $MAILFILE

     MAIL_SUBJECT="MDA claims intake PROCESS"
     $SCRIPT_DIR/mailto_IS_group.ksh
     exit 3
  fi
#---------------------------------------------------------------------------------
#  echo "File was moved to MDA staging dir... creating copy for processing"

#  echo ${OLD_DATAFILE} | cat | cut -f3 -d\. > $TEMP_PRCS_MONYYYY
#  echo ${CLIENT_NAME} | cat > $TEMP_CLIENT_NAME
#  echo `date +'%m%d%Y'`".dat."`date +'%Y%m%d%H%M%S'` | cat > $TEMP_PRCS_TIMESTMP#

#  paste -d. $TEMP_CLIENT_NAME $TEMP_PRCS_MONYYYY $TEMP_PRCS_TIMESTMP \
#                > $TEMP_PRCS_FILE_NAME

# create file name in a format that DFO expects/requires
#  CLIENT_DFO_FILE=$(cat $TEMP_PRCS_FILE_NAME)

#  echo "DFO file name just created " $CLIENT_DFO_FILE >>$LOG_FILE    
#  cp $STAGING_DIR/$OLD_DATAFILE $STAGING_DIR/$CLIENT_DFO_FILE
#  if [[ $? != 0 ]] then

#     echo "ERROR: File could not be copied for DFO processing.." >>$LOG_FILE

#     echo "Script: $SCRIPT_NAME"                               \
#          "\nProcessing for $CLIENT_NAME Failed:"              \
#          "\nFile could not be copied for DFO processing"      \
#          "\nLook for Log file $LOG_FILE" > $MAILFILE

#     MAIL_SUBJECT="DFO PROCESS"
#     $SCRIPT_DIR/mailto_IS_group.ksh
#     exit 4
#  fi

# create a compressed backup of the input file in case a rerun is needed
#  mv $STAGING_DIR/$OLD_DATAFILE $STAGING_DIR/$OLD_DATAFILE.$THIS_TIMESTAMP
#  if [[ $? != 0 ]] then

#     echo "WARNING: File could not be moved before compress processing..." >>$LOG_FILE

#     echo "Script: $SCRIPT_NAME"                                   \
#          "\nProcessing for $CLIENT_NAME had a problem:"           \
#          "\nFile could not be moved for compression processing"   \
#          "\nLook for Log file $LOG_FILE" > $MAILFILE

#     MAIL_SUBJECT="DFO PROCESS warning"
#     $SCRIPT_DIR/mailto_IS_group.ksh
#     return 5
#  fi
  
#  echo "Compressing $STAGING_DIR/$OLD_DATAFILE.$THIS_TIMESTAMP into $COMPRESSED_FTP_DIR"
#  compress $STAGING_DIR/$OLD_DATAFILE.$THIS_TIMESTAMP
#  if [[ $? != 0 ]] then

#     echo "WARNING: FTP input file was not successfully compressed..." >>$LOG_FILE

#     echo "Script: $SCRIPT_NAME"                                   \
#          "\nProcessing for $CLIENT_NAME had a problem:"           \
#          "\nFile could not be successfully cmpressed"             \
#          "\nLook for Log file $LOG_FILE" > $MAILFILE

#     MAIL_SUBJECT="DFO PROCESS warning"
#     $SCRIPT_DIR/mailto_IS_group.ksh
#     return 6
#  fi

#  mv $STAGING_DIR/$OLD_DATAFILE.$THIS_TIMESTAMP.Z  $COMPRESSED_FTP_DIR
#  if [[ $? != 0 ]] then

#     echo "WARNING: Compressed FTP input file could not be moved..." >>$LOG_FILE

#     echo "Script: $SCRIPT_NAME"                                   \
#          "\nProcessing for $CLIENT_NAME had a problem:"           \
#          "\nFile could not be moved after compression processing"   \
#          "\nLook for Log file $LOG_FILE" > $MAILFILE

#     MAIL_SUBJECT="DFO PROCESS warning"
#     $SCRIPT_DIR/mailto_IS_group.ksh
#     return 7
#  fi
  
#------------------------------------------------------------------
# CHECK FOR NUMBER OF FILES STARTING WITH CLIENT NAME IN 
# STAGING DIRECTORY.  IF THERE IS MORE THAN ONE FILE PRESENT
# E-MAIL TO IS GROUP AND STOP PROCESS.
# THIS MIGHT HAPPEN ON A RE-RUN, WHEN THE OLD FILE HAS NOT BEEN 
# PROPERLY CLEANED UP (PRECAUTIONARY CHECK)
#------------------------------------------------------------------

  NO_OF_FILES=`ls -1 $STAGING_DIR/*claims* | wc -l`
  
  if [[ $NO_OF_FILES -ne 1 ]] then
  
      echo "Script: $SCRIPT_NAME"                                 \
           "\nProcessing for $RUN_MODE claims intake Failed:"     \
           "\n$STAGING_DIR has more than one file for"            \
           "\nLook for Log file $LOG_FILE" > $MAILFILE

      MAIL_SUBJECT="MDA claims intake PROCESS"
      $SCRIPT_DIR/mailto_IS_group.ksh

      exit 2
  fi
  
#  OLD_DATAFILE=`ls -1 $STAGING_DIR/*claims*`
#  OLD_DATAFILE=`basename $OLD_DATAFILE`
    
#  echo "File named $OLD_DATAFILE was obtained.."
#  echo $OLD_DATAFILE > $DATA_FILE_NAME_FILE
  
  
  echo "Process Successful."
  echo "Process ended - `date +'%b %d, %Y %H:%M:%S'`......."
