#!/usr/bin/perl

use strict;
use warnings;
use utf8;
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
use JSON::XS;
use Data::Dumper;
use POSIX qw(strftime);
use Cwd qw(abs_path);
use Math::Trig;
use Text::CSV;
use constant PI => 4 * atan2(1, 1);
use constant X         => 0;
use constant Y         => 1;
use constant TWOPI    => 2*PI;
my ($basedir, $path);
BEGIN { ($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$}; push @INC, $basedir; }
use lib $basedir."lib/";	# Custom functions
use OpenInnovations::ProgressBar;


my ($hexjson,$json,$l,$t,@types,@layers,$osmconf,$o5mfile,$osmfile,$pbffile,$vrtfile,$geofile,$confile,$fh,$ofile,$ifile,$rawdir,$geojson,$tempgeo,$n,$f,$args,$update,$constituencies,@coord,$id,$data,$progress,$csv,$cn,$dt,$kept,$count);

# Get configuration
$json = LoadJSON($basedir."osmconf.json");

# Get hexes
$hexjson = LoadJSON($basedir.$json->{'hexjson'});

# Set variables
$osmconf = $basedir."osmconf.ini";
$rawdir = $basedir.$json->{'working'};
$pbffile = $rawdir.$json->{'prefix'}.".osm.pbf";

# Get the constituencies
# Originally from https://geoportal.statistics.gov.uk/datasets/e489d4e5fe9f4f9caa6af161da5442af_0/explore then reduced with MapShaper
msg("Loading constituencies and finding bounding boxes.");
$constituencies = addBoundingBoxes(LoadJSON($rawdir.$json->{'constituencies'}{'file'}));

# Create a progress bar
$progress = OpenInnovations::ProgressBar->new();
$progress->len(100);

# Make sure we have the PBF file
if(!-e $pbffile){
	msg("Downloading PBF (may take some time)\n");
	`wget -O $pbffile "$json->{'pbf'}"`;
}

# Create a YYYY-MM date from the PBF file last-modified date
$dt = strftime("%Y-%m", localtime((stat($pbffile))[9]));

@layers = @{$json->{'layers'}};

msg("Processing layers\n");
for($l = 0; $l < @layers; $l++){

	msg("<green>$layers[$l]{'id'}<none>:\n");

	$data = {};

	$osmfile = $rawdir.$json->{'prefix'}."-$layers[$l]{'id'}.osm.pbf";
	$geofile = $rawdir.$json->{'prefix'}."-".$layers[$l]{'id'}.".geojson";

	$update = 0;
	if(!-e $osmfile || -s $osmfile==0){
		$update = 1;
	}else{
		
		if((stat($osmfile))[9] < (stat($pbffile))[9]){
			$update = 1;
			# Remove the old file if it exists
			if(-e $osmfile){ `rm $osmfile`; }
		}
	}

	if($update){

		$args = $layers[$l]{'keep'}||"";
		if($args){
			`osmium tags-filter --overwrite -o $osmfile $pbffile -R $args`;
		}else{
			error("No keep types provided\n");
			exit;
		}
	}

	msg("\tCreate GeoJSON version <cyan>$geofile<none>\n");
	`osmium export $osmfile --overwrite -o $geofile`;
	$geojson = LoadJSON($geofile);

	$n = @{$geojson->{'features'}};
	$data = {};

	# Loop over all features and process them
	msg("\tProcessing features\n");
	$progress->max($n);
	$count = 0;
	for($f = 0; $f < $n; $f++){
		if($geojson->{'features'}[$f]{'geometry'}{'type'} ne "LineString"){
			@coord = getFirstPoint($geojson->{'features'}[$f]);
			$cn = @coord;
			if(@coord==2){
				$id = getFeature($f,$json->{'constituencies'}{'id'},$coord[0],$coord[1],@{$constituencies->{'features'}});
				if($id){
					$geojson->{'features'}[$f]{'properties'}{$json->{'constituencies'}{'id'}} = $id;
					if(!defined($data->{$id})){
						$data->{$id} = {};
						$data->{$id}{$json->{'constituencies'}{'id'}} = $id;
					}
					$data->{$id}{$dt}++;
				}else{
					warning("\tNo constituency found for $f ($coord[1]/$coord[0]) / ".($geojson->{'features'}[$f]{'geometry'}{'type'})." / ".($geojson->{'features'}[$f]{'properties'}{'name'}||"")."\n");
				}
				$count++;
			}else{
				warning("No coordinates found\n");
				print Dumper $geojson->{'features'}[$f];
			}
		}
		$progress->update($f,"\t");
	}
	$progress->update($n,"\t");
	msg("\tIdentified constituencies for <yellow>$count<none> features\n");

	# Save the combined GeoJSON
	$geofile = $rawdir.$json->{'prefix'}."-".$layers[$l]{'id'}.".geojson";
	SaveJSON($geofile,$geojson,2);

	# Save the constituency data
	$confile = $rawdir.$json->{'prefix'}."-".$layers[$l]{'id'}."-constituencies.json";
	SaveJSON($confile,$data,1);

	# Make a CSV
	if($layers[$l]{'output'}){
		AugmentCSV($basedir.$layers[$l]{'output'},$data,$json->{'constituencies'}{'id'});
	}
}






