#!/usr/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_SFTP_CVS_Secure_Server.ksh
#
# Description   : This script will run on demand basis to pick files from
#                  Rebate Server and the push them to the corresponding directory 
#                  on the Secure File Transport Server.
# Parameters    :  
#                 -d Source directory  i.e. Relative directory path i.e. relative to $REBATES_HOME
#                 -s Source filename   i.e. Source file name (including extension if any)
#                 -f Target filename   i.e. Target file name (including extension if any)
#                 -t Target directory  i.e. Target Directory path on secure server 
#                 -a Archive directory i.e. Archive directory path  (Optional argument)
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 03-21-14   qcpuk218    Initial Creation 
#                        ITPR005898 State of NY - Rebates Payment
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RCI_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=$SCRIPTNAME" Abended In "$REGION" "`date`

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR
        print " "
        print " !!! Aborting!!!"
        print " "
        print "return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`
   }    >> $LOG_FILE

   mailx -s "$EMAIL_SUBJECT" $TO_MAIL  < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE
   
}

#-------------------------------------------------------------------------#
# Function to create SFTP commands
#-------------------------------------------------------------------------#
function Generate_SFTP_Commands {

     SourceDir=$1
     SourceFile=$2 
     TargetDir=$3
     TargetFile=$4

     print "put " ${REBATES_HOME}/${SourceDir}"/"${SourceFile} ${TargetDir}/${TargetFile} >> $FTP_CMD_FILE 
     print "quit" >> $FTP_CMD_FILE
}


#-------------------------------------------------------------------------#
# Main Processing starts 
#-------------------------------------------------------------------------#
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"

FTP_CMD_FILE=$OUTPUT_DIR"/"$FILE_BASE"_ftpcmds.txt"
LOG_FILE_ARCH=${ARCH_LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
RETCODE=0

# Remove log file if present
rm -f $LOG_FILE
rm -f $FTP_CMD_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
{
      print "********************************************"
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
} > $LOG_FILE

# Assign values to variable from arguments passed
while getopts d:s:t:f:a: argument
do
   case $argument in
     d)SourceDir=$OPTARG;;
     s)SourceFile=$OPTARG;;
     t)TargetDir=$OPTARG;;
     f)TargetFile=$OPTARG;;
     a)ArchiveDir=$OPTARG;;
     *)
       echo "\n Usage: $SCRIPTNAME -d <directory> -s <file> -t <directory> -f <file> [-a] <directory>"                            >> $LOG_FILE
       echo "\n Example: $SCRIPTNAME -d TgtFiles -s NYS.Rebates.2014Q1.txt -t /GDX/test -f NYS.Rebates.2014Q1.txt <logs/archive>" >> $LOG_FILE
       echo "\n -d <Source directory> Relative directory path i.e. relative to $REBATES_HOME"                                     >> $LOG_FILE
       echo "\n -s <Source File Name> Source file name"                                                                           >> $LOG_FILE
       echo "\n -t <Target directory> Directory path on secure server"                                                            >> $LOG_FILE
       echo "\n -f <Target File Name> Target file name"                                                                           >> $LOG_FILE
       echo "\n [-a] <Archive Directory Path> Optional argument for archive location relative to $REBATES_HOME"                   >> $LOG_FILE
       exit_error ${RETCODE} "Incorrect arguments passed"
       ;;
   esac
done

print " "                                          >> $LOG_FILE
print " Parameters passed for current run "        >> $LOG_FILE
print " Source Directory path     : $SourceDir"    >> $LOG_FILE
print " Source File Name          : $SourceFile"   >> $LOG_FILE
print " Target Directory path     : $TargetDir"    >> $LOG_FILE
print " Target File Name          : $TargetFile"   >> $LOG_FILE
print " Archive Directory Path    : $ArchiveDir"   >> $LOG_FILE
print " "                                          >> $LOG_FILE
      
