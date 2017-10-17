#!/usr/bin/perl 
###############################################################################
#BEGINNING OF SUBROUTINES
###############################################################################

sub substitute_a_string  {

   my $string   = $_[0];
   my $position = $_[1];
   my $offset   = 1;

   my $ebcdic;
   my $converted_string;

   $ebcdic = substr($string, $position, $offset);

   if (exists $ebcdic_to_ascii_values{$ebcdic}) {

      $converted_string = $ebcdic_to_ascii_values{$ebcdic};
      substr($string, $position, $offset) = $converted_string;

   } else {

      $string = "Error";

   }
  
   $string;

}



sub is_numeric {

   my $string = $_[0];

   if ($string =~ /\b(\d+)(r|n|a|d|o|c|v)?\b/i) {
      1;
   } else {
      0;
   }

}



sub is_strictly_numeric {

   my $string = $_[0];

   if ($string =~ /^(\d+)$/) {
      1;
   } else {
      0;
   }

}


sub get_error_code {

   my $record_type    = $_[0];
   my $from_range     = $_[1] + 1;
   my $to_range       = $_[2] + 1;
   my $search_type    = $_[3];
   my $error_ref_file = $_[4];
   my $search_value;
   my $error_code;

   $from_range = sprintf "%03d", $from_range;
   $to_range   = sprintf "%03d", $to_range;

   $search_value  = "$record_type".":"."$from_range"."-"."$to_range".":"."$search_type";
   $error_code    = (split ":",`grep "^$search_value" "$error_ref_file"`)[$# - 2];

}


sub get_error_message {

   my $error_code     = $_[0];
   my $error_ref_file = $_[1];
   my $error_message;

   $error_code = ":"."$error_code".":";
   $error_message    = (split ":",`grep "$error_code" "$error_ref_file"`)[$# - 3];

}


###############################################################################
#END OF SUBROUTINES
###############################################################################

my $in_data_file          = shift @ARGV;
my $in_convert_ref_file   = shift @ARGV;
my $error_ref_file        = shift @ARGV;
my $in_reject_count_file  = shift @ARGV;
my $out_converted_file    = shift @ARGV;
my $out_good_data_file    = shift @ARGV;
my $out_reject_file       = shift @ARGV;
my $out_log_file          = shift @ARGV;
my $out_reject_count_file = shift @ARGV;
my $error_exists          = 0;
my %from_to_hash;

open IN_CONV_REF_FILE, "$in_convert_ref_file" or
    die "ERROR: Cannot open inputfile $in_convert_ref_file ($!)\n";

open OUT_LOG_FILE, ">$out_log_file" or
    die "\n Cannot open log file $out_log_file ($!)\n";


while (<IN_CONV_REF_FILE>) {

   chomp;

   my @list_of_positions = split;

   my $record_type       = shift @list_of_positions;
   if ($record_type =~ /^(\#)/ || $#list_of_positions eq -1 )    {

      #comment in reference file

       next;

   } else {
      
      if (! &is_strictly_numeric($record_type)) {

         print OUT_LOG_FILE "ERROR: Invalid record type:";
         print OUT_LOG_FILE "$record_type in reference file $in_convert_ref_file\n";

         $error_exists = 1;

         next;

      }

   }

   foreach $positions (<@list_of_positions>) {

      if ($positions =~ /(.+)-(.+)/) {
  
         my $from_column = $1;
         my $to_column   = $2;
	 
         if (! &is_numeric($from_column)) {

            print OUT_LOG_FILE "\nERROR: From column $from_column ";
            print OUT_LOG_FILE "in record type $record_type is invalid";

            $error_exists = 1;

            next;

         }

         if (! &is_numeric($to_column)) {

            print OUT_LOG_FILE "\nERROR: To column $to_column ";
            print OUT_LOG_FILE "in record type $record_type is invalid";

            $error_exists = 1;

            next;

         }

         #Define key

         my $this_key = $record_type."REC".$from_column;
	 
         if (exists $from_to_hash{$this_key}) {
            print OUT_LOG_FILE "\nERROR: Position $from_column-$to_column is ";
            print OUT_LOG_FILE "already defined for same record type $record_type";
            $error_exists = 1;
            next;
         } else {
            $from_to_hash{$this_key} = $to_column;
         }

      } else {

         print OUT_LOG_FILE "\nERROR: Invalid format $positions for record type ";
         print OUT_LOG_FILE "$record_type " ;
         print OUT_LOG_FILE "And the format is <From Column>[r|R|n|N|a|A]-<To Column>[r|R|n|N|a|A]";

         $error_exists = 1;

         next;

      }

   }

}

if ($error_exists) {
   
   exit 1;

}

open IN_DATA_FILE, "$in_data_file" or
    die "\n Cannot open input data file $in_data_file ($!)\n";

open IN_REJECT_COUNT_FILE, "$in_reject_count_file" or
    die "\n Cannot open input reject count file $in_reject_count_file ($!)\n";

open OUT_CONVERTED_FILE, ">$out_converted_file" or
    die "\n Cannot open out converted file $out_converted_file ($!)\n";

open OUT_GOOD_DATA_FILE, ">$out_good_data_file" or
    die "\n Cannot open out data file $out_good_data_file ($!)\n";

open OUT_REJECT_FILE, ">$out_reject_file" or
    die "\n Cannot open out reject file $out_reject_file ($!)\n";

open OUT_REJECT_COUNT_FILE, ">$out_reject_count_file" or
    die "\n Cannot open out reject count $out_reject_count_file ($!)\n";

%ebcdic_to_ascii_values = ( 
     "{" => "0", "A" => "1", "B" => "2", "C" => "3", "D" => "4",
     "E" => "5", "F" => "6", "G" => "7", "H" => "8", "I" => "9",
     "}" => "p", "J" => "q", "K" => "r", "L" => "s", "M" => "t",
     "N" => "u", "O" => "v", "P" => "w", "Q" => "x", "R" => "y",
                          );


#copay amount*******************************************#
#position=113:offset=1


#cmount billed******************************************#
#position=125:offset=1

my $successful_execution           = 1;
my $check_numeric                  = 0;
my $replace_with_zero              = 0;
my $replace_with_space             = 0;
my $stop_process_if_fails          = 0;
my $rejected_record_count          = 0;
my $reject_this_record             = 0;
my $other_record_count             = 0;
my $two_percent_error_count        = 0;
my $total_rejected_record_count    = 0;
my $previous_rejected_record_count = 0;
my $bad_pharm_hdr                  = 0;
my $bad_pharm_ctr                  = 0;
my $record_type_from_key;
my $returned_string;
my $position_list;
my $position;
my $reject_count_file_record;
my $temp_string;

#Read records from datafile
#Remember taht default variable $_ is used to store each record
#read from the file

while (<IN_REJECT_COUNT_FILE>) {

   if (/(TWO PERCENT=)(\d+.\d+)(\s+)(REJECTED SO FAR=)(.*)/) {

      $reject_count_file_record = $_;
      $two_percent_error_count = $2;
      $previous_rejected_record_count = $5;
      $total_rejected_record_count = $previous_rejected_record_count;
      
   }

}




while (<IN_DATA_FILE>) { #Beginning of 1st Loop

   #-------------------------------------------------------
   #Loop through each key from hashtable.
   #Get the record type from it.
   #If record type matches with the record type of this record
   #being read from the data file continue
   #otherwise read next key from hash table and repeat above logic
   #-------------------------------------------------------

   $stop_process_if_fails = 0;
   $successful_execution  = 1;
   $reject_this_record    = 0;
   $record_type_from_record = substr($_,0,1);

   foreach $key_of_from_to_hash (sort keys %from_to_hash) { 

               #Beginning of 2nd Loop
      
      $replace_with_zero     = 0;
      $replace_with_space    = 0;
      $donot_convert         = 0;
      $check_numeric         = 0;

      #-------------------------------------------------------
      #Matches for REC in the key. If match is not found
      #hash table has been corrupted. Terminate job abnormally
      #The strings before REC are the record type and
      #those after REC are from positions
      #-------------------------------------------------------

      if ($key_of_from_to_hash =~ /(REC)/) {
         $record_type_from_key    = $`;
         $from_pos                = $';
  #      $record_type_from_record = substr($_,0,1);

         if ($record_type_from_key ne $record_type_from_record) {
            #Goes to next iteration of key
            next;
         } 

      } else {
         print OUT_LOG_FILE "\nERROR: serious error in key structure";
         exit 1;
      }

      $to_pos   = $from_to_hash{$key_of_from_to_hash};
      
      #Eliminate last r or R from to_pos

      if ($from_pos =~ /\b(.+)(r|n|a|d|o|c|v)\b/i) {

         $from_pos              = $1;
        
         if ("\U$2" eq "N") {
            $replace_with_zero  = 1;
         } elsif ("\U$2" eq "A") {
            $replace_with_space = 1;
         } elsif ("\U$2" eq "O") {
            $donot_convert      = 1;
         } elsif ("\U$2" eq "D") {
            $donot_convert      = 1;
            $stop_process_if_fails = 1;
         } elsif ("\U$2" eq "C") {
            $check_numeric      = 1;
         } elsif ("\U$2" eq "V") {
            $check_numeric      = 1;
            $stop_process_if_fails = 1;
         } else {
            $stop_process_if_fails = 1;
         }

      }

      if ($to_pos =~ /\b(.+)(r|n|a|d|o|c|v)\b/i) {

         $to_pos                = $1;
         
         if ("\U$2" eq "N") {
            $replace_with_zero  = 1;
         } elsif ("\U$2" eq "A") {
            $replace_with_space = 1;
         } elsif ("\U$2" eq "O") {
            $donot_convert      = 1;
         } elsif ("\U$2" eq "D") {
            $donot_convert      = 1;
            $stop_process_if_fails = 1;
         } elsif ("\U$2" eq "C") {
            $check_numeric      = 1;
         } elsif ("\U$2" eq "V") {
            $check_numeric      = 1;
            $stop_process_if_fails = 1;
         } else {   
            $stop_process_if_fails = 1;
         }

      } 

      $from_pos --;
      $to_pos --;
      $string_offset = $to_pos - $from_pos + 1;

#     if the pharmacy number is blank, reject the trailer 
#     associated with the pharmacy
#      print "record_type_from_record(1):$record_type_from_record";
      if ($record_type_from_record =~ /2/) {
#          print "      in record_type_from_record 2";
          $temp_string = substr($_,17,4);
#          print "pharmacy number: $temp_string";
#          if (substr($_,17,4) =~ /^(\d+)$/) {
          if ($temp_string =~ /\D/) {
             # set flag to delete next 6 record
#             print "not numeric (2)";
             $bad_pharm_hdr = 1;
             $bad_pharm_ctr ++;
#             print "bad_pharm_hdr: $bad_pharm_hdr";
          }

      }

      if ($replace_with_zero) {
         $substitute_with = "0" x $string_offset;
         substr($_, $from_pos, $string_offset)  = $substitute_with;
         next;
      }

      if ($replace_with_space) {
         $substitute_with = " " x $string_offset;
         substr($_, $from_pos, $string_offset)  = $substitute_with;
         next;
      }

      $returned_string = "";

      if ($donot_convert || $check_numeric) {
         $returned_string = $_;
      } else {
         $returned_string = &substitute_a_string($_,$to_pos);
      }
     

      #------------------------------------------------------------
      #If string being returned from substitute_a_string subroutine
      #is "error" (case insensitive) the record is written into
      #bad file with reason and then 
      #process terminates if the argument wants any bad field to
      #reject the entire file and
      #reads the next record from file if file is not to be 
      #rejected
      #------------------------------------------------------------

      if ($returned_string =~ /^error/i) {

         #Write this record to bad file

         $reject_this_record = 1;
         $error_code = &get_error_code($record_type_from_record, $from_pos, $to_pos, "IS", $error_ref_file);

         if ($stop_process_if_fails) {
            $successful_execution = 0;
            $error_message = &get_error_message($error_code, $error_ref_file);
            $error_message = "\nProcess terminated because $error_message";
            last;
         }

         next;

      } else {

         $_ = $returned_string;

         if (! $check_numeric) {
            $string_offset = $to_pos - $from_pos;
         }

         $this_string   = substr($_, $from_pos, $string_offset);

#        subtract the number of bad pharmacys from the file
#        trailer counter
         
         if ($record_type_from_record =~ /8/) {
#             print "      in record_type_from_record 8\n";
#             print "8 record before: $_ \n";

             if ($bad_pharm_ctr > 0) {
                $temp_string = substr($_,319,5);
#                print "total pharmacy count: $temp_string\n";

                $temp_string = $temp_string - $bad_pharm_ctr;
                substr($_,319,5) = $temp_string;

#               print "8 record after: $_ \n";
                # we've subtracted the ctr once, reset ctr to not
                # subtract any more times if there's more '8' edits
                $bad_pharm_ctr = 0;
            }
         }

         #Check for numeric

         if (! &is_strictly_numeric($this_string)) {

            $reject_this_record = 1;
            $error_code = &get_error_code($record_type_from_record, $from_pos, $to_pos, "NN", $error_ref_file);

       
            if ($stop_process_if_fails) {
               $successful_execution = 0;
               $error_message = &get_error_message($error_code, $error_ref_file);
               $error_message = "\nProcess terminated because $error_message";
               last;
            }

            next;

         }
        
      } 

   } #End of 2nd Loop

   if ($reject_this_record) {

      $reject_this_record = 0;
      $total_rejected_record_count ++;
      $total_rejected_record_count = sprintf "%07d", $total_rejected_record_count;
      $write_error_record = "PRL$total_rejected_record_count".":"."$error_code".":"."$_";

      if ($record_type_from_record ne "4") {
         $other_record_count ++;
      } else {

         $rejected_record_count ++;
      }

      print OUT_REJECT_FILE "$write_error_record";

#     heavy handed force to continue the processing.
#     boolean logic is used, 1 is true for successful_execution
      $successful_execution = 1;

      if ($rejected_record_count > $two_percent_error_count) {
         $successful_execution = 0;
         $error_message = "\nERROR: more than 2% records rejected";
      }

   } else {

#     only write out non-rejected, converted records
#      print "\n\n     record_type_from_record(2): $record_type_from_record";
#      print "        bad_pharm_hdr(2): $bad_pharm_hdr\n\n";
      if (($record_type_from_record =~ /6/) && ($bad_pharm_hdr =~ /1/)) {
          # skip writing the pharmacy trailer '6' rec
          # and reset indicator for next pharmacy
          $bad_pharm_hdr = 0;
#          print "skipping record: $_ \n";
      } else {
          print OUT_CONVERTED_FILE "$_";
          print OUT_GOOD_DATA_FILE "$_";
      }
   }
#   moved this code- WJP
#   print OUT_CONVERTED_FILE "$_";

   if (! $successful_execution) {
      last;
   }

} #End of 1st Loop

$rejected_record_count = sprintf "%07d", $rejected_record_count;
$reject_count_file_record =~ s/(REJECTED SO FAR=)(.*)/$1$rejected_record_count/;

print OUT_REJECT_COUNT_FILE "$reject_count_file_record";

if (! $successful_execution) {
   print OUT_LOG_FILE "$error_message";
   exit 2;
}
