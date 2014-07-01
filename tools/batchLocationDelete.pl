#!/usr/bin/perl

#
# Progilone B10: StoreCallnumber
#

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use CGI;
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Items;
use C4::Koha;
use C4::Callnumber::StoreCallnumber;
use C4::Callnumber::FreeAccessCallnumber;

my $input = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/batchLocationDelete.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { editcatalogue => '*' },
        debug           => 1,
    }
);

#my $zone          = $input->param( 'zone' ) || '';
#my $block         = $input->param( 'block' ) || '';
#my $bay           = $input->param( 'bay' ) || '';
#my $bookcase      = $input->param( 'bookcase' ) || '';

my $op = $input->param( 'op' ) || '';

my $location = $input->param( 'location' );
my $callnumber_type = $input->param( 'callnumber_type' ) || 'store_callnumber'; 
my $callnumber_prefix = $input->param( 'callnumber_prefix' ) || '';
my $callnumber_min = $input->param( 'callnumber_min' );
my $callnumber_max = $input->param( 'callnumber_max' );

#my $physical_address = '';
my $message  = '';

my $location_loop = GetAuthorisedValues( "LOC", $location );

if ( $op eq 'op' ) {
	
	$callnumber_prefix =~ s/[\s\.-]//g;
	
	if ( $callnumber_type eq 'store_callnumber' ) {
		
		$callnumber_min = int( $callnumber_min || 0 );
		$callnumber_max = int( $callnumber_max || 999999 );
		
		my @itemnumbers = ();
		
		#Retrieve items to check that their callnumber is between min and max callnumber
		my $dbh = C4::Context->dbh;
		
		my $query = "SELECT itemnumber, 
							itemcallnumber
					 FROM items 
					 WHERE location = ? 
					 	   AND ExtractValue( more_subfields_xml, '//datafield[\@tag=\"999\"]/subfield[\@code=\"K\"]' ) = itemcallnumber ";
					 
		my $sth = $dbh->prepare( $query );
		$sth->execute( $location );
		
		my $rows = $sth->fetchall_arrayref({});
		foreach my $row ( @{$rows} ) {
		    my $itemnumber = @$row{'itemnumber'};
		    my $callnumber = @$row{'itemcallnumber'};
		    
		    my ( $base, $sequence, $rest ) =  C4::Callnumber::StoreCallnumber::GetBaseAndSequenceFromStoreCallnumber( $callnumber, 0 );
		    
		    if ( $base =~ m/^$callnumber_prefix/ && $sequence >= $callnumber_min && $sequence <= $callnumber_max ) {
		   		push( @itemnumbers, $itemnumber );
		    }
		}
		
		if ( @itemnumbers ) {
			$query = "UPDATE items SET physical_address = '', location = '' WHERE itemnumber IN (".join(',', @itemnumbers).")";
			$sth = $dbh->prepare( $query );
			$sth->execute();
		}
		
	} else {
		
		my @itemnumbers = ();
		
		#Retrieve items to check that their callnumber is between min and max callnumber
		my $dbh = C4::Context->dbh;
		
		my $query = "SELECT itemnumber, 
							itemcallnumber
					 FROM items 
					 WHERE location = ? 
					 	   AND ExtractValue( more_subfields_xml, '//datafield[\@tag=\"999\"]/subfield[\@code=\"B\"]' ) = itemcallnumber ";
					 
		my $sth = $dbh->prepare( $query );
		$sth->execute( $location );
		
		my $rows = $sth->fetchall_arrayref({});
		foreach my $row ( @{$rows} ) {
		    my $itemnumber = @$row{'itemnumber'};
		    my $callnumber = @$row{'itemcallnumber'};
		    
		    my ( $base, $sequence ) =  C4::Callnumber::FreeAccessCallnumber::GetBaseAndSequenceFromFreeAccessCallnumber( $callnumber );
		    
		    if ( $base eq $callnumber_prefix && C4::Callnumber::FreeAccessCallnumber::IsSequenceBetweenMinMax( $sequence, $callnumber_min, $callnumber_max ) ) {
		   		push( @itemnumbers, $itemnumber );
		    }
		}
		
		if ( @itemnumbers ) {
			$query = "UPDATE items SET physical_address = '', location = '' WHERE itemnumber IN (".join(',', @itemnumbers).")";
			$sth = $dbh->prepare( $query );
			$sth->execute();
		}
		
	}
	
	$message = "The operation was properly performed.";
}

$template->param(
	"callnumber_prefix" => $callnumber_prefix,
	"callnumber_min"    => $callnumber_min,
	"callnumber_max"    => $callnumber_max,
	"message"           => $message,
	"location_loop"     => $location_loop,
	$callnumber_type    => 1,
);

output_html_with_http_headers $input, $cookie, $template->output;
exit;
