#!/usr/bin/perl

use strict;
use warnings;
use utf8;
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
use Data::Dumper;
use File::Path qw( make_path );
use Text::CSV;
use Types::Serialiser;
use List::Util qw(min max);
use DateTime;
use Cwd qw(abs_path);
my ($basedir, $path);
BEGIN {
	# Get the real base directory for this script
	($basedir, $path) = abs_path($0) =~ m{(.*/)?([^/]+)$};
}
use lib $basedir."../lib/";	# Custom functions
require "lib.pl";


my ($tdir,$catnum,$rid,$row,$id,$category,$data,$file,$mps,$pconlookup,$pcon,$mp,$i,$value,$totals,$j,$name,$cat,$csv,$outfile,$curfile);

$tdir = $basedir."../../raw-data/society/RMFI/";
$file = "current-MPs.json";
$outfile = $basedir."../../src/themes/society/mps-financial-interests/_data/release/RMFI.csv";

# Get the current MPs file
if(!-d $tdir){
	makeDir($tdir);
}
$curfile = $basedir."../../lookups/current-MPs.json";
if(-e $curfile){
	$mps = LoadJSON($curfile);
}else{
	SaveFromURL("https://github.com/open-innovations/constituencies/raw/refs/heads/main/lookups/current-MPs.json",$tdir.$file);
	$mps = LoadJSON($tdir.$file);
}
# Make MP lookup
foreach $pcon (keys(%{$mps})){ $pconlookup->{$mps->{$pcon}{'ID'}} = $pcon; }

# Get the most recent date's data
$data = getMostRecent({"temp"=>$tdir});

# Update the MPs object
$mps = processRegister($mps,$data);

