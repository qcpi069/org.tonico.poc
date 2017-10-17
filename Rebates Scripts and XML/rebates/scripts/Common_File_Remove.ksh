#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_File_Remove.ksh
# Title         : Removes files based on directory name and file name passed.
#
# Parameters    :  
#                 -d directory  i.e. Relative directory path i.e. relative to $REBATES_HOME
#                 -f filename   i.e. File Name Suffix (without extension)
#                 -e extension  i.e. Extension of file without dot
#                 -t datePassed i.e. Date YYYYMMDD format  (Optional argument)
#                 -m email      i.e. email ID without @caremark.com  (Optional argument)
#		  -i input filetype i.e. indirect (Optional argument)
#
# Description   : The script will remove files using the <directory>/<filename>*.<extension>
#                 if date is passed then delete only files older than the passed date. 
#                 if additional email ID is passed then sent the failure message to this email ID.
#		  input filetype defines whether to delete the file name passed or list of files in the file name passed to script
#
# Output        : Log file as $LOG_FILE
#
# Input Files   : /opt/pcenter/<env>/rebates/TgtFiles
#                 where env is dev1/dev2 or sit1/sit2 or prod
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 03-21-14   qcpuk218    Initial Creation 
#                        ITPR005898 State of NY - Rebates Payment
# 03-31-16   qcpue98u    ITPR020090 - PBMDW migration. Changes to support indirect file removal
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
   else 
        mailx -s "$EMAIL_SUBJECT" -c $CC_EMAIL_LIST $TO_MAIL  < $LOG_FILE
   fi
   
   cp -f $LOG_FILE $LOG_FILE_ARCH
   rm -f $DATA_FILE
   exit $RETCODE
}

#-------------------------------------------------------------------------#
# Function to check if date is a valid date in YYYYMMDD format
#-------------------------------------------------------------------------#
function validate_date {
   DATE=$1
   isDateValid=0      # default value set to 0
   typeset -i day     #setting day variable of integer type
   
   #extracting Year, Month and day part from the date passed. 
   eval $(echo $DATE | sed 's/^\(....\)\(..\)\(..\)/year=\1 month=\2 day=\3/')
   
   # Print calendar value of date passed and see the day is present in the calendar for that month. 
   # If day is present then it is a valid date else it is a invalid date. 
   # For example, If date passed is 20140201 then 
   # cal $month $year will give "February 2014 Su Mo Tu We Th Fr Sa 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28"
   # grep -w $day will search for date 1st feb in the string. If 1st is a valid day then it is present in the calendar entry else it is an error.  

   cal $month $year | grep -w $day > /dev/null
   if [[ $? -eq 0 ]] ; then
           isDateValid=1
   else
           isDateValid=0
   fi
   export isDateValid
}

#-------------------------------------------------------------------------#
# Main Processing starts 
#-------------------------------------------------------------------------#

# Set Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")

# Set file path and names
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
DATA_FILE=${OUTPUT_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".data"

# Remove log file if present
rm -f $LOG_FILE
rm -f $DATA_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "********************************************"     >> $LOG_FILE
print "Starting the script $SCRIPTNAME ............"     >> $LOG_FILE
print `date +"%D %r %Z"`                                 >> $LOG_FILE
print "********************************************"     >> $LOG_FILE

directory=''      # set default value to blank before assigning
filename=''       # set default value to blank before assigning
extension=''      # set default value to blank before assigning 
CC_EMAIL_LIST=''  # set default value to blank before assigning
datepassed=''     # set default value to blank before assigning

# Assign values to variable from arguments passed
while getopts d:f:e:t:m:i: argument
do
      case $argument in
          d)directory=$REBATES_HOME/$OPTARG;;
          f)filename=$OPTARG;;
          e)extension=$OPTARG;;
          t)datePassed=$OPTARG;;
          m)CC_EMAIL_LIST=$OPTARG@caremark.com;;
	  i)inpfiletype=$OPTARG;;
          *)
            echo "\n Usage: $SCRIPTNAME -d -f -e [-t] [-m] [-i]"                                                       >> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -d TgtFiles -f NYS.Rebates.2014Q1 -e txt -t 20140303 -m navneet.deswal" >> $LOG_FILE
            echo "\n -d <Directory> Relative directory path i.e. relative to $REBATES_HOME"                       >> $LOG_FILE
            echo "\n -f <File Name> File name suffix (without extension) that needs to be deleted"                >> $LOG_FILE
            echo "\n -e <Extension> Extension of file without dot"                                                >> $LOG_FILE
            echo "\n -t <Date passed> Script will delete file older than this date"                               >> $LOG_FILE
            echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"   >> $LOG_FILE
            echo "\n -i <direct/indirect> Filetype to remove the filename passed or list of files inside the passed filename"   >> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done

