#!/usr/bin/perl -w
use strict;
use File::Temp ();
#use File::Basename;
use Getopt::Std;
use File::Find;
#use Storable;
#use File::Spec;
#use Data::Dumper;
#local $Data::Dumper::Useqq = 1;
#local $Data::Dumper::Maxdepth = 3;
#local $Data::Dumper::Deepcopy = 1;

my (%opts);
$Getopt::Std::STANDARD_HELP_VERSION = 1;

###### Get command line options
getopts( 't:c:d:p:r:o:k', \%opts );

my $titlecolumn = ($opts{t} || 1); # zero based index
my $datacolumn  = ($opts{c} || 3); # zero based index

# if smartctl files are not supplied on the command line...
my $directory = ($opts{d} || "."); # where to look for files
my $pattern   = ($opts{p} || ""); # which pattern to look for

#gnuplot parameter
my $gp_res    = ($opts{r} || "2560,720"); #where to write to 
my $gp_output = ($opts{o} || "/tmp/foo.png"); #where to write to

my $keeptmp   = ($opts{k} || 0 ); #keep temporary files

#here we supply the filenames on the comand line
my @smartfiles = @ARGV ;
#if/when that commandline gets too long (64k) we can switch to providing just a pattern and a directory to search.

my @directories=($directory);
if ($pattern) {
	# Traverse desired filesystems
	print {*STDERR} "running find ...\n";
	File::Find::find({wanted => \&wanted}, @directories);
}
sub wanted {
	if ($_ =~ m/$pattern/) {
		push @smartfiles,$File::Find::name ;
	}
	return 1;
}

if (scalar @smartfiles == 0) {
	print "Please call this script with some data files to work on.\n";
	print "E.g. $0 /var/log/smart/*sata*\n";
	print "Check out the examples... Read the source... Be nice to your parents.\n";
	exit 1;
}

my $timestamp_first;
my $timestamp_last;
my $number_of_attributes;


# extract the column (zero based) from the attributes table
sub get_smart_attributes_column { 
	my $filename = shift;
        my $column = shift;
	my @ret;
        open my $fh, '<', $filename or warn "Can't open '$filename': $!"; 
	while (my $line = <$fh>) { last if $line =~ m/^ID# ATTRIBUTE_NAME/; }
	while (<$fh>) { 
		last if $_ =~ m/^$/;
		my @a=split;
		push @ret,$a[$column];
	}
	close $fh;
	return @ret;
}

sub prepare_gnuplot_file {
	my $in = shift;
	my $gpdata = <<"END";
##### prepare gnuplot

set terminal png size $gp_res

set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S"
set format x "%Y-%m-%d\\n%H:%M:%S"

# time range must be in same format as data file
set xrange ["$timestamp_first":"$timestamp_last"]

set output "$gp_output"

# uncomment only one of the next two lines
#set logscale y 10
set yrange [0:]

set grid
set xlabel "Date\\nTime"
set ylabel "Value"
set title "Smart Attributes"
set key left box
set multiplot

plot for [i=2:$number_of_attributes] '$in' u 1:i w lp title columnheader(i)
END

	my ($tempgpfh, $tempgpfn) = File::Temp::tempfile();
	print {$tempgpfh} $gpdata;
	close $tempgpfh;
	return $tempgpfn;
}

#print Dumper(@smartfiles);


my ($tempdatafh, $tempdatafn) = File::Temp::tempfile(); 

##### get titles/headers from first file

print {$tempdatafh} "DateTime"."\t".join("\t",get_smart_attributes_column($smartfiles[0],$titlecolumn))."\n";

##### get data from all files
print {*STDERR} "Found ".scalar @smartfiles." candidate files.\n";
for my $file (sort @smartfiles) {
	die "$file doesn't exist or it's not a file!\n" unless -f $file;
	my $timestamp;
	## by smartctl-a files carry an "date --iso-8601=seconds" timestamp in the filename
	## but since gnuplot doesn't know about timezomes, we drop that
	if ( $file =~ m/(\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d)[-+]\d\d\d\d$/ ) { 
		$timestamp = $1;
	} else {
		warn "Filename $file does not contain expected timestamp! Skipping file.\n";
		next;
	}

	# keep track of timestamps 
	if (not defined $timestamp_first) {
		$timestamp_first = $timestamp; 
	}
	$timestamp_last = $timestamp;

	my @attributes = get_smart_attributes_column($file,$datacolumn);
	if (scalar @attributes <= 0) {
		warn "Skipping $file. No smart attributes found.\n";
		next;
	}

	#small check until this ist switched from an array to a hash
	if (not defined $number_of_attributes) {
		$number_of_attributes = scalar @attributes; 
	} elsif ( $number_of_attributes != scalar @attributes ) {
		warn "Different number of attributes in file $file (".scalar @attributes." instead of $number_of_attributes). Skipping file.\n";
		next;
	}

	print {$tempdatafh} $timestamp."\t".join("\t", @attributes)."\n";
}

close $tempdatafh;



my $tempgpfn = prepare_gnuplot_file($tempdatafn);

system ("gnuplot", $tempgpfn);

if ($keeptmp) {
	print "Kept temporary data file in $tempdatafn and gnuplot file in $tempgpfn\n";
} else {
	unlink ($tempdatafn, $tempgpfn) or warn "Could not unlink $tempdatafn or $tempgpfn: $!";
}

