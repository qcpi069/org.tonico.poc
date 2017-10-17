#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_CaRe_Outbound_to_SAP_Interface.ksh
# Title         :
#
# Description   : General Ledger System (SAP) Interface – outbound transactions
#  
# Maestro Job   : GDDY5000/GD_5040J
#
# Parameters    : N/A  
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
#  
# 02-12-09   is31701     Initial Creation
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_GDX_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
    RETCODE=$1
    EMAILPARM4='  '
    EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print 'Sending email notification with the following parameters'

        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"

        print '****** end of email parameters ******'
    }                                                                          >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}


#-------------------------------------------------------------------------#
# Function to ftp data file 
#-------------------------------------------------------------------------#

function run_ftp {
    typeset _FTP_COMMANDS=$(cat)                                         # pulls stdin into a variable
    typeset _FTP_OUTPUT=""
    typeset _ERROR_COUNT=""

    print "Transferring to $FTP_IP using commands:"                            >> $LOG_FILE
    print "$_FTP_COMMANDS"                                                     >> $LOG_FILE
    print ""                                                                   >> $LOG_FILE
    _FTP_OUTPUT=$(print "$_FTP_COMMANDS" | ftp -i -v $FTP_IP)
    RETCODE=$?

    print "$_FTP_OUTPUT"                                                       >> $LOG_FILE

    if [[ $RETCODE != 0 ]]; then
        print "Errors occurred during ftp."                                    >> $LOG_FILE
        exit_error $RETCODE
    fi

    # Parse the ftp output for errors
    # 400 and 500 level replies are errors
    # You have to vilter out the bytes sent message
    # it may say something 404 bytes sent and you don't
    # want to mistake this for an error message.
    _ERROR_COUNT=$(echo "$_FTP_OUTPUT" | egrep -v 'bytes (sent|received)' | egrep -c '^\s*[45][0-9][0-9]')
    if [[ $_ERROR_COUNT -gt 0 ]]; then
        print "Errors occurred during ftp."                                    >> $LOG_FILE
        RETCODE=5
        exit_error $RETCODE
    fi
}

#-------------------------------------------------------------------------#
# Set Script Variables
#-------------------------------------------------------------------------#


if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="QA"
        FTP_IP="sapqd1"
	FTP_PATH="/PCSdrop/PQA/autocash/"
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXITD@caremark.com"
    else
        # Running in Prod region
        SYSTEM="PRODUCTION"
        FTP_IP="sappdb"
        FTP_PATH="/PCSdrop/PPR/autocash/"
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXITD@caremark.com"
    fi
else
    # Running in Development region
    SYSTEM="DEVELOPMENT"
    FTP_IP="sapqd1"
    FTP_PATH="/PCSdrop/PQA/autocash/"
    export ALTER_EMAIL_TO_ADDY="nick.tucker@caremark.com"
    EMAIL_FROM_ADDY=$ALTER_EMAIL_TO_ADDY
fi


# Variables
RETCODE=0
JOBNAME="GD_5040J"
SCHEDULE="GDDY5000"

FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"
COUNT_FILE=$OUTPUT_PATH/$FILE_BASE"_count.dat"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}_${MODEL}.log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

DB2_MSG_FILE=$LOG_FILE.load

FTP_CMDS=$OUTPUT_PATH/$FILE_BASE"_ftpcmds.txt"
SAP_OUTBOUND_FILE=$OUTPUT_PATH/$FILE_BASE"_outbound_SAP.dat"
SAP_OUTBOUND_FILE_ARCH=$OUTPUT_PATH/archive/$FILE_BASE"_outbound_SAP.dat"`date +"%Y%m%d_%H%M%S"`
SAP_OUTBOUND_FILE_TRIG=$OUTPUT_PATH/$FILE_BASE"_outbound_SAP.trig"
SAP_OUTBOUND_FILE_FTP=$FTP_PATH"gdxpost.txt."`date +"%Y%m%d_%H%M%S"`
SAP_OUTBOUND_FILE_TRIG_FTP=$FTP_PATH"gdxtrig.txt."`date +"%Y%m%d_%H%M%S"`


rm -f $LOG_FILE
rm -f $DB2_MSG_FILE
rm -f $SAP_OUTBOUND_FILE
rm -f $SAP_OUTBOUND_FILE_TRIG
rm -f $FTP_CMDS

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   } > $LOG_FILE


#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >> $LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >> $LOG_FILE
   RETCODE=$?
   print "Connect to $DATABASE: RETCODE=<" $RETCODE ">"                        >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......"                        >> $LOG_FILE
      exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Step 2. Truncate the vrap.RCNC_PMT_PRCS_TXN_CNTL table.
