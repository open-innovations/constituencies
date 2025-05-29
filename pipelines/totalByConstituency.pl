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
use Text::CSV;
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."lib/";	# Custom functions
use OpenInnovations::Postcodes;
use OpenInnovations::GeoJSON;
require "lib.pl";


my ($geojson,$geo,$help,$pcdcolumn,$latcolumn,$loncolumn,$length,$ofile,$src,$ifile,$startrow,$tmpdir,$url,@rows,@row,$r,$c,$or,$pcds,$pcdfile,$ll,$pid,$match,$pcon,$data,$category,$cat,$name,$totals,$total,$groups,$group,$g,$csv,$dir,$fh,$badlocation,$badnovalue,$ok,$dt,$dtfull,$totalcolumn,$v,@datefiles);

# Get the command line options
GetOptions(
	"c|category=s" => \$category,					# string
	"g|geojson=s" => \$geojson,						# string
	"h|help" => \$help,								# flag
	"i|id=s" => \$pid,								# string
	"lat|latitude=s" => \$latcolumn,				# string
	"lon|longitude=s" => \$loncolumn,				# string
	"n|name=s" => \$name,							# string
	"o|output=s" => \$ofile,						# string
	"p|postcode=s" => \$pcdcolumn,					# string
	"s|startrow=i" => \$startrow,					# integer
	"t|total=s" => \$totalcolumn,					# string
	"u|updatedate=s" => sub { push(@datefiles,$_[1]) },	# string
);


if(defined($help) || !defined($ofile)){
	msg("Usage:\n");
	msg("    perl pipelines/totalByConstituency.pl <CSV file> -postcode <postcode Column> -geojson <GeoJSON file> -output <output file> -category <column to group by>\n");
	msg("\n");
	msg("Examples:\n");
	msg("    perl pipelines/totalByConstituency.pl https://www.gamblingcommission.gov.uk/downloads/premises-licence-register.csv -postcode=Postcode -o src/themes/society/gambling-premises/_data/release/premises.csv -c \"Premises Activity\"\n");
	msg("    perl pipelines/totalByConstituency.pl raw-data/society/post-offices/postofficebranches-details.csv -latitude=Latitude -longitude=Longitude -o src/themes/society/post-offices/_data/release/postoffices.csv -t \"%Y-%m\" -updatedate src/themes/society/post-offices/index.vto -updatedate src/themes/society/post-offices/_data/map_1.json\n");
	msg("    perl pipelines/totalByConstituency.pl https://www.openbenches.org/api/benches.tsv -latitude=latitude -longitude=longitude -o src/themes/society/benches/_data/release/open-benches.csv -t \"%Y-%m\" -updatedate src/themes/society/benches/_data/openbenches.json -updatedate src/themes/society/benches/index.vto\n");
	msg("\n");
	msg("Options:\n");
	msg("    <CSV file>                 the CSV file to load (can be at a URL)\n");
	msg("    -c, --category=Column      the column in the input CSV to use to total by\n");
	msg("    -d, --date=file            update the date in the file\n");
	msg("    -g, --geojson=file         the GeoJSON file to use to find postcodes for\n");
	msg("    -i, --id=Property          the GeoJSON property to use as the area ID\n");
	msg("    -lat=Column                the column in the input CSV to use for the latitude (if no postcode)\n");
	msg("    -lon=Column                the column in the input CSV to use for the longitude (if no postcode)\n");
	msg("    -n, --name=Property        the GeoJSON property to use as the area name\n");
	msg("    -o, --output=file          the destination file to save the results to\n");
	msg("    -p, --postcode=Column      the column in the input CSV to use for the postcode (otherwise use latitude/longitude)\n");
	msg("    -s, --startrow=2           the row number for the first row of data\n");
	msg("    -t, --total=Total          the name of the column for the total\n");
	msg("    -u, --updatedate=file      the name of a file in which to update the date stamp\n");
	exit;
}


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
# Set the default total column name
if(!defined($totalcolumn)){ $totalcolumn = ""; }



# Load the constituency GeoJSON file
$geo = new OpenInnovations::GeoJSON;
if(!-e $geojson){
	SaveFromURL("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Westminster_Parliamentary_Constituencies_July_2024_Boundaries_UK_BGC/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson",$geojson);
}
$geo->load($geojson);

$src = $ARGV[0]||"";

$tmpdir = $basedir."../raw-data/";
$ifile = $tmpdir.($src =~ /([^\/]+\.[^\/]{3})$/ ? $1 : "temp-download.csv");

# Get the data file if necessary
if($src =~ /^https?/){
	SaveFromURL($src,$ifile);
}else{
	$ifile = $src;
}



