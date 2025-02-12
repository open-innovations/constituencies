#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use JSON::XS;
use Data::Dumper;
my $dir;
BEGIN {
	$dir = $0;
	$dir =~ s/[^\/]*$//g;
	if(!$dir){ $dir = "./"; }
}

my ($ifile,$cmd,$namecol,$col,$rtn,$r,$h,$csv,$hexjson,$lookup,$pcon,$val,$ofile);

$cmd = getCommandLineOpts();
$ifile = $cmd->{'args'}[0];
$namecol = $cmd->{'c'}||$cmd->{'constituency'};

if(!-e $ifile){
	error("No input file <cyan>$ifile<none>\n");
	exit;
}
if(!$namecol){
	error("Please specify the name of the column with the constituency name.\n");
	exit;
}

$rtn = LoadCSV($ifile);

$hexjson = LoadJSON($dir."../src/_data/hexjson/uk-constituencies-2024.hexjson");
foreach $pcon (keys(%{$hexjson->{'hexes'}})){
	$lookup->{$hexjson->{'hexes'}{$pcon}{'n'}} = $pcon;
}

# Find the column index 
$col = getIndexOf(@{$rtn->{'header'}},$namecol);
if($col < 0){
	error("Can't find \"$namecol\" in the input CSV\n");
	exit;
}


$csv = "";
for($h = 0; $h < @{$rtn->{'header'}}; $h++){
	$csv .= ($h > 0 ? ",":"");
	$csv .= "$rtn->{'header'}[$h]";
	if($h == $col){
		$csv .= ",PCON24CD";
	}
}
$csv .= "\n";
for($r = 0; $r < @{$rtn->{'rows'}}; $r++){
	for($h = 0; $h < @{$rtn->{'header'}}; $h++){
		$val = $rtn->{'rows'}[$r]{$rtn->{'header'}[$h]};
		$csv .= ($h > 0 ? ",":"");
		$csv .= ($val =~ /,/ ? "\"":"").$val.($val =~ /,/ ? "\"":"");
		if($h == $col){
			$csv .= ",$lookup->{$val}";
			if(!$lookup->{$val}){
				warning("Can't find code for $val\n");
			}
		}
	}
	$csv .= "\n";
}

$ofile = $cmd->{'o'} || $cmd->{'output'};
if($ofile){
	open(FILE,">utf8",$ofile);
	print FILE $csv;
	close(FILE);
}else{
	print $csv;
}




######################

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

sub getCommandLineOpts {
	my $data = {'args'=>[]};
	for(my $i = 0; $i < @ARGV; $i++){
		if($ARGV[$i] =~ /^\-\-?(.*)/){
			$data->{$1} = $ARGV[++$i];
		}else{
			push(@{$data->{'args'}},$ARGV[$i]);
		}
		
	}
	return $data;
}

sub LoadCSV {
	my $file = shift;
	my $col = shift;

	my (@lines,$str,@rows,@cols,@header,$r,$c,@features,$data,$key,$k,$f);

	msg("Processing CSV from <cyan>$file<none>\n");
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);
	@rows = split(/[\r\n]+/,$str);

	for($r = 0; $r < @rows; $r++){
		@cols = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$rows[$r]);
		for($c = 0; $c < @cols; $c++){
			$cols[$c] =~ s/(^\"|\"$)//g;
		}
		if($r < 1){
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
			for($c = 0; $c < @cols; $c++){
				$data->{$header[$c]} = $cols[$c];
			}
			push(@features,$data);
		}
	}
	if($col){
		$data = {};
		for($r = 0; $r < @features; $r++){
			$data->{$features[$r]->{$col}} = $features[$r];
		}
		return {'data'=>$data,'header'=>\@header};
	}else{
		return {'rows'=>\@features,'header'=>\@header};
	}
}

sub getIndexOf {
	my @array = @_;
	my $val = pop(@array);
	for(my $i = 0; $i < @array; $i++){
		if($array[$i] eq $val){ return $i; }
	}
	return -1;
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

# Version 1.1.1
sub SaveJSON {
	my $json = shift;
	my $file = shift;
	my $depth = shift;
	my $oneline = shift;
	if(!defined($depth)){ $depth = 0; }
	my $d = $depth+1;
	my ($txt,$fh);
	

	$txt = JSON::XS->new->canonical(1)->pretty->space_before(0)->encode($json);
	$txt =~ s/   /\t/g;
	$txt =~ s/\n\t{$d,}//g;
	$txt =~ s/\n\t{$depth}([\}\]])(\,|\n)/$1$2/g;
	$txt =~ s/": /":/g;

	if($oneline){
		$txt =~ s/\n[\t\s]*//g;
	}

	msg("Save JSON to <cyan>$file<none>\n");
	open($fh,">:utf8",$file);
	print $fh $txt;
	close($fh);

	return $txt;
}