#-------------------------------------------------------------------------#

   
   print "Truncate table vrap.RCNC_PMT_PRCS_TXN_CNTL"                           >> $LOG_FILE
   TRUNC_SQL="import from /dev/null of del replace into vrap.RCNC_PMT_PRCS_TXN_CNTL"
   db2 -stvxw $TRUNC_SQL                                                 	>> $LOG_FILE
   RETCODE=$?
   print "Truncate table, RETCODE: RETCODE=<" $RETCODE ">"                      >> $LOG_FILE

   if [[ $RETCODE > 1 ]]; then
       print " "                                                                >> $LOG_FILE
       print "Error: truncate table vrap.RCNC_PMT_PRCS_TXN_CNTL...... "         >> $LOG_FILE
       exit_error $RETCODE
       print " "                                                                >> $LOG_FILE
   fi

#-------------------------------------------------------------------------#
# Step 3. Insert data into the vrap.RCNC_PMT_PRCS_TXN_CNTLtable
#-------------------------------------------------------------------------#

   
   INS_SQL="INSERT into vrap.RCNC_PMT_PRCS_TXN_CNTL "
   INS_SQL=$INS_SQL"SELECT a.PMT_TXN_GID, a.PMT_DTL_TXN_GID "
   INS_SQL=$INS_SQL"FROM vrap.RCNT_CASH_BTCH_DTL a "
   INS_SQL=$INS_SQL"WHERE a.REC_STAT_CD = ' ' "
   INS_SQL=$INS_SQL"  AND a.dex_vect_cd = 'O' " 

   INS_SQL=$(echo "$INS_SQL" | tr '\n' ' ')  
   db2 -stvxw $INS_SQL                                                         >> $LOG_FILE
  
   RETCODE=$?

   print "Insert INTO CNTL table, RETCODE: RETCODE=<" $RETCODE ">"             >> $LOG_FILE
                                        
   if [[ $RETCODE > 1 ]]; then
      print " "                                                                >> $LOG_FILE
      print "Error: insert INTO vrap.RCNC_PMT_PRCS_TXN_CNTLtable...... "       >> $LOG_FILE
      exit_error 999
   else
      if [[ $RETCODE = 1 ]]; then
         print "No rows found to insert into vrap.RCNC_PMT_PRCS_TXN_CNTL table" >> $LOG_FILE
         print "exiting normally "			 	               >> $LOG_FILE		       	                                        
         RETCODE=0
         exit $RETCODE       
      fi                                                                       >> $LOG_FILE
   fi

   print "Successfully inserted rows into vrap.RCNC_PMT_PRCS_TXN_CNTL table "  >> $LOG_FILE


#-------------------------------------------------------------------------#
# Step 4. Build the Outbound SAP File
#-------------------------------------------------------------------------#

SEL_SQL=" export to $SAP_OUTBOUND_FILE of del modified by coldel| nochardel striplzeros SELECT " 
SEL_SQL=$SEL_SQL" cast(year(a.DOC_DT) as char(4)) " 	
SEL_SQL=$SEL_SQL" concat case when month(a.DOC_DT) < 10 "
SEL_SQL=$SEL_SQL" then '0' concat cast(Month(a.DOC_DT) as char(1)) "
SEL_SQL=$SEL_SQL" else  cast(Month(a.DOC_DT) as char(2)) end "		
SEL_SQL=$SEL_SQL" concat CASE WHEN DAY(a.DOC_DT) < 10 "
SEL_SQL=$SEL_SQL" then '0' concat cast(DAY(a.DOC_DT) as char(1)) "
SEL_SQL=$SEL_SQL" else  cast(DAY(a.DOC_DT) as char(2)) END "
SEL_SQL=$SEL_SQL" ,rtrim(a.GL_CO_CD) "
SEL_SQL=$SEL_SQL" ,rtrim(a.GL_POST_DOC_NB) "
SEL_SQL=$SEL_SQL" ,rtrim(a.DOC_NB) "
SEL_SQL=$SEL_SQL" ,rtrim(a.GL_DOC_TYP_CD) "
SEL_SQL=$SEL_SQL" ,rtrim(a.GL_UAPLD_ACCT_NB) "
SEL_SQL=$SEL_SQL" ,rtrim(a.GL_AR_ACCT_NB) "
SEL_SQL=$SEL_SQL" ,rtrim(a.GL_AR_ACCT_NM) "
SEL_SQL=$SEL_SQL" ,rtrim(a.GL_QTR_ASGN_CD) "
SEL_SQL=$SEL_SQL" ,rtrim(a.GL_NOTE_TXT) "
SEL_SQL=$SEL_SQL" ,a.GL_PMT_AMT "
SEL_SQL=$SEL_SQL" ,a.LAST_UPDT_USER_ID "
SEL_SQL=$SEL_SQL" FROM vrap.RCNT_CASH_BTCH_DTL a, " 
SEL_SQL=$SEL_SQL"  VRAP.RCNC_PMT_PRCS_TXN_CNTL b "
SEL_SQL=$SEL_SQL" WHERE a.PMT_TXN_GID = b.PMT_TXN_GID "
SEL_SQL=$SEL_SQL"   AND a.PMT_DTL_TXN_GID = b.PMT_DTL_TXN_GID "
SEL_SQL=$SEL_SQL"   AND a.dex_vect_cd = 'O' "

  
   SEL_SQL=$(echo "$SEL_SQL" | tr '\n' ' ')  
   print $SEL_SQL  							      >> $LOG_FILE 
   db2 -x $SEL_SQL							      >> $LOG_FILE  

   RETCODE=$?

   print `date` "Build of the Outbound SAP file RETCODE: RETCODE=<" $RETCODE ">"  >> $LOG_FILE
                                        
   if [[ $RETCODE != 0 ]]; then
         print " "                                                            >> $LOG_FILE
         print "Error: Build of the Outbound SAP file...... "                 >> $LOG_FILE
         tail -20 $SAP_OUTBOUND_FILE					      >> $LOG_FILE	
         exit_error 999
   else
         print " "                                                            >> $LOG_FILE
         print "Successfully selected rows for Outbound SAP file "            >> $LOG_FILE
   fi

