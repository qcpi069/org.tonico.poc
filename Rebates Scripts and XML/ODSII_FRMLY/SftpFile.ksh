#!/bin/ksh
###################################################################
# NAME: SftpFile.ksh - Do a single SFTP action.
#
# DESCRIPTION:
#   1. Do a single SFTP action and optionally verify results.
#   2. OPTIONS: -h host (other end of connection)
#               -u userid (on host)
#               -c command (to ftp: get put rename delete)
#               -w workfile (for put command for doing put then rename of file)
#               -v (verify put command with get of file and compare)
#               -n (no execute, just print created control file)
#   3. ARGS: $1 = from (file name)
#            $2 = to (file name. Not needed for delete)
#
# EXAMPLES:
#   SftpFile.ksh -hqadom2 -ufrmlyods -cput file.dat
#
# CHANGE LOG:
#   02/18/2003  Michael Jacks    Created
#   06/23/2003  Michael Jacks    Add -q option to allow for arbitrary quoting.
#   07/02/2006  Shyam Antari     Fixed a typo with type(changed O_TYOE to O_TYPE) parameter.
#   06/24/2015  Hiri K           Changed FTP connection to SFTP
###################################################################
#set -x

####  Initialize option related variables  ####
O_HOST=localhost
O_USER=
O_PASSWORD=
O_COMMAND=put
O_WORKFILE=
O_VERIFY=false
O_NOEXECUTE=false

####  Process command line options  ####
while getopts ":h:u:c:w:vn" opt; do
  case $opt in
    h ) O_HOST=$OPTARG ;;
    u ) O_USER=$OPTARG ;;
    c ) O_COMMAND=$OPTARG ;;
    w ) O_WORKFILE=$OPTARG ;;
    v ) O_VERIFY=true ;;
    n ) O_NOEXECUTE=true ;;
    \? ) print 'usage: SftpFile [-h host] [-u userid] [-c command] [-w workfile] [-vn] fromfile tofile'
         return 1 ;;
  esac
done
shift $(($OPTIND - 1))
if [[ $O_COMMAND != put ]]; then
  if [[ -n $O_WORKFILE ]]; then
    print "w option only allowed for put command."
    exit 1
  fi
  if [[ $O_VERIFY = true ]]; then
    print "v option only allowed for put command."
    exit 1
  fi
fi

####  Build SFTP control file  ####
FFILE=$1
TFILE=$2
if [[ -z $O_WORKFILE ]]; then
  O_WORKFILE=$TFILE
fi
COMPAREFILE=/tmp/SftpFile.compare.$$
CFILE=/tmp/SftpFile.commands.$$

print "$O_COMMAND $FFILE $O_WORKFILE" >> $CFILE
if [[ $O_VERIFY = true ]]; then
  print "get $O_WORKFILE $COMPAREFILE" >> $CFILE
fi
print "quit" >> $CFILE

####  Do the SFTP  ####
EFILE=/tmp/sftpFile.ksh.error.$$
if [[ $O_NOEXECUTE = false ]]; then
  sftp -b $CFILE $O_USER@$O_HOST  > $EFILE 2>&1
  SFTP_CODE=$?
  if [[ $SFTP_CODE != 0 ]]; then
    print "Error doing ftp."
    cat $EFILE
    rm $CFILE
    rm $EFILE
    exit 1
  else
    rm $CFILE
    rm $EFILE
  fi
else
  cat $CFILE
  rm $CFILE
  exit 0
fi

####  If verify option requested, check that file was sent correctly  ####
if [[ $O_VERIFY = true ]]; then
  cmp $FFILE $COMPAREFILE
  if (( $? != 0 )); then
    print "File verification failed."
    rm $COMPAREFILE
    exit 1
  else
    rm $COMPAREFILE
  fi
fi


exit 0
