#!/bin/ksh
#=====================================================================
#
#
#=====================================================================
#
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh

export LIB_PATH=$REBATES_PATH'/lib'

#-------------------------------------------------------------------------#
# Exec the Java to extract the new file              
#-------------------------------------------------------------------------#


   java -classpath ./:$REBATES_PATH/lib/log4j-1.2.6.jar:$REBATES_PATH/lib/classes12.zip:$REBATES_PATH/lib/apc_validation.jar com.advpcs.rebates.apc.APCValidator $SCRIPT_PATH/apc_UNIX.props

