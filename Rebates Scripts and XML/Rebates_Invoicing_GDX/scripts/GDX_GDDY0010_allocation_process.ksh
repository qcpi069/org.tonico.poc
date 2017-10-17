#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDDY0010_allocation_process.ksh   
# Title         : This is the main script for the Rebates Integration Rlse 3
#                   allocation process.
#
#                 
# This script is executed from the following Maestro jobs:
# Maestro Job   : GDDY0010 / GD_0022J - GPO R Rebate
#                GD_0024J - GPO M Marketshare
#                GD_0026J - GPO M ExclusionMarketshare
#                GD_0028J - GPO R ExclusionRebate
#
#                            GD_0032J - DSC R Rebate
#                GD_0034J - DSC M Marketshare
#                GD_0036J - DSC M ExclusionMarketshare
#                GD_0038J - DSC R ExclusionRebate
#                            
#                            GD_0042J - XMD R Rebate
#                GD_0044J - XMD M Marketshare
#                GD_0046J - XMD M ExclusionMarketshare
#                GD_0048J - XMD R ExclusionRebate
#
# Parameters    : MODEL_IN - Allocation Model - DSC, GPO, XMD
#                 HRCY_TYP_CD_IN - Whether the report is a Rebate or Market Share 
#                 REPORT_TYP_IN - The type of report. See above 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 or > = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 04-18-05   qcpu70z    6010240   Initial Creation  
# 
#-------------------------------------------------------------------------#
# 10-25-06   qcpi03o    9101132   last_aloc_ts not set during allocation
#   set Last_Aloc_ts when start allocation (updated GDX_Allocation_trpt_stat_updt.sql)
#   for each allocation period, write start timestamp at the beginning of the loop 
#   before update the rpt_alloc_stat_cd to 3, log the count of reports for the allocation period
#                                          (new GDX_Allocation_trpt_StatUpdt_cnt.sql)
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
       export ALTER_EMAIL_ADDRESS="matthew.lewter@caremark.com"
       LOG_FILE_SIZE_MAX=5000000
    else
    # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        LOG_FILE_SIZE_MAX=5000000
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="matthew.lewter@caremark.com"
    LOG_FILE_SIZE_MAX=100
fi


#-------------------------------------------------------------------------#
# Set the Initial Variables.
#-------------------------------------------------------------------------#

SCHEDULE="GDDY0010"
JOB=""
DFLT_FILE_BASE="GDX_"$SCHEDULE"_allocation_process"
SCRIPTNAME=$DFLT_FILE_BASE".ksh"

MODEL_IN=$(echo $1|dd conv=ucase 2>/dev/null)
HRCY_TYP_CD_IN=$2
REPORT_TYP_IN=$3
MODEL_TYP_CODE=$(echo $MODEL_IN | cut -c 1)
REPORT_TYP_CODE=$(echo $REPORT_TYP_IN | cut -c 1)

#-------------------------------------------------------------------------#
# First verify the input parameters.
#-------------------------------------------------------------------------#

