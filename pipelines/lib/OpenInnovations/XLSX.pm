package OpenInnovations::XLSX;

# Version 1.1

use strict;
use warnings;
use Data::Dumper;
use Encode;
use XML::Simple;
use Time::HiRes qw( time );
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

sub getXLSXSharedStrings {
	my $self = shift;
	my ($parser,$str,$t,$i,$n);
	# First we need to get the sharedStrings.xml
	$str = `unzip -p $self->{'file'} xl/sharedStrings.xml 2>/dev/null`;
	if(!utf8::is_utf8($str)){ $str = decode_utf8($str); }
	$parser = XMLin($str);
	$n = @{$parser->{'si'}};
	for($i = 0; $i < $n; $i++){
		if(ref($parser->{'si'}[$i]{'t'}) eq "HASH"){
			$self->{'strings'}[$i] = $parser->{'si'}[$i]{'t'}{'content'};
		}else{
			$self->{'strings'}[$i] = $parser->{'si'}[$i]{'t'};
		}
	}
	return @{$self->{'strings'}};
}

sub getXLSXSheets {
	my $self = shift;
	my ($str,$parse,$id,$rid,$attr);

	$str =  `unzip -p $self->{'file'} xl/workbook.xml`;
	$str =~ s/<definedNames>.*?<\/definedNames>//;
	my $parser = XMLin($str);
	foreach $id (keys(%{$parser->{'sheets'}{'sheet'}})){
		$rid = $parser->{'sheets'}{'sheet'}{$id}{'r:id'};
		$rid =~ s/^rId/sheet/;
		$attr = {
			'name'=>$id,
			'id'=>$rid,
			'sheetId'=>$parser->{'sheets'}{'sheet'}{$id}{'sheetId'}
		};
		push(@{$self->{'sheets'}},$attr);
	}
	return @{$self->{'sheets'}};
}

sub loadSheet {
	my $self = shift;
	my $sheet = shift;
	my $args = shift;
	my @strings = @_;

	msg("\tProcessing sheet <yellow>$sheet<none>\n");

	my ($stime,$etime,$txt,$xlsx,$parser,$nrows,$ncols,$found,$s,$str,$sheetcontent,$props,$row,$attr,$rowdata,$col,$c,$a,$n,@rows,$r,$head,$headers,$datum,$key,@features);
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
	
	$stime = time();
	$parser = XMLin($str);
	$nrows = @{$parser->{'sheetData'}{'row'}};
	$ncols = 0;

	for($r = 0; $r < $nrows; $r++){
		if(ref($parser->{'sheetData'}{'row'}[$r]{'c'}) eq "HASH"){
			$parser->{'sheetData'}{'row'}[$r]{'c'} = [$parser->{'sheetData'}{'row'}[$r]{'c'}];
		}
		if(ref($parser->{'sheetData'}{'row'}[$r]{'c'}) eq "ARRAY"){
			$ncols = @{$parser->{'sheetData'}{'row'}[$r]{'c'}};
			$rowdata = ();
			for($c = 0; $c < $ncols; $c++){
				if($parser->{'sheetData'}{'row'}[$r]{'c'}[$c]{'r'} =~ /^([A-Z]+)([0-9]+)/){
					$a = $1;
					$n = $2;
					$col = $parser->{'sheetData'}{'row'}[$r]{'c'}[$c]{'v'};
					if(!defined($parser->{'sheetData'}{'row'}[$r]{'c'}[$c]{'t'})){ $parser->{'sheetData'}{'row'}[$r]{'c'}[$c]{'t'} = ""; }
					if($parser->{'sheetData'}{'row'}[$r]{'c'}[$c]{'t'} eq "s"){
						$rowdata->{$a} = $self->{'strings'}[$col];
					}else{
						$rowdata->{$a} = $col;
					}
				}
			}
			$rows[$r] = $rowdata;
		}else{
			warning("Not an array of columns on row <yellow>$r<none>\n");
		}
	}
	$etime = time();
	msg("\tParsed data in <green>".sprintf("%.2f",$etime - $stime)."<none>s\n");

	foreach $r (sort(@{$args->{'header'}})){
		foreach $col (keys(%{$rows[$r]})){
			$head = $rows[$r]{$col};
			if(defined($args->{'rename'})){
				$head = $args->{'rename'}->($rows[$r]{$col});
			}
			$headers->{$col} .= ($headers->{$col} ? "→" : "").$head;
		}
	}

	# Build output
	$xlsx = {
		'headers'=>{
			'lookup'=>$headers,
		}
	};
	my @heads = keys(%{$headers});
	for($r = $args->{'header'}[@{$args->{'header'}}-1]+1; $r < @rows; $r++){

		if($r >= $args->{'startrow'}){
			$datum = {};
			foreach $key (@heads){
				if(!defined($rows[$r]->{$key})){ $rows[$r]->{$key} = ""; }
				$datum->{$headers->{$key}} = $rows[$r]->{$key};
			}
			push(@{$xlsx->{'rows'}},$datum);
		}
	}
	@{$xlsx->{'headers'}{'columns'}} = sort{length($a) <=> length($b) || $a cmp $b}(keys(%{$headers}));
	for($r = 0 ; $r < @{$xlsx->{'headers'}{'columns'}}; $r++){
		$xlsx->{'headers'}{'columns'}[$r] = {
			'title'=>$headers->{$xlsx->{'headers'}{'columns'}[$r]},
			'key'=>$xlsx->{'headers'}{'columns'}[$r]
		};
	}
	return $xlsx;
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