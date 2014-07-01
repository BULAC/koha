#!/usr/bin/perl     

#
# B014
#
# On crée notre objet qui initialise le CGI et crée une couche d'abstraction envoi/réception pour communiquer avec notre client    

use strict;     
use warnings;     
use CGI;  
use C4::Members; 
use CGI qw/:standard/;

my $input = new CGI;

binmode STDOUT, ":utf8";
print $input->header(-type => 'text/plain', -charset => 'UTF-8');

my $data=$input->param('debut');  
my $result="";
$result = GetCitiesZip($data); 

print " | \n";

foreach my $k (keys %$result) { 
	print "$result->{$k}->{'city_zipcode'}|$result->{$k}->{'city_name'}\n";
	
}