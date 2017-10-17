#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script: Common_GDX_APC_Status_update.ksh
#
# Description: Writes the start or end timestamp for the APC process status entry.
#
# Abends        :
#
# Maestro Job   : Multiple 
#
# Parameters:
#   1 - The PRCS_ID value to update.
#   2 - A flag to tell the process to update the start or end timestamp.
#
# Output        : Log file as $LOG_FILE, 
#
# Input Files   : 
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-24-09   qcpi733     Initial script
# 05-14-10   qcpi733     Removed comment on Common_GDX_Environment call
#-------------------------------------------------------------------------#
. $(dirname $0)/Common_GDX_Environment.ksh

SUBSCRIPTNAME="Common_GDX_APC_Status_update.ksh"
# Get the INPUT PARMS
#------------------------------------------
PRCS_ID=$1
UPDT_FLG="$2"

PRCS_TABLE_NAME="VRAP.TAPC_QTR_PRCS_EVENT"

print " "
print " "
print "****************************************"
print "Starting update for APC Status"

# Check argument count
#------------------------------------------
#if [[ $# < 3 ]] || [[ $# > 4 ]]; then 
#    echo "Error: Usage $0 <prcs id> [prcs arg txt]" 
#    exit 1
#fi

# Connect to db2
#------------------------------------------

db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" 

APCRETCODE=$?

if [[ $APCRETCODE != 0 ]]; then
    echo "Error: couldn't connect to database" 
    print '****** start of input parameters ******' 
    print "Input parms to $SUBSCRIPTNAME" 
    print "PRCS_ID   =>$PRCS_ID<" 
    print "UPDT_FLG  =>$UPDT_FLG<" 
    print "Assigned values:" 
    print "SET_STMNT=$SET_STMNT" 
    print "UPDT_STMNT=$UPDT_STMNT" 
    print '******* end of input parameters *******' 
    print ".... $SUBSCRIPTNAME  abended ...." 
    print "****************************************"
    print " "
    print " "
    return $APCRETCODE
fi

# Determine which field(s) should be updated
#------------------------------------------

case $UPDT_FLG in 
    "END" )
        SET_STMNT=" SET END_TS = CURRENT TIMESTAMP, PRCS_STAT_TXT='Successful' "
        ;;
    "STRT" )
        SET_STMNT=" SET STRT_TS = CURRENT TIMESTAMP, END_TS = NULL, PRCS_ERR_TS = NULL, PRCS_STAT_TXT='Running' "
        ;;
    "ERR" )
        SET_STMNT=" SET PRCS_ERR_TS = CURRENT TIMESTAMP, PRCS_STAT_TXT='Error-IT Investigating' "
        ;;
    * )
        SET_STMNT="Error in case statment in $SUBSCRIPTNAME" 
        APCRETCODE=2
        ;;
esac

if [[ $APCRETCODE != 0 ]]; then
    print '****** start of input parameters ******' 
    print "Input parms to $SUBSCRIPTNAME" 
    print "PRCS_ID   =>$PRCS_ID<" 
    print "UPDT_FLG  =>$UPDT_FLG<" 
    print "Assigned values:" 
    print "SET_STMNT=$SET_STMNT" 
    print "UPDT_STMNT=$UPDT_STMNT" 
    print '******* end of input parameters *******' 
    print ".... $SUBSCRIPTNAME  abended ...." 
    print "****************************************"
    print " "
    print " "
    return $APCRETCODE
fi


# Generate the SQL for the update statement
#------------------------------------------
UPDT_STMNT="
  update ${PRCS_TABLE_NAME}
  $SET_STMNT
  where PRCS_ID = $PRCS_ID
"

# Execute the UPDT_STMNT
#------------------------------------------
UPDT_STMNT=$(echo "$UPDT_STMNT" | tr '\n' ' ')
print "APC Status udpate - $UPDT_STMNT" 
db2 -px "$UPDT_STMNT" 

APCRETCODE=$?

print " "

if [[ $APCRETCODE != 0 ]]; then
    print "Error: could not update table ${PRCS_TABLE_NAME}" 
    if [[ APCRETCODE = 1 ]]; then
        print "Update syntax good could not find record" 
    else
        print "Syntax or database error" 
    fi
    print '****** start of input parameters ******' 
    print "Input parms to $SUBSCRIPTNAME" 
    print "PRCS_ID   =>$PRCS_ID<" 
    print "UPDT_FLG  =>$UPDT_FLG<" 
    print "Assigned values:" 
    print "SET_STMNT=$SET_STMNT" 
    print "UPDT_STMNT=$UPDT_STMNT" 
    print '******* end of input parameters *******' 
    print ".... $SUBSCRIPTNAME  abended ...." 
    print "****************************************"
    print " "
    print " "
    return $APCRETCODE
fi

print "Successfully Completed $SUBSCRIPTNAME"
print " "
print "Continuing now with calling script"
print "****************************************"
print " "
print " "

return $APCRETCODE