$pcdfile = $ifile;
$pcdfile =~ s/\.csv/_postcodes\.csv/;
$badlocation = 0;
$badnovalue = 0;


if(!-e $ifile){
	error("Can't find <cyan>$ifile<none>\n");
	exit;
}
# Load the input data file
@rows = LoadCSV($ifile,{'startrow'=>$startrow});



# Create a new Postcodes cache
if(defined($pcdcolumn)){
	$pcds = new OpenInnovations::Postcodes;
	$pcds->setFile($pcdfile);
	$pcds->setLocation("/mnt/c/Users/StuartLowe/Documents/Github/Postcodes2LatLon/postcodes/");
}


# Update the total column with any date strings
$totalcolumn = strftime($totalcolumn, localtime((stat($ifile))[9]));


$totals = {};
# Loop over rows in input file and find totals
for($r = 0; $r < @rows; $r++){

	$ll = undef;
	
	if(defined($pcdcolumn)){
		if(!defined($rows[$r]->{$pcdcolumn})){
			warning("No postcode column <yellow>$pcdcolumn<none> seems to exist <yellow>$r<none>.\n");
			print Dumper $rows[$r];
		}else{
			$ll = $pcds->getPostcode($rows[$r]{$pcdcolumn});
		}
	}elsif(defined($latcolumn) && defined($loncolumn)){
		if(!defined($rows[$r]->{$latcolumn}) || !defined($rows[$r]->{$loncolumn})){
			warning("Missing latitude/longitude column <yellow>$r<none>:\n");
			print Dumper $rows[$r];
		}else{
			$ll = {'lat'=>$rows[$r]->{$latcolumn},'lon'=>$rows[$r]->{$loncolumn}};
		}
	}

	if(!defined($ll) || !defined($ll->{'lat'}) || !defined($ll->{'lon'}) || $ll->{'lat'} eq "" || $ll->{'lon'} eq ""){
		#warning("Bad coordinates for <yellow>$r<none>\n");
		$badlocation++;
	}else{

		if($geo->withinGeoJSON($ll->{'lat'},$ll->{'lon'})){

			$match = $geo->getFeatureAt($ll->{'lat'},$ll->{'lon'});

			if(!defined($match->{'properties'}{$pid})){

				warning("No properties <yellow>$pid<none> for row <yellow>$r<none> ($ll->{'lat'}/$ll->{'lon'})\n");
				$badnovalue++;

			}else{

				$pcon = $match->{'properties'}{$pid};

				if(defined($pcon)){

					$cat = $totalcolumn;
					if(defined($category)){
						if(defined($rows[$r]->{$category})){
							$cat = $rows[$r]->{$category};
							if($totalcolumn){
								$cat .= ($rows[$r]->{$category} ? " ":"");
							}
							$cat .= $totalcolumn;
						}
					}

					if($cat eq ""){
						warning("Bad row <yellow>$r<none> has no <yellow>$category<none>\n");
						print Dumper $rows[$r];
						$badnovalue++;
					}else{
						if(!defined($totals->{$cat})){ $totals->{$cat} = {}; }
						if(!defined($totals->{$cat}{$pcon})){ $totals->{$cat}{$pcon} = 0; }
						$totals->{$cat}{$pcon}++;
					}
				}else{
					warning("No constituency.\n");
					$badnovalue++;
				}
			}
		}else{
			$badlocation++;
		}
	}
}

# Save our cached postcodes
if(defined($pcds)){
	$pcds->save();
}

# Load the output file (if it exists);
if(-e $ofile){
	$data = LoadCSVSimple($ofile,{'key'=>$pid});
}else{
	$data->{'rows'} = [];
	$data->{'lookup'} = {'row'=>{},'col'=>{}};
	$data->{'head'} = [$pid,$name,$totalcolumn];
	for($c = 0; $c < @{$data->{'head'}}; $c++){
		$data->{'lookup'}{'col'}{$data->{'head'}[$c]} = $c;
	}
}

# Add empty rows for any missing constituencies
for($r = 0; $r < @{$geo->{'geojson'}{'features'}}; $r++){
	$pcon = $geo->{'geojson'}{'features'}[$r]{'properties'}{$pid};
	# If there is no row lookup for this constituency we add it
	if(!defined($data->{'lookup'}{'row'}{$pcon})){
		push(@{$data->{'rows'}},[]);
		$or = @{$data->{'rows'}} - 1;
		for($c = 0; $c < @{$data->{'head'}}; $c++){
			$v = undef;
			if($data->{'head'}[$c] eq $pid){ $v = $pcon; }
			if($data->{'head'}[$c] eq $name && defined($geo->{'geojson'}{'features'}[$r]{'properties'}{$name})){ $v = $geo->{'geojson'}{'features'}[$r]{'properties'}{$name}; }
			$data->{'rows'}[$or][$c] = $v;
		}
		$data->{'lookup'}{'row'}{$pcon} = $or;
	}
}

