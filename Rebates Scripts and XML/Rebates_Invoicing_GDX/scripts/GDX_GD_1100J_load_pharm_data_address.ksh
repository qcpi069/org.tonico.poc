#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_GD_1100J_load_pharm_data_address.ksh    
# Title         : Load Pharmacy data and Pharmacy Address data
#                 
#
# Description   : This script waits for Pharmacy data, Pharmacy Address data 
#                 and trigger files from Analytics group.  
#                 The data will be loaded into Rebate GDX tables: 
#                         VRAP.TPHARM 
#                         VRAP.TPHMAD_PHM_ADDRESS 
#                 One copy of the input data files are backuped under
#                         $GDXROOT$/input/archive/npixref.
#                 The load is a full replace for both tables.
#
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE
#
# Input Files   : $GDXROOT$/input/QLdata/mda.vrap.tpharm.dat
#                 $GDXROOT$/input/QLdata/mda.vrap.tphmad_phm_address.dat
#
# Trigger Files : $GDXROOT$/input/QLdata/mda.vrap.tpharm.dat.ok
#                 $GDXROOT$/input/QLdata/mda.vrap.tphmad_phm_address.dat.ok
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-23-08   qcpu70x     Added column information to expand TPHARM load.
# 
# 08-03-06   qcpi03o     Initial Creation
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
    EMAILPARM4='MAILPAGER'
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
    } >> $LOG_FILE

   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH
    exit $RETCODE
}
#-------------------------------------------------------------------------#
function reload_tpham {

   sql="import from $EXPORT_FILE of DEL
           commitcount 1000 messages "$DB2_MSG_FILE"
           replace into vrap.tpharm"
   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCDimp1=$?
print '...recover table vrap.tpharm from backup RETCODE=<'$RETCDimp1'>'        >>$LOG_FILE

   print "----------------------------------------------------------------"    >>$LOG_FILE

   sql="import from $EXPORT_FILE2 of DEL
           commitcount 1000 messages "$DB2_MSG_FILE"
           replace into vrap.tphmad_phm_address"
   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCDimp2=$?
print '...recover table vrap.tphmad_phm_address RETCODE=<'$RETCDimp2'>'        >>$LOG_FILE

   print "----------------------------------------------------------------"    >>$LOG_FILE

if [[ $RETCDimp1 != 0  || $RETCDimp2 != 0 ]]; then
	print "Import failed, recover tables also failed. SEVERE ERROR!!!"     >> $LOG_FILE
	return 1
else
	print "Having problem with import. Reloaded tables from backup......"  >> $LOG_FILE
	return 0
fi

}
#-------------------------------------------------------------------------#

# Region specific variables
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="kurt.gries@caremark.com"
fi


# Variables
RETCODE=0
SCHEDULE=
JOB=""
FILE_BASE=""
SCRIPTNAME=$(basename "$0")

# LOG FILES
LOG_FILE_ARCH=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE_NM=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_NM

DB2_MSG_FILE=$LOG_FILE.load
DB2_MSG_FILE_ARCH=$DB2_MSG_FILE"."`date +"%Y%m%d_%H%M%S"`

INPUT_FILE=$GDX_PATH/input/QLdata/mda.vrap.tpharm.dat
INPUT_FILE2=$GDX_PATH/input/QLdata/mda.vrap.tphmad_phm_address.dat

EXPORT_FILE=$GDX_PATH/input/GDX_tpharm.bkp
EXPORT_FILE2=$GDX_PATH/input/GDX_tph_phm_address.bkp

TRIGGER_FILE=$GDX_PATH/input/QLdata/mda.vrap.tpharm.dat.ok.excp
TRIGGER_FILE2=$GDX_PATH/input/QLdata/mda.vrap.tphmad_phm_address.dat.ok.excp

if [[ ( -e $LOG_FILE ) ]]; then
   rm -f $LOG_FILE