print " "                                    >> $LOG_FILE
print " Parameters passed for current run "  >> $LOG_FILE
print " Directory path     : $directory"     >> $LOG_FILE
print " File Name prefix   : $filename"      >> $LOG_FILE
print " Extension of file  : $extension"     >> $LOG_FILE
print " Date Passed        : $datePassed"    >> $LOG_FILE
print " Alternate Email ID : $CC_EMAIL_LIST" >> $LOG_FILE
print " Alternate Email ID : $CC_EMAIL_LIST" >> $LOG_FILE
print " Input File Type    : $inpfiletype"   >> $LOG_FILE
print " " >> $LOG_FILE
      
if [[ $directory = '' || $filename = '' || $extension = '' ]]; then
      RETCODE=1
      echo "\n Usage: $SCRIPTNAME -d -f -e [-t] [-m]"                                                       >> $LOG_FILE
      echo "\n Example: $SCRIPTNAME -d TgtFiles -f NYS.Rebates.2014Q1 -e txt -t 20140303 -m navneet.deswal" >> $LOG_FILE
      echo "\n -d <Directory> Relative directory path i.e. relative to $REBATES_HOME"                       >> $LOG_FILE
      echo "\n -f <File Name> File name suffix (without extension) that needs to be deleted"                >> $LOG_FILE
      echo "\n -e <Extension> Extension of file without dot"                                                >> $LOG_FILE
      echo "\n -t <Date passed> Script will delete file older than this date"                               >> $LOG_FILE
      echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"   >> $LOG_FILE
      echo "\n -i <input filetype - direct/indirect - optional parameter"                                   >> $LOG_FILE
      exit_error ${RETCODE} "Incorrect arguments passed"
fi

lcinpfiletype=$( echo "$inpfiletype" | tr -s  '[:upper:]'  '[:lower:]' )

if [[ $datePassed -ne '' ]]; then

      # Check format of date passed. It should be YYYYMMDD only
      validate_date $datePassed
       
      if [[ isDateValid -eq 0 ]]; then
          print "Incorrect date format passed - ${datePassed}. Please enter date in YYYYMMDD format only"    
          exit_error 1 "Incorrect date format passed - ${datePassed}. Please enter date in YYYYMMDD format only"
      fi 
      
      touch -t ${datePassed}0000.01 $DATA_FILE

      if [[ $lcinpfiletype = 'indirect' ]]; then

       while read delfile;
        do
	  print "Removing below mentioned files ....................." >> $LOG_FILE
	  find ${directory} -name $delfile -type f ! -newer $DATA_FILE -exec ls -l {} \;   >> $LOG_FILE
          find ${directory} -name $delfile -type f ! -newer $DATA_FILE -exec rm -f {} \; 
		if [[ $? != 0 ]]; then
        	       print "Problem removing the file $delfile in indirect file ${filename}.${extension} with date parameter and indirect file" >> $LOG_FILE 
			exit_error 1
        	fi

        done < "${directory}/${filename}.${extension}"

       else

              print "Removing below mentioned files ....................." >> $LOG_FILE
              find ${directory} -name ${filename}*.${extension} -type f ! -newer $DATA_FILE -exec ls -l {} \;  >> $LOG_FILE
              find ${directory} -name ${filename}*.${extension} -type f ! -newer $DATA_FILE -exec rm -f {} \;
                      if [[ $? != 0 ]]; then
                        print "Problem removing the file ${filename}*.${extension}" >> $LOG_FILE
                        exit_error 1
                      fi
       fi

elif [[ $lcinpfiletype = 'indirect' ]]; then

       print "Removing below mentioned files .....................\n" >> $LOG_FILE

       while read delfile;
	do
	 print "${directory}/$delfile"					     >> $LOG_FILE 
	 rm -f ${directory}/$delfile;
  	
	 if [[ $? != 0 ]]; then
          	print "Problem removing the file $delfile in indirect file ${filename}*.${extension} without date parameter but indirect file" >> $LOG_FILE
       		exit_error 1
   	fi
		
	done < "${directory}/${filename}.${extension}"

else
     
     print "Removing below mentioned files ....................."  >> $LOG_FILE
     ls -ltr ${directory}/${filename}*.${extension}                >> $LOG_FILE

     # Removing temporary files
     rm -f ${directory}/${filename}*.${extension}

	if [[ $? != 0 ]]; then
          	print "Problem removing the file in ${directory} with matching pattern" >> $LOG_FILE
       		exit_error 1
   	fi

fi

print "********************************************"    >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."    >> $LOG_FILE
print `date +"%D %r %Z"`                                >> $LOG_FILE
print "********************************************"    >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH
rm -f $DATA_FILE
exit $RETCODE

#-------------------------------------------------------------------------#
# End of Script
#-------------------------------------------------------------------------#

