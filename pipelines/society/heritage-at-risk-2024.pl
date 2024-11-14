#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use JSON::XS;
use Data::Dumper;
use Cwd qw(abs_path);
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';


# Get the real base directory for this script
my ($basedir, $path);
BEGIN { ($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$}; push @INC, $basedir; }


my $hexmap = LoadJSON($basedir.'../../src/_data/hexjson/uk-constituencies-2024.hexjson');
my $constituencies = {};
foreach my $hex (sort(keys(%{$hexmap->{'hexes'}}))){
	$constituencies->{$hexmap->{'hexes'}{$hex}{'n'}} = {
		'Name'=>$hexmap->{'hexes'}{$hex}{'n'},
		'Region'=>$hexmap->{'hexes'}{$hex}{'region'},
		'PCON24CD'=>$hex
	};
}


my $mpdata = LoadCSV($basedir.'../../src/_data/sources/society/general-elections-2024.csv',{
	'columns'=>{
		'PCON24CD'=>'PCON24CD',
		'MP'=>'MP',
		'Party'=>'Party'
	},
	'key'=>'PCON24CD'
});

my $twfy = LoadCSV($basedir.'../../lookups/theyworkforyou-2024.csv',{
	'columns'=>{
		'Person ID'=>'ID',
		'URI'=>'URI',
		'Constituency'=>'Constituency'
	},
	'key'=>'Constituency'
});

#my @rows = getXLSX({
#	'url'=>'https://historicengland.org.uk/content/docs/har/har-2024-entries-additions-removals/',
#	'file'=>$basedir.'temp/har.xlsx',
#	'sheet'=>'sheet2',
#	'keys'=>{
#		'Site name'=>'B',
#		'PCON24NM'=>'I',
#		'Heritage Category'=>'K',
#		'List Entry Number'=>'M',
#		'Place of worship'=>'P',
#		'Risk methodology'=>'Q',
#		'Priority category'=>'W',
#		'Narrow Term'=>'AC'
#	},
#	'startrow'=>2
#});

#my @rows = LoadCSV($basedir.'../../../../../Downloads/HARExport.csv',{
#	'columns'=>{
#		'Parliamentary Constituency'=>'PCON24NM',
#		'Entry Name'=>'Site name',
#		'Heritage Category'=>'Heritage Category',
#		'List Entry Number'=>'List Entry Number',
#		'Designation'=>'Narrow Term',
#		'Assessment Type'=>'Risk methodology'
#	},
#	'startrow'=>2
#});

# Heritage England provide an ODS (previously XLSX) file at https://historicengland.org.uk/content/docs/har/har-2024-entries-additions-removals/
# Extract the second sheet and make sure it is converted to UTF8
my @rows = LoadCSV($basedir.'../../raw-data/HAR Register 2024 Entries including additions and removals.csv',{
	'columns'=>{
		'Parliamentary Constituency (as at General Election July 2024)'=>'PCON24NM',
		'Published site name'=>'Site name',
		'Heritage Category'=>'Heritage Category',
		'List Entry Number (LEN) or Conservation Area Number (CAN)'=>'List Entry Number',
		'Narrow Term'=>'Narrow Term',
		'Risk methodology'=>'Risk methodology'
	},
	'startrow'=>2
});

my $mplookup = LoadCSV($basedir.'../../lookups/current-MPs.csv',{
	'columns'=>{
		'PCON24CD'=>'PCON24CD',
		'MP ID'=>'MPID',
		'BG'=>'BG'
	},
	'key'=>'PCON24CD'
});


my $nocon = 0;
my $badcon = 0;
my $double = 0;
my $counts = {};
my $types = {};
my $nrows = @rows;
my ($r,$pcon,@pcons,$p,$pid,$pname);


foreach $pcon (keys(%{$constituencies})){
	$constituencies->{$pcon}{'Historic England Name'} = $pcon;
	$constituencies->{$pcon}{'TWFY'} = $twfy->{$pcon}{'URI'};
}


