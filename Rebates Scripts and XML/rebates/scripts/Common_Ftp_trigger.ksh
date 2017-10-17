#!/usr/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : ftp_script.ksh
#
# Description   : General Purpose script to ftp files
#
#
# Command Line Flags:   -h <host>
#                       -s <fully qualified source file>
#                       -t <fully qualified target file>
#                       -b <sets to binary usage>
#                       -m <defines a mainframe target>
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
#
# 06-23-09   ur24xdp     Initial Creation
# 07-29-13   qcpi733     Modified during Infa 9.5.1 upgrade.  Added logic
#                        to evaluate a new value being passed in that is
#                        inside the HOSTNAME parm.  The value could be
#                        RPSDM or GDX to indicate it needs to be sent to
#                        those boxes, or if not either of those values,
#                        treat it as a real HOST DNS.
# 07-30-2013 qcpi2d6     Changed the HOSTNAME to be from Env variables based
#                        on the parameter passed (GDX or RPSDM)
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_RCI_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script
#-------------------------------------------------------------------------#
function exit_script {

    RETCODE=$1

    print " "
    print ".... $SCRIPTNAME  completed with return code $RETCODE ...." >> $LOGFILE
    print " "

    if [[ $RETCODE != 0 ]];then
        cp $LOGFILE $ARCH_LOGFILE
    else
        mv $LOGFILE $ARCH_LOGFILE
    fi

    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

HOSTNAME=" "
SOURCE=" "
TARGET=" "
FILE_TYPE="type ascii"
MF=
MFC=
MF_CNTLCARD=" "
RC=0
SCRIPTNAME=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_BASE=$FILE_BASE".log"
LOG=$LOG_BASE"."`date +"%Y%j%H%M%S"`
LOGFILE="$LOG_DIR/$LOG"
ARCH_LOGFILE="$ARCH_LOG_DIR/$LOG"
FTP_CMD_BASE="$OUTPUT_DIR/$FILE_BASE.ftpcmds"
FTP_CMD_FILE="$FTP_CMD_BASE."`date +"%Y%j%H%M%S"`
LRECL=
LR=
SITECMD=

while getopts h:s:t:c:L:bmH opt
do
    case $opt in
        h)
            HOSTNAME=$OPTARG
            ;;
        s)
            SOURCE=$OPTARG
            ;;
        t)
            TARGET=$OPTARG
            ;;
        c)
            MFC="1"
            MF_CNTLCARD=$OPTARG
            ;;
        L)
            LR="1"
            LRECL=$OPTARG
            ;;
        b)
            FILE_TYPE="type binary"
            ;;
        m)
            MF="1"
            ;;
        H)
            echo "Usage: $SCRIPTNAME -h  -s -t [-u] [-p] [-b] [-m] [-H]"
            echo "Example: $SCRIPTNAME -h tstudb4 -s fake_file -t /GDX/test/tmp/fake_file"
            echo "-h <hostname>   The hostname to ftp to."
            echo "-s <source file> The file to be transfered"
            echo "-t <target file> The target file including path"
            echo "-u <uname>"
            echo "-p <passwd>"
            echo "-b Switch to binary for transfer"
            echo "-m Switch indicates this files is going over to mainframe"
            echo "-H Help.  This message"
            exit_script 0
            ;;
        esac
    done

print "Starting the $SCRIPTNAME script checking and validating paramters for $0" >>$LOGFILE
## Check the variaables

if [[ $HOSTNAME == " " ]];then
    echo "Hostname is required!"
    print "HOSTNAME is reqiured! see usage: $SCRIPTNAME -H"                >> $LOGFILE
    print " "
    exit_script 1
else
    case $HOSTNAME in
        RPSDM)
            HOSTNAME=$RPSDM_APPL_DB_SERVER_NM
            ;;
        GDX)
            HOSTNAME=$GDX_APPL_DB_SERVER_NM
            ;;
        *)
            HOSTNAME=$HOSTNAME
            ;;
    esac
fi

if [[ $SOURCE == " " ]];then
    echo "Source is required!"
    print "SOURCE is required! see usage: $SCRIPTNAME -H "                 >>$LOGFILE
    exit_script 1
fi

if [[ $TARGET == " " ]];then
    echo "Target is required!"
    print "TARGET is reqiured! see usage: $SCRIPTNAME -H"                  >> $LOGFILE
    exit_script 1
fi


if [[ $MF -eq "1" ]];then
    if [[ $MFC -eq "1" ]];then
        TEMP="'$MVS_FTP_PREFIX$TARGET($MF_CNTLCARD)' (replace"
        TARGET=$TEMP

    else
        TEMP="'$MVS_FTP_PREFIX$TARGET' (replace"
        TARGET=$TEMP
    fi
    if [[ $LR -eq "1" ]];then
        SITECMD="quote site lrecl=$LRECL recfm=fb blksize=0"
    fi
fi

print $FILE_TYPE                                                               >> $FTP_CMD_FILE
print $SITECMD                                                                 >> $FTP_CMD_FILE
print "put $SOURCE $TARGET"                                                    >> $FTP_CMD_FILE
print "quit"                                                                   >> $FTP_CMD_FILE

print "start cat of ftp cmds" >>$LOGFILE
print " "
cat $FTP_CMD_FILE                                                              >> $LOGFILE
print " "
print "END cat of ftp cmds" >>$LOGFILE

ftp -i $HOSTNAME < $FTP_CMD_FILE

RC=$?

exit_script $RC
