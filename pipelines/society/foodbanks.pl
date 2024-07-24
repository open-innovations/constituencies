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
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";

my $hexfile = $basedir."../../src/_data/hexjson/uk-constituencies-2024.hexjson";
my $fbkfile = $basedir."../../raw-data/society/foodbanks.json";
my $outfile = $basedir."../../src/themes/society/food-banks/_data/foodbanks.csv";

# Get a new copy of the food bank data
SaveFromURL("https://www.givefood.org.uk/api/2/foodbanks/",$fbkfile);

my (@items,$i,$lookup,$pcon,$totals,$name,$namesafe);

# Read in the HexJSON and build the lookup
my $hexjson = LoadJSON($hexfile);
@items = keys(%{$hexjson->{'hexes'}});
$lookup = {};
for($i = 0; $i < @items; $i++){
	$lookup->{$hexjson->{'hexes'}{$items[$i]}{'n'}} = {'id'=>$items[$i],'region'=>$hexjson->{'hexes'}{$items[$i]}{'a'},'total'=>0};
}

# Read in the Food Banks data
my $json = LoadJSON($fbkfile);
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


open(my $fh,">:utf8",$outfile) || error("Unable to save to <cyan>$outfile<none>\n");
print $fh "Code,Constituency,Slug,Region,Food banks\n";
foreach $name (sort{ $lookup->{$a}{'id'} cmp $lookup->{$b}{'id'} }(keys(%{$lookup}))){
	$namesafe = lc($name);
	$namesafe =~ s/ /\-/g;
	print $fh ($lookup->{$name}{'id'}||"").",".($name =~ /\,/ ? "\"$name\"" : $name).",".($namesafe =~ /\,/ ? "\"$namesafe\"" : $namesafe).",".($lookup->{$name}{'region'}||"").",".($lookup->{$name}{'total'}||"0")."\n";
}
close($fh);
msg("Saved to <cyan>$outfile<none>\n");

updateCreationTimestamp($basedir."../../src/themes/society/food-banks/index.njk");
