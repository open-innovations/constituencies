package OpenInnovations::GeoJSON;

# Version 1.0

use strict;
use warnings;
use Data::Dumper;
use List::Util qw[min max];
use JSON::XS;
use Math::Trig;

use constant PI => 4 * atan2(1, 1);
use constant X         => 0;
use constant Y         => 1;
use constant TWOPI    => 2*PI;

sub new {
    my ($class, %args) = @_;
 
    my $self = \%args;
 
    bless $self, $class;
	
	$self->{'layerorder'} = ();

	if($self->{'file'}){ $self->load($self->{'file'}); }
 
    return $self;
}


# Add a layer:
# addLayer('id-of-layer','filepath',{extra properties})
sub load {
	my ($self, $file, $props) = @_;
	my (@lines,$json,@features,$minlat,$maxlat,$minlon,$maxlon,$ok,@gs,$n,$f,$p,$total);
	
	if(-e $file){
		# Get the populations data
		open(FILE,$file);
		@lines = <FILE>;
		close(FILE);
		$json = JSON::XS->new->utf8->decode(join("\n",@lines));
		$self->{'_file'} = $file;
		$self->{'geojson'} = $json;
		$self->{'options'} = $props;

		$total = @{$json->{'features'}};

		# Work out the bounding box for this feature
		for($f = 0; $f < $total; $f++){
			@gs = "";
			$ok = 0;
			$minlat = 90;
			$maxlat = -90;
			$minlon = 180;
			$maxlon = -180;
			if($json->{'features'}[$f]->{'geometry'}->{'type'} eq "Polygon"){
				($minlat,$maxlat,$minlon,$maxlon) = getBBox($minlat,$maxlat,$minlon,$maxlon,@{$json->{'features'}[$f]->{'geometry'}->{'coordinates'}});
				# Set the bounding box
				$json->{'features'}[$f]->{'_bbox'} = {'lat'=>{'min'=>$minlat,'max'=>$maxlat},'lon'=>{'min'=>$minlon,'max'=>$maxlon}};
			}elsif($json->{'features'}[$f]->{'geometry'}->{'type'} eq "MultiPolygon"){
				$n = @{$json->{'features'}[$f]->{'geometry'}->{'coordinates'}};
				for($p = 0; $p < $n; $p++){
					($minlat,$maxlat,$minlon,$maxlon) = getBBox($minlat,$maxlat,$minlon,$maxlon,@{$json->{'features'}[$f]->{'geometry'}->{'coordinates'}[$p]});
				}
				# Set the bounding box
				$json->{'features'}[$f]->{'_bbox'} = {'lat'=>{'min'=>$minlat,'max'=>$maxlat},'lon'=>{'min'=>$minlon,'max'=>$maxlon}};
			}else{
				#print "ERROR: Unknown geometry type $json->{'features'}[$f]->{'geometry'}->{'type'}\n";
			}
		}
		$self->{'features'} = $json->{'features'};

	}else{
		print "File $file does not seem to exist.\n";
	}

	return $self;
}

sub findPoint {
	my $self = shift;
	my $code = shift;
	my $lat = shift;
	my $lon = shift;

	my ($f,$total,$n,$ok,@gs,@features);

	@features = @{$self->{'features'}};

	$total = @features;
	for($f = 0; $f < $total; $f++){
		@gs = "";
		$ok = 0;

		# If we are in the bounding box
		if($lat >= $features[$f]->{'_bbox'}{'lat'}{'min'} && $lat <= $features[$f]->{'_bbox'}{'lat'}{'max'} && $lon >= $features[$f]->{'_bbox'}{'lon'}{'min'} && $lon <= $features[$f]->{'_bbox'}{'lon'}{'max'}){
			if($features[$f]->{'geometry'}->{'type'} eq "Polygon"){
				$ok = withinPolygon($lat,$lon,@{$features[$f]->{'geometry'}->{'coordinates'}});
			}else{
				$n = @{$features[$f]->{'geometry'}->{'coordinates'}};
				$ok = withinMultiPolygon($lat,$lon,@{$features[$f]->{'geometry'}->{'coordinates'}});
			}
			if($ok){
				return $features[$f]->{'properties'}->{$code};
			}
		}
	}
	return "";
}

