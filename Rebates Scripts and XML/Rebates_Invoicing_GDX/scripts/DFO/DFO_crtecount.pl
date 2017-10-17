#!/usr/bin/perl

$DATE = `date +"%b %d, %Y %H:%M:%S"`;
print "Process begins - $DATE.......";
print "\nCreating rejected count reference file..";

my $in_data_file          = shift @ARGV;
my $out_reject_count_file = shift @ARGV;

open REFFILE, ">$out_reject_count_file" or
    die "ERROR: Cannot open inputfile  $out_reject_count_file ($!)\n";

$total_4_count         = `grep -c "^4" "$in_data_file"`;
$two_percent_count     = $total_4_count * 0.02;
$so_far_rejected_count = 0;

printf REFFILE "TOTAL 4 RECORDS=%07d TWO PERCENT=%07.1f REJECTED SO FAR=%07d\n", $total_4_count, $two_percent_count, $so_far_rejected_count;

print "\nrejected count reference file was created..";
print "\nProcess Successful.";
$DATE = `date +"%b %d, %Y %H:%M:%S"`;
print "\nProcess ended - $DATE.......";