#-------------------------------------------------------------------------#
# Step 5. Update the RCNT_CASH_BTCH_DTL table
#-------------------------------------------------------------------------#

   UPD_SQL=" UPDATE vrap.RCNT_CASH_BTCH_DTL a  "
   UPD_SQL=$UPD_SQL" SET a.REC_STAT_CD = 'C', "
   UPD_SQL=$UPD_SQL" a.LAST_UPDT_TS = current_timestamp " 
   UPD_SQL=$UPD_SQL" where a.PMT_TXN_GID in  "
   UPD_SQL=$UPD_SQL" (select b.PMT_TXN_GID from VRAP.RCNC_PMT_PRCS_TXN_CNTL b) "
   UPD_SQL=$UPD_SQL" and a.PMT_DTL_TXN_GID in  "
   UPD_SQL=$UPD_SQL" (select c.PMT_DTL_TXN_GID from VRAP.RCNC_PMT_PRCS_TXN_CNTL c) "
   UPD_SQL=$UPD_SQL" and a.DEX_VECT_CD = 'O' "
   

   UPD_SQL=$(echo "$UPD_SQL" | tr '\n' ' ')  
   db2 -stvxw $UPD_SQL                                                         >> $LOG_FILE
  
   RETCODE=$?

   print "Update of the RCNT_CASH_BTCH_DTL table RETCODE: RETCODE=<" $RETCODE ">" >> $LOG_FILE
                                        
  if [[ $RETCODE != 0 ]]; then
      print " "                                                                >> $LOG_FILE
      print "Error: pdate of the RCNT_CASH_BTCH_DTL table ...... "             >> $LOG_FILE
      exit_error 999
  else
      print " "                                                                >> $LOG_FILE
      print "Successfully updated the RCNT_CASH_BTCH_DTL table "               >> $LOG_FILE
  fi



#-------------------------------------------------------------------------#
# Step 6. Build FTP Command and FTP the data file to SAP (ascii)
#-------------------------------------------------------------------------#

print "===================== Build FTP Command =================="             >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $SAP_OUTBOUND_FILE_TRIG

{
  print 'ascii'
  print 'put ' $SAP_OUTBOUND_FILE ' ' $SAP_OUTBOUND_FILE_FTP ' (replace'
  print 'put ' $SAP_OUTBOUND_FILE_TRIG ' ' $SAP_OUTBOUND_FILE_TRIG_FTP ' (replace'
  print 'quit'
} >> $FTP_CMDS

print "================== FTP the Outbound SAP file  =================="     	>> $LOG_FILE
print "Starting the SAP FTP output to "$FTP_IP                                  >> $LOG_FILE
print `date +"%D %r %Z"`                                                        >> $LOG_FILE

run_ftp "$FTP_IP"  < $FTP_CMDS
print "Completed SAP FTP"                                                       >> $LOG_FILE


# move the output file to the output/archive directory
mv $SAP_OUTBOUND_FILE $SAP_OUTBOUND_FILE_ARCH

print `date +"%D %r %Z"`                                                        >> $LOG_FILE


#-------------------------------------------------------------------------#
# Step 7. Finish the script and log the time.
#-------------------------------------------------------------------------#
   {
      print "********************************************"
      print "Finishing the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "Final return code is : <" $RETCODE ">"
   }  									       >> $LOG_FILE

#-------------------------------------------------------------------------#
# Clean up files and move log file to archive with timestamp
#-------------------------------------------------------------------------#

    

# clean some old log file
 `find "$LOG_ARCH_PATH" -name "GDX_CaRe_Outbound_to_SAP*" -mtime +35 -exec rm -f {} \;  `  

# move the log file to the archive directory
  mv -f $LOG_FILE $LOG_FILE_ARCH


  exit $RETCODE
 