#################################

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
	my $json = {};
	if(!$str){ $str = "{}"; }
	eval {
		$json = JSON::XS->new->decode($str);
	};
	if($@){ error("\tInvalid output: $str\n"); }
	return $json;
}

sub LoadJSON {
	my (@files,$str,@lines,$json);
	my $file = $_[0];
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = (join("",@lines));
	# Error check for JS variable
	$str =~ s/[^\{]*var [^\{]+ = //g;
	return ParseJSON($str);
}

# Version 1.1
sub SaveJSON {
	my $file = shift;
	my $json = shift;
	my $depth = shift;
	my $oneline = shift;
	if(!defined($depth)){ $depth = 0; }
	my $d = $depth+1;
	my ($txt,$fh);
	
	$txt = JSON::XS->new->canonical(1)->pretty->space_before(0)->encode($json);
	$txt =~ s/   /\t/g;
	$txt =~ s/\n\t{$d,}//g;
	$txt =~ s/\n\t{$depth}\}(\,|\n)/\}$1/g;
	$txt =~ s/": /":/g;

	if($oneline){
		$txt =~ s/\n[\t\s]*//g;
	}

	open($fh,">:utf8",$file);
	print $fh $txt;
	close($fh);

	return $txt;
}


# version 1
sub LoadCSVSimple {
	my $file = shift;
	my $config = shift;
	
	my ($csv,$row,@rows,@cols,@header,$i,$r,$c,@features,$data,$key,$k,$f,$n,$n2,$hline,$sline,$col,$delimiter,$matches);
	if(not defined($config->{'header'})){ $config->{'header'} = {}; }
	if(not defined($config->{'header'}{'start'})){ $config->{'header'}{'start'} = 0; }
	if(not defined($config->{'header'}{'spacer'})){ $config->{'header'}{'spacer'} = 0; }
	if(not defined($config->{'header'}{'join'})){ $config->{'header'}{'join'} = "→"; }
	$sline = $config->{'startrow'}||1;
	$col = $config->{'key'};
	$delimiter = ",";
	$csv = Text::CSV->new ({
		binary => 1,
		sep_char => $delimiter,
		eol => $/,                # to make $csv->print use newlines
		always_quote => 1,        # to keep your numbers quoted
	});
	$n = 0;
	msg("\tProcessing CSV from <cyan>$file<none>\n");
	open(my $fh,"<:utf8",$file);
	while ($row = $csv->getline( $fh )) {
		# Check for BOM
		if($n==0){ $row->[0] =~ s/^\x{FEFF}//; }
		push(@rows,$row);
		$n++;
	}
	close($fh);
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
			push(@features,@cols);
		}
	}
	my $columns;
	for($c = 0; $c < @header; $c++){
		$columns->{$header[$c]} = $c;
	}
	splice(@rows,0,$sline);
	return {'rows'=>\@rows,'head'=>\@header,'columns'=>$columns};
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
			$csv .= ($c > 0 ? ",":"").($rows[$r][$c]=~/\,/ ? '"':'').$rows[$r][$c].($rows[$r][$c]=~/\,/ ? '"':'');
		}
		$csv .= "\n";
	}

	msg("\tUpdated <cyan>$file<none>\n");
	open($fh,">",$file);
	print $fh $csv;
	close($fh);
	return;
}

