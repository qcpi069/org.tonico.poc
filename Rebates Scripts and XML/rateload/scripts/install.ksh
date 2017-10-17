#!/bin/ksh
#------------------------------------------------------------------------------
# Script install.ksh
# Description:
#   This script installs the pos_import_export programs.
#------------------------------------------------------------------------------

# Change to base directory
basedir=`dirname $0`
if ! cd "$basedir/.." 2>/dev/null; then
	echo "Could not change to $basedir"
	exit 1
fi
basedir=`pwd`

function create_dir {
	echo "Creating [$1]"
	if [[ ! -d "$1" ]]; then
		mkdir -p "$1"
		if [[ ! -d "$1" ]]; then
			echo "Couldn't create directory $1"
			exit 1
		fi
	fi
	if ! chmod "$2" "$1"; then
		echo "Couldn't set permissions on directory $1!"
	fi
}

log_dir=logs
data_dir=data
script_dir=scripts
global_script_dir=`ksh -c "cd ../../scripts; pwd"`

create_dir "$log_dir" 777
create_dir "$script_dir" 775
create_dir "$data_dir/incoming" 777
create_dir "$data_dir/errors" 775
create_dir "$data_dir/completed" 775
create_dir "$data_dir/export" 775
create_dir "$data_dir/upload" 775
create_dir "$data_dir/upload/business" 775

for executable in `ls $script_dir/*.ksh $script_dir/*.pl`; do
	echo "Setting execute permissions on [$executable]"
	if ! chmod a+x "$executable"; then
		exit 1
	fi
done

# install files into global scripts directory
for executable in `ksh -c "cd $script_dir; ls rbate_KCDY4300*.ksh rbate_KCDY4300*.pl"`; do
	echo "Copying [$executable] to [$global_script_dir]"
	if ! cp "$script_dir/$executable" "$global_script_dir/$executable"; then
		echo "Error: couldn't copy file"
		exit 1
	fi
	if ! chmod 775 "$global_script_dir/$executable"; then
		echo "Error: couldn't set permission"
		exit 1
	fi
done

chmod 775 "$data_dir"
chmod 775 scripts
chmod 775 scripts/*
chmod 775 conf
chmod 664 conf/*
chmod 660 conf/datasource*