# Set each total in the output to zero
foreach $total (sort(keys(%{$totals}))){
	# Do we have the total column already?
	if(!defined($data->{'lookup'}{'col'}{$total})){
		push(@{$data->{'head'}},$total);
		$data->{'lookup'}{'col'}{$total} = @{$data->{'head'}};
	}
	# We need to set the total to zero in every row
	for($r = 0; $r < @{$data->{'rows'}}; $r++){
		$data->{'rows'}[$r][$data->{'lookup'}{'col'}{$total}] = 0;
	}
}

# Loop over data rows and update the totals
for($r = 0; $r < @{$data->{'rows'}}; $r++){
	$pcon = $data->{'rows'}[$r][$data->{'lookup'}{'col'}{$pid}];
	if($pcon){
		foreach $total (keys(%{$totals})){
			$data->{'rows'}[$r][$data->{'lookup'}{'col'}{$total}] = $totals->{$total}{$pcon}||0;
		}
	}else{
		warning("No constituency ID for row <yellow>$r<none>.\n");
		print Dumper $data->{'rows'}[$r];
	}
}


# Build CSV output
# Build header
$csv = "";
for($c = 0; $c < @{$data->{'head'}}; $c++){
	$csv .= ($c > 0 ? ",":"").($data->{'head'}[$c] =~ /\,/ ? "\"":"").$data->{'head'}[$c].($data->{'head'}[$c] =~ /\,/ ? "\"":"");
}
$csv .= "\n";
# Build rows
for($r = 0; $r < @{$data->{'rows'}}; $r++){
	for($c = 0; $c < @{$data->{'head'}}; $c++){
		$v = $data->{'rows'}[$r][$data->{'lookup'}{'col'}{$data->{'head'}[$c]}];
		if(!defined($v)){ $v = ""; }
		$csv .= ($c > 0 ? ",":"").($v =~ /\,/ ? "\"" : "").$v.($v =~ /\,/ ? "\"" : "");
	}
	$csv .= "\n";
}

# Make the output directory if it doesn't exist
$dir = $ofile;
$dir =~ s/[^\/]+$//;
makeDir($dir);

msg("Saving output to <cyan>$ofile<none>\n");
open($fh,">:utf8",$ofile);
print $fh $csv;
close($fh);


# Create a YYYY-MM date from the file last-modified date
$dt = strftime("%Y-%m", localtime((stat($ifile))[9]));
$dtfull = strftime("%Y-%m-%dT%H:%M", localtime((stat($ifile))[9]));
# Update dates
for(my $d = 0; $d < @datefiles; $d++){
	if($datefiles[$d] =~ /\.vto/){
		updateCreationTimestamp($datefiles[$d],$dtfull);
	}elsif($datefiles[$d] =~ /\.json/){
		my $tjson = LoadJSON($datefiles[$d]);
		if(defined($tjson->{'config'})){
			#if(defined($tjson->{'config'}{'value'})){
			#	$tjson->{'config'}{'value'} = $dt;
			#}
			#if(defined($tjson->{'config'}{'tooltip'})){
			#	$tjson->{'config'}{'tooltip'} =~ s/\{\{ [0-9]{4}-[0-9]{2} ([^\}]*)\}\}/\{\{ $dt $1\}\}/g;
			#}
			$tjson->{'date'} = $dtfull;
		}
		SaveJSON($tjson,$datefiles[$d],3);
	}else{
		warning("Unknown file type to update date for <cyan>$datefiles[$d]<none>\n");
	}
}
	

if($badlocation > 0){
	msg("There were <red>$badlocation<none> rows without location information (either postcodes or latitude/longitude).\n");
}
if($badnovalue > 0){
	msg("There were <red>$badnovalue<none> rows without a valid value.\n");
}










############################

