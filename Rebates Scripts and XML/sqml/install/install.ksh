#!/bin/ksh

base_dir=`dirname $0`
cd $base_dir/..
base_dir=`pwd`
xml_dir="../../xml"
script_dir="../../scripts"

echo "Installing from $base_dir"

if ! echo $base_dir | egrep -q '/java/Common_java_db_interface$'; then
	echo "Installation should occur under java/Common_java_db_interface" >&2
	exit 1
fi

if [[ ! -d "$script_dir" ]]; then
	echo "Can not find script dir!" >&2
	exit 1
fi
script_dir=`ksh -c "cd $script_dir; pwd"`

if [[ ! -d "$xml_dir" ]]; then
	mkdir -p "$xml_dir"
	if [[ ! -d "$xml_dir" ]]; then
		echo "Couldn't create $xml_dir" >&2
		exit 1
	fi
	chmod 775 "$xml_dir"
fi
xml_dir=`ksh -c "cd $xml_dir; pwd"`

chmod 775 conf
chmod 775 lib
chmod 775 lib/*
chmod 660 conf/datasource.xml

for exe in `ls install/*.ksh`; do
	echo "Setting execution bit on [$exe]"
	if ! chmod a+rx "$exe"; then
		exit 1
	fi
done

for xml in `ksh -c "cd install; ls *.xml"`; do
	echo "Copying [$xml] to [$xml_dir]"
	if ! cp "install/$xml" "$xml_dir"; then
		exit 1
	fi
	if ! chmod 664 "$xml_dir/$xml"; then
		exit 1
	fi
done


for exe in `ksh -c "cd install; ls Common_*.ksh"`; do
	echo "Copying [install/$exe] to [$script_dir]"
	if ! cp "install/$exe" "$script_dir"; then
		exit 1
	fi
	if ! chmod 775 "install/$exe"; then
		exit 1
	fi
done


