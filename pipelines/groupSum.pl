#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Data::Dumper;
use Cwd qw(abs_path);
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
use JSON::XS;
use POSIX qw(strftime);
use Getopt::Long;
use Text::CSV;
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."lib/";	# Custom functions
require "lib.pl";


my ($help,$keep,@keeps,$sum,@sums,$precision,@precisions,$scale,@scales,$sumcolumns,$col,$length,$ofile,$src,$ifile,$startrow,$tmpdir,$r,$c,$pid,$pcon,$constituencies,$match,$lookup,$csvrow,@row,@rows,@cols,$ll,$pcds,$or,$data,$category,$cat,$name,$totals,$total,$groups,$group,@grouplist,$g,$csv,$dir,$fh,$badlocation,$badnovalue,$ok,$dt,$dtfull,$totalcolumn,$v,@datefiles);

# Get the command line options
GetOptions(
	"k|keep=s" => sub { $keep .= ($keep ? ",":"").$_[1] },	# columns to keep in the output
	"g|group=s" => \$group,							# create totals by this column
	"h|help" => \$help,								# show help
	"i|id=s" => \$pid,								# the column to use for the GSS code
	"o|output=s" => \$ofile,						# the output file
	"startrow=i" => \$startrow,						# the start row of the data in the CSV file
	"sum=s" => sub { $sum .= ($sum ? ",":"").$_[1] },	# columns to sum
	"precision=s" => sub { $precision .= ($precision ? ",":"").$_[1] },	# precision for the sum columns
	"scale=s" => sub { $scale .= ($scale ? ",":"").$_[1] },	# scale for the sum columns
	"u|updatedate=s" => sub { push(@datefiles,$_[1]) },	# any files to update dates in
);

if(defined($help)){ showHelp(); }


# Set the data start row if not provided
if(!defined($startrow)){ $startrow = 1; }
# Set the default property ID
if(!defined($pid)){ $pid = "PCON24CD"; }

# Get the input file
$src = $ARGV[0]||"";
$tmpdir = $basedir."../raw-data/";
$ifile = $tmpdir.($src =~ /([^\/]+\.[^\/]{3})$/ ? $1 : "temp-download.csv");
# Get the data file if necessary
if($src =~ /^https?/){
	SaveFromURL($src,$ifile);
}else{
	$ifile = $src;
}
if(!-e $ifile){
	error("Can't find <cyan>$ifile<none>\n");
	exit;
}

@sums = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$sum);
@precisions = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$precision);
@scales = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$scale);
for($r = 0; $r < @sums; $r++){
	$sumcolumns->{$sums[$r]} = {};
	if(defined($precisions[$r])){ $sumcolumns->{$sums[$r]}{'precision'} = $precisions[$r]; }
	if(defined($scales[$r])){ $sumcolumns->{$sums[$r]}{'scale'} = $scales[$r]; }
}
if(@sums == 0){
	error("No columns provided to sum over. Try providing <cyan>--sum \"column name,second column\".\n");
	exit;
}


# Load in the CSV input file
$csv = LoadCSVSimple($src);

# Check if we have an ID column
if(!defined($csv->{'lookup'}{'col'}{$pid})){
	error("No column <yellow>$pid<none> is in the CSV. Try providing the name with the <cyan>--id<none> flag. Possible columns:\n");
	foreach $col (sort(keys(%{$csv->{'lookup'}{'col'}}))){
		msg("\t<yellow>$col<none>\n");
	}
	exit;
}

# Check if we have a group column
if(!defined($csv->{'lookup'}{'col'}{$group})){
	error("No column <yellow>$group<none> is in the CSV. Try providing the name with the <cyan>--group<none> flag. Possible columns:\n");
	foreach $col (sort(keys(%{$csv->{'lookup'}{'col'}}))){
		msg("\t<yellow>$col<none>\n");
	}
	exit;
}

if(!defined($keep)){
	$keep = $pid;
	for($r = 0; $r < @sums; $r++){
		$keep .= ($keep ? ",":"").$sums[$r];
	}
}
@keeps = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$keep);


$constituencies = {};
$lookup = $csv->{'lookup'}{'col'};
@cols = sort{$lookup->{$a} <=> $lookup->{$b}}(keys(%{$lookup}));

