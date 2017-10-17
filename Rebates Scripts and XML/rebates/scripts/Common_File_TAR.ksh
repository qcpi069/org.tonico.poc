#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_File_TAR.ksh
# Title         : Archives files in TAR format based on directory name and file name passed.
#
# Parameters    :  
#                 -s source directory  i.e. Relative directory path i.e. relative to $REBATES_HOME
#                 -f filename   i.e. (indirect file with list of files to archive or file name pattern)
#		  -i input filetype i.e. (indirect/pattern)  
#                 -o output directory  i.e. Relative directory path i.e. relative to $REBATES_HOME
#                 -t tar filename  (with/without tar extension)
#		  -m email id <otpional>
#
# Description   : The script will archive the files in tar file format using the <directory>/<filename>* when the input file type is "pattern"
#		  archive the files from the indirect file using the <directory>/<filename>, when the input file type is "indirect"
#                 if additional email ID is passed then sent the failure message to this email ID.
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 07-17-17   qcpue98u    ITPR019305 Rebates System Archiving 
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
   EMAIL_SUBJECT=$SCRIPTNAME" Abended in "$REGION" "`date`

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR
        print " "
        print " !!! Aborting !!!"
        print " "
        print "Return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`
   } >> $LOG_FILE

   # Check if error message needs to be CCed (when email ID is passed)
   if [[ $CC_EMAIL_LIST = '' ]]; then
        mailx -s "$EMAIL_SUBJECT" $TO_MAIL  < $LOG_FILE
        echo ''
   else 
        mailx -s "$EMAIL_SUBJECT" -c $CC_EMAIL_LIST $TO_MAIL  < $LOG_FILE
	echo ''
   fi
   
   exit $RETCODE
}


#-------------------------------------------------------------------------#
# Main Processing starts 
#-------------------------------------------------------------------------#

# Set Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")

PRCS_ID=$$

# Set file path and names
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')"_P_ID"$PRCS_ID".log"
 
#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "********************************************"     >> $LOG_FILE
print "Starting the script $SCRIPTNAME ............"     >> $LOG_FILE
print `date +"%D %r %Z"`                                 >> $LOG_FILE
print "********************************************"     >> $LOG_FILE

print "\n PRCS_ID for Script run --- $PRCS_ID "		>> $LOG_FILE


# set default value to blank before assigning

DIRECTORY=''		
FILENAME=''		
INPFILETYPE=''		
OUTDIRECTORY=''		
TARFILE=''		
CC_EMAIL_LIST=''	


# Assign values to variable from arguments passed
while getopts s:f:i:o:t:m: argument
do
      case $argument in
          s)DIRECTORY=$REBATES_HOME/$OPTARG;;
          f)FILENAME=$OPTARG;;
          i)INPFILETYPE=$OPTARG;;
	  o)OUTDIRECTORY=$REBATES_HOME/$OPTARG;;
          t)TARFILE=$OPTARG;;
          m)CC_EMAIL_LIST=$OPTARG@caremark.com;;
          *)
            echo "\n Usage: $SCRIPTNAME -s -f -i -t [-m]"										>> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -s SourceDir -f SourceFile -i indirect/pattern -o outdir -t tarfilename -m firsname.lastname" >> $LOG_FILE
            echo "\n -s <Directory> Relative directory path i.e. relative to $REBATES_HOME"						>> $LOG_FILE
            echo "\n -f <File Name> File name pattern or filename with indirect file list to archive"					>> $LOG_FILE
            echo "\n -i <pattern/indirect> Filetype to arhive files or list of files inside the passed filename"			>> $LOG_FILE
            echo "\n -o <out/Target Directory> Relative directory path i.e. relative to $REBATES_HOME"					>> $LOG_FILE
            echo "\n -t <Tar Filename> Filename with Tar/without Tar extension"								>> $LOG_FILE
            echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"				>> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done

print " "					>> $LOG_FILE
print " Parameters passed for current run "	>> $LOG_FILE
print " Source Directory path: $DIRECTORY"	>> $LOG_FILE
print " File Name: $FILENAME"			>> $LOG_FILE
print " File type: $INPFILETYPE"		>> $LOG_FILE
print " Output Directory path: $OUTDIRECTORY"   >> $LOG_FILE
print " Tar Filename: $TARFILE"			>> $LOG_FILE
print " Alternate Email ID: $CC_EMAIL_LIST"	>> $LOG_FILE


print " " >> $LOG_FILE