sub getBBox {
	my @gs = @_;
	my ($minlat,$maxlat,$minlon,$maxlon,$n,$i);
	$minlat = shift(@gs);
	$maxlat = shift(@gs);
	$minlon = shift(@gs);
	$maxlon = shift(@gs);
	$n = @{$gs[0]};

	for($i = 0; $i < $n; $i++){
		if($gs[0][$i][0] < $minlon){ $minlon = $gs[0][$i][0]; }
		if($gs[0][$i][0] > $maxlon){ $maxlon = $gs[0][$i][0]; }
		if($gs[0][$i][1] < $minlat){ $minlat = $gs[0][$i][1]; }
		if($gs[0][$i][1] > $maxlat){ $maxlat = $gs[0][$i][1]; }
	}
	return ($minlat,$maxlat,$minlon,$maxlon);
}

sub setBounds {
	my ($self, $props) = @_;
	
	$self->{'bounds'} = $props;

	return $self;
}

sub getBounds {
	my ($self,$data) = @_;
	my ($mxlat,$mxlon,$mnlat,$mnlon,@order,$l,%layer,$n,$f,@c,$nc,$i,$j,$k,$p,%feature);

	$mxlat = -90;
	$mxlon = -180;
	$mnlat = 90;
	$mnlon = 180;
	
	@order = @{$self->{'layerorder'}};
	
	for($l = 0; $l < @order; $l++){
		%layer = %{$self->{'layers'}{$order[$l]}};
		if($layer{'data'}){
			$n = @{$layer{'data'}{'features'}};
			for($f = 0; $f < $n; $f++){
				if($layer{'data'}{'features'}[$f]){
					%feature = %{$layer{'data'}{'features'}[$f]};
					@c = $layer{'data'}{'features'}[$f]{'geometry'}{'coordinates'};
					$nc = @c;
					if($layer{'data'}{'features'}[$f]{'geometry'}{'type'} eq "Polygon"){
						for($i = 0; $i < $nc; $i++){
							for($j = 0; $j < @{$c[$i]}; $j++){
								for($k = 0; $k < @{$c[$i][$j]}; $k++){
									if($c[$i][$j][$k][0] > $mxlon){ $mxlon = $c[$i][$j][$k][0]; }
									if($c[$i][$j][$k][0] < $mnlon){ $mnlon = $c[$i][$j][$k][0]; }
									if($c[$i][$j][$k][1] > $mxlat){ $mxlat = $c[$i][$j][$k][1]; }
									if($c[$i][$j][$k][1] < $mnlat){ $mnlat = $c[$i][$j][$k][1]; }
								}
							}
						}
					}elsif($layer{'data'}{'features'}[$f]{'geometry'}{'type'} eq "MultiPolygon"){
						for($i = 0; $i < $nc; $i++){
							for($j = 0; $j < @{$c[$i]}; $j++){
								for($k = 0; $k < @{$c[$i][$j]}; $k++){
									for($p = 0; $p < @{$c[$i][$j][$k]}; $p++){
										if($c[$i][$j][$k][$p][0] > $mxlon){ $mxlon = $c[$i][$j][$k][$p][0]; }
										if($c[$i][$j][$k][$p][0] < $mnlon){ $mnlon = $c[$i][$j][$k][$p][0]; }
										if($c[$i][$j][$k][$p][1] > $mxlat){ $mxlat = $c[$i][$j][$k][$p][1]; }
										if($c[$i][$j][$k][$p][1] < $mnlat){ $mnlat = $c[$i][$j][$k][$p][1]; }
									}
								}
							}
						}
					}
				}
			}
		}	
	}
	return ('_northEast'=>{'lat'=>$mxlat,'lng'=>$mxlon},'_southWest'=>{'lat'=>$mnlat,'lng'=>$mnlon});
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
					print "Found in hole in Polygon $p\n";
					return 0;
				}
			}
		}
		return 1;
	}

	return 0;
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

1;