sub getFirstPoint {
	my $c = shift;
	my (@coord,$n);
	if(defined($c->{'geometry'})){ $c = $c->{'geometry'}; }
	if($c->{'type'} eq "GeometryCollection"){
		return getFirstPoint($c->{'geometries'}[0]);
	}
	if($c->{'coordinates'}){
		@coord = @{$c->{'coordinates'}};
		while(ref($coord[0]) eq "ARRAY"){
			@coord = @{$coord[0]};
		}
		return @coord;
	}else{
		warning("No coordinates in structure\n");
		print Dumper $c;
	}
	return;
}

sub getCentre {
	my $c = shift;
	my ($i,$a,$b,$cx,$cy,$n,@coords);
	if(defined($c->{'geometry'})){ $c = $c->{'geometry'}; }
	if($c->{'type'} eq "Point"){
		return ($c->{'coordinates'}[0],$c->{'coordinates'}[1]);
	}elsif($c->{'type'} eq "Polygon"){
		# Calculate the centre of a polygon https://en.wikipedia.org/wiki/Centroid#Of_a_polygon
		$a = 0;
		$b = 0;
		$cx = 0;
		$cy = 0;
		@coords = @{$c->{'coordinates'}};
		$n = @coords-1;	# Last coordinate should be a duplicate of the first
		for($i = 0; $i < $n; $i++){
			$b = (($coords[$i][0] * $coords[$i+1][1]) - ($coords[$i+1][0] * $coords[$i][1]));
			$a += $b;
			$cx += ($coords[$i][0] + $coords[$i+1][0])*$b;
			$cy += ($coords[$i][1] + $coords[$i+1][1])*$b;
		}

		if($a == 0){
			# The area is zero which may indicate this polygon intersects with itself so just return the first coordinates
			$cx = $coords[0][0]+0;
			$cy = $coords[0][1]+0;
		}else{
			$a *= 0.5;
			$cx *= 1/(6*$a);
			$cy *= 1/(6*$a);
		}

		return ($cx,$cy);
	}elsif($c->{'type'} eq "MultiPolygon"){
		# Calculate the centre of a polygon https://en.wikipedia.org/wiki/Centroid#Of_a_polygon
		$a = 0;
		$b = 0;
		$cx = 0;
		$cy = 0;
		# Just take the first polygon
		@coords = @{$c->{'coordinates'}[0][0]};
		$n = @coords-1;	# Last coordinate should be a duplicate of the first
		for($i = 0; $i < $n; $i++){
			$b = (($coords[$i][0] * $coords[$i+1][1]) - ($coords[$i+1][0] * $coords[$i][1]));
			$a += $b;
			$cx += ($coords[$i][0] + $coords[$i+1][0])*$b;
			$cy += ($coords[$i][1] + $coords[$i+1][1])*$b;
		}

		if($a == 0){
			# The area is zero which may indicate this polygon intersects with itself so just return the first coordinates
			$cx = $coords[0][0]+0;
			$cy = $coords[0][1]+0;
		}else{
			$a *= 0.5;
			$cx *= 1/(6*$a);
			$cy *= 1/(6*$a);
		}
		return ($cx,$cy);
	}elsif($c->{'type'} eq "LineString"){
		return @{$c->{'coordinates'}[0]};
	}else{
		warning("Don't know how to find centre of <yellow>$c->{'type'}<none>\n");
	}
	return ();
}


sub mapAdjPairs (&@) {
    my $code = shift;
    map { local ($a, $b) = (shift, $_[0]); $code->() } 0 .. @_-2;
}

sub Angle{
    my ($x1, $y1, $x2, $y2) = @_;
    my $dtheta = atan2($y1, $x1) - atan2($y2, $x2);
    $dtheta -= TWOPI while $dtheta >   PI;
    $dtheta += TWOPI while $dtheta < - PI;
    return $dtheta;
}

sub PtInPoly{
    my ($poly, $pt) = @_;
    my $angle=0;

    mapAdjPairs{
        $angle += Angle(
            $a->[X] - $pt->[X],
            $a->[Y] - $pt->[Y],
            $b->[X] - $pt->[X],
            $b->[Y] - $pt->[Y]
        )
    } @$poly, $poly->[0];

    return !(abs($angle) < PI);
}