if [[ $DIRECTORY = '' || $FILENAME = '' || $INPFILETYPE = '' || $OUTDIRECTORY = '' || $TARFILE = '' ]]; then
      RETCODE=1
            echo "\n Usage: $SCRIPTNAME -s -f -i -t [-m]"										>> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -s SourceDir -f SourceFile -i indirect/pattern -o outdir -t tarfilename -m firsname.lastname" >> $LOG_FILE
            echo "\n -s <Directory> Relative directory path i.e. relative to $REBATES_HOME"						>> $LOG_FILE
            echo "\n -f <File Name> File name pattern or filename with indirect file list to archive"					>> $LOG_FILE
            echo "\n -i <pattern/indirect> Filetype to arhive files or list of files inside the passed filename"			>> $LOG_FILE
            echo "\n -o <out/Target Directory> Relative directory path i.e. relative to $REBATES_HOME"					>> $LOG_FILE
            echo "\n -t <Tar Filename> Filename with Tar/without Tar extension"								>> $LOG_FILE
            echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"				>> $LOG_FILE
      exit_error ${RETCODE} "Incorrect arguments passed"
fi

INPFILETYPE=$( echo "$INPFILETYPE" | tr -s  '[:upper:]'  '[:lower:]' )


#---------------------------------------------------------------------------------------------------------------#
# Build the variables for the tar file. 
# Even if a wrong extension was passed, script will generate the tar file name with filename passed to -t switch
# FNAME - stores the filename without extension
# EXTN - stores the file extension
#----------------------------------------------------------------------------------------------------------------#

FNAME="${TARFILE%.*}"
EXTN="${TARFILE##*.}"
EXTN=$( echo "$EXTN" | tr -s  '[:upper:]'  '[:lower:]' )


if [[ $EXTN != 'tar' ]]; then

	TARFILENAME=$FNAME".tar"

else

	TARFILENAME=$TARFILE
fi

#-------------------------------------------------------------------------#
# Validate Source and Output directory existence
#-------------------------------------------------------------------------#

print "Validate Source and Output directories existence"											>> $LOG_FILE
                if [[ -d ${DIRECTORY} ]]; then
                      print "  Source Directory - ${DIRECTORY} "										>> $LOG_FILE
                else
                      exit_error 1 "Source Directory path incorrect or not available - ${DIRECTORY}"
                fi

	        if [[ -d ${OUTDIRECTORY} ]]; then
                      print " Output Directory - ${OUTDIRECTORY} "										>> $LOG_FILE
                else
		      exit_error 1  "Output Directory path incorrect or not available - ${OUTDIRECTORY}"
                fi

#--------------------------------------------------------------------------------#
# Archive Steps, on successful archive remove source files and any support files
#--------------------------------------------------------------------------------#

if [[ $INPFILETYPE = 'indirect' ]]; then

	if [[ -s ${DIRECTORY}/${FILENAME} ]]; then
	      print "Files specified in indirect file ${DIRECTORY}/${FILENAME} will be archived"						>> $LOG_FILE
	else
		print "Indirect File - ${DIRECTORY}/${FILENAME} does not exist."								>> $LOG_FILE
      		exit_error 1  "Indirect File - ${DIRECTORY}/${FILENAME} does not exist."         
	fi


        if [[ -s ${OUTDIRECTORY}/${TARFILENAME} ]]; then
              print  "TAR file -- ${TARFILENAME} specified already present in ${OUTDIRECTORY}/${TARFILENAME}"                                    >> $LOG_FILE
              exit_error 1 "TAR file ${tarfilename} specified already present in ${OUTDIRECTORY}/${TARFILENAME}"                                
        fi

   cd ${DIRECTORY}

     print "tar -cvf ${OUTDIRECTORY}/${TARFILENAME} -L ${DIRECTORY}/${FILENAME}" 								>> $LOG_FILE

     tar -cvf ${OUTDIRECTORY}/${TARFILENAME} -L ${DIRECTORY}/${FILENAME}									>> $LOG_FILE

     if [[ $? != 0 ]]; then
	print "Error archiving the files in indirect file ${FILENAME}"										>> $LOG_FILE
	exit_error 1 
     fi

     CNT_IND_FILE=`sed -n '$=' ${DIRECTORY}/${FILENAME}`     
     CNT_TAR_FILE=`tar -tvf ${OUTDIRECTORY}/${TARFILENAME} | wc -l | tr -d ' '`

     if [[ $CNT_IND_FILE != $CNT_TAR_FILE ]]; then

	print "Error archiving counts mismatch"													>> $LOG_FILE
	print "# of Files To archive - $CNT_IND_FILE and # of files in tar - $CNT_TAR_FILE"							>> $LOG_FILE
	exit_error 1
    fi

       print "Removing below mentioned files .....................\n"										>> $LOG_FILE

       while read DELFILE;
        do
         print "$DELFILE"															>> $LOG_FILE
         rm -f $DELFILE

         if [[ $? != 0 ]]; then
                print "Problem removing the file $delfile in indirect file ${FILENAME}"								>> $LOG_FILE
                exit_error 1
        fi

        done < "${DIRECTORY}/${FILENAME}"

	rm -f ${DIRECTORY}/${FILENAME}