# version 1.1
sub LoadCSVSimple {
	my $file = shift;
	my $config = shift;
	my ($csv,$row,@rows,@cols,@header,$i,$r,$c,@features,$data,$key,$k,$f,$n,$n2,$hline,$sline,$delimiter,$matches,$rowlookup,$fh);

	if(not defined($config->{'header'})){ $config->{'header'} = {}; }
	if(not defined($config->{'header'}{'start'})){ $config->{'header'}{'start'} = 0; }
	if(not defined($config->{'header'}{'spacer'})){ $config->{'header'}{'spacer'} = 0; }
	if(not defined($config->{'header'}{'join'})){ $config->{'header'}{'join'} = "→"; }
	$sline = $config->{'startrow'}||1;
	$key = $config->{'key'};
	if(defined($key)){
		$rowlookup = {};
	}
	$delimiter = ",";
	$csv = Text::CSV->new ({
		binary => 1,
		sep_char => $delimiter,
		eol => $/,                # to make $csv->print use newlines
		always_quote => 1,        # to keep your numbers quoted
	});
	$n = 0;
	msg("\tProcessing CSV from <cyan>$file<none>\n");
	open($fh,"<:utf8",$file);
	while ($row = $csv->getline( $fh )) {
		# Check for BOM
		if($n==0){ $row->[0] =~ s/^\x{FEFF}//; }
		push(@rows,$row);
		$n++;
	}
	close($fh);
	$f = 0;
	for($r = $config->{'header'}{'start'}; $r < $n; $r++){
		$rows[$r] =~ s/[\n\r]//g;
		@cols = @{$rows[$r]};
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
			push(@features,[]);
			for($c = 0; $c < @cols; $c++){
				$features[$f][$c] = $cols[$c];
				if(defined($key) && $header[$c] eq $key){
					$rowlookup->{$cols[$c]} = $f;
				}
			}
			$f++;
		}
	}
	my $columns;
	for($c = 0; $c < @header; $c++){
		$columns->{$header[$c]} = $c;
	}
	return {'rows'=>\@features,'head'=>\@header,'lookup'=>{'row'=>$rowlookup,'col'=>$columns}};
}

sub AugmentCSV {
	my $file = shift;
	my $data = shift;
	my $key = shift;
	my ($odata,@rows,@head,$r,$c,$rowlookup,$id,@row,$col,$csv,@extrahead,$arow,@header,@ids);
	
	if(-e $file){
		# Should read in any existing output CSV here
		$odata = LoadCSVSimple($file,{'key'=>$key});
	}else{
		# Build the data
		$odata = {
			'rows'=>[],
			'head'=>[],
			'columns'=>{}
		};
		@ids = sort(keys(%{$data}));
		for($r = 0; $r < @ids; $r++){
			if($r == 0){
				@header = reverse(sort(keys(%{$data->{$ids[$r]}})));
				@{$odata->{'head'}} = @header;
			}
			@row = ();
			for($c = 0; $c < @{$odata->{'head'}}; $c++){
				$row[$c] = $data->{$ids[$r]}{$odata->{'head'}[$c]};
			}
			@{$odata->{'rows'}[$r]} = @row;
		}
		for($c = 0; $c < @header; $c++){
			$odata->{'columns'}{$header[$c]} = $c;
		}
	}

	@rows = @{$odata->{'rows'}};
	@head = @{$odata->{'head'}};
	# Loop through the rows to find all the things we have by "$key"
	for($r = 0; $r < @rows; $r++){
		$rowlookup->{$rows[$r][$odata->{'columns'}{$key}]} = $r;
	}

	# Have we got new columns?
	foreach $id (sort(keys(%{$data}))){
		foreach $col (sort(keys(%{$data->{$id}}))){
			if(!defined($odata->{'columns'}{$col})){
				push(@head,$col);
				$odata->{'columns'}{$col} = 1;
				push(@extrahead,$col);
			}
		}
	}
	# Update all the rows to add an empty cell
	for($r = 0; $r < @rows; $r++){
		for($c = 0; $c < @extrahead; $c++){
			push(@{$rows[$r]},"");
		}
	}

	foreach $id (sort(keys(%{$data}))){
		if(defined($rowlookup->{$id})){
			# If we have this ID already we update it
			$r = $rowlookup->{$id};
			for($c = 0; $c < @head; $c++){
				if(defined($data->{$id}{$head[$c]})){
					$rows[$r][$c] = $data->{$id}{$head[$c]};
				}
			}
		}else{
			# Otherwise we add a new row
			@row = ();
			for($c = 0; $c < @head; $c++){
				if($head[$c] eq $key){
					push(@row,$id);
				}else{
					push(@row,$data->{$id}{$head[$c]}||"");
				}
			}
			push(@rows,\@row);
		}
	}

	$csv = "";
	for($c = 0; $c < @head; $c++){
		$csv .= ($c > 0 ? ",":"").($head[$c]=~/\,/ ? '"':'').$head[$c].($head[$c]=~/\,/ ? '"':'');
	}
	$csv .= "\n";
	for($r = 0; $r < @rows; $r++){
		for($c = 0; $c < @head; $c++){
			$csv .= ($c > 0 ? ",":"").($rows[$r][$c]=~/\,/ ? '"':'').($rows[$r][$c]||0).($rows[$r][$c]=~/\,/ ? '"':'');
		}
		$csv .= "\n";
	}

	msg("\tUpdated <cyan>$file<none>\n");
	open($fh,">",$file);
	print $fh $csv;
	close($fh);
	return;
}
