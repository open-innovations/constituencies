#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Data::Dumper;
use Cwd qw(abs_path);
use Text::CSV;
use POSIX qw(strftime);
use open qw(:std :encoding(UTF-8));
binmode(STDOUT, ":utf8");
binmode(STDIN, ":encoding(UTF-8)");
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";
use OpenInnovations::XLSX;

my $url = "https://www.link.co.uk/data-research/the-atm-network";
my $hexjson = $basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson";
my $ofile = $basedir."../../src/themes/economy/atms/_data/release/link.csv";
my $visfile = $basedir."../../src/themes/economy/atms/_data/total.json";
my $htmfile = $basedir."../../src/themes/economy/atms/index.vto";


my ($file,$html,$xlsx,$table,$row,$r,$c,$h,$v,$hid,$pcons,$pcon,$pconid,$m,$r2,$key,@head,@rows,@cols,$pconidx,$fh,$csv,$now);


$now = (strftime "%Y-%m-%dT%H:%M", localtime);

$hexjson = LoadJSON($hexjson);

# Build lookup
$pcons = {};
foreach $hid (keys(%{$hexjson->{'hexes'}})){
	$pcons->{$hexjson->{'hexes'}{$hid}{'n'}} = $hid;
}
$pcons->{"Montgomeryshire and Glyndwr"} = "W07000102";


# Get the LINK HTML page and look for 
# <a aria-label="LINK ATMs by Parliamentary Constituency" href="/media/2arbyzvm/ons-constituency-summary-rolling-monthly-overview-april-2025.xlsx"
$html = GetURL($url);
if($html =~ /aria-label="LINK ATMs by Parliamentary Constituency"[^\>]*href="([^\"]+)"/){
	$file = $basedir."../../raw-data/economy/link-atms.xlsx";
	$url = "https://www.link.co.uk".$1;
	# Get the remote data
	SaveFromURL($url,$file);
}else{
	error("Can't find link for parliamentary breakdown in <cyan>$url<none>.\n");
	exit;
}

$csv = LoadCSVSimple($ofile);

# Load in the Excel file
$xlsx = OpenInnovations::XLSX->new()->load($file);
$table = $xlsx->loadSheet('2024 Constituency Boundaries',{
	'header'=>[1,2],
	'startrow'=>3,
	'rename'=>sub {
		my $str = shift;
		my $months = {'January'=>'01','February'=>'02','March'=>'03','April'=>'04','May'=>'05','June'=>'06','July'=>'07','August'=>'08','September'=>'09','October'=>'10','November'=>'11','December'=>'12'};
		if($str =~ /([A-Z][a-z]{3,}) ([0-9]{4})/){
			#return $2."-".$months->{$1};
		}elsif($str =~ "Parliamentary Constituency"){
			return "Parliamentary Constituency";
		}
		return $str;
	}
});


@head = @{$csv->{'head'}};
@rows = @{$csv->{'rows'}};
$pconidx = getIndexOf( qr/PCON24CD/, @head );

# Loop over the rows in XLSX table and add in data from the existing CSV
for($r = 0; $r < @{$table->{'rows'}}; $r++){
	#$pconid = $row->{'Lookup'};
	$pcon = $table->{'rows'}[$r]{'Parliamentary Constituency'};
	if($table->{'rows'}[$r]{'Lookup'}){
		if(defined($pcons->{$pcon})){
			$pconid = $pcons->{$pcon};
			# Find the row in the original CSV
			$m = -1;

			for($r2 = 0; $r2 < @rows; $r2++){
				if($rows[$r2][$pconidx] eq $pconid){
					$m = $r2;
					last;
				}
			}
			if($m >= 0){
				for($c = 0; $c < @{$rows[$m]}; $c++){
					$table->{'rows'}[$r]{$head[$c]} = $rows[$m][$c];
				}
			}
		}else{
			warning("No match for <yellow>$pcon<none>\n");
		}
	}

}

# Just store the new header columns that look like dates
my @newhead = sort(keys(%{$table->{'headers'}{'lookup'}}));
for(my $c = @newhead - 1; $c >= 0; $c--){
	$newhead[$c] = $table->{'headers'}{'lookup'}{$newhead[$c]};
	if($newhead[$c] !~ /([A-Z][a-z]{3,}) ([0-9]{4})/){
		splice(@newhead,$c,1);
	}else{
		my @i = grep { $head[$_] eq $newhead[$c] } 0 .. $#head;
		if(@i > 0){
			splice(@newhead,$c,1);
		}
		
	}
}
splice(@head,getIndexOf( qr/Region/, @head )+1,0,sortColumns(@newhead));
my $latest = "";
my $idx = getIndexOf( qr/Region/, @head )+1;
if($head[$idx] =~ /([A-Z][a-z]{2,} [0-9]{4})/){
	$latest = $1;
}