else
        LSTFILENAME="Files_"${FILENAME}".lst"

	print "find ${DIRECTORY} ! -path ${DIRECTORY} -prune -type f -name "${FILENAME}*" "			>> $LOG_FILE
        find ${DIRECTORY} ! -path ${DIRECTORY} -prune -type f -name "${FILENAME}*" | awk 'BEGIN{FS="[/]"}{print $(NF)}' > ${DIRECTORY}/${LSTFILENAME}

     if [[ $? != 0 ]]; then
        print "Error writing the tar list file $LSTFILENAME"											>> $LOG_FILE
        exit_error 1
      fi

        if [[ -s ${DIRECTORY}/$LSTFILENAME ]]; then
               print  "Files specified in the  list file ${DIRECTORY}/$LSTFILENAME will be archived"						>> $LOG_FILE	
        else
                print "List File - ${DIRECTORY}/${LSTFILENAME} is ZERO byte. No Files listed in the list file"					>> $LOG_FILE	
                exit_error 1  "List File - ${DIRECTORY}/${LSTFILENAME} is ZERO byte. No Files listed in the list file"
        fi

     
	if [[ -s ${OUTDIRECTORY}/${TARFILENAME} ]]; then 
              print  "TAR file -- ${TARFILENAME} specified already present in ${OUTDIRECTORY}/${TARFILENAME}"				        >> $LOG_FILE
              exit_error 1 "TAR file ${TARFILENAME} specified already present in ${OUTDIRECTORY}/${TARFILENAME}"                                
        fi

     cd ${DIRECTORY}

       print "tar -cvf ${OUTDIRECTORY}/${TARFILENAME} -L ${DIRECTORY}/$LSTFILENAME"								>> $LOG_FILE

        tar -cvf ${OUTDIRECTORY}/${TARFILENAME} -L ${DIRECTORY}/$LSTFILENAME									>> $LOG_FILE

     if [[ $? != 0 ]]; then
        print "Error archiving the files in list file $lstfilename"										>> $LOG_FILE
        exit_error 1
      fi

     CNT_LST_FILE=`sed -n '$=' ${DIRECTORY}/${LSTFILENAME}`
     CNT_TAR_FILE=`tar -tvf ${OUTDIRECTORY}/${TARFILENAME} | wc -l | tr -d ' '`


     if [[ "$CNT_LST_FILE" != "$CNT_TAR_FILE" ]]; then

        print "Error archiving counts mismatch"													>> $LOG_FILE
        print "# of Files To archive - $cnt_lst_file and # of files in tar - $CNT_TAR_FILE"							>> $LOG_FILE
	exit_error 1
     fi

     print "Removing source files .....................\n"											>> $LOG_FILE

     print "find ${DIRECTORY} ! -path ${DIRECTORY} -prune -type f -name "${FILENAME}*" -exec rm -f {} \; "					>> $LOG_FILE

     find ${DIRECTORY} ! -path ${DIRECTORY} -prune -type f -name "${FILENAME}*" -exec rm -f {} \;

     if [[ $? != 0 ]]; then
         print "Problem removing the file ${FILENAME}*"												>> $LOG_FILE
         exit_error 1
     fi

     print "Removing List File .....................\n"												>> $LOG_FILE
   
     print "find ${DIRECTORY}  -path ${DIRECTORY} -prune -type f -name "${LSTFILENAME}" -exec rm -f {} \;" 					>> $LOG_FILE

     find ${DIRECTORY}  -path ${DIRECTORY} -prune -type f -name "${LSTFILENAME}" -exec rm -f {} \;


     if [[ $? != 0 ]]; then
         print "Problem removing the file ${LSTFILENAME}"											>> $LOG_FILE
         exit_error 1
     fi

fi


print "********************************************"												>> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."												>> $LOG_FILE
print `date +"%D %r %Z"`															>> $LOG_FILE
print "********************************************"												>> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH
exit $RETCODE

#-------------------------------------------------------------------------#
# End of Script
#-------------------------------------------------------------------------#


