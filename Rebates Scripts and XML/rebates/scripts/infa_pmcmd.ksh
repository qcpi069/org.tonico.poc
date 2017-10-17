#!/bin/ksh

# Workflowname is input

#--------------------------------------------------------------------------#
#   Date                 Description
# ----------  ----------  -------------------------------------------------#
# 04-01-2009                     Initial Creation.
# 07-23-2013   qcpi2d6     Remove hardcodes and pull from environment script.
# 11-02-2013   qcpi2gt     Modified to keep the LOGFILE and printing a few
#                          variables for debugging purposes
#--------------------------------------------------------------------------#

. `dirname $0`/Common_RCI_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script
#-------------------------------------------------------------------------#
function exit_script {

    RETCODE=$1

    print " "
    print ".... $SCRIPTNAME  completed with return code $RETCODE ...."         >> $LOGFILE
    print " "

    if [[ $RETCODE != 0 ]];then
        cp $LOGFILE $LOG_FILE_ARCH
    else
        mv $LOGFILE $LOG_FILE_ARCH
    fi

    return $RETCODE
}


PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.

. /home/user/udbcae/sqllib/db2profile

INFA_DOMAINS_FILE=$INFA_HOME/domains.infa
LIBPATH=$INFA_HOME/server/bin:$INFA_HOME/java/jre/bin:$INFA_HOME/java/jre/bin/classic:$LIBPATH

PATH=$INFA_HOME/server/bin:$INFA_HOME/java/jre/bin:$INFA_HOME/java/jre/bin/classic:$PATH

SCRIPTNAME=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_BASE=$FILE_BASE".log"
LOG=$LOG_BASE"."`date +"%Y%j%H%M"`
LOGFILE="$LOG_DIR/$LOG"
LOG_FILE_ARCH="$ARCH_LOG_DIR/$LOG"
METASQL="$OUTPUT_DIR/$1.sql"
INFA_FOLDER=

##
# connect to the metadata db
##
db2 -p connect to $META_DB user $META_CONNECT_ID using $META_CONNECT_PWD
 if [[ $? != 0 ]]; then
    print "aborting script - cant connect to udb "
    print "aborting script - cant connect to udb "                             >> $LOGFILE
    exit_script 1
 fi

##
# Build the sql to run
##
cat > $METASQL <<EOF
SELECT B.SUBJ_NAME
FROM $META_SCHEMA.OPB_TASK A, $META_SCHEMA.OPB_SUBJECT  B
WHERE A.TASK_TYPE = 71
AND A.SUBJECT_ID = B.SUBJ_ID
AND A.TASK_NAME = '$1'
AND B.SUBJ_NAME LIKE '%Rebates%'
AND B.SUBJ_NAME NOT IN ('Rebates_RCI_Maintenance');
EOF

print "executing the following query to get the folder name for $1"            >>$LOGFILE
print " "                                                                      >>$LOGFILE
cat $METASQL                                                                   >> $LOGFILE
##
# Run Query and get the folder name
##
INFA_FOLDER=`db2 -stxwf $METASQL`
 
if [[ $? != 0 ]]; then
    print "aborting script - Error executing query "
    print "aborting script - Error executing query"                            >> $LOGFILE
    exit_script 1
 fi

##
# Disconnect form udb
##
db2 -stvx connect reset
db2 -stvx quit

export INFA_DOMAINS_FILE
export LIBPATH
export PATH

print "REBATES_INFA_SV:$REBATES_INFA_SV"                                         >> $LOGFILE
print " "                                                                        >> $LOGFILE
print "REBATES_INFA_DOM:$REBATES_INFA_DOM"                                       >> $LOGFILE
print " "                                                                        >> $LOGFILE
print "INFA_FOLDER:$INFA_FOLDER"                                                 >> $LOGFILE
print " "                                                                        >> $LOGFILE

pmcmd startworkflow -sv $REBATES_INFA_SV -d $REBATES_INFA_DOM -f $INFA_FOLDER -uv PMUSER -pv PMPASS -wait $1

exit_script $?
