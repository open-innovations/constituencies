package OpenInnovations::XLSX;

# Version 1.0

use strict;
use warnings;
use Data::Dumper;
use Encode;
use open qw(:std :encoding(UTF-8));
binmode(STDOUT, ":utf8");
binmode(STDIN, ":encoding(UTF-8)");

sub new {
    my ($class, %args) = @_;
 
    my $self = \%args;
 
    bless $self, $class;

	if($self->{'file'}){ $self->load($self->{'file'}); }
 
    return $self;
}


sub load {
	# version 1.2
	my $self = shift;
	my $file = shift;
	my $args = shift;

	if(!-e $file){
		error("No XLSX file to open at <cyan>$file<none>.\n");
	}

	msg("Unzipping xlsx <cyan>$file<none>\n");
	$self->{'file'} = $file;

	$self->getXLSXSharedStrings();
	$self->getXLSXSheets();

	return $self;
}

sub loadSheet {
	my $self = shift;
	my $sheet = shift;
	my $args = shift;
	my @strings = @_;

	msg("\tProcessing sheet <yellow>$sheet<none>\n");

	my ($txt,$xlsx,$found,$s,$str,$sheetcontent,$props,$row,$attr,$rowdata,$col,$c,$n,@rows,$r,$head,$headers,$datum,$key,@features);
	$xlsx = {};

	# See if the sheet matches
	$found = -1;
	for($s = 0; $s < @{$self->{'sheets'}}; $s++){
		if($self->{'sheets'}[$s]{'id'} eq $sheet || $self->{'sheets'}[$s]{'name'} eq $sheet){
			$found = $s;
			$s = @{$self->{'sheets'}};
		}
	}
	if($found < 0){
		$txt = "\tNo sheet <yellow>$sheet<none> in the file.\n";
		$txt .= "\tProvide one of the following: ";
		for($s = 0; $s < @{$self->{'sheets'}}; $s++){
			$txt .= ($s==0 ? "":", ")."<yellow>".$self->{'sheets'}[$s]{'name'}."<none>";
		}
		$txt .= "\n";
		error($txt);
		exit;
	}

	$str = `unzip -p $self->{'file'} xl/worksheets/$self->{'sheets'}[$found]{'id'}.xml`;
	if(!utf8::is_utf8($str)){ $str = decode_utf8($str); }
	$str = decode_utf8(join("",$str));

	if($str =~ /<sheetData>(.*?)<\/sheetData>/){
		$sheetcontent = $1;
		while($sheetcontent =~ s/<row([^\>]*?)>(.*?)<\/row>//){
			$props = $1;
			$row = $2;
			$attr = {};
			while($props =~ s/([^\s]+)="([^\"]+)"//){ $attr->{$1} = $2; }
			$rowdata = {};
			$rowdata->{'cols'} = ();
			while($row =~ s/<c([^\>]*?)>(.*?)<\/c>//){
				$props = $1;
				$col = $2;
				$col =~ s/<[^\>]+>//g;
				$attr = {};
				while($props =~ s/([^\s]+)="([^\"]+)"//){ $attr->{$1} = $2; }
				if($attr->{'r'} =~ /^([A-Z]+)([0-9]+)/){
					$c = $1;
					$n = $2;
					if(!defined($attr->{'t'})){ $attr->{'t'} = ""; }
					if($attr->{'t'} eq "s"){
						$rowdata->{'cols'}{$c} = $self->{'strings'}[$col];
					}else{
						$rowdata->{'cols'}{$c} = $col;
					}
				}
			}
			push(@rows,$rowdata);
		}
	}

	foreach $r (sort(@{$args->{'header'}})){
		foreach $col (keys(%{$rows[$r]{'cols'}})){
			$head = $rows[$r]{'cols'}{$col};
			if(defined($args->{'rename'})){
				$head = $args->{'rename'}->($rows[$r]{'cols'}{$col});
			}
			$headers->{$col} .= ($headers->{$col} ? "→" : "").$head;
		}
	}

	for($r = $args->{'header'}[@{$args->{'header'}}-1]+1; $r < @rows; $r++){

		if($r >= $args->{'startrow'}){
			$datum = {};
			foreach $key (keys(%{$headers})){
				if($rows[$r]->{'cols'}{$key}){
					$datum->{$headers->{$key}} = $rows[$r]->{'cols'}{$key};
				}	
			}
			push(@features,$datum);
		}
	}

	$xlsx = {
		'headers'=>{
			'lookup'=>$headers,
		}
	};
	@{$xlsx->{'rows'}} = @features;
	@{$xlsx->{'headers'}{'columns'}} = sort{length($a) <=> length($b) || $a cmp $b}(keys(%{$headers}));
	for($r = 0 ; $r < @{$xlsx->{'headers'}{'columns'}}; $r++){
		$xlsx->{'headers'}{'columns'}[$r] = {
			'title'=>$headers->{$xlsx->{'headers'}{'columns'}[$r]},
			'key'=>$xlsx->{'headers'}{'columns'}[$r]
		};
	}
	return $xlsx;
}

sub getXLSXSharedStrings {
	my $self = shift;
	my (@strings,$str,$t);
	# First we need to get the sharedStrings.xml
	$str = `unzip -p $self->{'file'} xl/sharedStrings.xml 2>/dev/null`;
	if(!utf8::is_utf8($str)){ $str = decode_utf8($str); }
	while($str =~ s/<si>(.*?)<\/si>//){
		$t = $1;
		$t =~ s/<[^\>]+>//g;
		push(@strings,$t);
	}
	@{$self->{'strings'}} = @strings;
	return @strings;
}

sub getXLSXSheets {
	my $self = shift;
	my ($str,@lines,$i,@sheets,$props,$attr);

	$str =  `unzip -p $self->{'file'} xl/workbook.xml`;
	while($str =~ s/<sheet([^\>]*)\/>//){
		$props = $1;
		$attr = {};
		while($props =~ s/([^\s]+)="([^\"]+)"//){ $attr->{$1} = $2; }
		$attr->{'id'} = $attr->{'r:id'};
		$attr->{'id'} =~ s/^rId//;
		$attr->{'id'} = "sheet".$attr->{'id'};
		push(@sheets,$attr);
		
	}
	@{$self->{'sheets'}} = @sheets;
	return @sheets;
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

1;