# Build the CSV output
$csv = "";
my $n = 0;
my @headers = ();
for($h = 0; $h < @head; $h++){
	@cols = split(/→/,$head[$h]);
	$headers[$h] = ();
	for($c = 0; $c < @cols; $c++){
		$headers[$h][$c] = $cols[$c];
		if(@{$headers[$h]} > $n){ $n = @{$headers[$h]}; }
	}
}

for($r = 0; $r <= $n; $r++){
	for($c = 0; $c < @headers; $c++){
		if($r < $n){
			$v = $headers[$c][$r]||"";
		}else{
			$v = "---";
		}
		$csv .= ($c > 0 ? ",":"").$v;
	}
	$csv .= "\n";
}

# Loop over the rows
for($r = 0; $r < @{$table->{'rows'}}; $r++){
	$row = $table->{'rows'}[$r];
	if($row->{'PCON24CD'} && defined($hexjson->{'hexes'}{$row->{'PCON24CD'}})){
		for($c = 0; $c < @head; $c++){
			if(!defined($row->{$head[$c]})){ $row->{$head[$c]} = ""; }
			$csv .= ($c > 0 ? ",":"").($row->{$head[$c]} =~ /,/ ? '"' : '').($row->{$head[$c]}||"").($row->{$head[$c]} =~ /,/ ? '"' : '');
		}
		$csv .= "\n";
	}
}
open($fh,">",$ofile);
print $fh $csv;
close($fh);

my $json = LoadJSON($visfile);
$json->{'config'}{'value'} = $latest."→TOTAL";
for($c = 0; $c < @{$json->{'config'}{'tools'}{'slider'}{'columns'}}; $c++){
	$json->{'config'}{'tools'}{'slider'}{'columns'}[$c]{'value'} =~ s/^.*(→)/$latest$1/g;
}
$json->{'date'} = parseDate($latest);

SaveJSON($json,$visfile,4);
updateCreationTimestamp($htmfile,$now);





###################################
sub sortColumns {
	my @keys = @_;
	return map { $_->[0] } reverse sort { $a->[1] cmp $b->[1] || $b->[2] cmp $a->[2] } map { [$_, parseDate($_), ($_ =~ /→(.*)/ ? lc($1) : '') ] } @keys;
}

sub parseDate {
	my $str = shift;
	my $months = {'January'=>'01','February'=>'02','March'=>'03','April'=>'04','May'=>'05','June'=>'06','July'=>'07','August'=>'08','September'=>'09','October'=>'10','November'=>'11','December'=>'12'};
	if($str =~ /([A-Z][a-z]{3,}) ([0-9]{4})/){
		return $2."-".$months->{$1};
	}
	return $str;
}

# version 1.3
sub LoadCSVSimple {
	my $file = shift;
	my $config = shift;
	my ($csv,$row,@rows,@cols,@header,$i,$r,$c,@features,$data,$key,$k,$f,$n,$n2,$hline,$sline,$delimiter,$matches,$rowlookup,$fh,$lasthead);

	if(not defined($config->{'header'})){ $config->{'header'} = {}; }
	if(not defined($config->{'header'}{'start'})){ $config->{'header'}{'start'} = 0; }
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
	$lasthead = $config->{'header'}{'start'};
	$sline = $config->{'header'}{'start'} + 1;
	if(defined($config->{'startrow'})){
		$sline = $config->{'startrow'};
	}
	my $counter = 0;
	for($r = $config->{'header'}{'start'}; $r < $n; $r++){
		$rows[$r] =~ s/[\n\r]//g;
		@cols = @{$rows[$r]};
		for($c = 0, $counter = 0; $c < @cols; $c++){
			if($cols[$c] eq "---"){ $counter++; }
		}
		if($counter > 0 && $counter eq @cols){
			$sline = $r+1;
			$lasthead = $r-1;
		}
	}
	for($r = $config->{'header'}{'start'}; $r < $n; $r++){
		$rows[$r] =~ s/[\n\r]//g;
		@cols = @{$rows[$r]};
		if($r <= $lasthead){
			# Header
			if(!@header){
				for($c = 0; $c < @cols; $c++){
					$cols[$c] =~ s/(^\"|\"$)//g;
				}
				@header = @cols;
			}else{
				for($c = 0; $c < @cols; $c++){
					if($cols[$c] && $cols[$c] ne "---"){ $header[$c] .= $config->{'header'}{'join'}.$cols[$c]; }
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


sub getIndexOf {
	my $pattern = shift;
	my @array = @_;
	my( $found, $index ) = ( undef, -1 );
	for(my $i = 0; $i < @array; $i++ ) {
		if( $array[$i] =~ $pattern ) {
			$found = $array[$i];
			$index = $i;
			return $i;
			last;
		}
	}
	return -1;
}
