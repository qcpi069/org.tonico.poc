#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_duplicate_claim.ksh   
# Title         : Duplicate Claims Clean up.
#
# Description   : Cleans up SCRC and SCRC_hold when duplicate
#                 claims exist.
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09-18-2002  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

rm -f $OUTPUT_PATH/rbate_duplicate_claim.log

export EDW_USER="/"

#-------------------------------------------------------------------------#
# Check for proper parameters passed; if none, exit
# Requires a table name for $1
#      and a table name for $2
#      and a Procedure_Name for $2
#      and a Cycle_GID for $2
#-------------------------------------------------------------------------#

if [ $# -lt 4 ] 
then
    print ' '                                        >> $OUTPUT_PATH/rbate_duplicate_claim.log
    print 'Insufficient arguments passed to script.' >> $OUTPUT_PATH/rbate_duplicate_claim.log
    print 'Arguments passed are as follows:'         >> $OUTPUT_PATH/rbate_duplicate_claim.log
    print ' '                                        >> $OUTPUT_PATH/rbate_duplicate_claim.log    
    print 'Table name1 is : ' `print $1`             >> $OUTPUT_PATH/rbate_duplicate_claim.log
    print 'Table name2 is : ' `print $2`             >> $OUTPUT_PATH/rbate_duplicate_claim.log
    print 'Procedure Name is : ' `print $3`          >> $OUTPUT_PATH/rbate_duplicate_claim.log
    print 'Cycle_GID is : ' `print $4`               >> $OUTPUT_PATH/rbate_duplicate_claim.log
    print ' '                                        >> $OUTPUT_PATH/rbate_duplicate_claim.log
    exit 1
fi

#-------------------------------------------------------------------------#
## Set vars from input parameters
#-------------------------------------------------------------------------#

export Table_Name1=`print $1`
export Table_Name2=`print $2`
export Procedure_Name=`print $3`
export Cycle_GID=`print $4`

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

PKGEXEC1='dma_rbate2.pk_cycle_util.truncate_table'\(\'$Table_Name1\'\);
PKGEXEC2='dma_rbate2.pk_cycle_util.truncate_table'\(\'$Table_Name2\'\);
PKGEXEC3='dma_rbate2.pk_cycle_util.SCRC_DUP_CLAIM_TRACE'\(\'$Procedure_name\'\,\'$Cycle_GID\'\);
PKGEXEC4='dma_rbate2.pk_refresh.MOVE_SCRC_DUPLICATES_TO_HOLD'\(\'$Cycle_GID\'\);


print ' '                         >> $OUTPUT_PATH/rbate_duplicate_claim.log
print 'Exec stmt 1 is $PKGEXEC1'  >> $OUTPUT_PATH/rbate_duplicate_claim.log
print 'Exec stmt 2 is $PKGEXEC2'  >> $OUTPUT_PATH/rbate_duplicate_claim.log
print 'Exec stmt 3 is $PKGEXEC3'  >> $OUTPUT_PATH/rbate_duplicate_claim.log
print 'Exec stmt 3 is $PKGEXEC4'  >> $OUTPUT_PATH/rbate_duplicate_claim.log

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

rm -f $INPUT_PATH/rbate_duplicate_claim.sql

cat > $INPUT_PATH/rbate_duplicate_claim.sql << EOF
set serveroutput on size 1000000
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/rbate_duplicate_claim.log
SET TIMING ON
exec $PKGEXEC1;
exec $PKGEXEC2;
exec $PKGEXEC3;
exec $PKGEXEC4;
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/rbate_duplicate_claim.sql

export RETCODE=$?

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " "                                                                 >> $OUTPUT_PATH/rbate_duplicate_claim.log
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/rbate_duplicate_claim.log
   print "  Error Executing rbate_duplicate_claim.ksh          "       >> $OUTPUT_PATH/rbate_duplicate_claim.log
   print "  Look in "$OUTPUT_PATH/rbate_duplicate_claim.log            >> $OUTPUT_PATH/rbate_duplicate_claim.log
   print "=================================================================" >> $OUTPUT_PATH/rbate_T_BATCH_LCL_snapshot.log
   cp -f $OUTPUT_PATH/rbate_duplicate_claim.log $LOG_ARCH_PATH/rbate_duplicate_claim.log.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print '....Completed executing rbate_duplicate_claim.ksh ....'         >> $OUTPUT_PATH/rbate_duplicate_claim.log
mv -f $OUTPUT_PATH/rbate_duplicate_claim.log $LOG_ARCH_PATH/rbate_duplicate_claim.log.`date +"%Y%j%H%M"`


exit $RETCODE

