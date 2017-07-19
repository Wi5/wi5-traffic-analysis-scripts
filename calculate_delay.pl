# usage:  $ perl calculate_delay.pl origin.txt destination.txt

# Modifies identification to be continous and sort destination packets

# trace files are of this kind:

# origin.txt
#     12 1500025045.507989             192.168.3.1           192.168.2.131         UDP      122    0x4f56 (20310) 597798999 Len=80
#     13 1500025045.512982             192.168.3.1           192.168.2.131         UDP      122    0x4f57 (20311) 597798999 Len=80
#     14 1500025045.518109             192.168.3.1           192.168.2.131         UDP      122    0x4f58 (20312) 597798999 Len=80
#     15 1500025045.523235             192.168.3.1           192.168.2.131         UDP      122    0x4f59 (20313) 597798999 Len=80
#     17 1500025045.533319             192.168.3.1           192.168.2.131         UDP      122    0x4f5b (20315) 597798999 Len=80

# destination.txt
#     12 1500025045.607989             192.168.3.1           192.168.2.131         UDP      122    0x4f56 (20310) 597798999 Len=80
#     13 1500025045.712982             192.168.3.1           192.168.2.131         UDP      122    0x4f57 (20311) 597798999 Len=80
#     15 1500025045.623235             192.168.3.1           192.168.2.131         UDP      122    0x4f59 (20313) 597798999 Len=80
#     17 1500025045.733319             192.168.3.1           192.168.2.131         UDP      122    0x4f5b (20315) 597798999 Len=80

# Output is as follows:

# Identification    Origin[s]   Delay[s]
# 20310 1500025045.507989   0.1
# 20311 1500025045.512982   0.2
# 20312 1500025045.518109   lost
# 20313 1500025045.523235   0.1
# 20315 1500025045.533319   0.2
# Sent packets: 5     Received packets: 4
# Dup packets: 0 Lost packets: 1       Loss rate: 0.2
# Minimum delay: 0.1      Maximum delay: 0.2        Average delay: 0.15


$first_file = $ARGV[0];
$second_file = $ARGV[1];

$number_sent_packets = 0;
$number_lost_packets = 0;
$number_received_packets = 0;
$acum_packet_size = 0;
$min_delay = 1;
$max_delay = 0;
$avg_delay = 0;
$max_id = 0;
$pre_id = 0;
$dups = 0;

# open the origin file
open my $info1, $first_file || die "Can't open $first_file $!";

# open the destination file
open my $info2, $second_file || die "Can't open $second_file $!";

# create the modified origin file with continous id number
open my $info1_extra,'>', 'origin_extra.txt' || die "Can't open origin_extra.txt $!";
my $line1 = <$info1>; # First line is column name
while ( my $line1 = <$info1>) {
    @origin = split(/\s+/, $line1);
    $identificator = substr($origin[7], 1, length($origin[7])-2)+$max_id*(65535.0+1.0);
    print $info1_extra "$identificator\t$origin[2]\n";
    if($identificator == ($max_id+1)*65535+$max_id){
        $max_id=$max_id+1.0;
    }
}
close $info1; # Close file
close $info1_extra; # Close file
$max_id=0; # Reset max_id

# create the modified destination file with continous id number
open my $info2_extra,'>', 'destination_extra.txt' || die "Can't open destination_extra.txt $!";
my $line2 = <$info2>; # First line is column name
my $line2 = <$info2>; # First frame
@destination = split(/\s+/, $line2);
$pre_id = substr(@destination[7], 1, length(@destination[7])-2);
print $info2_extra "$pre_id\t@destination[2]\n";
while ( my $line2 = <$info2>) {
    @destination = split(/\s+/, $line2);
    $identificator = substr(@destination[7], 1, length(@destination[7])-2);
    
    if($identificator - $pre_id < -1000){ # Change to 0
       $max_id=$max_id+1.0;
       # print STDOUT "Change: $identificator $max_id\n";
    }
    if($identificator - $pre_id > 1000){ # Delayed frame, return to previous max_id
       $max_id=$max_id-1.0;
       # print STDOUT "Change: $identificator $max_id\n";
    }
    $id = substr(@destination[7], 1, length(@destination[7])-2)+$max_id*(65535.0+1.0);
    print $info2_extra "$id\t@destination[2]\n";
    $pre_id = $identificator;
}
close $info2; # Close file
close $info2_extra; # Close file

open my $info2_extra, 'destination_extra.txt' || die "Can't open destination_extra.txt $!";
my @not_sorted = <$info2_extra>;  # read entire file in the array
close $info2_extra; # Close file

@sorted = sort { $a->[2] <=> $b->[2] } @not_sorted; # numerical sort

open my $info2_sorted,'>', 'destination_sorted.txt' || die "Can't open destination_sorted.txt $!";


foreach(@sorted) {
    print $info2_sorted "$_";
}
close $info2_sorted;

# print a title line
print STDOUT "Identification\tOrigin[s]\tDelay[s]\n";

open my $info1_extra, 'origin_extra.txt' || die "Can't open origin_extra.txt $!";
open my $info2_sorted, 'destination_sorted.txt' || die "Can't open destination_sorted.txt $!";

$pre_id=-1;

#Read a line from the destination file
while ( my $line2 = <$info2_sorted>) {

    # Parse the line of the destination file
	@destination = split(/\s+/, $line2);
	$number_received_packets = $number_received_packets + 1;
	
	if($destination[0]==$pre_id){
        $dups = $dups+1;
        # my $resp = <STDIN>;
        next;
	}

	# Read a line from the origin file
	my $line1 = <$info1_extra>;
    @origin = split(/\s+/, $line1);

	$number_sent_packets = $number_sent_packets + 1;
	
	while ( $origin[0] ne $destination[0] ) { # Note: 'ne' is the 'not equal' operator for strings
	
        
        print STDOUT "$origin[0]\t$origin[1]\tlost\n";
        
		# read another line from the origin file
		my $line1 = <$info1_extra>;
		@origin = split(/\s+/, $line1);

		$number_lost_packets = $number_lost_packets + 1;
        $number_sent_packets = $number_sent_packets + 1;
	}
	
    print STDOUT "$origin[0]\t$origin[1]\t";

	$delay = $destination[1] - $origin[1];

	if($min_delay>$delay){
        $min_delay = $delay;
    }
    if($max_delay<$delay){
        $max_delay = $delay;
    }
    $avg_delay = $avg_delay  + (($delay  - $avg_delay)/( $number_received_packets)); # Cumulative moving average, recived packets already increased

	print STDOUT "$delay\n";
	
	if($delay<0){
        # my $resp = <STDIN>;
	}
	$pre_id=$destination[0];
	
}

$packet_loss = $number_lost_packets / $number_sent_packets;

# write the results
print STDOUT "Sent packets: $number_sent_packets\tReceived packets: $number_received_packets\n";
print STDOUT "Dup packets: $dups\tLost packets: $number_lost_packets\tLoss rate: $packet_loss\n";
print STDOUT "Minimum delay: $min_delay\tMaximum delay: $max_delay\tAverage delay: $avg_delay\n";

close $info1_extra;
close $info2_sorted;
exit(0);
