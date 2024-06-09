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

my ($hexjson,$lookup,$pcon,@candidates,$con);


$hexjson = LoadJSON($basedir."../../src/_data/hexjson/uk-constituencies-2023.hexjson");
# Build a lookup from constituency name to code
$lookup = {};
foreach $pcon (keys(%{$hexjson->{'hexes'}})){ $lookup->{$hexjson->{'hexes'}{$pcon}{'n'}} = $pcon; }

$con = addCandidateData($con,getCandidates());

my $csv = makeSummary($con);
my $updated = saveSummary($basedir."../../src/_data/sources/society/general-elections-2024.csv",$csv);
if($updated){
	updateCreationTimestamp($basedir."../../src/themes/society/general-elections/index.njk");
	updateCreationTimestamp($basedir."../../src/themes/society/general-elections/embeds/candidates-2024.njk");
}

#######################
sub updateCreationTimestamp {
	my $file = shift;
	my(@lines,$fh,$i,$dt);
	open($fh,$file);
	@lines = <$fh>;
	close($fh);
	$dt = strftime("%FT%H:%M", localtime);
	for($i = 0; $i < @lines ; $i++){
		$lines[$i] =~ s/^(updated: )(.*)/$1$dt/;
	}
	msg("Updating timestamp in <cyan>$file<none>\n");
	open($fh,">",$file);
	print $fh @lines;
	close($fh);
}
sub addCandidateData {
	my $con = shift||{};
	my @candidates = @_;
	my ($i,$pcon,$name);
	
	for($i = 0; $i < @candidates; $i++){
		if($lookup->{$candidates[$i]{'post_label'}}){
			$pcon = $lookup->{$candidates[$i]{'post_label'}};
			$candidates[$i]{'PCON24CD'} = $lookup->{$candidates[$i]{'post_label'}};
			if(!defined($con->{$pcon})){
				$name = $hexjson->{'hexes'}{$pcon}{'n'}||"";
				$con->{$pcon} = { 'name'=>$name,'n'=>0,'list'=>[] };
			}
			$con->{$pcon}{'n'}++;
			push(@{$con->{$pcon}{'list'}},{
				'name'=>$candidates[$i]{'person_name'},
				'party'=>$candidates[$i]{'party_name'},
				'id'=>$candidates[$i]{'person_id'}
			});
		}else{
			warning("No match for <yellow>$candidates[$i]{'post_label'}<none>\n");
		}
	}
	return $con;
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

sub getCandidates {
	my (@lines,$file,$fh,@candidates);
	$file = $basedir."ge-2024-candidates.csv";
	@lines = `curl 'https://candidates.democracyclub.org.uk/data/export_csv/?election_date=2024-07-04'`; # -o "$file"
	return ParseCSV(join("",@lines));
}

#sub getCandidates {
#	my (@lines,$file,$fh,@candidates);
#	$file = $basedir."ge-2024-candidates.csv";
#	if(-e $file){
#		open($fh,"<:utf8",$file);
#		@lines = <$fh>;
#		close($fh);
#	}else{
#		@lines = `curl 'https://candidates.democracyclub.org.uk/data/export_csv/?election_date=2024-07-04' -o "$file"`; # -o "$file"
#	}
#	return ParseCSV(join("",@lines));
#}
