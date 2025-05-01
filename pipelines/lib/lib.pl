#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use JSON::XS;
use POSIX qw(strftime);
use open qw(:std :encoding(UTF-8));
binmode(STDOUT, ":utf8");
binmode(STDIN, ":encoding(UTF-8)");

################
# Subroutines

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

sub updateCreationTimestamp {
	my $file = shift;
	my(@lines,$fh,$i,$dt);
	open($fh,$file);
	@lines = <$fh>;
	close($fh);
	$dt = strftime("%FT%H:%M", localtime);
	for($i = 0; $i < @lines ; $i++){
		$lines[$i] =~ s/^(updated: )(.*)/$1$dt/;
		$lines[$i] =~ s/^([\t\s]+)"date": ?"[^\"]*"/$1"date": "$dt"/;
	}
	msg("Updating timestamp in <cyan>$file<none>\n");
	open($fh,">",$file);
	print $fh @lines;
	close($fh);
}

# Version 1.4
sub ParseCSV {
	my $str = shift;
	my $config = shift;
	my (@rows,@cols,@header,$r,$c,@features,$data,$key,$k,$f,$n,$n2,$compact,$hline,$sline,$col);

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
		}
		if($r >= $sline){
			$data = {};
			for($c = 0; $c < @cols; $c++){
				$cols[$c] =~ s/(^\"|\"$)//g;
				$data->{$header[$c]} = $cols[$c];
			}
			push(@features,$data);
		}
	}
	if($col){
		$data = {};
		for($r = 0; $r < @features; $r++){
			$f = $features[$r]->{$col};
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

sub LoadJSON {
	my (@files,$str,@lines);
	my $file = $_[0];
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = (join("",@lines));
	# Error check for JS variable e.g. South Tyneside https://maps.southtyneside.gov.uk/warm_spaces/assets/data/wsst_council_spaces.geojson.js
	$str =~ s/[^\{]*var [^\{]+ = //g;
	if(!$str){ $str = "{}"; }
	return JSON::XS->new->decode($str);
}

sub SaveFromURL {
	my $url = shift;
	my $file = shift;
	my $args = shift;
	my ($age,$now,$epoch_timestamp,$arguments,$h);

	msg("URL: <yellow>$url<none>\n");

	$age = 100000;
	if(-e $file){
		$epoch_timestamp = (stat($file))[9];
		$now = time;
		$age = ($now-$epoch_timestamp);
	}

	msg("File: <cyan>$file<none>\n");
	if($age >= 86400 || -s $file == 0){
		$arguments = "";
		if($args->{'headers'}){
			foreach $h (keys(%{$args->{'headers'}})){
				$arguments .= ($arguments ? " " : "")."-H \"$h: $args->{'headers'}{$h}\"";
			}
		}
		if($args->{'method'}){
			$arguments .= " -X $args->{'method'}"
		}
		if($args->{'form'}){
			$arguments .= " --data-raw \'$args->{'form'}\'";
		}
		`curl -s --insecure -L $arguments --compressed -o $file "$url"`;
		msg("Downloaded to <cyan>$file<none>\n");
	}
	return $file;
}

1;