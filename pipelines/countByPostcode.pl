#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Data::Dumper;
use Cwd qw(abs_path);
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
use JSON::XS;
use POSIX qw(strftime);
use Getopt::Long;
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."lib/";	# Custom functions
use OpenInnovations::Postcodes;
use OpenInnovations::GeoJSON;
require "lib.pl";


my ($geojson,$geo,$help,$pcdcolumn,$length,$ofile,$src,$ifile,$startrow,$tmpdir,$url,@rows,$r,$pcds,$pcdfile,$ll,$pid,$match,$pcon,$data,$category,$cat,$name,$groups,$g,$csv,$dir,$total,$fh,$bad,$badnovalue);

# Get the command line options
GetOptions(
	"c|category=s"    => \$category,	# string
	"g|geojson=s"    => \$geojson,		# string
	"h|help" => \$help,					# flag
	"i|id=s"   => \$pid,				# string
	"o|output=s"   => \$ofile,			# string
	"p|postcode=s"   => \$pcdcolumn,	# string
	"s|startrow=i"   => \$startrow,		# integer
);

if(defined($help) || !defined($ofile)){
	msg("Usage:\n");
	msg("    perl byPostcode.pl <CSV file> -postcode <postcode Column> -geojson <GeoJSON file> -output <output file> -category <column to group by>\n");
	msg("\n");
	msg("Examples:\n");
	msg("    perl pipelines/countByPostcode.pl https://www.gamblingcommission.gov.uk/downloads/premises-licence-register.csv -postcode=Postcode -o src/themes/society/gambling-premises/_data/release/premises.csv -c \"Premises Activity\"\n");
	msg("\n");
	msg("Options:\n");
	msg("    <CSV file>                 the CSV file to load\n");
	msg("    -c, --category=Column      the column in the input CSV to use to total by\n");
	msg("    -g, --geojson=file         the GeoJSON file to use to find postcodes for\n");
	msg("    -i, --id=Property          the GeoJSON property to use as the area ID\n");
	msg("    -n, --name=Property        the GeoJSON property to use as the area name\n");
	msg("    -o, --output=file          the destination file to save the results to\n");
	msg("    -p, --postcode=Column      the column in the input CSV to use for the postcode\n");
	msg("    -s, --startrow=2           the row number for the first row of data\n");
	exit;
}


$tmpdir = $basedir."../raw-data/";
$ifile = $tmpdir."premises-licence-register.csv";
$pcdfile = $ifile;
$pcdfile =~ s/\.csv/_postcodes\.csv/;
$bad = 0;
$badnovalue = 0;


# Set the GeoJSON file if not provided on the command line
if(!defined($geojson)){
	$geojson = $basedir."../raw-data/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC.geojson";
}

# Set the data start row if now provided
if(!defined($startrow)){ $startrow = 1; }

# Set the default property ID
if(!defined($pid)){ $pid = "PCON24CD"; }

# Set the default property name
if(!defined($name)){ $name = "PCON24NM"; }



# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
if(!-e $geojson){
	SaveFromURL("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson",$geojson);
}
$geo->load($geojson);



# Create a new Postcodes cache
$pcds = new OpenInnovations::Postcodes;
$pcds->setFile($pcdfile);
$pcds->setLocation("/mnt/c/Users/StuartLowe/Documents/Github/Postcodes2LatLon/postcodes/");



# Get the data file if necessary
$src = $ARGV[0]||"https://www.gamblingcommission.gov.uk/downloads/premises-licence-register.csv";
if($src =~ /^https?/){
	SaveFromURL($src,$ifile);
}else{
	$ifile = $src;
}
if(!-e $ifile){
	error("Can't find <cyan>$ifile<none>\n");
	exit;
}

# Load the data file
@rows = LoadCSV($ifile,{'startrow'=>$startrow});

$data = {};
$groups = {};
# Process rows
for($r = 0; $r < @rows; $r++){

	if(!defined($rows[$r]->{$pcdcolumn})){
		warning("No postcode column <yellow>$pcdcolumn<none> seems to exist.\n");
		print Dumper $rows[$r];
		$bad++;
	}else{
	
	
		$ll = $pcds->getPostcode($rows[$r]{$pcdcolumn});

		if(defined($ll) && defined($ll->{'lat'}) && defined($ll->{'lon'})){

			$match = $geo->getFeatureAt($ll->{'lat'},$ll->{'lon'});

			if(!defined($match->{'properties'}{$pid})){
				warning("No properties <yellow>$pid<none> for row <yellow>$r<none>\n");
				$badnovalue++;
			}else{

				$pcon = $match->{'properties'}{$pid};

				if(!defined($data->{$pcon})){
					$data->{$pcon} = {'name'=>'','totals'=>{}};
					if(defined($match->{'properties'}{$name})){
						$data->{$pcon}{'name'} = $match->{'properties'}{$name};
					}
				}
				$cat = "";
				if(defined($category)){
					if(defined($rows[$r]->{$category})){
						$cat = $rows[$r]->{$category};
					}else{
						$cat = "";
					}
				}

				if($cat eq ""){
					warning("Bad row <yellow>$r<none> has no <yellow>$category<none>\n");
					print Dumper $rows[$r];
					$badnovalue++;
				}else{
					$groups->{$cat} = 1;

					if(!defined($data->{$pcon}{'totals'}{$cat})){
						$data->{$pcon}{'totals'}{$cat} = 0;
					}
					$data->{$pcon}{'totals'}{$cat}++;
				}
			}
		}else{
			warning("Bad postcode <yellow>$rows[$r]{$pcdcolumn}<none>\n");
			$bad++;
		}
	}
	
}
# Save our cached postcodes
$pcds->save();


$csv = "$pid,$name";
foreach $g (sort(keys(%{$groups}))){
	$csv .= ",$g";
}
$csv .= ",Total\n";

foreach $pcon (sort(keys(%{$data}))){
	$csv .= "$pcon,";
	$csv .= ($data->{$pcon}{'name'} =~ /\,/ ? "\"":"").$data->{$pcon}{'name'}.($data->{$pcon}{'name'} =~ /\,/ ? "\"":"");
	$total = 0;
	foreach $g (sort(keys(%{$groups}))){
		$csv .= ",".($data->{$pcon}{'totals'}{$g}||0);
		$total += ($data->{$pcon}{'totals'}{$g}||0);
	}
	$csv .= ",".($total||0)."\n";
}

# Make the output directory if it doesn't exist
$dir = $ofile;
$dir =~ s/[^\/]+$//;
makeDir($dir);

msg("Saving output to <cyan>$ofile<none>\n");
open($fh,">:utf8",$ofile);
print $fh $csv;
close($fh);

if($bad > 0){
	msg("There were <red>$bad<none> rows without postcodes.\n");
}
if($badnovalue > 0){
	msg("There were <red>$badnovalue<none> rows without a <yellow>$category<none> value.\n");
}