foreach $pcon (sort(keys(%{$mps}))){
	$name = $mps->{$pcon}{'MP'}||"";
	$mps->{$pcon}{'totals'} = {'employment'=>{'count'=>0,'value'=>0,'hours'=>0},'donations'=>{'count'=>0,'value'=>0},'trips'=>{'count'=>0,'value'=>0},'gifts'=>{'count'=>0,'value'=>0}};
	# Process the first section
	$cat = '1. Employment and earnings';
	if(ref($mps->{$pcon}{'category'}{$cat}{'list'}) eq "ARRAY"){
		for($i = 0; $i < @{$mps->{$pcon}{'category'}{$cat}{'list'}}; $i++){
			if(defined($mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'hours'})){
				$mps->{$pcon}{'totals'}{'employment'}{'hours'} += $mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'hours'};
			}
			if(defined($mps->{$pcon}{'category'}{'1. Employment and earnings'}{'list'}[$i]{'value'})){
				$mps->{$pcon}{'totals'}{'employment'}{'value'} += $mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'};
			}
			$mps->{$pcon}{'totals'}{'employment'}{'count'}++;
		}
	}
	$cat = '2. Donations and other support (including loans) for activities as an MP';
	if(ref($mps->{$pcon}{'category'}{$cat}{'list'}) eq "ARRAY"){
		# Process the Donations sections
		for($i = 0; $i < @{$mps->{$pcon}{'category'}{$cat}{'list'}}; $i++){
			if(defined($mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'})){
				$mps->{$pcon}{'totals'}{'donations'}{'value'} += $mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'};
			}
			$mps->{$pcon}{'totals'}{'donations'}{'count'}++;
		}
	}
	$cat = '3. Gifts, benefits and hospitality from UK sources';
	if(ref($mps->{$pcon}{'category'}{$cat}{'list'}) eq "ARRAY"){
		# Process the Gifts sections
		for($i = 0; $i < @{$mps->{$pcon}{'category'}{$cat}{'list'}}; $i++){
			if(defined($mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'})){
				$mps->{$pcon}{'totals'}{'gifts'}{'value'} += $mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'};
			}
			$mps->{$pcon}{'totals'}{'gifts'}{'count'}++;
		}
	}
	$cat = '4. Visits outside the UK';
	if(ref($mps->{$pcon}{'category'}{$cat}{'list'}) eq "ARRAY"){
		# Process the trips section
		for($i = 0; $i < @{$mps->{$pcon}{'category'}{$cat}{'list'}}; $i++){
			if(defined($mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'})){
				$mps->{$pcon}{'totals'}{'trips'}{'value'} += $mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'};
			}
			$mps->{$pcon}{'totals'}{'trips'}{'count'}++;
		}
	}
	$cat = '5. Gifts and benefits from sources outside the UK';
	if(ref($mps->{$pcon}{'category'}{$cat}{'list'}) eq "ARRAY"){
		for($i = 0; $i < @{$mps->{$pcon}{'category'}{$cat}{'list'}}; $i++){
			if(defined($mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'})){
				$mps->{$pcon}{'totals'}{'gifts'}{'value'} += $mps->{$pcon}{'category'}{$cat}{'list'}[$i]{'value'};
			}
			$mps->{$pcon}{'totals'}{'gifts'}{'count'}++;
		}
	}
	if(defined($mps->{$pcon}{'category'}{'10. Family members engaged in lobbying the public sector on behalf of a third party or client'})){
#		print $mp."\n$name\n";
#		print Dumper $mps->{$pcon}{'category'}{'10. Family members engaged in lobbying the public sector on behalf of a third party or client'};
	}

}

$csv = "PCON24CD,PCON24NM,ParlID,Party,Name,Employment,Employment (£),Donations,Donations (£),Gifts,Gifts (£),Trips,Trips (£)\n";
foreach $pcon (sort(keys(%{$mps}))){
	$csv .= "$pcon";
	$csv .= ",".($mps->{$pcon}{'PCON24NM'} =~ /,/ ? "\"":"").$mps->{$pcon}{'PCON24NM'}.($mps->{$pcon}{'PCON24NM'} =~ /,/ ? "\"":"");
	$csv .= ",".$mps->{$pcon}{'ID'};
	$csv .= ",".$mps->{$pcon}{'Party'};
	$csv .= ",".($mps->{$pcon}{'MP'} =~ /,/ ? "\"":"").($mps->{$pcon}{'MP'}||"").($mps->{$pcon}{'MP'} =~ /,/ ? "\"":"");
	$csv .= ",".($mps->{$pcon}{'totals'}{'employment'}{'count'}||"0").",".($mps->{$pcon}{'totals'}{'employment'}{'value'}||"0");
	$csv .= ",".($mps->{$pcon}{'totals'}{'donations'}{'count'}||"0").",".($mps->{$pcon}{'totals'}{'donations'}{'value'}||"0");
	$csv .= ",".($mps->{$pcon}{'totals'}{'gifts'}{'count'}||"0").",".($mps->{$pcon}{'totals'}{'gifts'}{'value'}||"0");
	$csv .= ",".($mps->{$pcon}{'totals'}{'trips'}{'count'}||"0").",".($mps->{$pcon}{'totals'}{'trips'}{'value'}||"0");
	$csv .= "\n";
}
my $outdir = $outfile;
$outdir =~ s/[^\/]+$//;
makeDir($outdir);
msg("Saving summary to <cyan>$outfile<none>\n");
open(my $fh,">:utf8",$outfile) || error("Unable to save to <cyan>$outfile<none>\n");
print $fh $csv;
close($fh);


updateCreationTimestamp($basedir."../../src/themes/society/mps-financial-interests/index.vto",$data->{'date'});
updateCreationTimestamp($basedir."../../src/themes/society/mps-financial-interests/_data/map_1.json",$data->{'date'});





#########################

sub processRegister {
	my $mps = shift;
	my $inp = shift;
	my $dt = $inp->{'date'};
	my $data = $inp->{'csv'};

	my ($catnum,$rid,$row,$id,$category,$pcon,$datum,$c,$short,$num,$date,@subrows,$s,$item,$scaling,@trips,$trip);

	msg("Processing RMFI for <yellow>$dt<none>\n");
	foreach $catnum (sort(keys(%{$data}))){
		foreach $rid (sort(keys(%{$data->{$catnum}}))){
			$row = $data->{$catnum}{$rid};
			if(defined($row)){
				# Get the MP ID
				$id = $row->{'MNIS ID'};
				# Get the category
				$category = $catnum.". ".$row->{'Category'};
				$pcon = $pconlookup->{$id}||"";
				$row->{'PCON24CD'} = $pcon;
				if($pcon && defined($mps->{$pcon})){

					if(!defined($mps->{$pcon}{'category'})){
						$mps->{$pcon}{'category'} = {};
					}

					if($catnum ne "1.1" && $catnum ne "1.2"){

						if($id){

							# If we haven't created the category, add it
							if(!defined($mps->{$pcon}{'category'}{$category})){
								$mps->{$pcon}{'category'}{$category} = {'list'=>[]};
							}
							# Set the output to empty
							$datum = {'_details'=>{}};
				
							# Combine "_0" style variables into arrays
							foreach $c (keys(%{$row})){

								# Remove characters that break the JSON
								$row->{$c} =~ s/[\t\n	]{1,}/ /g;
								$row->{$c} =~ s/  / /g;
								if(defined($row->{$c}) && $row->{$c} ne ""){
									if($row->{$c} eq "True" || $row->{$c} eq "False"){
										$row->{$c} = bool($row->{$c});
									}

									if($c =~ /^(.*)\_([0-9]+)/){
										$short = $1;
										$num = $2+0-1;
										if(!defined($datum->{'_details'}{$short})){
											$row->{$short} = [];
										}
										if(defined($row->{$c})){
											$row->{$short}[$num] = $row->{$c};
										}
										delete $row->{$c};
									}
								}
							}

							# Add everything to _details
							foreach $c (keys(%{$row})){
								if(defined($row->{$c}) && $row->{$c} ne ""){
									# Store the value
									$datum->{'_details'}{$c} = $row->{$c};
								}
							}

							# Add all the things that look like dates
							foreach $c (keys(%{$row})){
								if($row->{$c} =~ /[0-9]{4}\-[0-9]{2}-[0-9]{2}/){
									$date = $c;
									$date =~ s/Date//g;
									$date = lc($date);
									if(!defined($datum->{'dates'})){ $datum->{'dates'} = {}; }
									if($date =~ /^updated/){
										if(!defined($datum->{'dates'}{'updated'})){
											$datum->{'dates'}{'updated'} = [];
										}
										push(@{$datum->{'dates'}{'updated'}},$row->{$c});
									}else{
										$datum->{'dates'}{$date} = $row->{$c};
									}
									delete $row->{$c};
								}
							}

							if($catnum eq "1"){

								if(gotValue($datum->{'_details'},'Summary')){
									$datum->{'summary'} = $datum->{'_details'}{'Summary'};
								}

								if(gotValue($datum->{'_details'},'PayerName') || gotValue($datum->{'_details'},'PayerPublicAddress')){
									
									$datum->{'payer'} = {};
									my $payer = "";
									if(gotValue($datum->{'_details'},'PayerName')){
										$payer .= $datum->{'_details'}{'PayerName'};
										$datum->{'payer'}{'name'} = $datum->{'_details'}{'PayerName'};
									}
									if(gotValue($datum->{'_details'},'PayerPublicAddress')){
										$payer .= ($payer ? " / ":"").$datum->{'_details'}{'PayerPublicAddress'};
										$datum->{'payer'}{'address'} = $datum->{'_details'}{'PayerPublicAddress'};
									}
								}

								# Need to add each corresponding item in 1.1
								@subrows = getByParent($row->{'ID'},$data,'1.1');
								# Need to add each corresponding item in 1.2
								push(@subrows,getByParent($row->{'ID'},$data,'1.2'));
								if(@subrows > 0){
									$datum->{'items'} = [];
								}
								# Loop over subrows
								for($s = 0; $s < @subrows; $s++){
									$scaling = getScalingFractions($dt,$subrows[$s]);

									$item = {
										'category'=>$subrows[$s]->{'_src'},
										'hours'=>{},
										'value'=>{}
									};
									if(gotValue($subrows[$s],'PaymentDescription')){
										$item->{'details'} = $subrows[$s]->{'PaymentDescription'};
									}
									if(gotValue($subrows[$s],'HoursWorked')){
										$item->{'hours'}{'value'} = $subrows[$s]->{'HoursWorked'}+0;
										$item->{'hours'}{'total'} = $subrows[$s]->{'HoursWorked'} * $scaling->{'hours'};
									}
									if(gotValue($subrows[$s],'HoursDetails')){
										$item->{'hours'}{'details'} = $subrows[$s]->{'HoursDetails'};
									}
									if(gotValue($subrows[$s],'PeriodForHoursWorked')){
										$item->{'hours'}{'period'} = $subrows[$s]->{'PeriodForHoursWorked'};
									}
									if(gotValue($subrows[$s],'Value')){
										$item->{'value'}{'amount'} = $subrows[$s]->{'Value'}+0;
									}
									if(gotValue($subrows[$s],'PaymentType')){
										$item->{'value'}{'type'} = $subrows[$s]->{'PaymentType'};
									}
									if(gotValue($subrows[$s],'RegularityOfPayment')){
										$item->{'value'}{'period'} = $subrows[$s]->{'RegularityOfPayment'};
									}
									if(gotValue($subrows[$s],'ReceivedDate')){
										$item->{'received'} = $subrows[$s]->{'ReceivedDate'};
									}
									if(gotValue($subrows[$s],'Registered')){
										$item->{'registered'} = $subrows[$s]->{'Registered'};
									};
									if(gotValue($subrows[$s],'StartDate')){
										$item->{'start'} = $subrows[$s]->{'StartDate'};
									}
									if(gotValue($subrows[$s],'EndDate')){
										$item->{'end'} = $subrows[$s]->{'EndDate'};
									}
									push(@{$datum->{'items'}},$item);

									# Add the hours worked
									if(defined($subrows[$s]->{'HoursWorked'})){
										if(!defined($datum->{'hours'})){
											$datum->{'hours'} = 0;
										}
										$datum->{'hours'} += ($subrows[$s]->{'HoursWorked'}||0) * $scaling->{'hours'};
									}
									# Add the value
									if(defined($subrows[$s]->{'Value'})){
										if(!defined($datum->{'value'})){
											$datum->{'value'} = 0;
										}
										$datum->{'value'} += ($subrows[$s]->{'Value'}||0) * $scaling->{'pay'};
									}
									
								}

							}elsif($catnum eq "2"){

								addDonor($datum,'donor');

								if(gotValue($datum->{'_details'},'Value')){
									$datum->{'value'} = $datum->{'_details'}{'Value'}+0;
								}

							}elsif($catnum eq "3"){

								if(gotValue($datum->{'_details'},'PaymentDescription')){
									$datum->{'summary'} = $datum->{'_details'}{'PaymentDescription'};
								}

								addDonor($datum,'donor');
								
								if(gotValue($datum->{'_details'},'Value')){
									$datum->{'value'} = $datum->{'_details'}{'Value'}+0;
								}

							}elsif($catnum eq "4"){

								if(gotValue($datum->{'_details'},'PaymentDescription')){
									$datum->{'summary'} = $datum->{'_details'}{'PaymentDescription'};
								}

								if(defined($datum->{'_details'}{'Donors_Value'})){
									$datum->{'value'} = 0;
									for($s = 0; $s < @{$datum->{'_details'}{'Donors_Value'}}; $s++){
										$datum->{'value'} += ($datum->{'_details'}{'Donors_Value'}[$s]||0);
									}
								}

								if(gotValue($datum->{'_details'},'PaymentDescription')){
									$datum->{'destination'} = $datum->{'_details'}{'PaymentDescription'};
								}			
								if(gotValue($datum->{'_details'},'Purpose')){
									$datum->{'purpose'} = $datum->{'_details'}{'Purpose'};
								}

								if(defined($datum->{'_details'}{'Donors_Value'})){
									@trips = ();
									for($s = 0; $s < @{$datum->{'_details'}{'Donors_Value'}}; $s++){
										$trip = {};
										$trip->{'destination'} = {
											'place'=>$datum->{'_details'}{'VisitLocations_Destination'}[$s],
											'country'=>$datum->{'_details'}{'VisitLocations_Country'}[$s]
										};
										$trip->{'donor'} = {};
										if(defined($datum->{'_details'}{'Donors_Name'}[$s])){
											$trip->{'donor'}{'name'} = $datum->{'_details'}{'Donors_Name'}[$s];
										}
										if(defined($datum->{'_details'}{'Donors_PublicAddress'}[$s])){
											$trip->{'donor'}{'address'} = $datum->{'_details'}{'Donors_PublicAddress'}[$s];
										}
										if(defined($datum->{'_details'}{'Donors_PaymentType'}[$s])){
											$trip->{'donor'}{'type'} = $datum->{'_details'}{'Donors_PaymentType'}[$s];
										}
										if(defined($datum->{'_details'}{'Donors_PaymentDescription'}[$s])){
											$trip->{'donor'}{'description'} = $datum->{'_details'}{'Donors_PaymentDescription'}[$s];
										}
										if(defined($datum->{'_details'}{'Donors_IsSoleBeneficiary'}[$s])){
											$trip->{'donor'}{'solebeneficiary'} = $datum->{'_details'}{'Donors_IsSoleBeneficiary'}[$s];
										}
										if(defined($datum->{'_details'}{'Donors_IsPrivateIndividual'}[$s])){
											$trip->{'donor'}{'privateindividual'} = $datum->{'_details'}{'Donors_IsPrivateIndividual'}[$s];
										}
										if(defined($datum->{'_details'}{'Donors_Value'}[$s])){
											$trip->{'donor'}{'value'} = ($datum->{'_details'}{'Donors_Value'}[$s]||0)+0;
										}
										
										push(@trips,$trip);
									}
									@{$datum->{'parts'}} = @trips;
								}


							}elsif($catnum eq "5"){
								
								if(gotValue($datum->{'_details'},'PaymentDescription')){
									$datum->{'summary'} = $datum->{'_details'}{'PaymentDescription'};
								}

								addDonor($datum,'donor');

								if(gotValue($datum->{'_details'},'Value')){
									$datum->{'value'} = $datum->{'_details'}{'Value'}+0;
								}

							}elsif($catnum eq "6"){
								
								
								if(gotValue($datum->{'_details'},'PropertyType')){
									$datum->{'type'} = $datum->{'_details'}{'PropertyType'};
								}
								if(gotValue($datum->{'_details'},'NumberOfProperties')){
									$datum->{'quantity'} = $datum->{'_details'}{'NumberOfProperties'}+0;
								}
								if(gotValue($datum->{'_details'},'Location')){
									$datum->{'location'} = $datum->{'_details'}{'Location'};
								}
								if(gotValue($datum->{'_details'},'PropertyOwnerDetails')){
									$datum->{'details'} = $datum->{'_details'}{'PropertyOwnerDetails'};
								}
								if(gotValue($datum->{'_details'},'RegistrableRentalIncome')){
									$datum->{'registerableincome'} = $datum->{'_details'}{'RegistrableRentalIncome'};
								}
								if(gotValue($datum->{'_details'},'IsAnyRentalIncomePaidToAnotherPerson')){
									$datum->{'anotherperson'} = $datum->{'_details'}{'IsAnyRentalIncomePaidToAnotherPerson'};
								}
								if(gotValue($datum->{'_details'},'IsLand')){
									$datum->{'land'} = $datum->{'_details'}{'IsLand'};
								}
								if(gotValue($datum->{'_details'},'Country')){
									$datum->{'country'} = $datum->{'_details'}{'Country'};
								}
							
							}elsif($catnum eq "7"){
									
								if(gotValue($datum->{'_details'},'ShareholdingThreshold')){
									$datum->{'threshold'} = $datum->{'_details'}{'ShareholdingThreshold'};
								}
								if(gotValue($datum->{'_details'},'Summary')){
									$datum->{'summary'} = $datum->{'_details'}{'Summary'};
								}
								if(gotValue($datum->{'_details'},'OrganisationName')){
									if(!defined($datum->{'org'})){
										$datum->{'org'} = {};
									}
									$datum->{'org'}{'name'} = $datum->{'_details'}{'OrganisationName'};
								}
								if(gotValue($datum->{'_details'},'OrganisationDescription')){
									if(!defined($datum->{'org'})){
										$datum->{'org'} = {};
									}
									$datum->{'org'}{'description'} = $datum->{'_details'}{'OrganisationDescription'};
								}
							
							}elsif($catnum eq "8"){
								
								
								if(gotValue($datum->{'_details'},'Summary')){
									$datum->{'summary'} = $datum->{'_details'}{'Summary'};
								}
								if(gotValue($datum->{'_details'},'MiscellaneousInterestType')){
									$datum->{'type'} = $datum->{'_details'}{'MiscellaneousInterestType'};
								}
							
							}elsif($catnum eq "9"){

								if(gotValue($datum->{'_details'},'PersonName')){
									$datum->{'name'} = $datum->{'_details'}{'PersonName'};
								}
								if(gotValue($datum->{'_details'},'FamilyMemberRelationshipLevel')){
									$datum->{'relationshiplevel'} = $datum->{'_details'}{'FamilyMemberRelationshipLevel'};
								}
								if(gotValue($datum->{'_details'},'FamilyRelationType')){
									$datum->{'relationship'} = $datum->{'_details'}{'FamilyRelationType'};
								}
								if(gotValue($datum->{'_details'},'JobTitle')){
									$datum->{'jobtitle'} = $datum->{'_details'}{'JobTitle'};
								}
								if(gotValue($datum->{'_details'},'WorkingPattern')){
									$datum->{'workingpattern'} = $datum->{'_details'}{'WorkingPattern'};
								}

							}elsif($catnum eq "10"){

								if(gotValue($datum->{'_details'},'Summary')){
									$datum->{'summary'} = $datum->{'_details'}{'Summary'};
								}
								if(gotValue($datum->{'_details'},'PersonName')){
									$datum->{'name'} = $datum->{'_details'}{'PersonName'};
								}
								if(gotValue($datum->{'_details'},'FamilyMemberRelationshipLevel')){
									$datum->{'relationshiplevel'} = $datum->{'_details'}{'FamilyMemberRelationshipLevel'};
								}
								if(gotValue($datum->{'_details'},'FamilyRelationType')){
									$datum->{'relationship'} = $datum->{'_details'}{'FamilyRelationType'};
								}
								if(gotValue($datum->{'_details'},'JobTitle')){
									$datum->{'jobtitle'} = $datum->{'_details'}{'JobTitle'};
								}
								if(gotValue($datum->{'_details'},'Employer')){
									$datum->{'employer'} = $datum->{'_details'}{'Employer'};
								}
								if(gotValue($datum->{'_details'},'WorkingPattern')){
									$datum->{'workingpattern'} = $datum->{'_details'}{'WorkingPattern'};
								}
							}

							# Remove the temporary _details.
							delete $datum->{'_details'};

							if($datum->{'txt'}){
								$datum->{'txt'} = "<table class=\"descriptive-list\">$datum->{'txt'}</table>";
							}

							# Add to the category list
							push(@{$mps->{$pcon}{'category'}{$category}{'list'}},$datum);

						}else{

							warning("No ID provided for $catnum:\n");
							print Dumper $row;

						}
					}
				}else{
					warning("No MP found for <yellow>$id<none> ($row->{'Member'}) - they may have stopped being an MP\n");
					print Dumper $row;
				}
			}else{
				warning("No data for $rid - $catnum\n");
			}
		}
	}
	return $mps;
}


sub bool {
	my $v = shift||"";
	if($v eq "True"){ return Types::Serialiser::true; }
	return Types::Serialiser::false;
}

sub addDonor {
	my $datum = shift;
	my $key = shift||"donor";
	my $donor = {};
	my $added = 0;

	if(gotValue($datum->{'_details'},'DonorName')){
		$donor->{'name'} = $datum->{'_details'}{'DonorName'};
		$added++;
	}
	if(gotValue($datum->{'_details'},'DonorStatus')){
		$donor->{'status'} = $datum->{'_details'}{'DonorStatus'};
		$added++;
	}
	if(gotValue($datum->{'_details'},'DonorPublicAddress')){
		$donor->{'address'} = $datum->{'_details'}{'DonorPublicAddress'};
		$added++;
	}
	if(gotValue($datum->{'_details'},'Value')){
		$donor->{'nature'} = "£".$datum->{'_details'}{'Value'};
		$added++;
	}
	if(gotValue($datum->{'_details'},'Value')){
		$donor->{'values'} = [$datum->{'_details'}{'Value'}+0];
		$added++;
	}
	if(gotValue($datum->{'_details'},'DonorCompanyIdentifier')){
		$donor->{'companyregistration'} = $datum->{'_details'}{'DonorCompanyIdentifier'};
		$added++;
	}
	if(gotValue($datum->{'_details'},'DonationSource')){
		$donor->{'type'} = $datum->{'_details'}{'DonationSource'};
		$added++;
	}
	if(gotValue($datum->{'dates'},'received')){
		$donor->{'date-received'} = $datum->{'dates'}{'received'};
		$added++;
	}
	if(gotValue($datum->{'dates'},'accepted')){
		$donor->{'date-accepted'} = $datum->{'dates'}{'accepted'};
		$added++;
	}
	if(gotValue($datum->{'dates'},'registered')){
		$donor->{'date-registered'} = $datum->{'dates'}{'registered'};
		$added++;
	}
	if($added > 0){
		$datum->{$key} = $donor;
	}
	return $datum->{$key}||{};
}

sub gotValue {
	my $row = shift;
	my $v = shift;
	if(defined($row->{$v}) && $row->{$v} ne ""){
		return 1;
	}else{
		return 0;
	}
}

sub getByParent {
	my $pid = shift;
	my $data = shift;
	my $key = shift;
	my ($sid,@rows);
	foreach $sid (keys(%{$data->{$key}})){
		if($data->{$key}{$sid}{'Parent Interest ID'} eq $pid){
			$data->{$key}{$sid}{'_src'} = $key;
			push(@rows,$data->{$key}{$sid});
		}
	}
	return @rows;
}

sub getScalingFractions {
	my $dt = shift;
	my $d = shift;
	my ($sdate,$edate,$dt1,$dt2,$hours_period,$pay_period,$h,$p,$weeks,$months,$days,$years,$yearago);

	$edate = ($d->{'EndDate'} || $dt);
	# Limit to the date of the RMFI
	if($edate gt $dt){ $edate = $dt; }
	$yearago = previousYear($dt);
	$sdate = ($d->{'StartDate'} || $yearago);
	if($sdate lt $yearago && $yearago lt $edate){ $sdate = $yearago; }

	$hours_period = $d->{'PeriodForHoursWorked'}||"one-off";
	$pay_period = $d->{'RegularityOfPayment'}||"one-off";

	# Work out what fraction of a year this is valid for
	$h = 1;
	$p = 1;

	if($sdate lt $edate){

		$dt1 = iso8601_date($sdate);
		$dt2 = iso8601_date($edate);

		$days = $dt1->delta_days($dt2)->delta_days();
		$months = $dt1->delta_md($dt2)->{'months'};
		$weeks = int($days/7);
		if($weeks > 52){ $weeks = 52; }
		if($months > 12){ $months = 12; }
		if($days > 365){ $days = 365; }

		# Work out scaling factor for hours
		if($hours_period ne "one-off"){
			
			# If the hours are monthly we 
			if($hours_period eq "Yearly"){
				$h = $days/365;
			}elsif($hours_period eq "Monthly"){
				$h = $months;
			}elsif($hours_period eq "Quarterly"){
				$h = int($months/4);
			}elsif($hours_period eq "Weekly"){
				$h = $weeks;
			}else{
				warning("Unknown hours period <cyan>$hours_period<none>.\n");
			}
		}

		if($pay_period ne "one-off"){
			# If the hours are monthly we 
			if($pay_period eq "Yearly"){
				$p = $days/365;
			}elsif($pay_period eq "Monthly"){
				$p = $months;
			}elsif($pay_period eq "Quarterly"){
				$p = int($months/4);
			}elsif($pay_period eq "Weekly"){
				$p = $weeks;
			}else{
				warning("Unknown pay period <cyan>$pay_period<none>.\n");
			}
		}
	}elsif($sdate eq $edate){
	}else{
		warning("Start date <yellow>$sdate<none> ($d->{'StartDate'}) seems to be after end date <yellow>$edate<none> ($d->{'EndDate'}).\n");
		#print Dumper $d;
	}
	return {'pay'=>$p,'hours'=>$h};
}

sub previousYear {
	my $dt = shift;
	if($dt =~ /^([0-9]{4})(\-[0-9]{2}\-[0-9]{2})/){
		my $y = $1+0;
		$y--;
		$dt = sprintf("%04d",$y).$2;
	}
	return $dt;
}

sub iso8601_date {
	die unless $_[0] =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)$/;
	return DateTime->new(year => $1, month => $2, day => $3,
		hour => 12, minute => 0, second => 0, time_zone  => 'UTC');
}


sub getMostRecent {
	my $opts = shift;
	my ($dt,$temp,$reg,$l,$href,$zipdir,$zipfile,$filename,$data,$catnum,$dh);
	$temp = ParseJSON(`wget -q --no-check-certificate -O- "https://interests-api.parliament.uk/api/v1/Registers?Take=10&Skip=0"`);
	if(@{$temp->{'items'}} > 0){
		$reg = $temp->{'items'}[0];
		$dt = $reg->{'publishedDate'};
		$href = "";
		# Loop over links
		for($l = 0; $l < @{$reg->{'links'}}; $l++){
			if($reg->{'links'}[$l]{'rel'} eq "csv"){
				$href = $reg->{'links'}[$l]{'href'};
			}
		}

		if($href){

			$zipdir = $opts->{'temp'};
			$zipfile = $zipdir."$dt.zip";
			if($zipdir){
				if(!-d $opts->{'temp'}){
					make_path($opts->{'temp'});
				}
				if(!-e $zipfile){
					msg("Download from <cyan>$href<none> to <cyan>$zipfile<none>.\n");
					`wget -q --no-check-certificate -O $zipfile "$href"`;
				}
				`unzip -o $zipfile -d $zipdir`;



				# Read contents of directory
				opendir($dh, $zipdir) || error("Error in opening dir $zipdir\n");
				$data = {'date'=>$dt,'csv'=>{}};
				while(($filename = readdir($dh))){
					if($filename =~ /Category_(.*)\.csv$/){
						$catnum = $1;
						$data->{'csv'}{$catnum} = LoadCSV2($zipdir.$filename,{'key'=>'ID'});
					}
				}
				closedir($dh);
				return $data;
			}else{
				warning("No temporary directory provided to save to. Failing.\n");
			}
		}
		return {};
	}else{
		error("No items in response\n");
		print Dumper $temp;
		exit;
	}
}


# version 2
sub LoadCSV2 {
	my $file = shift;
	my $config = shift;
	
	my ($csv,$row,@rows,@cols,@header,$i,$r,$c,@features,$data,$key,$k,$f,$n,$n2,$compact,$hline,$sline,$col,$delimiter,$matches);

	$compact = $config->{'compact'};
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
	msg("Processing CSV from <cyan>$file<none>\n");
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
			$data = {};
			for($c = 0; $c < @cols; $c++){
				$cols[$c] =~ s/(^\"|\"$)//g;
				$data->{$header[$c]} = $cols[$c];
			}
			push(@features,$data);
		}
	}
	if($col){
		$data = {};
		for($r = 0; $r < @features; $r++){
			$f = $features[$r]->{$col};
			if($compact){ $f =~ s/ //g; }
			$data->{$f} = $features[$r];
		}
		return $data;
	}else{
		return @features;
	}
}
