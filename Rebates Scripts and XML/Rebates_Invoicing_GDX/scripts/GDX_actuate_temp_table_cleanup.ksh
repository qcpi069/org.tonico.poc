#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDWKSUN1_weekly_actuate_cleanup.ksh
# Title         : Temporary Table Cleanup created by reports from Actuate
#                 factory.
#
# Description   : This script will drop all the temporary tables created
#                 when Actuate reports run and are failed. 
#
# Maestro Job   : GDWKSUN1 GD_0124J
#
# Parameters    : N/A
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09/09/15   qcpi733     Removed calls to Common_Prcs* scripts and
#                         associated variables.
# 03-14-06   is00084     Initial Creation.
# 05-10-12   is90001     Report Capsules - Added HRCY and INV tables
#                                          to the list
# 12-06-12   qcpi0rb     Report Capsules Defect - 1238 - Added TCPSL_LINK_RPT_% and
#                                          RCN_COMPARE%, RCN_MATCH%, RCN_SCRB% 
#                                          tables to the list
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS="gdxsittest@caremark.com"
        export ALTER_EMAIL_ADDRESS=""
        TEMP_TBL_OWNER="VACTUATE"
        EMAIL_TO_LIST="GDXITD@caremark.com"
        EMAIL_CC_LIST="GDXITD@caremark.com"
        SYSTEM="QA"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        TEMP_TBL_OWNER="VACTUATE"
        EMAIL_TO_LIST="GDXITD@caremark.com"
        EMAIL_CC_LIST="GDXITD@caremark.com"
        SYSTEM="PRODUCTION"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
    EMAIL_TO_LIST="randy.redus@caremark.com"
    EMAIL_CC_LIST="randy.redus@caremark.com"
    TEMP_TBL_OWNER="VACTUATE"
    SYSTEM="DEVELOPMENT"
fi


RETCODE=0
SCHEDULE="GDWKSUN1"
JOB="GD_0124J"
FILE_BASE="GDX_"$SCHEDULE"_weekly_actuate_cleanup"
SCRIPTNAME=$FILE_BASE".ksh"
# LOG FILES
LOG_FILE_ARCH=$FILE_BASE".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_ARCH
# UDB SQL files
TEMP_TABLE_FILE=$LOG_PATH/$FILE_BASE"_Data.dat"
RCN_TEMP_TABLE_FILE=$LOG_PATH/$FILE_BASE"_RCN_Data.dat"
EMAIL_FROM_LIST="GDXITD@Caremark.com"
EMAIL_TEXT=$LOG_PATH/$FILE_BASE"_email.txt"

#REMOVE THE PREVIOUS LOG FILE
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script to Drop the Temporary Tables
#-------------------------------------------------------------------------#
print `date`                                                                   >> $LOG_FILE
print "Starting the script to Drop the Temporary tables."                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE


print " "                                                                  >> $LOG_FILE
print "Connect to UDB database $DATABASE as user $CONNECT_ID."             >> $LOG_FILE

UDB_CONNECT_STRING="connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" >> $LOG_FILE
db2 -p $UDB_CONNECT_STRING                                                 >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Error connecting to UDB."                                       >> $LOG_FILE
    print " Return Code = "$RETCODE                                        >> $LOG_FILE
    print "Script will now abend."                                         >> $LOG_FILE
fi


if [[ $RETCODE = 0 ]]; then

        #------------------------------------------------------#
        # Get the count of the temporary tables to be dropped.
        #------------------------------------------------------#

        SQL_STRING="SELECT count (*)
                    FROM SYSCAT.TABLES
                    WHERE TABSCHEMA = 'VACTUATE'
                    AND coalesce (days (CURRENT DATE) - days (CREATE_TIME), 0) > 7
                    AND ( ( (TABNAME LIKE 'R%' OR TABNAME LIKE 'H%' OR TABNAME LIKE 'I%')
                    AND substr (TABNAME, 2, (locate ('_', TABNAME) - 2)) IN
                     (SELECT cast (RPT_ID AS CHAR (50)) FROM VRAP.TRPT_REQMT
                      UNION
                      SELECT cast (HRCY_ID AS CHAR (50)) FROM VRAP.THIERARCHY
                      UNION
                      SELECT INV_ID FROM VRAP.RCNT_RBAT_MFG_INV_HDR))
                    OR ( TABNAME LIKE 'TCPSL_LINK_RPT_%')) with ur"

        print $SQL_STRING >> $LOG_FILE

        db2 -px $SQL_STRING | read COUNT

        SQL_STRING="SELECT count(1) as RCN_COUNT
                    FROM SYSCAT.TABLES
                    WHERE TABSCHEMA = 'VACTUATE'
                    AND coalesce (days (CURRENT DATE) - days (CREATE_TIME), 0) > 7
                    AND ( TABNAME LIKE 'RCN_COMPARE%'
                    OR TABNAME LIKE 'RCN_MATCH%'
                    OR TABNAME LIKE 'RCN_SCRB%' )
                    with ur"

        print $SQL_STRING >> $LOG_FILE

        db2 -px $SQL_STRING | read RCN_COUNT

        SQLCODE=$?

        if [[ $SQLCODE != 0 ]]; then
           print "Script " $SCRIPTNAME "failed in the initial COUNT step querying SYSCAT.TABLES." >> $LOG_FILE
           print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
           RETCODE=$SQLCODE
        fi

        if [[ $SQLCODE = 0 ]]; then

            print "Count of Temporary tables to delete is : <" $COUNT ">" >>$LOG_FILE

            print "Count of RECON Temporary tables to delete is : <" $RCN_COUNT ">" >>$LOG_FILE

        fi

        if [[ $SQLCODE = 0 ]]; then

