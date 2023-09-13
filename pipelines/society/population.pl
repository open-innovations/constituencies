#!/usr/bin/perl

use lib "./../lib/";	# Custom functions
use Data::Dumper;


my $popfile = "../../raw-data/Population_all.csv";
my $outfile = "../../src/_data/sources/society/population-2020.csv";

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


my @rows = LoadCSV($popfile);


my $ages = {};
my $totals = {};

for($r = 0; $r < @rows; $r++){
	$pcon = $rows[$r]->{'PCON11CD'};
	$age = $rows[$r]->{'Age_year'};
	$n = $rows[$r]->{'Age_pop'};
	if(!$ages->{$pcon}){ $ages->{$pcon} = {}; }
	if(!$ages->{$pcon}{$age}){ $ages->{$pcon}{$age} = 0; }
	if(!$totals->{$pcon}){ $totals->{$pcon} = {}; }
	if(!$totals->{$pcon}{$age}){ $totals->{$pcon}{$age} = 0; }
	$ages->{$pcon}{$age} = $n;
	$totals->{$pcon}{$age} = $n;
}

$categories = {
	'total'=>{'min'=>0,'max'=>200},
	'<18'=>{'min'=>0,'max'=>17},
	'16+'=>{'min'=>16,'max'=>200},
	'17+'=>{'min'=>17,'max'=>200},
	'18+'=>{'min'=>18,'max'=>200},
	'18-64'=>{'min'=>18,'max'=>64},
	'65+'=>{'min'=>65,'max'=>200},
	'67+'=>{'min'=>67,'max'=>200},
	'70+'=>{'min'=>70,'max'=>200}
};
msg("Calculating age category totals\n");
foreach $pcon (keys(%{$ages})){
	foreach $cat (sort(keys(%{$categories}))){
		$totals->{$pcon}{$cat} = 0;
		foreach $age (keys(%{$ages->{$pcon}})){
			if($age >= $categories->{$cat}{'min'} && $age <= $categories->{$cat}{'max'}){
				$totals->{$pcon}{$cat} += $ages->{$pcon}{$age};
			}
		}
		
	}
}


msg("Saving to <cyan>$outfile<none>\n");
open(FILE,">",$outfile);
print FILE "PCON11CD";
for($i = 0; $i <= 90; $i++){
	print FILE ",".$i;
	if($i == 90){ print FILE "+"; }
}
foreach $cat (sort(keys(%{$categories}))){
	print FILE ",".$cat;
}
print FILE "\n";
foreach $pcon (sort(keys(%{$totals}))){
	print FILE "$pcon";
	for($i = 0; $i <= 90; $i++){
		print FILE ",".$totals->{$pcon}{$i};
	}
	foreach $cat (sort(keys(%{$categories}))){
		print FILE ",".$totals->{$pcon}{$cat};
	}
	print FILE "\n";
}




################
# Subroutines

sub msg {
	my $str = $_[0];
	my $dest = $_[1]||STDOUT;
	foreach my $c (keys(%colours)){ $str =~ s/\< ?$c ?\>/$colours{$c}/g; }
	print $dest $str;
}

sub error {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	msg($str,STDERR);
}

sub warning {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1$colours{'yellow'}WARNING:$colours{'none'} /;
	print STDERR $str;
}


sub LoadCSV {
	# version 1.1
	my $file = shift;
	my $col = shift;
	my $compact = shift;

	my (@lines,$str,@rows,@cols,@header,$r,$c,@features,$data,$key,$k,$f,$n,$n2);

	msg("Processing CSV from <cyan>$file<none>\n");
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	$n = () = $str =~ /\r\n/g;
	$n2 = () = $str =~ /\n/g;
	if($n < $n2 * 0.25){ 
		# Replace CR LF with escaped newline
		$str =~ s/\r\n/\\n/g;
	}
	@rows = split(/[\n]/,$str);

	$n = @rows;
	
	for($r = 0; $r < @rows; $r++){
		@cols = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$rows[$r]);

		if($r < 1){
			# Header
			if(!@header){
				for($c = 0; $c < @cols; $c++){
					$cols[$c] =~ s/(^\"|\"$)//g;
				}
				@header = @cols;
			}else{
				for($c = 0; $c < @cols; $c++){
					$header[$c] .= "\n".$cols[$c];
				}
			}
		}else{
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