for($r = 0; $r < @rows; $r++){
	$pname = $rows[$r]{'PCON24NM'};
	@pcons = ();
	# Split into multiple constituencies
	if($pname){
		if($pname =~ / \/.*/){
			@pcons = split(/ \/ /,$pname);
			$double++;
		}else{
			@pcons = ($pname);
		}
	}
	$p = @pcons;
	if($p > 0){
		for($p = 0; $p < @pcons; $p++){
			$pname = $pcons[$p];
			$pcon = $pname;
			$pcon =~ s/St\./St/g;
			$pcon =~ s/-Super-/-super-/g;
			if($pcon){
				
				if($constituencies->{$pcon}){
					$constituencies->{$pcon}{'Historic England Name'} = $pname;
					$pid = $constituencies->{$pcon}{'PCON24CD'};
					if(!$counts->{$pid}){ $counts->{$pid} = {'name'=>$pcon,'total'=>0,'types'=>{}}; }
					
					if($rows[$r]{'Narrow Term'}){
						# Only keep a count of the types once per row
						if($p==0){
							if(!$types->{$rows[$r]{'Risk methodology'}}){ $types->{$rows[$r]{'Risk methodology'}} = 0; }
							$types->{$rows[$r]{'Risk methodology'}}++;
							if(!$types->{'All'}){ $types->{'All'} = 0; }
							$types->{'All'}++;
						}
						if(!$counts->{$pid}{'types'}{'All'}){ $counts->{$pid}{'types'}{'All'} = 0; }
						$counts->{$pid}{'types'}{'All'}++;
						if(!$counts->{$pid}{'types'}{$rows[$r]{'Risk methodology'}}){ $counts->{$pid}{'types'}{$rows[$r]{'Risk methodology'}} = 0; }
						$counts->{$pid}{'types'}{$rows[$r]{'Risk methodology'}}++;
					}
					$counts->{$pid}{'total'}++;
				}else{
					warning("No constituency matches <yellow>$pcon<none>\n");
					$badcon++;
				}
			}
		}
	}else{
		#warning("No constituency for row <green>".($r+2)."<none> \"$rows[$r]{'Site name'}\"\n");
		$nocon++;
	}
}

msg("Stats:\n");
msg("\t<green>$nrows<none> entries in the register.\n");
msg("\t<green>$nocon<none> with no constituency given.\n");
msg("\t<green>$double<none> with multiple constituencies.\n");
msg("\t<green>$badcon<none> with a bad constituency name.\n");
print Dumper $types;

my ($t,$fh,@typ);
foreach $t (sort(keys(%{$types}))){
	push(@typ,$t);
}
@typ = sort(@typ);




my ($csvpow,$csvfull,$file);

# Create CSV headers
$csvfull = "PCON24CD,PCON24NM,HAR name,MP,Party short,Party,ID,BG";
for($t=0;$t < @typ;$t++){
	$csvfull .= ",Type";
}
$csvfull .= "\n,,,,,,,";
for($t=0;$t < @typ;$t++){
	$csvfull .= ",".$typ[$t];
}
$csvfull .= "\n---,---,---,---,---,---,---";
for($t=0;$t< @typ;$t++){
	$csvfull .= ",---";
}
$csvfull .= "\n";

# Add data to CSVs
foreach $pcon (sort(keys(%{$constituencies}))){
	$pid = $constituencies->{$pcon}{'PCON24CD'};
	if($pid =~ /^E/){
		#print Dumper $constituencies->{$pcon};
		$pname = $constituencies->{$pcon}{'Historic England Name'}||$pcon;

		# Build full CSV row
		$csvfull .= $pid;
		$csvfull .= ",".($pcon =~ /,/ ? "\"$pcon\"" : $pcon);
		$csvfull .= ",".($pname =~ /,/ ? "\"$pname\"" : $pname);
		$csvfull .= ",".($mpdata->{$pid}{'MP'}||"?");
		$csvfull .= ",".$mpdata->{$pid}{'Party'}.",".updatePartyName($mpdata->{$pid}{'Party'});
		$csvfull .= ",".$mplookup->{$pid}{'MPID'};#($mplookup->{$pid}{'MPID'} ? "https://members.parliament.uk/member/$mplookup->{$pid}{'MPID'}/contact" : "");
		$csvfull .= ",".($mplookup->{$pid}{'BG'});
		for($t=0;$t< @typ;$t++){
			$csvfull .= ",".($counts->{$pid}{'types'}{$typ[$t]}||"0");
		}
		$csvfull .= "\n";

	}
}

# Save outputs
$file = $basedir."../../src/themes/society/heritage-at-risk/_data/HAR2024.csv";
msg("Save to <cyan>$file<none>\n");
open($fh,">:utf8",$file);
print $fh $csvfull;
close($fh);




#####################

sub msg {
	my $str = $_[0];
	my $dest = $_[1]||"STDOUT";
	
	my %colours = (
		'black'=>"\033[0;30m",
		'red'=>"\033[0;31m",
		'green'=>"\033[0;32m",
		'yellow'=>"\033[0;33m",
		'blue'=>"\033[0;34m",
		'magenta'=>"\033[0;35m",
		'cyan'=>"\033[0;36m",
		'white'=>"\033[0;37m",
		'none'=>"\033[0m"
	);
	foreach my $c (keys(%colours)){ $str =~ s/\< ?$c ?\>/$colours{$c}/g; }
	if($dest eq "STDERR"){
		print STDERR $str;
	}else{
		print STDOUT $str;
	}
}