fi
if [[ ( -e $DB2_MSG_FILE ) ]]; then
   rm -f $DB2_MSG_FILE
fi
#-------------------------------------------------------------------------#
# Starting the script and log the start time. 
#-------------------------------------------------------------------------#
print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE

#-------------------------------------------------------------------------#
# Step 1. Check the trigger files, exit if no trigger file.
#         Rename the trigger files.
#-------------------------------------------------------------------------#

if [[ (! -f $TRIGGER_FILE) || (! -f $TRIGGER_FILE2) ]]; then 
  print "Trigger file not received......expected $TRIGGER_FILE"                >>$LOG_FILE
# email GDXITD and page on call before exit
   exit_error 999
else
   mv -f $TRIGGER_FILE $TRIGGER_FILE.bak
   mv -f $TRIGGER_FILE2 $TRIGGER_FILE2.bak
fi

print "********************************************"                           >> $LOG_FILE
print "Step 1: check trigger files...... "                                     >> $LOG_FILE
print "..............Completed"                                                >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
#-------------------------------------------------------------------------#
# Step 2. Connect to UDB.
#         backup table vrap.tpharm & vrap.tphmad_phm_address.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >>$LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >>$LOG_FILE
   RETCODE=$?
print 'connect to GDX database RETCODE=<'$RETCODE'>'                           >>$LOG_FILE

if [[ $RETCODE != 0 ]]; then
   print "Error: couldn't connect to database......"                           >>$LOG_FILE
# email GDXITD and page on call before exit
   exit_error $RETCODE
fi

   print "Connected to database, will start backup tables:"                    >>$LOG_FILE
   print "... vrap.tpharm and vrap.tphmad_phm_address under $GDX_PATH/input directory.">>$LOG_FILE
#-------------------------------------------------------------------------#
# Backup tables, export data into flat files.
#-------------------------------------------------------------------------#

   sql="export to $EXPORT_FILE of DEL select * from vrap.tpharm"
   echo "$sql"                                                                 >>$LOG_FILE
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCDimp1=$?
print '...backup table vrap.tpharm RETCODE=<'$RETCDimp1'>'                     >>$LOG_FILE
   print "----------------------------------------------------------------"    >>$LOG_FILE
   sql="export to $EXPORT_FILE2 of DEL select * from vrap.tphmad_phm_address"
   echo "$sql"                                                                 >>$LOG_FILE
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCDimp2=$?
print '...backup table vrap.tphmad_phm_address RETCODE=<'$RETCDimp2'>'         >>$LOG_FILE
   print "----------------------------------------------------------------"    >>$LOG_FILE


if [[ $RETCDimp1 != 0  || $RETCDimp2 != 0 ]]; then
	print "Error: Step 2 abend, having problem backup the tables......"    >> $LOG_FILE
	exit_error 999
else
print "********************************************"                           >> $LOG_FILE
print "Step 2: backup tables vrap.tpharm / vrap.tphmad_phm_address"            >> $LOG_FILE
print "..............Completed"                                                >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Step 3. Import data from input files, overlay the current tables 
#-------------------------------------------------------------------------#

   sql="import from $INPUT_FILE of asc
           method L(1 7, 8 11, 12 41, 42 45, 46 54, 55 63, 64 67, 68 97, 98 101,
                    102 102, 103 106, 107 107, 108 111, 112 115, 116 117, 118 118,
                    119 123, 124 124, 125 128, 129 129, 130 139, 140 145, 146 155,
                    156 167, 168 182, 183 202, 203 217, 218 237, 238 241, 242 250,
                    251 254, 255 258, 259 266, 267 292, 293 296, 297 304, 305 308, 309 334)
	    commitcount 1000 messages "$DB2_MSG_FILE" 
           replace into vrap.tpharm
		(NABP_ID, CMK_CNTRCT_IN, PHARM_NM, PHARM_ACTV_CD, PHARM_ADDR_ID,
		   CHN_PHARM_ADDR_ID, PHARM_CHN_CD, PHARM_CHN_NM,
                   PCL_CD, REC_TERM_CD, PRE_OVR_CD, PCH_USE_CD, PCY_CD, LBR_UNN_CD, STT_CD, STT_USE_CD,
                   ZIP_CD, ZIP_USE_CD, ZIP_SFX_CD, ZIP_SFX_USE_CD, AFF_EFF_DT, PAY_CEN_CD, PAY_CEN_EFF_DT,
                   FED_LIN_NB, FED_TAX_ID, STT_LIN_NB, STT_TAX_ID, MCA_ID, TFH_OPN_CD, EFT_RTE_ADDR_TXT,
                   HSC_TRN_CD, HSC_SRC_CD, HSC_USR_ID, HSC_TS, HSU_TRN_CD, HSU_USR_ID, HSU_SRC_CD, HSU_TS )"

   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCDimp1=$?
