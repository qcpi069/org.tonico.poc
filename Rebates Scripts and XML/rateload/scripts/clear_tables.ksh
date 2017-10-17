#!/usr/bin/ksh
#-------------------------------------------------------------------------------
# This script resets the database tables for testing Manufacturer Enrollment.
#-------------------------------------------------------------------------------

user=rbate_reg
password=devrbate_reg
sid=MAPLE
schema=RBATE_REG

tables="
	MFG_RATE_LOAD
	MFG_PMCY_EXCL_LOAD
	MFG_ST_EXCL_LOAD
	MFG_RATE
	MFG_PMCY_EXCL
	MFG_ST_EXCL
	HISTORY_MFG_RATE
	HISTORY_MFG_PMCY_EXCL
	HISTORY_MFG_ST_EXCL
	MFG_LOAD_ERR
	POS_FILE_XPRT
"

adjudication_engines="
	RECAP
	RXC
	QLC
"

file_types="
	MFG_RATE
	MFG_PMCY_EXCL	
	MFG_ST_EXCL
	POS_CLT
"

function get_counts {
	{ # Create delete statements for all tables.
		count=0
		for table in $tables; do
			if [[ $count -gt 0 ]]; then
				echo "UNION ALL"
			fi
			echo "SELECT '$table' AS TABLE_NAME, COUNT(*) AS COUNT FROM $schema.$table"
			count=`expr $count + 1`
		done
		echo ";"
	} | sqlplus -s "$user/$password@$sid"
}

get_counts

{ # Create delete statements for all tables.
	for table in $tables; do
		#echo "DELETE FROM $schema.$table;"
		echo "TRUNCATE TABLE $schema.$table;"
	done
	for engine in $adjudication_engines; do
		for file_type in $file_types; do
			cat <<-END_SQL	
				INSERT INTO $schema.POS_FILE_XPRT VALUES (
					'$engine',
					'$file_type',
					1,
					TO_DATE('01/01/1900', 'MM/DD/YYYY'),
					SYSDATE
				);
			END_SQL
		done
	done
} | sqlplus -s "$user/$password@$sid" | egrep -v '^$'

get_counts