for($r = 0; $r < @{$csv->{'rows'}}; $r++){
	# Build each constituency
	@row = @{$csv->{'rows'}[$r]};
	$pcon = $row[$lookup->{$pid}];
	if(!defined($constituencies->{$pcon})){
		$constituencies->{$pcon} = [];
	}
	for($c = 0; $c < @cols; $c++){
		if(!defined($sumcolumns->{$cols[$c]})){
			if(defined($constituencies->{$pcon}[$c]) && $row[$c] ne ""){
				if($constituencies->{$pcon}[$c] !~ /$row[$c]/){
					$constituencies->{$pcon}[$c] .= $row[$c];
				}
			}else{
				$constituencies->{$pcon}[$c] = $row[$c];
			}
		}else{
			if(!defined($constituencies->{$pcon}[$c])){
				$constituencies->{$pcon}[$c] = {};
			}
			# Find the column for the group
			$g = $lookup->{$group};
			$groups->{$row[$g]} = 1;
			if(!defined($constituencies->{$pcon}[$c]{$row[$g]})){
				$constituencies->{$pcon}[$c]{$row[$g]} = 0;
			}
			$constituencies->{$pcon}[$c]{$row[$g]} += $row[$c];
		}

	}
}

@grouplist = sort(keys(%{$groups}));

# Build CSV output
$csv = "";
for($c = 0; $c < @keeps; $c++){
	if(defined($sumcolumns->{$keeps[$c]})){
		for($g = 0; $g < @grouplist; $g++){
			$csv .= ($csv ? ",":"").$keeps[$c]."→".$grouplist[$g];
		}
	}else{
		$csv .= ($csv ? ",":"").$keeps[$c];
	}
}
$csv .= "\n";
foreach $pcon (sort(keys(%{$constituencies}))){
	$csvrow = "";
	for($c = 0; $c < @keeps; $c++){
		$col = $lookup->{$keeps[$c]};
		if(defined($sumcolumns->{$keeps[$c]})){
			for($g = 0; $g < @grouplist; $g++){
				$v = ($constituencies->{$pcon}[$col]{$grouplist[$g]}||"");
				if(defined($sumcolumns->{$keeps[$c]})){
					if(defined($sumcolumns->{$keeps[$c]}{'scale'})){
						$v *= $sumcolumns->{$keeps[$c]}{'scale'};
					}
					if(defined($sumcolumns->{$keeps[$c]}{'precision'})){
						$v = $sumcolumns->{$keeps[$c]}{'precision'} * int(0.5 + $v / $sumcolumns->{$keeps[$c]}{'precision'});
					}
				}
				$csvrow .= ($csvrow ? ",":"").($v =~ /,/ ? "\"":"").($v).($v =~ /,/ ? "\"":"");
			}
		}else{
			$v = $constituencies->{$pcon}[$col]||"";
			$csvrow .= ($csvrow ? ",":"").($v =~ /,/ ? "\"":"").$constituencies->{$pcon}[$col].($v =~ /,/ ? "\"":"");
		}
	}
	$csv .= $csvrow."\n";

}

if(defined($ofile)){
	# Make the output directory if it doesn't exist
	$dir = $ofile;
	$dir =~ s/[^\/]+$//;
	makeDir($dir);

	msg("Saving output to <cyan>$ofile<none>\n");
	open($fh,">:utf8",$ofile);
	print $fh $csv;
	close($fh);
}else{
	print $csv;
}
exit;

# Create a YYYY-MM date from the file last-modified date
$dt = strftime("%Y-%m", localtime((stat($ifile))[9]));
$dtfull = strftime("%Y-%m-%dT%H:%M", localtime((stat($ifile))[9]));
# Update dates
for(my $d = 0; $d < @datefiles; $d++){
	if($datefiles[$d] =~ /\.vto/){
		updateCreationTimestamp($datefiles[$d],$dtfull);
	}elsif($datefiles[$d] =~ /\.json/){
		my $tjson = LoadJSON($datefiles[$d]);
		if(defined($tjson->{'config'})){
			#if(defined($tjson->{'config'}{'value'})){
			#	$tjson->{'config'}{'value'} = $dt;
			#}
			#if(defined($tjson->{'config'}{'tooltip'})){
			#	$tjson->{'config'}{'tooltip'} =~ s/\{\{ [0-9]{4}-[0-9]{2} ([^\}]*)\}\}/\{\{ $dt $1\}\}/g;
			#}
			$tjson->{'date'} = $dtfull;
		}
		SaveJSON($tjson,$datefiles[$d],3);
	}else{
		warning("Unknown file type to update date for <cyan>$datefiles[$d]<none>\n");
	}
}
	










