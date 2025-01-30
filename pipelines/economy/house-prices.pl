#!/usr/bin/perl

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
use OpenInnovations::XLSX;

my $url = "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/housing/datasets/parliamentaryconstituencyhousepricestatisticsforsmallareas/yearendingmarch2024/housepricestatisticsforsmallareasbyparliamentaryconstituency.xlsx";
my $file = $basedir."../../raw-data/hpssabyparlicons.xlsx";
my $odir = $basedir."../../src/themes/economy/_data/";

# Get the remote data
SaveFromURL($url,$file);

# Load in the Excel file
my $xlsx = OpenInnovations::XLSX->new()->load($file);
my $number = $xlsx->loadSheet('1a',{
	'header'=>[2],
	'startrow'=>3,
	'rename'=>sub {
		my $str = shift;
		my $months = {'Mar'=>'03','Jun'=>'06','Sep'=>'09','Dec'=>'12'};
		if($str =~ /Year ending ([A-Z][a-z]{2}) ([0-9]{4})/){
			return $2."-".$months->{$1};
		}elsif($str eq "Name"){
			return "ConstituencyName";
		}elsif($str eq "Code"){
			return "ONSConstID";
		}
		return $str;
	}
});
my $prices = $xlsx->loadSheet('2a',{
	'header'=>[2],
	'startrow'=>3,
	'rename'=>sub {
		my $str = shift;
		my $months = {'Mar'=>'03','Jun'=>'06','Sep'=>'09','Dec'=>'12'};
		if($str =~ /Year ending ([A-Z][a-z]{2}) ([0-9]{4})/){
			return $2."-".$months->{$1};
		}elsif($str eq "Name"){
			return "ConstituencyName";
		}elsif($str eq "Code"){
			return "ONSConstID";
		}
		return $str;
	}
});


saveSheet($odir."house_sales.csv",$number);
saveSheet($odir."house_prices.csv",$prices);


sub saveSheet {
	my $file = shift;
	my $data = shift;
	my @rawheaders = @{$data->{'headers'}{'columns'}};
	my @rows = @{$data->{'rows'}};
	my ($r,$c,$fh,$v,@headers);

	# Sort the headers
	@headers = sort{ sprintf("%3s",$a->{'key'}) cmp sprintf("%3s",$b->{'key'})}(@rawheaders);

	msg("Saving to <cyan>$file<none>\n");
	open($fh,">",$file);
	# Create header row
	for($c = 0; $c < @headers; $c++){
		$v = $headers[$c]{'title'}||"";
		print $fh ($c == 0 ? "":",").($v =~ /,/ ? "\"":"").($v).($v =~ /,/ ? "\"":"");
	}
	print $fh "\n";
	for($r = 0; $r < @rows; $r++){
		for($c = 0; $c < @headers; $c++){
			$v = $rows[$r]{$headers[$c]{'title'}}||"";
			print $fh ($c == 0 ? "":",").($v =~ /,/ ? "\"":"").($v).($v =~ /,/ ? "\"":"");
		}
		print $fh "\n";
	}
	close($fh);
}

