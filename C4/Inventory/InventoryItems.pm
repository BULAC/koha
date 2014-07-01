package C4::Inventory::InventoryItems;

#
# B12 : Inventory
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

use Carp;
use C4::Context;
use C4::Koha;
use C4::Dates qw/format_date/;

use C4::Callnumber::StoreCallnumber;
use C4::Callnumber::FreeAccessCallnumber;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    $VERSION = 3.02;

	require Exporter;
    @ISA = qw( Exporter );

    # function exports
    @EXPORT = qw(
        GetItemInfoForInventory
        GetItemsByCriteriaLocation
    );
}

=head2 GetItemInfoForInventory

  $item = GetItemInfoForInventory($barcode);

Return item information, for a given barcode.
The return value is a hashref mapping item column
names to values.

=cut

sub GetItemInfoForInventory {
    my ($barcode) = @_;
    my $dbh = C4::Context->dbh;
    my $data;
    if ($barcode) {
        my $sth = $dbh->prepare('
            SELECT itemnumber, location, holdingbranch, barcode, itemcallnumber, title, author, biblio.biblionumber, datelastseen, publicationyear
            FROM items
            LEFT JOIN biblio ON items.biblionumber = biblio.biblionumber
            LEFT JOIN biblioitems on items.biblionumber = biblioitems.biblionumber
            WHERE barcode = ?'
            );
        $sth->execute($barcode);
        $data = $sth->fetchrow_hashref;
        $data->{datelastseen}=format_date($data->{datelastseen});
    }
    return $data;
}

=head2 GetItemsByCriteriaLocation

  $item = GetItemsByCriteriaLocation($branch,$location,$minlocation,$maxlocation);

Return items for given location criteria.
The return value is a hashref mapping item column
names to values.

=cut

sub GetItemsByCriteriaLocation {
    my ( $branch, $location, $callnumber_prefix, $callnumber_min, $callnumber_max, $callnumber_type ) = @_;
    my @results;
    
    $callnumber_prefix =~ s/[\s\.-]//g;
    $callnumber_min = int( $callnumber_min || 0 );
	$callnumber_max = int( $callnumber_max || 999999 );
    
    if ( $callnumber_type eq 'store_callnumber' ) {
    	my @itemnumbers = ();
		
		#Retrieve items to check that their callnumber is between min and max callnumber
		my $dbh = C4::Context->dbh;
		
		my $query = "SELECT itemnumber, 
							itemcallnumber
					 FROM items 
					 WHERE ExtractValue( more_subfields_xml, '//datafield[\@tag=\"999\"]/subfield[\@code=\"K\"]' ) = itemcallnumber 
					 		AND items.holdingbranch = ? AND items.location = ?";
		
		my $sth = $dbh->prepare( $query );
		$sth->execute( $branch, $location );
		
		my $rows = $sth->fetchall_arrayref({});
		foreach my $row ( @{$rows} ) {
		    my $itemnumber = @$row{'itemnumber'};
		    my $callnumber = @$row{'itemcallnumber'};
		    
		    my ( $base, $sequence, $rest ) =  C4::Callnumber::StoreCallnumber::GetBaseAndSequenceFromStoreCallnumber( $callnumber );
		    
		    if ( $base =~ m/^$callnumber_prefix/ && $sequence >= $callnumber_min && $sequence <= $callnumber_max ) {
		   		push( @itemnumbers, $itemnumber );
		    }
		}
		
		if ( @itemnumbers ) {
			$query = "SELECT itemnumber, location, holdingbranch, barcode, itemcallnumber, title, author, biblio.biblionumber, datelastseen, publicationyear
	            	  FROM items
	            	  LEFT JOIN biblio ON items.biblionumber = biblio.biblionumber
	            	  LEFT JOIN biblioitems on items.biblionumber = biblioitems.biblionumber 
	            	  WHERE itemnumber IN (".join(',', @itemnumbers).")";
			$sth = $dbh->prepare( $query );
			$sth->execute();
			
			while ( my $row = $sth->fetchrow_hashref ) {
		        $row->{datelastseen}=format_date($row->{datelastseen});
		        push @results, $row;
		    }
		}
    } else {
		my @itemnumbers = ();
		
		#Retrieve items to check that their callnumber is between min and max callnumber
		my $dbh = C4::Context->dbh;
		
		my $query = "SELECT itemnumber, 
							itemcallnumber
					 FROM items 
					 WHERE ExtractValue( more_subfields_xml, '//datafield[\@tag=\"999\"]/subfield[\@code=\"B\"]' ) = itemcallnumber 
					 		AND items.holdingbranch = ? AND items.location = ?";
		
		my $sth = $dbh->prepare( $query );
		$sth->execute( $branch, $location );
		
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
			$query = "SELECT itemnumber, location, holdingbranch, barcode, itemcallnumber, title, author, biblio.biblionumber, datelastseen, publicationyear
	            	  FROM items
	            	  LEFT JOIN biblio ON items.biblionumber = biblio.biblionumber
	            	  LEFT JOIN biblioitems on items.biblionumber = biblioitems.biblionumber 
	            	  WHERE itemnumber IN (".join(',', @itemnumbers).")";
			$sth = $dbh->prepare( $query );
			$sth->execute();
			
			while ( my $row = $sth->fetchrow_hashref ) {
		        $row->{datelastseen}=format_date($row->{datelastseen});
		        push @results, $row;
		    }
		}
    }

    return \@results;
}


1;