sub error {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	msg($str,"STDERR");
}

sub warning {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<yellow>WARNING:<none> /;
	msg($str,"STDERR");
}

sub makeDir {
	my $str = $_[0];
	my @bits = split(/\//,$str);
	my $tdir = "";
	my $i;
	for($i = 0; $i < @bits; $i++){
		$tdir .= $bits[$i]."/";
		if(!-d $tdir){
			`mkdir $tdir`;
		}
	}
}

sub getDataFromURL {
	
	my $d = shift;
	my ($url,$file,$dir,$age,$now,$epoch_timestamp,$args,$h,$n);

	$url = $d->{'url'};
	$file = $d->{'file'};

	if(!$file){
		$file = $url;
		$file =~ s/^https:\/\///g;
		$file =~ s/[^A-Za-z0-9\-\.]/\_/g;
		$file =~ s/\_+$//g;
	}

	$dir = $file;
	if(!-d $dir){ $dir =~ s/[^\/]*$//g; }

	if($dir && !-d $dir){ makeDir($dir); }

	$age = 100000;
	if(-e $file){
		$epoch_timestamp = (stat($file))[9];
		$now = time;
		$age = ($now-$epoch_timestamp);
	}

	if($age >= 86400 || -s $file == 0){
		$args = "";
		if($d->{'headers'}){
			foreach $h (keys(%{$d->{'headers'}})){
				$args .= ($args ? " " : "")."-H \"$h: $d->{'headers'}{$h}\"";
			}
		}
		if($d->{'method'}){
			$args .= " -X $d->{'data'}[$n]{'method'}"
		}
		if($d->{'form'}){
			$args .= " --data-raw \'$d->{'data'}[$n]{'form'}\'";
		}
		msg("Getting <blue>$url<none>\n");
		`curl -s --insecure -L $args --compressed -o $file "$url"`;
		msg("\tDownloaded to <cyan>$file<none>\n");
	}
	return $file;
}

sub getXLSX {
	# Version 2

	my $d = shift;
	my ($url,$file,$str,$t,@si,@strings,$sheet,$props,$row,$col,$attr,$cols,@rows,$rowdata,@geo,@features,$c,$r,$n,$datum,@orows,$orow,$propsstrip,$colstrip,$added,$key);

	$url = $d->{'url'};
	$file = $d->{'file'};

	# Get the data (if we don't have a cached version)
	$file = getDataFromURL($d);
	
	msg("Processing xlsx to extract data from <cyan>$file<none>\n");

	# First we need to get the sharedStrings.xml
	$str = decode_utf8(join("",`unzip -p $file xl/sharedStrings.xml`));

	msg("\tGetting shared strings\n");
	@strings = split(/<si>/,$str);
	for($c = 0; $c < @strings; $c++){
		$strings[$c] =~ s/(.*?)<\/si>.*/$1/g;
		$strings[$c] =~ s/<[^\>]+>//g;
	}
	shift(@strings);

	msg("\tGetting data from sheet <green>$d->{'sheet'}<none>\n");
	$str = decode_utf8(join("",`unzip -p $file xl/worksheets/$d->{'sheet'}.xml`));
	if($str =~ /<sheetData>(.*?)<\/sheetData>/){
		$sheet = $1;
		@orows = split(/<row /,$sheet);
		shift(@orows);
		for($r = 0; $r < @orows; $r++){
			if($orows[$r] =~ /([^\>]*?)>(.*?)<\/row>.*/){
				$props = $1;
				$orow = $2;
				$row = $orow;
				$attr = {};
				while($props =~ s/([^\s]+)="([^\"]+)"//){ $attr->{$1} = $2; }
				$rowdata = {'content'=>$orow,'attr'=>$attr,'cols'=>{}};
				# Remove empty cells
				$row =~ s/<c[^\>]+\/>//g;
				while($row =~ s/<c([^\>]*?)>(.*?)<\/c>//){
					$props = $1;
					$propsstrip = $props;
					$col = $2;
					$colstrip = $col;
					$colstrip =~ s/<[^\>]+>//g;
					$attr = {};
					while($propsstrip =~ s/([^\s]+)="([^\"]+)"//){ $attr->{$1} = $2; }
					if($attr->{'r'} =~ /^([A-Z]+)([0-9]+)/){
						$c = $1;
						$n = $2;
						$rowdata->{'cols'}{$c} = $strings[$colstrip];
					}
				}
				push(@rows,$rowdata);
			}
		}

		for($r = 0; $r < @rows; $r++){
			if($rows[$r]->{'attr'}{'r'} >= $d->{'startrow'}){
				$datum = {};
				$added = 0;
				foreach $key (keys(%{$d->{'keys'}})){
					if($rows[$r]->{'cols'}{$d->{'keys'}{$key}}){
						$added++;
					}	
					$datum->{$key} = $rows[$r]->{'cols'}{$d->{'keys'}{$key}}||"";
				}
				if($added > 0){ push(@features,$datum); }
			}
		}
	}
	`rm $file`;
	return @features;
}


# Version 1.4.2
sub ParseCSV {
	my $str = shift;
	my $config = shift;
	my (@rows,@cols,@header,$r,$c,@features,$data,$key,$k,$f,$n,$n2,$compact,$hline,$sline,$col,$headerlookup,$v);

	$compact = $config->{'compact'};
	if(not defined($config->{'header'})){ $config->{'header'} = {}; }
	if(not defined($config->{'header'}{'start'})){ $config->{'header'}{'start'} = 0; }
	if(not defined($config->{'header'}{'spacer'})){ $config->{'header'}{'spacer'} = 0; }
	if(not defined($config->{'header'}{'join'})){ $config->{'header'}{'join'} = "→"; }
	$sline = $config->{'startrow'}||1;
	$col = $config->{'key'};

	$n = () = $str =~ /\r\n/g;
	$n2 = () = $str =~ /\n/g;
	if($n < $n2 * 0.25){ 
		# Replace CR LF with escaped newline
		$str =~ s/\r\n/\\n/g;
	}
	@rows = split(/[\n]/,$str);

	$n = @rows;

	for($r = $config->{'header'}{'start'}; $r < @rows; $r++){
		$rows[$r] =~ s/[\n\r]//g;
		@cols = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$rows[$r]);

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
			for($c = 0; $c < @header; $c++){
				$headerlookup->{$header[$c]} = $c;
			}
		}
		if($r >= $sline){
			$data = {};
			for($c = 0; $c < @cols; $c++){
				$cols[$c] =~ s/(^\"|\"$)//g;
				if(defined($config->{'columns'})){
					foreach $k (keys(%{$config->{'columns'}})){
						$v = $cols[$headerlookup->{$k}];
						$v =~ s/(^\"|\"$)//g;
						$data->{$config->{'columns'}{$k}} = $v;
					}
				}else{
					$data->{$header[$c]} = $cols[$c];
				}
			}
			push(@features,$data);
		}
	}
	if($col){
		$data = {};
		for($r = 0; $r < @features; $r++){
			$f = $features[$r]->{$col}||"";
			if($compact){ $f =~ s/ //g; }
			$data->{$f} = $features[$r];
		}
		return $data;
	}else{
		return @features;
	}
}

sub LoadCSV {
	# version 1.3
	my $file = shift;
	my $config = shift;
	
	msg("Processing CSV from <cyan>$file<none>\n");
	open(FILE,"<:utf8",$file);
	my @lines = <FILE>;
	close(FILE);
	return ParseCSV(join("",@lines),$config);
}

sub ParseJSON {
	my $str = shift;
	my $json = {};
	if(!$str){ $str = "{}"; }
	eval {
		$json = JSON::XS->new->decode($str);
	};
	if($@){ error("\tInvalid output.\n"); }
	return $json;
}

sub LoadJSON {
	my (@files,$str,@lines,$json);
	my $file = $_[0];
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = (join("",@lines));
	# Error check for JS variable e.g. South Tyneside https://maps.southtyneside.gov.uk/warm_spaces/assets/data/wsst_council_spaces.geojson.js
	$str =~ s/[^\{]*var [^\{]+ = //g;
	return ParseJSON($str);
}


sub updatePartyName {
	my $party = shift||"";

	if($party eq "Con"){ $party = "Conservative"; }
	elsif($party eq "Lab"){ $party = "Labour"; }
	elsif($party eq "LD" || $party eq "LDem"){ $party = "Liberal Democrat"; }
	elsif($party eq "Grn"){ $party = "Green"; }
	elsif($party eq "PC"){ $party = "Plaid Cymru"; }
	elsif($party eq "Ind"){ $party = "Independent"; }
	elsif($party eq "SF"){ $party = "Sinn Féin"; }
	elsif($party eq "WPB"){ $party = "Workers Party of Britain"; }
	elsif($party eq "Spk"){ $party = "Speaker"; }

	return $party;
}