#!/usr/bin/perl
# Script to process food bank data

use utf8;
use warnings;
use strict;
use Data::Dumper;
use Cwd qw(abs_path);
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
require $basedir."../util.pl";

my $hexfile = $basedir."../../src/_data/hexjson/constituencies.hexjson";
my $fbkfile = $basedir."../../raw-data/society/foodbanks.json";
my $outfile = $basedir."../../src/_data/sources/society/foodbanks.csv";


my (@items,$i,$lookup,$pcon,$totals,$name);

# Read in the HexJSON and build the lookup
my $hexjson = loadJSON($hexfile);
@items = keys(%{$hexjson->{'hexes'}});
$lookup = {};
for($i = 0; $i < @items; $i++){
	$lookup->{$hexjson->{'hexes'}{$items[$i]}{'n'}} = {'id'=>$items[$i],'region'=>$hexjson->{'hexes'}{$items[$i]}{'a'},'total'=>0};
}

# Read in the Food Banks data
my $json = loadJSON($fbkfile);
@items = @{$json};
$totals = {};
for($i = 0; $i < @items; $i++){
	$name = $items[$i]{'politics'}{'parliamentary_constituency'};
	if(defined($name)){
		$pcon = $lookup->{$name};
		if(defined($pcon->{'id'})){
			if(!defined($lookup->{$name})){ $lookup->{$name}{'total'} = 0; }
			$lookup->{$name}{'total'}++;
		}else{
			warning("No ID for $name\n");
		}
	}else{
		warning("No constituency given for $items[$i]{'name'}\n");
	}
}


open(my $fh,">",$outfile) || error("Unable to save to <cyan>$outfile<none>\n");
print $fh "Code,Constituency,Region,Food banks\n";
foreach $name (sort{ $lookup->{$a}{'id'} cmp $lookup->{$b}{'id'} }(keys(%{$lookup}))){
	print $fh $lookup->{$name}{'id'}.",".($name =~ /\,/ ? "\"$name\"" : $name).",".($lookup->{$name}{'region'}).",".($lookup->{$name}{'total'})."\n";
}
close($fh);
msg("Saved to <cyan>$outfile<none>\n");


