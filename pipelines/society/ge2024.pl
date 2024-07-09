#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use JSON::XS;
use Data::Dumper;
use Cwd qw(abs_path);
use POSIX qw(strftime);
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';

# Get the real base directory for this script
my ($basedir, $path);
BEGIN { ($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$}; push @INC, $basedir; }

my $ddir = $basedir."../../../ge-2024/src/constituency/_data/results/";
my $file = $basedir."../../src/_data/sources/society/general-elections-2024.csv";


my ($dh,$fh,$filename,$data,$pid,$results,$lookup,$key);

$lookup = {
	'lab'=>'Lab',
	'con'=>'Con',
	'ld'=>'LD',
	'ref'=>'Ref',
	'pc'=>'PC',
	'green'=>'Green',
	'snp'=>'SNP',
	'sf'=>'SF',
	'dup'=>'DUP',
	'sdlp'=>'SDLP',
	'apni'=>'APNI',
	'speaker'=>'Spk',
	'tuv'=>'TUV',
	'uup'=>'UUP',
	'other'=>'Ind'
};

opendir($dh,$ddir);
msg("Reading JSON files from <cyan>$ddir<none>\n");
while( ($filename = readdir($dh))) {
	if($filename =~ /[EWSN][0-9]{8}\.json$/){
		$data = processResult($ddir.$filename);
		if($data){
			$pid = $data->{'pcon24cd'};
			$key = $data->{'party_key'};
			if($lookup->{$data->{'party_key'}}){ $key = $lookup->{$data->{'party_key'}}; }
			$results->{$pid}{'Party'} = $key;
			$results->{$pid}{'MP'} = $data->{'mp'};
			$results->{$pid}{'Party name'} = $data->{'party_name'};
			$results->{$pid}{'PCON24NM'} = $data->{'pcon24nm'};
			$results->{$pid}{'Majority'} = $data->{'majority'};
			$results->{$pid}{'Percent'} = $data->{'pc'};
			$results->{$pid}{'Second'} = $lookup->{$data->{'second'}}||$data->{'second'};
			$results->{$pid}{'Electorate'} = $data->{'electorate'};
			$results->{$pid}{'Turnout'} = sprintf("%0.1f",100*$data->{'total_votes'}/$data->{'electorate'})
		}
	}
}
closedir($dh);

msg("Save to <cyan>$file<none>\n");
open($fh,">:utf8",$file);
print $fh "PCON24CD,PCON24NM,MP,Party,Party name,Share,Majority,Electorate,Turnout,Second\n";
foreach $pid (sort(keys(%{$results}))){
	print $fh "$pid,";
	print $fh "\"$results->{$pid}{'PCON24NM'}\",";
	print $fh "\"".($results->{$pid}{'MP'}||"")."\",";
	print $fh "$results->{$pid}{'Party'},";
	print $fh "\"".($results->{$pid}{'Party name'}||"")."\",";
	print $fh "$results->{$pid}{'Percent'},";
	print $fh "$results->{$pid}{'Majority'},";
	print $fh "$results->{$pid}{'Electorate'},";
	print $fh "$results->{$pid}{'Turnout'},";
	print $fh "$results->{$pid}{'Second'}\n";
}
close($fh);
exit;





##########################
# SUB ROUTINES
sub processResult {
	my $file = shift;
	my $data = LoadJSON($file);
	my ($i,@sortedvotes,$total);
	$total = 0;
	
	@sortedvotes = sort{ $b->{'votes'} <=> $a->{'votes'} }(@{$data->{'votes'}});

	for($i = 0; $i < @sortedvotes; $i++){
		$total += $sortedvotes[$i]->{'votes'};
	}
	$data->{'party_key'} = $sortedvotes[0]{'party_key'};
	$data->{'party_name'} = $sortedvotes[0]{'party_name'};
	$data->{'mp'} = $sortedvotes[0]{'person_name'};
	$data->{'majority'} = $sortedvotes[0]{'votes'}-$sortedvotes[1]{'votes'};
	$data->{'total_votes'} = $total;
	$data->{'pc'} = sprintf("%0.1f",100*$sortedvotes[0]->{'votes'}/$total);
	$data->{'second'} = $sortedvotes[1]{'party_key'};
	return $data;
}

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

sub ParseJSON {
	my $str = shift;
	my ($json);
	eval {
		$json = JSON::XS->new->decode($str);
	};
	if($@){ error("\tInvalid output in input: \"".substr($str,0,100)."...\".\n"); $json = {}; }
	return $json;
}

sub LoadJSON {
	my (@files,$str,@lines,$json);
	my $file = $_[0];
	open(FILE,"<:utf8",$file) || error("Unable to load <cyan>$file<none>.");
	@lines = <FILE>;
	close(FILE);
	$str = (join("",@lines));
	return ParseJSON($str);
}

sub SaveJSON {
	my $file = shift;
	my $json = shift;
	my $txt = JSON::XS->new->canonical(1)->pretty->space_before(0)->encode($json);
	my ($fh);
	$txt =~ s/   /\t/g;

	open($fh,">:utf8",$file);
	print $fh $txt;
	close($fh);
	return;
}