############################
sub showHelp {
	msg("Usage:\n");
	msg("    perl pipelines/groupSum.pl <CSV file> --group <group column> --sum <column to sum by group> --output <output file>\n");
	msg("\n");
	msg("Examples:\n");
	msg("    perl pipelines/groupSum.pl raw-data/society/households_census.csv -group \"groups\" -sum \"Con_num,Con_pc,RN_pc,Nat_pc\" -id \"ONSConstID\" -keep \"ONSConstID,ConstituencyName,RegNationID,RegNationName,NatComparator,Con_num,Con_pc,RN_pc,Nat_pc\" -o src/themes/society/household-composition/_data/release/households_census.csv\n");
	msg("\n");
	msg("    perl pipelines/groupSum.pl raw-data/society/UCAS\ end\ of\ cycle\ 2024\ -\ Parliamentary\ Constituency\ entry\ rates.csv -group \"Year\" -id \"Parliamentary constituency code\" -sum \"Entry rate\" -o src/themes/society/ucas/_data/release/entry_rates.csv\n");
	msg("\n");
	msg("Options:\n");
	msg("    <CSV file>                 the CSV file to load (can be at a URL)\n");
	msg("    -g, --group=Column         the column in the input CSV to group by - these end up as columns\n");
	msg("    -h, --help                 this help\n");
	msg("    -i, --id                   this column with the GSS code\n");
	msg("    -k, --keep=Column          a comma-separated list of columns to keep in the output\n");
	msg("    -o, --output=file          the destination file to save the results to\n");
	msg("    --startrow=2               the row number for the first row of data\n");
	msg("    --sum=Column               a comma-separated list of columns to sum up by group\n");
	msg("    -u, --updatedate=file      the name of a file in which to update the date stamp\n");
	exit;
}

# version 1.1
sub LoadCSVSimple {
	my $file = shift;
	my $config = shift;
	my ($csv,$row,@rows,@cols,@header,$i,$r,$c,@features,$data,$key,$k,$f,$n,$n2,$hline,$sline,$delimiter,$matches,$rowlookup,$fh);

	if(not defined($config->{'header'})){ $config->{'header'} = {}; }
	if(not defined($config->{'header'}{'start'})){ $config->{'header'}{'start'} = 0; }
	if(not defined($config->{'header'}{'spacer'})){ $config->{'header'}{'spacer'} = 0; }
	if(not defined($config->{'header'}{'join'})){ $config->{'header'}{'join'} = "→"; }
	$sline = $config->{'startrow'}||1;
	$key = $config->{'key'};
	if(defined($key)){
		$rowlookup = {};
	}
	$delimiter = ",";
	$csv = Text::CSV->new ({
		binary => 1,
		sep_char => $delimiter,
		eol => $/,                # to make $csv->print use newlines
		always_quote => 1,        # to keep your numbers quoted
	});
	$n = 0;
	msg("Processing CSV from <cyan>$file<none>\n");
	open($fh,"<:utf8",$file);
	while ($row = $csv->getline( $fh )) {
		# Check for BOM
		if($n==0){ $row->[0] =~ s/^\x{FEFF}//; }
		push(@rows,$row);
		$n++;
	}
	close($fh);
	$f = 0;
	for($r = $config->{'header'}{'start'}; $r < $n; $r++){
		$rows[$r] =~ s/[\n\r]//g;
		@cols = @{$rows[$r]};
		if($r < $sline-$config->{'header'}{'spacer'}){
			# Header
			if(!@header){
				for($c = 0; $c < @cols; $c++){
					$cols[$c] =~ s/(^\"|\"$)//g;
				}
				@header = @cols;
			}else{
				for($c = 0; $c < @cols; $c++){
					if($cols[$c]){ $header[$c] .= $config->{'header'}{'join'}.$cols[$c]; }
				}
			}
		}
		if($r >= $sline){
			push(@features,[]);
			for($c = 0; $c < @cols; $c++){
				$features[$f][$c] = $cols[$c];
				if(defined($key) && $header[$c] eq $key){
					$rowlookup->{$cols[$c]} = $f;
				}
			}
			$f++;
		}
	}
	my $columns;
	for($c = 0; $c < @header; $c++){
		$columns->{$header[$c]} = $c;
	}
	return {'rows'=>\@features,'head'=>\@header,'lookup'=>{'row'=>$rowlookup,'col'=>$columns}};
}