#-------------------------------------------------------------#  >> $LOG_FILE
# Temp Tables other than RECON Tables Processing		 >> $LOG_FILE
#-------------------------------------------------------------#  >> $LOG_FILE



           if [[ $COUNT > 0 ]]; then

              #------------------------------------------------------#
              # Get the temporary tables information to be dropped.
              #------------------------------------------------------#

              SQL_STRING="SELECT TABNAME
                    FROM SYSCAT.TABLES
                    WHERE TABSCHEMA = 'VACTUATE'
                    AND coalesce (days (CURRENT DATE) - days (CREATE_TIME), 0) > 7
                    AND ( ( (TABNAME LIKE 'R%' OR TABNAME LIKE 'H%' OR TABNAME LIKE 'I%')
                    AND substr (TABNAME, 2, (locate ('_', TABNAME) - 2)) IN
                     (SELECT cast (RPT_ID AS CHAR (50)) FROM VRAP.TRPT_REQMT
                      UNION
                      SELECT cast (HRCY_ID AS CHAR (50)) FROM VRAP.THIERARCHY
                      UNION
                      SELECT INV_ID FROM VRAP.RCNT_RBAT_MFG_INV_HDR))
                    OR ( TABNAME LIKE 'TCPSL_LINK_RPT_%'))"
                    

              print $SQL_STRING >>$LOG_FILE

              db2 -px $SQL_STRING > $TEMP_TABLE_FILE

              SQLCODE=$?

              if [[ $SQLCODE != 0 ]]; then
                 print "Script " $SCRIPTNAME "failed querying TABNAME from SYSCAT.TABLES." >> $LOG_FILE
                 print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
                 RETCODE=$SQLCODE
              fi

              if [[ $SQLCODE = 0 ]]; then

                 while read rec_TABNAME ; do

                    if [[ $rec_TABNAME > ' ' ]]; then
                       TAB_NAME=$rec_TABNAME
                       print $TAB_NAME                                          >> $LOG_FILE
                    fi

                    #------------------------------------------------#
                    #   DROP the Temporary Table selected.
                    #------------------------------------------------#

                    if [[ $SQLCODE = 0 ]]; then
                        SQL_STRING="DROP TABLE $TEMP_TBL_OWNER.$TAB_NAME"
                        db2 -v $SQL_STRING                                        >> $LOG_FILE
                        SQLCODE=$?
                    fi

                    if [[ $SQLCODE != 0 ]]; then

                        print "Drop Failed  "      >> $LOG_FILE
                        SQLCODE=0
                    fi

                 done < $TEMP_TABLE_FILE

		 db2 quit

              fi

           else
              print "No Temporary tables to drop"                                       >> $LOG_FILE
              RETCODE=0
           fi


