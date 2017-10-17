#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_PICO_prdct_cmpr_rpt_rpting.ksh
# Description  = Based upon TRIGGER file appearing, this script
#                will move the new files to a storage directory
#                from the Oracle writable directory, copy the files
#                to the user NT area via FTP and delete the TRIGGER.
# Author       = Kurt Gries 
# Date Written = June 25, 2002
#
#=====================================================================
# 10-01-02    K. Gries    added rbate_email_base.ksh call.
#
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh

rm -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
rm -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt
rm -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.dat

print ' ... Starting rbate_PICO_prdct_cmpr_rpt_rpting.ksh ... ' >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log

export ORA_UTL_FILE_DIR=/staging/rebate2
export FTP_NT_IP=AZSHISP00 

if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export REPORT_DIR=reporting_prod/rebates/data
   else  
     export REBATES_DIR=rebates_integration
     export REPORT_DIR=reporting_test/rebates/data
fi
cd $ORA_UTL_FILE_DIR

export MoreFiles=TRUE

while [[ $MoreFiles = "TRUE" ]]; do

  ls PICO_prdct_cmpr_rpt_*.trigger >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.dat

  export FilesLeft=FALSE

  while read file_name; do

    print ' '        >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
    print $file_name >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
    print ' '        >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log

    export MATCH_VALUE=$file_name
    export FILE_BASE=${MATCH_VALUE%%.*}
    export FILE_OUT=$FILE_BASE'_extract.txt'
    export FILE_OUT2=$FILE_BASE'.txt'

    if [[ -w $file_name ]]; then

      print 'FTPing ' $FILE_OUT ' to ' $FTP_NT_IP  >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
      print 'cd /'$REBATES_DIR                                   >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt
      print 'cd '$REPORT_DIR                                    >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt
      print 'put ' $OUTPUT_PATH/$FILE_OUT $FILE_OUT ' (replace' >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt
  
      print 'Moving ' $ORA_UTL_FILE_DIR/$FILE_OUT ' to ' $OUTPUT_PATH/$FILE_OUT >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
      mv $FILE_OUT $OUTPUT_PATH/$FILE_OUT
      mv $FILE_OUT2 $OUTPUT_PATH/$FILE_OUT2

      print 'Removing ' $ORA_UTL_FILE_DIR/$FILE_BASE'.trigger' >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log  
      rm $FILE_BASE'.trigger'
     
    else
      export FilesLeft=TRUE
    fi  

  done < $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.dat
  
  if [[ $FilesLeft = "TRUE" ]]; then

    mv -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.dat       $LOG_ARCH_PATH/rbate_PICO_prdct_cmpr_rpt_files.dat.`date +"%Y%j%H%M"`
    print 'quit' >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt
    ftp -i  $FTP_NT_IP < $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
    mv -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt $LOG_ARCH_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt.`date +"%Y%j%H%M"`

    print "*********************************************************" >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
    print "** There are more files that are not in rw- mode, yet. **" >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
    print "** date/time is " "$(date +%m)/$(date +%d)/$(date +%Y)" "/" "$(date +%r)"  >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log 
    print "** Sleeping for 300 seconds                            **" >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
    print "*********************************************************" >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
    sleep 300 

  else

    print 'quit' >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt
    ftp -i  $FTP_NT_IP < $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
    export MoreFiles=False

  fi  

done

mv -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.dat       $LOG_ARCH_PATH/rbate_PICO_prdct_cmpr_rpt_files.dat.`date +"%Y%j%H%M"`
mv -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt $LOG_ARCH_PATH/rbate_PICO_prdct_cmpr_rpt_ftpcommands.txt.`date +"%Y%j%H%M"`

RC=$?

if [[ $RC != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "  Error Executing rbate_PICO_prdct_cmpr_rpt_rpting.ksh        " >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "  Look in "$OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log       >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "=================================================================" >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
         
# Send the Email notification 
   export JOBNAME="RIDY3000 / RI_3200J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_PICO_prdct_cmpr_rpt_rpting.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_PICO_prdct_cmpr_rpt_files.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log                      $LOG_ARCH_PATH/rbate_PICO_prdct_cmpr_rpt_files.log.`date +"%Y%j%H%M"`
   exit RC
fi

print '....Completed executing rbate_PICO_prdct_cmpr_rpt_rpting.ksh ....' >> $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log
mv -f $OUTPUT_PATH/rbate_PICO_prdct_cmpr_rpt_files.log                       $LOG_ARCH_PATH/rbate_PICO_prdct_cmpr_rpt_files.log.`date +"%Y%j%H%M"`
