package C4::Callnumber::OlimpWS;

#
# Progilone B10: FreeAccessCallnumber
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

use C4::Context;
use SOAP::Lite;

use C4::Callnumber::StoreCallnumber;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    $VERSION = 3.2.0;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &GetStoreLocation
        &GetFreeAccessLocation
        &FindLocationAndAddress
        &UpdateStoreEndCallnumber
        &UpdateFreeAccessEndCallnumber
    );
}

my $ws_hostname  = C4::Context->preference('UseOlimpLocation') || '';
my $ws_address   = $ws_hostname.'/OLIMP-ear-OLIMP-ejb/BatchLocationWS';
my $ws_namespace = 'http://webservice.olimp.progilone.com/';
my $ws_prefix    = 'olimp';

sub GetStoreLocation {
    my ( $callnumber ) = @_;
    
    my $location = '';
    my $address = '';
    
    eval {
        my ( $base, $sequence, $rest ) = C4::Callnumber::StoreCallnumber::GetBaseAndSequenceFromStoreCallnumber( $callnumber, 1 );
        
        if ( $base ) {
	        my $ws_method = 'getStoreBatchLocation';
	        my @args = ();
	        push( @args, SOAP::Data->name( 'base' => $base ) );
	        push( @args, SOAP::Data->name( 'sequence' => $sequence ) );
	        
	        my $soap = SOAP::Lite
	            ->uri($ws_namespace)
	            ->ns($ws_namespace, $ws_prefix)
	            ->on_action(sub { "$ws_namespace/$ws_method" } )
	            ->proxy($ws_address);
	        
	        my $result = $soap->call($ws_method => @args)->result;
	        
	        ( $location, $address ) = _formatResult( $result );
        } else {
        	( $location, $address ) = ( undef, 'InvalidCallnumber' );
        }
    };
    
    return ( $location, $address );
}

sub GetFreeAccessLocation {
    my ( $callnumber ) = @_;
    
    my $location = '';
    my $address = '';
    
    eval {
        my $ws_method = 'getFreeAccessBatchLocation';
        my @args = ();
        push( @args, SOAP::Data->name( 'callnumber' => $callnumber ) );
        
        my $soap = SOAP::Lite
            ->uri($ws_namespace)
            ->ns($ws_namespace, $ws_prefix)
            ->on_action(sub { "$ws_namespace/$ws_method" } )
            ->proxy($ws_address);
        
        my $result = $soap->call($ws_method => @args)->result;
        
        my ( $location, $address ) = _formatResult( $result );
    };
    return ( $location, $address );
}

sub FindLocationAndAddress {
    my ( $callnumber, $freeAccessCallnumber, $storeCallnumber ) = @_;
    
    my $location = undef;
    my $address = '';
    
    if ( $callnumber ne '' ) {
        if ( $callnumber eq $storeCallnumber ) {
            ( $location, $address ) = GetStoreLocation( $callnumber );
        } elsif ( $callnumber eq $freeAccessCallnumber ) {
            ( $location, $address ) = GetFreeAccessLocation( $callnumber );
        }
    }
    
    return ( $location, $address );
}

sub _formatResult {
    my ( $result ) = @_;
    
    if ( $result eq '' || $result eq 'NotFound' || $result eq 'NoLocalisation' ) {
        return ( undef, $result );
    }
    
    my ( $location, $address ) = split(/-/, $result, 2);
    return ( $location, $address );
}

sub UpdateStoreEndCallnumber {
    my ( $callnumber ) = @_;
    
    eval {
        my ( $base, $sequence, $rest ) = C4::Callnumber::StoreCallnumber::GetBaseAndSequenceFromStoreCallnumber( $callnumber, 1 );
        
        if ( $base ) {
	        my $ws_method = 'updateStoreEndCallnumber';
	        my @args = ();
	        push( @args, SOAP::Data->name( 'base' => $base ) );
	        push( @args, SOAP::Data->name( 'sequence' => $sequence ) );
	        
	        my $soap = SOAP::Lite
	            ->uri($ws_namespace)
	            ->ns($ws_namespace, $ws_prefix)
	            ->on_action(sub { "$ws_namespace/$ws_method" } )
	            ->proxy($ws_address);
	        
	        $soap->call($ws_method => @args)->result;
        }
    };
}

sub UpdateFreeAccessEndCallnumber {
    my ( $callnumber ) = @_;
    
    my $location = '';
    my $address = '';
    
    eval {
        my $ws_method = 'updateFreeAccessEndCallnumber';
        my @args = ();
        push( @args, SOAP::Data->name( 'callnumber' => $callnumber ) );
        
        my $soap = SOAP::Lite
            ->uri($ws_namespace)
            ->ns($ws_namespace, $ws_prefix)
            ->on_action(sub { "$ws_namespace/$ws_method" } )
            ->proxy($ws_address);
        
        my $result = $soap->call($ws_method => @args)->result;
        
        my ( $location, $address ) = _formatResult( $result );
    };
    return ( $location, $address );
}

1;
__END__