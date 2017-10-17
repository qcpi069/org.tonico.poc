#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_ncpdp_tape_verification_rpting.ksh
# Description  = Based upon the NCPDP file appearing, this script
#                will copy the files to the user NT area via FTP and 
#                delete the files from the source area.
# Author       = Kurt Gries 
# Date Written = July 24, 2002
#
#=====================================================================
# 04-10-03    K. Gries    modified to send new txt files to the Report Directory
#                         and send the zip files to the Data Directory.
#
# 10-01-02    K. Gries    added rbate_email_base.ksh call.
#
#----------------------------------
# Caremark Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh

# Clean up old files that have been archived previously
rm -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
rm -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
rm -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.dat
rm -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat


print ' ... Starting rbate_ncpdp_tape_verification_rpting.ksh ... ' >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log

#Export the variables needed for the source file location and the NT Server
export FTP_NT_IP=AZSHISP00 

if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export REPORT_DIR=reporting_prod/rebates/data
     export DATA_DIR=rbate2
     export SRC_FILE_DIR=/staging/apps/rebates/prod/rebateengine/output
   else  
     export REBATES_DIR=rebates_integration
     export REPORT_DIR=reporting_test/rebates/data
     export DATA_DIR=rbate2/TEST
     export SRC_FILE_DIR=/staging/apps/rebates/dev3/rebateengine/output
fi

# Change directory to the location of the source NCPDP file
cd $SRC_FILE_DIR

#============================================================================
# get a list of the NCPDP trigger file names into a readable file.
#
# read the file and create FTP commands to send their related zip and txt file
#      to their intended destinations.
#   txt files go to the Report Directory.
#   zip files go to the Data Directory.
#   
# create a file of filenames that are being transmitted.
#
# at end of the loop call the FTP routine to use these commands
#
# read the file of transmitted filenames and perform remove (rm) commands 
#      against each of the files in order to delete them and save space
#============================================================================

NCPDP_RC=0
ls *ncpdp.trg >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.dat

while read NCPDPfile_name; do

    print ' '         >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
    print $NCPDPfile_name >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
    print ' '         >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log

    export NCPDPfile_base=${NCPDPfile_name%%_ncpdp.trg}

    export NCPDP_D_FILE_IN=$NCPDPfile_base'D_ncpdp.zip'
    export NCPDP_M_FILE_IN=$NCPDPfile_base'M_ncpdp.zip'
    export NCPDP_DS_FILE_IN=$NCPDPfile_base'ds_ncpdp.txt'
    export NCPDP_MS_FILE_IN=$NCPDPfile_base'ms_ncpdp.txt'

    export NCPDP_D_FILE_OUT='NCPDP_TAPE_VERF_'$NCPDPfile_base'D.zip'
    export NCPDP_M_FILE_OUT='NCPDP_TAPE_VERF_'$NCPDPfile_base'M.zip'
    export NCPDP_DS_FILE_OUT='ncpdp_DFile_Ver_f_'$NCPDPfile_base'ds.txt'
    export NCPDP_MS_FILE_OUT='ncpdp_MFile_Ver_f_'$NCPDPfile_base'ms.txt'

    
    if [[ -w $NCPDPfile_name ]]; then

      print 'FTPing ' $NCPDP_FILE_OUT ' to ' $FTP_NT_IP '/' $REPORT_DIR            >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print 'cd /'$REBATES_DIR                                                     >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'cd '$REPORT_DIR                                                       >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'ascii'                                                                >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'put ' $SRC_FILE_DIR/$NCPDP_DS_FILE_IN $NCPDP_DS_FILE_OUT ' (replace'  >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'put ' $SRC_FILE_DIR/$NCPDP_MS_FILE_IN $NCPDP_MS_FILE_OUT ' (replace'  >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'cd /'$REBATES_DIR                                                     >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'cd '$DATA_DIR                                                         >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'binary'                                                               >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'put ' $SRC_FILE_DIR/$NCPDP_D_FILE_IN $NCPDP_D_FILE_OUT ' (replace'    >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
      print 'put ' $SRC_FILE_DIR/$NCPDP_M_FILE_IN $NCPDP_M_FILE_OUT ' (replace'    >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt

      print $SRC_FILE_DIR/$NCPDPfile_name                                          >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat
      print $SRC_FILE_DIR/$NCPDP_D_FILE_IN                                         >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat
      print $SRC_FILE_DIR/$NCPDP_M_FILE_IN                                         >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat
      print $SRC_FILE_DIR/$NCPDP_DS_FILE_IN                                        >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat
      print $SRC_FILE_DIR/$NCPDP_MS_FILE_IN                                        >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat

      NCPDP_RC=0             
    else
      print "===================== J O B  A B E N D I N G ====================   " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "                                                                    " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "  MS Summary text file is not writeable.                            " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "  Abending because we will not be able to delete the file after FTP " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "  Fix permission to -rw-rw-rw (666) at a minimum for file           " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "  " $SRC_FILE_DIR/$NCPDPfile_name                                     >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "  Then restart this script from the beginning.                      " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "                                                                    " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "=================================================================   " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log 
      print "  Look in "$OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log       >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      print "=================================================================   " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
      NCPDP_RC=1
      exit
    fi  

done < $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.dat

if [[ $NCPDP_RC = 0 ]]; then  
    print 'quit' >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt
    ftp -i  $FTP_NT_IP < $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
    NCPDP_RC=$?
fi

if [[ $NCPDP_RC = 0 ]]; then
    while read NCPDPfile_name; do
        print 'Removing ' $NCPDPfile_name >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log  
        rm $NCPDPfile_name
    done < $OUTPUT_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat
fi

mv -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat $LOG_ARCH_PATH/rbate_ncpdp_tape_verification_files_to_delete.dat.`date +"%Y%j%H%M"`
mv -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.dat           $LOG_ARCH_PATH/rbate_ncpdp_tape_verification_files.dat.`date +"%Y%j%H%M"`
mv -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt     $LOG_ARCH_PATH/rbate_ncpdp_tape_verification_ftpcommands.txt.`date +"%Y%j%H%M"`


# Set the return code for abend checking.

if [[ $NCPDP_RC != 0 ]]; then
   RC=$NCPDP_RC
else
   RC=0
fi
  

if [[ $RC != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "  Error Executing rbate_ncpdp_tape_verification_rpting.ksh        " >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "  Look in "$OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log       >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "=================================================================" >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
         
# Send the Email notification 
   export JOBNAME="RIHR4200 / RI_4200J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_ncpdp_tape_verification_rpting.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_ncpdp_tape_verification_files.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log                      $LOG_ARCH_PATH/rbate_ncpdp_tape_verification_files.log.`date +"%Y%j%H%M"`
   exit RC
fi

print '....Completed executing rbate_ncpdp_tape_verification_rpting.ksh ....' >> $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log
mv -f $OUTPUT_PATH/rbate_ncpdp_tape_verification_files.log                       $LOG_ARCH_PATH/rbate_ncpdp_tape_verification_files.log.`date +"%Y%j%H%M"`