sub getFeature {
	my $id = shift;
	my $key = shift;
	my $lon = shift;
	my $lat = shift;
	my @features = @_;
	
	if(!defined($lat)){
		error("Bad latitude $id\n");
		exit;
	}
	my ($f,$n,$ok,@gs);
	for($f = 0; $f < @features; $f++){
		$ok = 0;
		# Use pre-computed bounding box to do a first cut - this makes things a lot quicker
		if($lat >= $features[$f]->{'geometry'}{'bbox'}{'lat'}{'min'} && $lat <= $features[$f]->{'geometry'}{'bbox'}{'lat'}{'max'} && $lon >= $features[$f]->{'geometry'}{'bbox'}{'lon'}{'min'} && $lon <= $features[$f]->{'geometry'}{'bbox'}{'lon'}{'max'}){
			# Is this a Polygon?
			if($features[$f]->{'geometry'}->{'type'} eq "Polygon"){

				@gs = @{$features[$f]->{'geometry'}->{'coordinates'}[0]};
				$ok = withinPolygon($lat,$lon,@{$features[$f]->{'geometry'}->{'coordinates'}});

			}elsif($features[$f]->{'geometry'}->{'type'} eq "MultiPolygon"){

				$n = @{$features[$f]->{'geometry'}->{'coordinates'}};
				$ok = withinMultiPolygon($lat,$lon,@{$features[$f]->{'geometry'}->{'coordinates'}});

			}
			if($ok){
				return $features[$f]->{'properties'}->{$key};
			}
		}
	}
	return "";
}

sub withinMultiPolygon {
	my @gs = @_;
	my ($lat,$lon,$p,$n,$ok);
	$lat = shift(@gs);
	$lon = shift(@gs);
	$n = @gs;

	for($p = 0; $p < $n; $p++){
		if(withinPolygon($lat,$lon,@{$gs[$p]})){
			return 1;
		}
	}
	return 0;
}

sub withinPolygon {
	my @gs = @_;
	my ($lat,$lon,$p,$n,$ok,$hole);
	$lat = shift(@gs);
	$lon = shift(@gs);
	$ok = 0;
	$n = @gs;

	$ok = (PtInPoly( \@{$gs[0]}, [$lon,$lat]) ? 1 : 0);

	if($ok){
		if($n > 1){
			#print "Check if in hole\n";
			for($p = 1; $p < $n; $p++){
				$hole = (PtInPoly( \@{$gs[$p]}, [$lon,$lat]) ? 1 : 0);
				if($hole){
					return 0;
				}
			}
		}
		return 1;
	}

	return 0;
}

sub getBounds {
	my $bounds = shift;
	my @features = @_;
	my ($i,$values,$n);
	$n = @features;
	$values = 0;
	for($i = 0; $i < @features; $i++){
		if(ref($features[$i]) eq "ARRAY"){	
			$bounds = getBounds($bounds,@{$features[$i]});
		}else{
			$values++;
		}
	}
	if($values==2){
		if($features[0] < $bounds->{'lon'}{'min'}){ $bounds->{'lon'}{'min'} = $features[0]; }
		if($features[0] > $bounds->{'lon'}{'max'}){ $bounds->{'lon'}{'max'} = $features[0]; }
		if($features[1] < $bounds->{'lat'}{'min'}){ $bounds->{'lat'}{'min'} = $features[1]; }
		if($features[1] > $bounds->{'lat'}{'max'}){ $bounds->{'lat'}{'max'} = $features[1]; }
	}
	return $bounds;
}

sub addBoundingBoxes {
	my $geojson = shift;
	my $nf = @{$geojson->{'features'}};
	my ($f,$minlat,$maxlat,$minlon,$maxlon,$n,$p,$bounds);
	# Loop over features and add rough bounding box
	for($f = 0; $f < $nf; $f++){
		$bounds = getBounds({"lat"=>{"min"=>90,"max"=>-90},"lon"=>{"min"=>180,"max"=>-180}},$geojson->{'features'}[$f]{'geometry'}{'coordinates'});
		$geojson->{'features'}[$f]->{'geometry'}{'bbox'} = $bounds;
	}
	return $geojson;
}