#-------------------------------------------------------------#  >> $LOG_FILE
# RECON Tables Processing					 >> $LOG_FILE
#-------------------------------------------------------------#  >> $LOG_FILE



           if [[ $RCN_COUNT > 0 ]]; then
	   
		print " "										 >> $LOG_FILE
		print "Connect to UDB database $DATABASE as user $RCN_CONNECT_ID."			 >> $LOG_FILE

		RCN_UDB_CONNECT_STRING="connect to $DATABASE user $RCN_CONNECT_ID using $RCN_CONNECT_PWD" 
		db2 -p $RCN_UDB_CONNECT_STRING								  >> $LOG_FILE

              #------------------------------------------------------#
              # Get the temporary tables information to be dropped.
              #------------------------------------------------------#

              SQL_STRING="SELECT TABNAME
                    FROM SYSCAT.TABLES
                    WHERE TABSCHEMA = 'VACTUATE'
                    AND coalesce (days (CURRENT DATE) - days (CREATE_TIME), 0) > 7
                    AND ( TABNAME LIKE 'RCN_COMPARE%'
                    OR TABNAME LIKE 'RCN_MATCH%'
                    OR TABNAME LIKE 'RCN_SCRB%' )
                    with ur"
                    

              print $SQL_STRING >>$LOG_FILE

              db2 -px $SQL_STRING > $RCN_TEMP_TABLE_FILE

              SQLCODE=$?

              if [[ $SQLCODE != 0 ]]; then
                 print "Script " $SCRIPTNAME "failed querying RECON TABNAME from SYSCAT.TABLES." >> $LOG_FILE
                 print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
                 RETCODE=$SQLCODE
              fi

              if [[ $SQLCODE = 0 ]]; then

                 while read rec_RCN_TABNAME ; do

                    if [[ $rec_RCN_TABNAME > ' ' ]]; then
                       RCN_TAB_NAME=$rec_RCN_TABNAME
                       print $RCN_TAB_NAME                                          >> $LOG_FILE
                    fi

                    #------------------------------------------------#
                    #   DROP the Temporary Table selected.
                    #------------------------------------------------#

                    if [[ $SQLCODE = 0 ]]; then
                        SQL_STRING="DROP TABLE $TEMP_TBL_OWNER.$RCN_TAB_NAME"
                        db2 -v $SQL_STRING                                        >> $LOG_FILE
                        SQLCODE=$?
                    fi

                    #SQLCODE=0
                    if [[ $SQLCODE != 0 ]]; then

                        print "Drop Failed  "      >> $LOG_FILE
                        SQLCODE=0
                    fi

                 done < $RCN_TEMP_TABLE_FILE

		 db2 quit

              fi

           else
              print "No RCN Temporary tables to drop"                                       >> $LOG_FILE
              RETCODE=0
           fi
      fi
fi

print " "                                                                      >> $LOG_FILE


#-------------------------------------------------------------------------#
# Check for good return and Log.
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
    print "Failure in Script " $SCRIPT_NAME >> $LOG_FILE
    print "Return Code is : " $RETCODE >> $LOG_FILE
    print `date` >> $LOG_FILE
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    # Send email error message
    EMAIL_SUBJECT="$SYSTEM Actuate Temp Table Cleanup Error Occurred "`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
    print "\nThe Actuate Temp Table Cleanup has ERRORED." >> $EMAIL_TEXT
    print "\nLook in $LOG_ARCH/$LOG_FILE." >> $EMAIL_TEXT
    print "\nThis run was in $SYSTEM." >> $EMAIL_TEXT

    print " mail command is : " >> $LOG_FILE
    print " mailx -r $EMAIL_FROM_LIST -c $EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $EMAIL_TO_LIST < $EMAIL_TEXT " >> $LOG_FILE
    mailx -r $EMAIL_FROM_LIST -c $EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $EMAIL_TO_LIST < $EMAIL_TEXT

    MAIL_RETCODE=$?

    if [[ $MAIL_RETCODE != 0 ]]; then
       print "There was an error when sending the abend email.  Return code from mailx command was $MAIL_RETCODE." >> $LOG_FILE
       RETCODE=$MAIL_RETCODE
    fi

    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`
else
    print " " >> $LOG_FILE
    print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
    print `date` >> $LOG_FILE

    # Send email completed message
    EMAIL_SUBJECT="$SYSTEM Actuate Temp Table Cleanup Completed "`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
    print "\nThe Actuate Temp Table Cleanup has Completed." >> $EMAIL_TEXT
    print "\nLook in $LOG_ARCH/$LOG_FILE." >> $EMAIL_TEXT
    print "\nThis run was in $SYSTEM." >> $EMAIL_TEXT

    print " mail command is : " >> $LOG_FILE
    print " mailx -r $EMAIL_FROM_LIST -c $EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $EMAIL_TO_LIST < $EMAIL_TEXT " >> $LOG_FILE
    mailx -r $EMAIL_FROM_LIST -c $EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $EMAIL_TO_LIST < $EMAIL_TEXT

    MAIL_RETCODE=$?

    if [[ $MAIL_RETCODE != 0 ]]; then
       print "There was an error when sending the abend email.  Return code from mailx command was $MAIL_RETCODE." >> $LOG_FILE
       RETCODE=$MAIL_RETCODE
    else
       mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`
    fi
fi

exit $RETCODE
