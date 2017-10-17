#!/bin/ksh
#=====================================================================
#
# File Name    = rbate_NCPDP_detail.ksh
# Description  = Starts java application to create selected NCPDP Detail files
#
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  07/23/02  ba001                 added comments;
#==============================================================================
#----------------------------------
# Application Classpath variables
#
# /staging/apps/rebates/prod/rebateengine/libs/classes12.zip
# /staging/apps/rebates/prod/rebateengine/libs/j2ee.jar
# /staging/apps/rebates/prod/rebateengine/libs/xerces.jar
# /staging/apps/rebates/prod/rebateengine/libs/rebateengine.jar
#----------------------------------
#----------------------------------
# Application Property Files
#
# /staging/apps/rebates/prod/rebateengine/property_files/rbate_NCPDP_detail.props
#----------------------------------
#----------------------------------
# Application Executable Class
#
# com.advpcs.rebatebilling.engine.NCPDPDetailEngine
#----------------------------------


cd /staging/apps/rebates/prod/scripts
java -classpath .:/staging/apps/rebates/prod/rebateengine/libs/classes12.zip:/staging/apps/rebates/prod/rebateengine/libs/j2ee.jar:/staging/apps/rebates/prod/rebateengine/libs/xerces.jar:/staging/apps/rebates/prod/rebateengine/libs/rebateengine.jar  com.advpcs.rebatebilling2.engine.NCPDPDetailEngine /staging/apps/rebates/prod/rebateengine/property_files/rbate_NCPDP_detail.props
