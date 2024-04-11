#!/usr/bin/perl

use strict; use warnings;
use utf8;
use JSON::XS;
use Encode;
use Data::Dumper;
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
use Cwd qw(abs_path);


# Get the real base directory for this script
my ($basedir, $path);
BEGIN { ($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$}; push @INC, $basedir; }

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

my $constituencies = getCSV({
	'file'=>$basedir.'../../lookups/constituencies-2010.csv',
	'keys'=>{
		'PCON10CD'=>'PCON10CD',
		'Name'=>'Name',
		'Region'=>'Region'
	},
	'index'=>'Name',
	'startrow'=>2
});

my $mpdata = getCSV({
	'file'=>$basedir.'../../src/_data/sources/society/general-elections.csv',
	'keys'=>{
		'PCON10CD'=>'const_id',
		'MP'=>'Current MP',
		'Party'=>'Current'
	},
	'index'=>'PCON10CD',
	'startrow'=>2
});

my @rows = getXLSX({
	'url'=>'https://historicengland.org.uk/content/docs/har/har-2023-entries-additions-removals/',
	'file'=>$basedir.'temp/har.xlsx',
	'sheet'=>'sheet2',
	'keys'=>{
		'Site name'=>'B',
		'PCON10NM'=>'I',
		'Heritage Category'=>'K',
		'List Entry Number'=>'M',
		'Place of worship'=>'P',
		'Risk methodology'=>'Q',
		'Priority category'=>'W',
		'Narrow Term'=>'AC'
	},
	'startrow'=>2
});

my $nocon = 0;
my $badcon = 0;
my $double = 0;
my $counts = {};
my $types = {};
my $nrows = @rows;
my ($r,$pcon,@pcons,$p,$pid,$pname);
for($r = 0; $r < @rows; $r++){
	$pname = $rows[$r]{'PCON10NM'};
	@pcons = ();
	# Limit to first constituency when two are given
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
			if($pcon){
				if($constituencies->{$pcon}){
					$constituencies->{$pcon}{'Historic England Name'} = $pname;
					$pid = $constituencies->{$pcon}{'PCON10CD'};
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

my $csv = "PCON10CD,Name,MP,Party short,Party";
for($t=0;$t < @typ;$t++){
	$csv .= ",Type";
}
$csv .= "\n,,,,";
for($t=0;$t < @typ;$t++){
	$csv .= ",".$typ[$t];
}
$csv .= "\n---,---,---,---,---";
for($t=0;$t< @typ;$t++){
	$csv .= ",---";
}

$csv .= "\n";
foreach $pcon (sort(keys(%{$constituencies}))){
	$pid = $constituencies->{$pcon}{'PCON10CD'};
	if($pid =~ /^E/){
		#print Dumper $constituencies->{$pcon};
		$pname = $constituencies->{$pcon}{'Historic England Name'}||$pcon;
		$csv .= $pid.",".($pcon =~ /,/ ? "\"$pname\"" : $pname);
		$csv .= ",".$mpdata->{$pid}{'MP'};
		$csv .= ",".$mpdata->{$pid}{'Party'}.",".updatePartyName($mpdata->{$pid}{'Party'});
		for($t=0;$t< @typ;$t++){
			$csv .= ",".($counts->{$pid}{'types'}{$typ[$t]}||"0");
		}
		$csv .= "\n";
	}
}

open($fh,">:utf8",$basedir."../../src/_data/sources/society/heritage-at-risk.csv");
print $fh $csv;
close($fh);


#####################

sub msg {
	my $str = $_[0];
	my $dest = $_[1]||"STDOUT";
	foreach my $c (keys(%colours)){ $str =~ s/\< ?$c ?\>/$colours{$c}/g; }
	if($dest eq "STDOUT"){
		print STDOUT $str;
	}else{
		print STDERR $str;
	}
}

sub error {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	msg($str,"STDERR");
}

sub warning {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1$colours{'yellow'}WARNING:$colours{'none'} /;
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


sub getCSV {
	my $d = shift;

	my ($url,$file,@lines,$str,@rows,@cols,@header,$r,$c,@features,$dict,$data,$key,$k,$f,$v,$headerlookup);

	$url = $d->{'url'};
	$file = $d->{'file'};

	if($url){
		# Get the data (if we don't have a cached version)
		$file = getDataFromURL($d);
	}

	msg("Processing CSV <cyan>$file<none>\n");
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);
	@rows = split(/\n/,$str);

	for($r = 0; $r < @rows; $r++){
		@cols = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$rows[$r]);
		if($r < $d->{'startrow'}-1){
			# Header
			if(!@header){
				@header = @cols;
			}else{
				for($c = 0; $c < @cols; $c++){
					$header[$c] .= "\n".$cols[$c];
				}
			}
		}else{
			$data = {};
			if($r == $d->{'startrow'}-1){
				# Process header line - rename columns based on the defined keys
				for($c = 0; $c < @cols; $c++){
					$key = $header[$c];
					foreach $k (keys(%{$d->{'keys'}})){
						if($d->{'keys'}{$k} eq $key){
							$header[$c] = $k;
							last;
						}
					}
				}
				for($c = 0; $c < @header; $c++){
					$headerlookup->{$header[$c]} = $c;
				}
			}
			foreach $k (keys(%{$d->{'keys'}})){
				$v = $cols[$headerlookup->{$k}];
				$v =~ s/(^\"|\"$)//g;
				$data->{$k} = $v;
			}
			if($d->{'index'}){
				$v = $cols[$headerlookup->{$d->{'index'}}];
				$v =~ s/(^\"|\"$)//g;
				$dict->{$v} = $data;
			}else{
				push(@features,$data);
			}
		}
	}
	if($d->{'index'}){
		return $dict;
	}else{
		return @features;
	}
}

sub updatePartyName {
	my $party = shift;

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