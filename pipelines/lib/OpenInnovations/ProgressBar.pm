# ============
# ProgressBar v0.1
package OpenInnovations::ProgressBar;

use strict;
use warnings;
use Data::Dumper;

sub new {
	my ($class, %args) = @_;
 
	my $self = \%args;
	$self->{'len'} = 100;
	$self->{'per'} = -1;
	$self->{'start'} = 0;
	$self->{'bar'} = "";
	bless $self, $class;

	return $self;
}


sub len {
	my ($self, $v) = @_;
	$self->{'len'} = $v;
	return $v;
}

sub max {
	my ($self, $v) = @_;
	$self->{'max'} = $v;
	$self->{'per'} = -1;
	$self->{'bar'} = "";
	return $v;
}

sub update {
	my ($self, $v, $prefix) = @_;
	my ($per) = int(100*$v/$self->{'max'});
	my $bar;
	if($self->{'per'}==-1 || $per != $self->{'per'}){
		$| = 1;	# To force printing https://stackoverflow.com/questions/6558634/why-doesnt-print-output-anything-on-each-iteration-of-a-loop-when-i-use-sleep
		$bar = ($prefix||"")."[ ".("#" x int($self->{'len'}*$per/100)).(" " x int($self->{'len'}*(100-$per)/100))." ] $per\%";
		print "\033[J".$bar."\033[G";
		$self->{'per'} = $per;
	}
	if($v == $self->{'max'}){
		print "\n";
	}
	
	return;	
}

1;