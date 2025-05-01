package OpenInnovations::Postcodes;

use warnings;
use strict;
use utf8;
use Data::Dumper;

sub new {
    my ($class, %args) = @_;
 
    my $self = \%args;
 
    bless $self, $class;
	
	$self->{'postcodelookup'} = {};
	$self->{'postcodes'} = {};

    return $self;
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

sub setFile {
	my ($self, $file) = @_;
	my (@lines,$line,$pcd,$lat,$lon,$fh,$i);

	$self->{'file'} = $file;
	
	if(!defined($self->{'file'})){
		error("No postcode file provided.\n");
		exit;
	}

	if(-e $self->{'file'}){
		msg("Reading existing postcodes from <cyan>$self->{'file'}<none>...\n");
		open($fh,$self->{'file'});
		@lines = <$fh>;
		close($fh);

		for($i = 1; $i < @lines; $i++){
			$line = $lines[$i];
			$line =~ s/[\n\r]//g;
			($pcd,$lat,$lon) = split(/,/,$line);
			$pcd = uc($pcd);
			$pcd =~ s/ //g;
			$self->{'postcodelookup'}{$pcd} = {};
			if($lat){ $self->{'postcodelookup'}{$pcd}{'lat'} = $lat; }
			if($lon){ $self->{'postcodelookup'}{$pcd}{'lon'} = $lon; }
		}
	}
	return $self;
} 

sub save {
	my $self = shift;
	my ($la,$pcd,$fh);
	msg("Saving postcodes to <cyan>$self->{'file'}<none>...\n");
	open($fh,">",$self->{'file'});
	print $fh "Postcode,latitude,longitude\n";
	foreach $pcd (sort(keys(%{$self->{'postcodelookup'}}))){
		if($pcd){
			print $fh "$pcd,".($self->{'postcodelookup'}{$pcd}{'lat'}||"").",".($self->{'postcodelookup'}{$pcd}{'lon'}||"")."\n";
		}
	}
	close($fh);
	return $self;
}

sub getPostcode {
	my ($self, $postcode) = @_;
	
	my ($i,$pcd,$fh,@lines,$p,$lat,$lon,$url);

	$postcode =~ /^([A-Z]{1,2})/;
	$pcd = $1;
	$postcode =~ s/ //g;
	
	if(defined($self->{'postcodelookup'}{$postcode})){
		return $self->{'postcodelookup'}{$postcode};
	}
	if(!defined($self->{'postcodes'}{$pcd})){
		$self->{'postcodelookup'}{$postcode} = {'lat'=>undef,'lon'=>undef};
		$self->{'postcodes'}{$pcd} = {};
		$url = "https://odileeds.github.io/Postcodes2LatLon/postcodes/".$pcd.".csv";
		msg("Need to download <green>$pcd<none> postcodes from <cyan>$url<none>\n");
		@lines = `curl -s --insecure --compressed "$url"`;

		if(@lines > 1){
			for($i = 1; $i < @lines; $i++){
				$lines[$i] =~ s/[\n\r]//g;
				($p,$lat,$lon) = split(/,/,$lines[$i]);
				$p =~ s/ //g;
				$self->{'postcodes'}{$pcd}{$p} = {'lat'=>undef,'lon'=>undef};
				if($lat && $lon){
					$self->{'postcodes'}{$pcd}{$p}{'lat'} = $lat;
					$self->{'postcodes'}{$pcd}{$p}{'lon'} = $lon;
				}
			}
		}
	}
	if(defined($self->{'postcodes'}{$pcd}{$postcode})){
		$self->{'postcodelookup'}{$postcode} = $self->{'postcodes'}{$pcd}{$postcode};
		return $self->{'postcodes'}{$pcd}{$postcode};
	}else{
		warning("\t... no coordinates found for $postcode\n");
	}
	return;
}


1;