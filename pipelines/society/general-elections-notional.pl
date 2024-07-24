#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Data::Dumper;
use POSIX qw(strftime);
use Cwd qw(abs_path);
use open qw(:std :encoding(UTF-8));
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';

my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
require $basedir."../lib/lib.pl";

my ($hexjson,$lookup,$pcon,$con,$i,$pname,$party);


$hexjson = LoadJSON($basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson");
# Build a lookup from constituency name to code
#$lookup = {};
#foreach $pcon (keys(%{$hexjson->{'hexes'}})){ $lookup->{$hexjson->{'hexes'}{$pcon}{'n'}} = $pcon; }

my @notional = getNotional("https://electionresults.parliament.uk/general-elections/5/candidacies.csv",$basedir."ge-2019-notional.csv");

$con = {};
for($i = 0; $i < @notional; $i++){

	$pcon = $notional[$i]->{'Constituency geographic code'};

	$pname = $notional[$i]->{'Constituency name'};
	if($pname eq "Montgomeryshire and Glyndwr"){ $pname = "Montgomeryshire and Glyndŵr"; }
	if($pname eq "Queen&#39;s Park and Maida Vale"){ $pname = "Queen's Park and Maida Vale"; }

	if(!$con->{$pcon}){ $con->{$pcon} = {'name'=>$pname,'candidates'=>[],'majority'=>0,'party'=>'','electorate'=>$notional[$i]->{'Electorate'}+0}; }
	$party = $notional[$i]->{'Main party abbreviation'};
	if(!$party){
		if($notional[$i]->{'Candidate is standing as independent'} eq "true"){ $party = "Ind"; }
		if($notional[$i]->{'Candidate is standing as Commons Speaker'} eq "true"){ $party = "Spk"; }
	}
	if($notional[$i]->{'Candidate result position'} == 1){
		$con->{$pcon}{'party'} = $party;
		$con->{$pcon}{'majority'} = $notional[$i]->{'Majority'}+0;
	}
	push(@{$con->{$pcon}{'candidates'}},{'party'=>$party,'count'=>$notional[$i]->{'Candidate vote count'}+0});
}

my $csv = "PCON24CD,Name,GE 2019 Electorate,GE 2019 Party,GE 2019 Majority\n";
foreach $pcon (sort(keys(%{$con}))){
	$csv .= "$pcon,\"$con->{$pcon}{'name'}\",$con->{$pcon}{'electorate'},$con->{$pcon}{'party'},$con->{$pcon}{'majority'}\n";
}

my $updated = saveSummary($basedir."../../src/_data/sources/society/general-elections-notional.csv",$csv);



#######################

sub addNotionalData {
	my $con = shift||{};
	my @notional = @_;
	my ($n,$pcd,@pcds,$pname);
	@pcds = keys(%{$hexjson->{'hexes'}});

	print Dumper @notional;
	for($n = 0; $n < @notional; $n++){

		$pname = $notional[$n]->{'Constituency name'};
		if($pname eq "Montgomeryshire and Glyndwr"){ $pname = "Montgomeryshire and Glyndŵr"; }
		if($pname eq "Queen&#39;s Park and Maida Vale"){ $pname = "Queen's Park and Maida Vale"; }
		if($lookup->{$pname}){
			$pcd = $lookup->{$pname};
			$con->{$pcd}{'GE 2019* Majority'} = $notional[$n]->{'Majority'};
			$con->{$pcd}{'GE 2019* Majority'} = $notional[$n]->{'Majority'};
		}else{
			warning("No match for <yellow>$pname<none>\n");
		}
	}
	exit;
}

sub makeSummary {
	my $con = shift;
	my ($i,$pcon,$csv,$list,$fh);

	$csv = "PCON24CD,Name,Number of Candidates,Candidates\n";
	foreach $pcon (sort(keys(%{$hexjson->{'hexes'}}))){
		$csv .= "$pcon,\"$hexjson->{'hexes'}{$pcon}{'n'}\"";
		$csv .= ",".($con->{$pcon}{'n'}||0);
		$list = "";
		if(defined($con->{$pcon}{'list'})){
			for($i = 0; $i < @{$con->{$pcon}{'list'}}; $i++){
				$list .= ($i == 0 ? "":"<br />")."<a href='https://whocanivotefor.co.uk/person/$con->{$pcon}{'list'}[$i]{'id'}'>".$con->{$pcon}{'list'}[$i]{'name'}."</a> (".$con->{$pcon}{'list'}[$i]{'party'}.")";
			}
		}
		$csv .= ",\"$list\"";
		$csv .= "\n";
	}
	return $csv;
}

sub saveSummary {
	my $file = shift;
	my $csv = shift;
	my ($fh,$existing,@lines);

	# Read in the existing summary
	open($fh,$file);
	@lines = <$fh>;
	close($fh);
	$existing = join("",@lines);
	
	if($existing ne $csv){
		msg("Updating CSV at <cyan>$file<none>\n");
		open($fh,">",$file);
		print $fh $csv;
		close($fh);
		return 1;
	}
	return 0;
}

sub getNotional {
	my $url = shift;
	my $file = shift;
	my (@lines,$fh,@candidates);
	if(-e $file){
		open($fh,"<:utf8",$file);
		@lines = <$fh>;
		close($fh);
	}else{
		msg("Get <cyan>$url<none>\n");
		@lines = `curl '$url' -o "$file"`;
	}
	return ParseCSV(join("",@lines));
}