print '...import phm_data RETCODE=<'$RETCDimp1'>'                              >>$LOG_FILE

   print "----------------------------------------------------------------"    >>$LOG_FILE

   sql="import from $INPUT_FILE2 of asc 
	    method L (1 9, 10 49, 50 89, 90 129, 130 169 ,170 199, 200 201, 202 206, 207 210, 
		211 213, 214 220, 221 225, 226 228 ,229 235 ) 
	    commitcount 1000 messages "$DB2_MSG_FILE" 
	    replace into vrap.tphmad_phm_address 
		(PHARM_ADDR_ID, ADDR1_TX, ADDR2_TX, ADDR3_TX, ADDR4_TX,CITY_TX,
		ST_ABBR_CD, ZIP_CD, ZIP_EXT_CD, AREA_CD_NB, PHONE_NB, 	
			PHONE_NB_EXT, FAX_AREA_CD_NB, FAX_PHONE_NB )"

   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCDimp2=$?
print '...import phm_address RETCODE=<'$RETCDimp2'>'                           >>$LOG_FILE

# make sure both import complete successfully
# otherwise load the original data back.                
if [[ $RETCDimp1 != 0  || $RETCDimp2 != 0 ]]; then
	print "Error: Step 3 import failed ......"                             >> $LOG_FILE
	reload_tpham
	RETCODE=$?
	if [[ $RETCODE != 0 ]]; then
   	   print "SEVERE ERROR: both import and recover failed, please investigate......"      >>$LOG_FILE
  	   exit_error 999
	fi
	rm -f $EXPORT_FILE
	rm -f $EXPORT_FILE2
        mv $TRIGGER_FILE.bak $TRIGGER_FILE
        mv $TRIGGER_FILE2.bak $TRIGGER_FILE2
        cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH
	exit_error 999
fi

print "********************************************"                           >> $LOG_FILE
print "Step 3: import from pharmacy data files......"                          >> $LOG_FILE
print "..............Completed"                                                >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE
#-------------------------------------------------------------------------#
# Step 4. Clean up.                  
#-------------------------------------------------------------------------#

	RETCODE=0
# remove the exported files
	rm -f $EXPORT_FILE
	rm -f $EXPORT_FILE2
# remove trigger files here
       rm -f $TRIGGER_FILE.bak
       rm -f $TRIGGER_FILE2.bak
# remove DB2 message
	rm -f $DB2_MSG_FILE
# backup the input data files to $GDXROOT/input/archive/npixref
	mv -f $INPUT_FILE $GDX_PATH/input/archive/npixref
	mv -f $INPUT_FILE2 $GDX_PATH/input/archive/npixref
# be nice, close db connection
	db2 -p "connect reset"  				               >>$LOG_FILE

# clean some old log file?
   `find "$LOG_ARCH_PATH" -name "GDX_load_pharm_data_address.log*" -mtime +60 -exec rm -f {} \;  `

print "********************************************"                           >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

# move log file to archive with timestamp
        mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH

exit $RETCODE