if [[ $SourceDir = '' || $SourceFile = '' || $TargetDir = '' || $TargetFile = '' ]]; then
      RETCODE=1
      echo "\n Usage: $SCRIPTNAME -d <directory> -s <file> -t <directory> -f <file> [-a] <directory>"                            >> $LOG_FILE
      echo "\n Example: $SCRIPTNAME -d TgtFiles -s NYS.Rebates.2014Q1.txt -t /GDX/test -f NYS.Rebates.2014Q1.txt <logs/archive>" >> $LOG_FILE
      echo "\n -d <Source directory> Relative directory path i.e. relative to $REBATES_HOME"                                     >> $LOG_FILE
      echo "\n -s <Source File Name> Source file name"                                                                           >> $LOG_FILE
      echo "\n -t <Target directory> Directory path on secure server"                                                            >> $LOG_FILE
      echo "\n -f <Target File Name> Target file name"                                                                           >> $LOG_FILE
      echo "\n [-a] <Archive Directory Path> Optional argument for archive location relative to $REBATES_HOME"                   >> $LOG_FILE
      exit_error ${RETCODE} "Incorrect arguments passed"
fi
     
if [[ -d ${REBATES_HOME}/${SourceDir} ]]; then
      print ""                                                                   >> $LOG_FILE
      print "Source Directory - ${REBATES_HOME}/${SourceDir} "                   >> $LOG_FILE
else
    RETCODE=1
    print "ERROR: Directory path incorrect ${REBATES_HOME}/${SourceDir}"         >> $LOG_FILE
    exit_error $RETCODE " Directory path incorrect ${REBATES_HOME}/${SourceDir}" >> $LOG_FILE
fi

if [[ -s ${REBATES_HOME}/${SourceDir}/${SourceFile} ]]; then
      print "Source File - ${REBATES_HOME}/${SourceDir}/${SourceFile} "          >> $LOG_FILE
else
      RETCODE=1
      print "ERROR: Source file not present or empty - ${REBATES_HOME}/${SourceDir}/${SourceFile}"                  >> $LOG_FILE
      exit_error $RETCODE "Source file is either empty or not present - ${REBATES_HOME}/${SourceDir}/${SourceFile}" >> $LOG_FILE
fi

if [[ $ArchiveDir = '' ]]; then
      print "Archival Directory is not passed so file won't be archived on succesful SFTP tranfer " >> $LOG_FILE    
else 

      if [[ -d ${REBATES_HOME}/${ArchiveDir} ]]; then
            print "Archival Directory - ${REBATES_HOME}/${ArchiveDir} "                             >> $LOG_FILE   
      else 
            RETCODE=1
            print "ERROR: Directory path incorrect ${REBATES_HOME}/${ArchiveDir} "                  >> $LOG_FILE
            exit_error $RETCODE " Directory path incorrect ${REBATES_HOME}/${ArchiveDir}"           >> $LOG_FILE
      fi 
fi
            
Generate_SFTP_Commands $SourceDir $SourceFile $TargetDir $TargetFile

print " SFTP FTP commands "                                                    >> $LOG_FILE
cat $FTP_CMD_FILE                                                              >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "#-------------------------------------------------------------------#"  >> $LOG_FILE
print `date` "SFTP-ing file to Secure FTP Server"     >> $LOG_FILE
print "#-------------------------------------------------------------------#"  >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

sftp -b $FTP_CMD_FILE $SFTP_USER@$SFTP_SERVER                                  >> $LOG_FILE
SFTP_RET_CODE=$?

echo "SFTP RETURN CODE [$SFTP_RET_CODE]"                                       >> $LOG_FILE

if [ $SFTP_RET_CODE = 0 ]
then
      print "File Transfer is Successful ...." >> $LOG_FILE
      # If archival option is set then move the file from source to archival path 
      # (On successful transfer of file only) 
      if [[ $ArchiveDir != '' ]]; then
            ArchiveFile=${REBATES_HOME}/${ArchiveDir}"/"${SourceFile}.`date +"%Y%m%d_%H%M%S"`
            print "Archiving ${REBATES_HOME}/${SourceDir}/${SourceFile} to $ArchiveFile " >> $LOG_FILE
            
            mv ${REBATES_HOME}/${SourceDir}/${SourceFile} $ArchiveFile
            
            RETCODE=$?
        if [[ $RETCODE != 0 ]]; then
             print "Unable to archive ${REBATES_HOME}/${SourceDir}/${SourceFile} to $ArchiveFile " >> $LOG_FILE
             exit_error $RETCODE "Unable to archive ${REBATES_HOME}/${SourceDir}/${SourceFile} to $ArchiveFile"
            fi
      fi  
else
      exit_error $SFTP_RET_CODE "SFTP Command Failed"
fi

mv -f $LOG_FILE $LOG_FILE_ARCH

exit $RETCODE

#-------------------------------------------------------------------------#
# End of script
#-------------------------------------------------------------------------#