if [[ $# -lt 3 ]]; then
    
    LOG_FILE=$LOG_PATH/$DFLT_FILE_BASE".log"
    print "Error receiving input parameters. Did not receive three input "     >> $LOG_FILE
    print "  parms as expected:  "                                             >> $LOG_FILE
    print "MODEL  = >$MODEL_IN<"                                               >> $LOG_FILE
    print "HRCY_TYP_CD = >$HRCY_TYP_CD_IN<"                                    >> $LOG_FILE     
    print "REPORT_TYPE = >$REPORT_TYP_IN<"                         >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Script will abend."                                                 >> $LOG_FILE
    RETCODE=1 
    exit $RETCODE   
elif [[ "$MODEL_IN" != "DSC" && "$MODEL_IN" != "GPO" && "$MODEL_IN" != "XMD" ]]; then
    LOG_FILE=$LOG_PATH/$DFLT_FILE_BASE".log"
    print "Error receiving input parameters."                                  >> $LOG_FILE
    print "$MODEL_IN is an invalid Model."                                     >> $LOG_FILE
    print "Valid options are 'GPO', 'DSC', or 'XMD'."                          >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Script will abend."                                                 >> $LOG_FILE
    RETCODE=1  
    exit $RETCODE
elif [[ "$REPORT_TYP_IN" != "Rebate" && "$REPORT_TYP_IN" != "Marketshare" && "$REPORT_TYP_IN" != "ExclusionMarketshare" && "$REPORT_TYP_IN" != "ExclusionRebate" ]]; then
    LOG_FILE=$LOG_PATH/$DFLT_FILE_BASE".log"
    print "Error receiving input parameters."                                  >> $LOG_FILE
    print "$REPORT_TYP_IN is an invalid Report Type."                          >> $LOG_FILE
    print "Valid options are 'Rebate' or 'Marketshare'."                       >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Script will abend."                                                 >> $LOG_FILE
    RETCODE=1 
    exit $RETCODE
elif [[ "$HRCY_TYP_CD_IN" != "M" && "$HRCY_TYP_CD_IN" != "R" ]]; then
    LOG_FILE=$LOG_PATH/$DFLT_FILE_BASE".log"
    print "Error receiving input parameters."                                  >> $LOG_FILE
    print "$HRCY_TYP_CD_IN is an invalid Hierarchy Type Code."                 >> $LOG_FILE
    print "Valid options are 'M' or 'R'. "                                     >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Script will abend."                                                 >> $LOG_FILE
    RETCODE=1 
    exit $RETCODE
else
    FILE_BASE="GDX_"$SCHEDULE"_"$MODEL_IN"_"$HRCY_TYP_CD_IN"_"$REPORT_TYP_IN"_allocation_process"
    LOG_FILE_ARCH=$FILE_BASE".log" 
    LOG_FILE=$LOG_PATH/$LOG_FILE_ARCH
    print "Received the input parameters successfully."                        >> $LOG_FILE     
    print "MODEL  = " $MODEL_IN                                        >> $LOG_FILE
    print "HRCY_TYP_CD = " $HRCY_TYP_CD_IN                                 >> $LOG_FILE     
    print "REPORT_TYPE = " $REPORT_TYP_IN                      >> $LOG_FILE
    MODEL=$MODEL_IN
    RETCODE=0
    case $HRCY_TYP_CD_IN in 
        "M" )
            HRCY_TYP_CD=2
            print "HRCY_TYP_CD value is now 2 "                        >> $LOG_FILE
        ;;
        "R" )
            HRCY_TYP_CD=3
            print "HRCY_TYP_CD value is now 3 "                        >> $LOG_FILE
        ;;
         * )
            print "Error - invalid HRCY_TYP_CD passed in. Value must be "      >> $LOG_FILE
            print "  M for Marketshare or R for Rebate report "                >> $LOG_FILE
            print "Script will abend."                                         >> $LOG_FILE
            RETCODE=1 
    ;;
     esac
fi

#-------------------------------------------------------------------------#
# Call the Java Allocation Process
#-------------------------------------------------------------------------#

if [[ $RETCODE = 0 ]]; then
   JAVACMD=$JAVA_HOME/bin/java
   print "----------------------------------------------------------------"    >>$LOG_FILE
   print "$($JAVACMD -version 2>&1)"                                           >>$LOG_FILE
   print "----------------------------------------------------------------"    >>$LOG_FILE
      
   print "$JAVACMD" "-Dlog4j.configuration=log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.allocation.AllocationMain $MODEL $HRCY_TYP_CD_IN $REPORT_TYP_IN >> $LOG_FILE

   "$JAVACMD" "-Dlog4j.configuration=log4j.properties" "-DlogFile=${LOG_FILE}" "-DREGION=${REGION}" "-DQA_REGION=${QA_REGION}" com.caremark.gdx.allocation.AllocationMain $MODEL $HRCY_TYP_CD_IN $REPORT_TYP_IN >> $LOG_FILE
   export RETCODE=$?

   print "RETCODE=$RETCODE "                                                   >> $LOG_FILE

fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
    EMAILPARM4="  "
    EMAILPARM5="  "
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
fi

#-----------------------------------------------------------------------------------------#
# Check if the LOG_FILE size is greater than 5MB and move the log file to archive.
#-----------------------------------------------------------------------------------------#

#Get the size of the LOGFILE
if [[ -s $LOG_FILE ]]; then
   FILE_SIZE=$(ls -l "$LOG_FILE" | awk '{ print $5 }')
fi

print " "                                                                      >> $LOG_FILE
print "LOGFILE SIZE  = >$FILE_SIZE<"                                           >> $LOG_FILE
print $FILE_SIZE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

# Removing the $LOGFILE as size is more than 5MB
if [[ $FILE_SIZE -gt $LOG_FILE_SIZE_MAX ]]; then
    mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH.`date +"%Y%j%H%M"`
fi   

exit $RETCODE

