package C4::Callnumber::FreeAccessCallnumber;

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
use C4::Utils::Constants;

use C4::Callnumber::Utils;
use C4::Utils::String;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    $VERSION = 3.2.0;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &GenerateFreeAccessCallnumber
        &IsFreeInputCallnumber
        &IsSerialCallnumber
        &FreeAccessCallnumberCut
        &CutSerialComplement
        &FindNextSerialNumber
        &ComputeSerialComplement
        &FormatFreeAccessCallnumberFields
        &GetBaseAndSequenceFromFreeAccessCallnumber
        &IsSequenceBetweenMinMax
        &GetGeoIndexAuthValues
    );
}

my $TOTAL_LENGTH = $GEO_INDEX_LEN + $CLASSIFICATION_LEN + $COMPLEMENT_LEN + $VOLUME_LEN;

=head2 GetCallNumber

  $item = GetCallNumber($callnumber);

Return item information, for a given barcode.
The return value is a hashref mapping item column
names to values.

=cut

sub GenerateFreeAccessCallnumber {
    my ( $geo_index, $classification, $complement, $volume ) = @_;
    ( $geo_index, $classification, $complement, $volume ) = FormatFreeAccessCallnumberFields( $geo_index, $classification, $complement, $volume );
    
    my $callnumber = "$geo_index$classification$complement$volume";
    
    return $callnumber;
}

sub IsFreeInputCallnumber {
	my ( $callnumber ) = @_;
	
	if ( length( TrimStr( $callnumber ) ) == 0) {
		return 0;
	}
	
	if ( length( $callnumber ) > $TOTAL_LENGTH ) {
		return 1;
	}
	
	my ( $geo_index, $classification, $complement, $volume) = FreeAccessCallnumberCut( $callnumber );
	
	if ( !_findGeoIndexValue( $geo_index ) ) {
		warn 'geo_index --'.$geo_index.'-- not found';
        return 1;
    }
	
	return 0;
}

sub IsSerialCallnumber {
	my ( $callnumber ) = @_;
	my ( $geo_index, $classification, $complement, $volume ) = FreeAccessCallnumberCut( $callnumber );
	
	if ( TrimStr( $geo_index) eq '' && 
		 TrimStr( $classification) eq '' && 
		 TrimStr( $complement) eq '' && 
		 TrimStr( $volume) eq '') {
		return 0;
	}
	return ( $classification eq  '' );
}

sub FreeAccessCallnumberCut {
	my ( $callnumber ) = @_;
	
	if ( length( $callnumber ) < $TOTAL_LENGTH ) {
		$callnumber = sprintf( "%*s", -$TOTAL_LENGTH, $callnumber );
	} 
	
    my $geo_index      = TrimStr( substr( $callnumber, 0, $GEO_INDEX_LEN ) );
    my $classification = TrimStr( substr( $callnumber, $GEO_INDEX_LEN, $CLASSIFICATION_LEN ) );
    my $complement     = TrimStr( substr( $callnumber, $GEO_INDEX_LEN + $CLASSIFICATION_LEN, $COMPLEMENT_LEN ) );
    my $volume         = TrimStr( substr( $callnumber, $GEO_INDEX_LEN + $CLASSIFICATION_LEN + $COMPLEMENT_LEN, $VOLUME_LEN ) );
    
    return ( $geo_index, $classification, $complement, $volume );
}

sub CutSerialComplement {
	my ( $complement ) = @_;
	
	$complement = sprintf( "%*s", -$COMPLEMENT_LEN, $complement );
	#The first 5 characters are the actual complement and the last four characters are the sequence number
	return ( TrimStr( substr( $complement, 0, $SERIAL_COMPLEMENT_LEN ) ), 
			 TrimStr( substr( $complement, $SERIAL_COMPLEMENT_LEN, $SERIAL_NUMBER_LEN ) ) );
}

sub FindNextSerialNumber {
	my ( $geo_index, $complement ) = @_;
	$geo_index  = sprintf( "%*s", -$GEO_INDEX_LEN,         $geo_index );
	$complement = sprintf( "%*s", -$SERIAL_COMPLEMENT_LEN, $complement );
	
	my $number  = '';
	my $message = '';
	
	my $dbh = C4::Context->dbh;
	my $query = 'SELECT number FROM callnumberrules WHERE geo_index = ? AND complement = ?';
	my $sth = $dbh->prepare( $query );
	$sth->execute( $geo_index, $complement );
	
	my $row = $sth->fetchall_arrayref({});
	if ( $row->[0] ) {
		$number = $row->[0]{'number'};
	}
	
	$number = sprintf( "%*s", -$SERIAL_NUMBER_LEN, $number );

	return $number;
}

