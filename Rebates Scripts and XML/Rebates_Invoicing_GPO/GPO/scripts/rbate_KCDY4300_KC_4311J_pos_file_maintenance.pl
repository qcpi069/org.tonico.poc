#!/usr/bin/perl -w
#------------------------------------------------------------------------------
# Script: pos_file_maintenance.pl
# Description:
#  This program removes old data files for the Manufacturer enrollment
#  process.
#
#  Author: Bryan Castillo
#------------------------------------------------------------------------------
use strict;
use DirHandle;
use File::Basename;
use Data::Dumper;
use Cwd;

my $MTIME = 9; # Constant for accessing mod time in stat

#------------------------------------------------------------------------------
my $CONFIG = {

	# Set test to non-zero to only print deletes and not really do them.
	test => 0,

	# Sub directories to archive (delete) files from
	directories => [qw{
		incoming
		errors
		completed 
		export
	}],		

	# Rules for deletion
	# The first item is the regex matching files to delete	
	# The 2nd item is the number of days old the file should
	#  be for the delete to occur.
	rules => [

		# Delete QL Enrollment files older than 366 days	
		[ qr/QLC_CLT_ENRL/i, 366 ],

		# Delete other files older than 30 days
		[ qr/.*\.(zip|txt|csv|tgz|tar\.gz|gz|log)$/i, 95 ]
	]
};
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Find the data directory
sub find_datadir {
	# $0 is the name of the current script
	my $script_dir = dirname($0);
	my @sub_dirs = qw{
		../data
		../clientreg/pos_import_export/data
	};
	foreach my $sub_dir (@sub_dirs) {
		if (-d "$script_dir/$sub_dir") {
			return "$script_dir/$sub_dir";
		}
	}
	die "Error: couldn't find the data directory.";
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
sub archive_files {
	my ($basedir, $config) = @_;

	my $delete_count = 0;
	my $test = $config->{test};
	my @delete_files;

	# Loop through all directories 
	# and build list of files to delete.
	foreach my $dir (@{$config->{directories}}) {
		# loop through the files
		$dir = "$basedir/$dir";
		my $dh = DirHandle->new($dir);
		if (defined $dh) {
			while (my $filename = $dh->read) {
				my $full_file = rel2abs("$dir/$filename");
				if (check_archive_rules($full_file, $config->{rules})) {
					push(@delete_files, $full_file);
				}
			}
		}
		else {
			warn "couldn't open $dir - $!";
		}
	}

	# Delete the list of files
	foreach my $file (@delete_files) {
		print "Deleting $file\n";
		$delete_count++;
		if (!$test) {
			#print "unlink($file);\n";
			unlink($file);
			if (-e $file) {
				warn "Warning: delete failed on $file";
			}
		}
	}

	return $delete_count;
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Get the absolute name of a file
sub rel2abs {
	my ($file) = @_;
	my $dpart = dirname($file);
	my $fpart = basename($file);

	my $cwd = getcwd();
	if (!chdir($dpart)) {
		warn "Couldn't change to $dpart - $!";
		return $file;
	}
	$dpart = getcwd();
	if (!chdir($cwd)) {
		die "Error: couldn't change back to $cwd - $!";
	}

	if ($dpart =~ /[\\\/]$/) {
		return "${dpart}${fpart}";	
	}
	else {
		return "$dpart/$fpart";
	}
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
sub check_archive_rules {
	my ($file, $rules) = @_;

	# The file should be a plain file
	if (! -f $file) {
		return 0;
	}

	my @st = stat($file);
	if (!@st) {
		warn "couldn't stat $file - $!";
		return 0;
	}

	# Check all of the delete rules
	foreach my $rule (@$rules) {

		my $pattern = $rule->[0];
		my $age_threshold = $rule->[1];

		# Check for file pattern name match
		if ($file =~ $pattern) {

			# compute the max age the file can be
			# age_threshold is in days, it must be converted to a number
			# of seconds.
			my $max_file_age = time() - ($age_threshold * 24 * 60 * 60);

			# $st[$MTIME] is the last modifcation time of the file
			if ($st[$MTIME] < $max_file_age) {
				return 1; # delete the file!
			}

			# If there was a name match but the file
			# wasn't old enough, do not delete the file.	
			return 0; # do not delete the file
		}
	}

	return 0; # do not delete the file
}
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# main
sub main {
	my $EXIT_CODE = 0;
	my $SCRIPT_NAME = basename($0);
	printf "[%s] (%s) Starting.....\n", scalar localtime(), $SCRIPT_NAME;
	eval {
		my $data_dir = find_datadir();
		my $delete_count = archive_files($data_dir, $CONFIG);
		printf "Deleted %d files.\n", $delete_count;

	};
	if ($@) { # catch any errors from die
		warn $@, "\n";
		my $EXIT_CODE = 1;
	}
	printf "[%s] (%s) Ending EXIT_CODE=%d\n", scalar localtime(), $SCRIPT_NAME, $EXIT_CODE;
	exit($EXIT_CODE);
}
#------------------------------------------------------------------------------


main();