sub ComputeSerialComplement {
	my ( $base_complement, $number ) = @_;
	
	$base_complement = sprintf( "%*s", -$SERIAL_COMPLEMENT_LEN, $base_complement );
	$number = sprintf( "%*s", -$SERIAL_NUMBER_LEN, $number );
	
	return $base_complement.$number;
}

sub FormatFreeAccessCallnumberFields {
	my ( $geo_index, $classification, $complement, $volume ) = @_;
	
	$geo_index      = sprintf( "%*s", -$GEO_INDEX_LEN,      TrimStr( $geo_index ) );
	$classification = sprintf( "%*s", -$CLASSIFICATION_LEN, TrimStr( $classification ) );
	$complement     = sprintf( "%*s", -$COMPLEMENT_LEN,     TrimStr( $complement ) );
	$volume         = sprintf( "%*s", -$VOLUME_LEN,         TrimStr( $volume ) );
	
	return ( $geo_index, $classification, $complement, $volume );
}

sub GetBaseAndSequenceFromFreeAccessCallnumber {
	my ( $callnumber ) = @_;
	my ( $geo_index, $classification, $complement, $volume ) = FreeAccessCallnumberCut( $callnumber );
	
	$geo_index =~ s/[\s]//g;
	$classification =~ s/[\s]//g;
	
	return ( $geo_index, $classification );
}

sub IsSequenceBetweenMinMax {
	my ( $sequence, $callnumber_min, $callnumber_max ) = @_;
	
	my ( $sequence_nb, $sequence_other );
	if ( ( $sequence =~ tr/\.// ) > 0 ) {
		( $sequence_nb, $sequence_other ) = split( /\./, $sequence, 2 );
	} else {
		( $sequence_nb, $sequence_other ) = ( $sequence, '' );
	}
	
	my ( $callnumber_min_nb, $callnumber_min_other );
	if ( ( $callnumber_min =~ tr/\.// ) > 0 ) {
		( $callnumber_min_nb, $callnumber_min_other ) = split( /\./, $callnumber_min, 2 );
	} else {
		( $callnumber_min_nb, $callnumber_min_other ) = ( $callnumber_min, '' );
	}
	
	my ( $callnumber_max_nb, $callnumber_max_other );
	if ( ( $callnumber_max =~ tr/\.// ) > 0 ) {
		( $callnumber_max_nb, $callnumber_max_other ) = split( /\./, $callnumber_max, 2 );
	} else {
		( $callnumber_max_nb, $callnumber_max_other ) = ( $callnumber_max, '' );
	}
	
	$sequence_nb = int ( $sequence_nb );
	$callnumber_min_nb = int ( $callnumber_min_nb );
	$callnumber_max_nb = int ( $callnumber_max_nb );
	
	if ( $sequence_nb < $callnumber_min_nb || ( $sequence_nb == $callnumber_min_nb && $sequence_other lt $callnumber_min_other ) ) {
		return 0;
	}
	
	if ( $sequence_nb > $callnumber_max_nb || ( $sequence_nb == $callnumber_max_nb && $sequence_other gt $callnumber_max_other ) ) {
		return 0;
	}
	
	return 1;
}

sub GetGeoIndexAuthValues {
	my ( $selected_value ) = @_;
	
	$selected_value = sprintf( "%*s", -$GEO_INDEX_LEN, $selected_value );
	my $empty_value = sprintf( "%*s", $GEO_INDEX_LEN, '');
	if ( $selected_value eq $empty_value ) {
		$selected_value = '';
	}
	
	return GetPaddedAuthValues( $selected_value, "BULAC_GEO", $GEO_INDEX_LEN );
}

sub _findGeoIndexValue {
    my ( $geo_index ) = @_;
    
    my $dbh = C4::Context->dbh;
    my $query = 'SELECT COUNT(*) FROM authorised_values WHERE category = ? AND authorised_value = ?';
    my $sth = $dbh->prepare( $query );
    $sth->execute( "BULAC_GEO", TrimStr( $geo_index ) );
    
    return int( $sth->fetchrow );
}

1;
__END__