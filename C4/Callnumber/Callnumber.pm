package C4::Callnumber::Callnumber;

#
# Progilone B10: Callnumber
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
use C4::Biblio;
use C4::Branch;
use C4::Serials;
use C4::Utils::Constants;
use C4::Callnumber::StoreCallnumber;
use C4::Callnumber::FreeAccessCallnumber;
use C4::Callnumber::OlimpWS;
use C4::Callnumber::Utils;
use C4::Utils::String;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
	$VERSION = 3.2.0;
	require Exporter;
	@ISA    = qw(Exporter);
	@EXPORT = qw(
		&UpdateCallnumberrules
		&UpdateSerialCallnumberRule
		&GetCallnumberParts
	);
}

=head2 UpdateCallnumberrules

  $callnumber = UpdateCallnumberrules( $branch, $mention, $type, $format, $number );

Return the computed callnumber from the fields of the callnumber. 
Each field is padded to fit the max length of the field.

=cut

sub UpdateCallnumberrules {
	my ( $item, $itemnumber, $biblionumber ) = @_;
	
	my $dbh = C4::Context->dbh;
	my $query = '';
	my $sth;

	my $field = $item->field( '995' );
	my $subfieldk = $field->subfield( 'k' ) || ''; #Active Callnumber
	my $subfieldK = $field->subfield( 'K' ) || ''; #StoreCallnumber
	my $subfieldB = $field->subfield( 'B' ) || ''; #FreeAccessCallnumber

	#Retrieve value of item in the database	
	my $old_item      = C4::Items::GetMarcItem( $biblionumber, $itemnumber );
	my $old_field     = $old_item->field( '995' ) || '';
	my ( $old_subfieldk, $old_subfieldK, $old_subfieldB ) = ( '', '', '' );
	if ( $old_field ) {
		$old_subfieldk = $old_field->subfield( 'k' ) || ''; #Active Callnumber
		$old_subfieldK = $old_field->subfield( 'K' ) || ''; #StoreCallnumber
		$old_subfieldB = $old_field->subfield( 'B' ) || ''; #FreeAccessCallnumber
	}
	
    my $homeorholdingbranchreturn = C4::Context->preference('HomeOrHoldingBranchReturn') || 'homebranch';
    my $branchcode;
    
    if ( $homeorholdingbranchreturn eq 'homebranch' ) {
    	$branchcode = $field->subfield( 'b' );
    } else {
    	$branchcode = $field->subfield( 'c' );
    }
    
    my $branchdetail = GetBranchDetail($branchcode);
    if ( $branchdetail && $branchdetail->{'branchcallnumberauto'} ) {
	
		if ( length( $subfieldK ) == 0 || C4::Callnumber::StoreCallnumber::IsRetroCallnumber( $subfieldK ) ) {
			_updateOlimpEndCallnumber( $subfieldK, 1 );
		} elsif ( $subfieldK ne $old_subfieldK ) {
			my $callnumber = _updateStoreCallnumber( $itemnumber, $field );
			if ( $subfieldk eq $subfieldK ) {
				$field->update( 'k' => $callnumber );
				_updateOlimpEndCallnumber( $callnumber, 1 );
			}
		}
	
		if ( $subfieldB ne $old_subfieldB ) {
			my $callnumber = _updateFreeAccessCallnumber( $itemnumber, $field, $biblionumber );
			if ( $subfieldk eq $subfieldB ) {
				$field->update( 'k' => $callnumber );
				_updateOlimpEndCallnumber( $callnumber, 0 );
			}
    	}
    
    } else {
    	#Check if a callnumber has changed, if yes auto update the active callnumber if it does not match
    	if ($old_subfieldK ne $subfieldK && $subfieldk eq $old_subfieldK) {
    		$field->update( 'k' => $subfieldK );
    		_updateOlimpEndCallnumber( $subfieldK, 1 );
    	}
    	if ($old_subfieldB ne $subfieldB && $subfieldk eq $old_subfieldB) {
            $field->update( 'k' => $subfieldB );
            _updateOlimpEndCallnumber( $subfieldB, 0 );
        }
    }
	
	_saveOldCallnumber( $old_field, $field );
}

sub _updateStoreCallnumber {
	my ( $itemnumber, $field ) = @_;
	
	my $dbh = C4::Context->dbh;
	my $sth;
	my $query = '';
	
	my ( $branch, $mention, $type, $format, $number ) = C4::Callnumber::StoreCallnumber::StoreCallnumberCut( $field->subfield( 'K' ) );
	my ( $next_number, $message ) = C4::Callnumber::StoreCallnumber::FindNextNumber( $branch, $mention, $type, $format );
	
	if ( $next_number < 0 ) {
		warn $message;
		return '';
	}
	
	if ( $next_number == 0 ) {
		$next_number = $number;
		
		$query = 'SELECT number FROM callnumberrules WHERE branch = ? AND mention = ? AND type = ? AND format = ?';
		$sth = $dbh->prepare( $query );
		$sth->execute( $branch, $mention, $type, $format );
		
		my $row = $sth->fetchall_arrayref( {} );
		my $old_number = $row->[0]{'number'};
		if ( $next_number >= $old_number ) {
			#User defined number is bigger than next number in the callnumber rule
			#The next number is updated to keep the bigger number for this rule
			$query = 'UPDATE callnumberrules SET number = ? WHERE branch = ? AND mention = ? AND type = ? AND format = ?';
			$sth = $dbh->prepare( $query );
			$sth->execute( $next_number + 1, $branch, $mention, $type, $format );
		}
		
	} else {
		$query = 'UPDATE callnumberrules SET number = ? WHERE branch = ? AND mention = ? AND type = ? AND format = ?';
		$sth = $dbh->prepare( $query );
		$sth->execute( $next_number + 1, $branch, $mention, $type, $format );
	}
	
	my $callnumber = C4::Callnumber::StoreCallnumber::GenerateStoreCallnumber( $branch, $mention, $type, $format, $next_number );
	$field->update( 'K' => $callnumber );
	
	return $callnumber;
}

sub _updateFreeAccessCallnumberRules {
	my ( $geo_index, $base_complement ) = @_;
	
	my $dbh = C4::Context->dbh;
	my $sth;
	my $query = '';
	
	my $number = C4::Callnumber::FreeAccessCallnumber::FindNextSerialNumber( $geo_index, $base_complement );
    my $complement = C4::Callnumber::FreeAccessCallnumber::ComputeSerialComplement( $base_complement, $number );
        
	if ( $number eq ( ' ' * $SERIAL_NUMBER_LEN ) ) {
		$number = 2;
			
		$query = 'INSERT INTO callnumberrules (geo_index, complement, number) VALUES (?, ?, ?)';
		$sth = $dbh->prepare( $query );
		$sth->execute( $geo_index, $base_complement, $number );
			
	} else {
		$number = int( TrimStr( $number ) );
		
		$query = 'UPDATE callnumberrules SET number = ? WHERE geo_index = ? AND complement = ?';
		$sth = $dbh->prepare( $query );
		$sth->execute( $number + 1, $geo_index, $base_complement );
	}
	
	return $complement;
}

sub _updateFreeAccessCallnumber {
	my ( $itemnumber, $field, $biblionumber ) = @_;
	my $callnumber = '';
	
	if ( C4::Callnumber::FreeAccessCallnumber::IsFreeInputCallnumber( $field->subfield( 'B' ) ) ) {
		$callnumber = $field->subfield( 'B' );
	} else {
		my ( $geo_index, $classification, $complement, $volume ) = C4::Callnumber::FreeAccessCallnumber::FreeAccessCallnumberCut( $field->subfield( 'B' ) );
		
		if (C4::Callnumber::FreeAccessCallnumber::IsSerialCallnumber( $field->subfield( 'B' ) ) ) {
			my ( $base_complement, $number ) = C4::Callnumber::FreeAccessCallnumber::CutSerialComplement( $complement );
			
			#Check if item is attached to a serial
			my $subscriptions = GetSubscriptionsFromBiblionumber( $biblionumber );
			unless ( scalar @$subscriptions ) {
				$complement = _updateFreeAccessCallnumberRules( $geo_index, $base_complement )
			}
		}
		
		$callnumber = C4::Callnumber::FreeAccessCallnumber::GenerateFreeAccessCallnumber( $geo_index, $classification, $complement, $volume );
	}
	
	$field->update( 'B' => $callnumber );
	
	return $callnumber;
}

sub _saveOldCallnumber {
	my ( $old_field, $field ) = @_;

	if ( $old_field ) {
		my $old_subfieldk = $old_field->subfield( 'k' ) || '';
		my $old_subfieldB = $old_field->subfield( 'B' ) || '';
		my $old_subfieldK = $old_field->subfield( 'K' ) || '';
		my $subfieldk = $field->subfield( 'k' ) || '';
		my $subfieldB = $field->subfield( 'B' ) || '';
		my $subfieldK = $field->subfield( 'K' ) || '';

		if ( $subfieldk eq $old_subfieldk ) {
			#Callnumber has not changed
			return;
		}
		
		if ( $subfieldk eq $subfieldK ) {
			if ( $old_subfieldk eq $old_subfieldK ) {
				#new store callnumber and old callnumber was old store callnumber -> save old store callnumber
				_addValueToSubfield( $field, 'A', $old_subfieldK );
			} elsif ( $old_subfieldk eq $old_subfieldB ) {
				#new store callnumber and old callnumber was old free access callnumber -> save old free access callnumber
				_addValueToSubfield( $field, 'A', $old_subfieldB );
			} else {
				#the old callnumber is neither a store callnumber nor a free access callnumber, save it just in case ...
				_addValueToSubfield( $field, 'A', $old_subfieldk );
			}
		} elsif ( $subfieldk eq $subfieldB ) {
			if ( $old_subfieldk eq $old_subfieldK ) {
				#new free access callnumber and old callnumber was old store callnumber -> save old store callnumber
				_addValueToSubfield( $field, 'A', $old_subfieldk );
			} elsif ( $old_subfieldk eq $old_subfieldB ) {
				#new free access callnumber and old callnumber was old free access callnumber -> nothing to do
			} else {
				#the old callnumber is neither a store callnumber nor a free access callnumber, save it just in case ...
				_addValueToSubfield( $field, 'A', $old_subfieldk );
			}
		}
	}
}

sub _addValueToSubfield {
	my ( $field, $subfield_code, $value ) = @_;
	my $add_subfield = 1;

	my @subfields = $field->subfield( $subfield_code );
	foreach my $subfield ( @subfields ) {
		if ( $value eq $subfield ) {
			$add_subfield = 0;
			last;
		}
	}
	
	if ( $add_subfield ) {
		$field->add_subfields( $subfield_code => $value );
	}
}

sub UpdateSerialCallnumberRule {
	my ( $callnumber ) = @_;
	
	if ( $callnumber eq '' ) {
		return '';
	}
	
	my ( $geo_index, $classification, $complement, $volume ) = C4::Callnumber::FreeAccessCallnumber::FreeAccessCallnumberCut( $callnumber );
	my ( $base_complement, $number ) = C4::Callnumber::FreeAccessCallnumber::CutSerialComplement( $complement );
	
	$complement = _updateFreeAccessCallnumberRules( $geo_index, $base_complement );
	$callnumber = C4::Callnumber::FreeAccessCallnumber::GenerateFreeAccessCallnumber( $geo_index, $classification, $complement, $volume );
	
	return $callnumber;	
}

sub _updateOlimpEndCallnumber {
	
	my ( $callnumber, $isStoreCallnumber) = @_;
	
	my $useOLIMP = C4::Context->preference('UseOlimpLocation') || '';
    
    if ( $useOLIMP ) {
    	if ( $isStoreCallnumber ) {
    		C4::Callnumber::OlimpWS::UpdateStoreEndCallnumber( $callnumber );
    	} else {
    		C4::Callnumber::OlimpWS::UpdateFreeAccessEndCallnumber( $callnumber );
    	}
    }
    
}

sub GetCallnumberParts {
	my ( $itemnumber, $subscription_id, $subscription_location, $serialseq ) = @_;
	
	my ( $level, $geo, $classif, $cplt, $tome, $magasin ) = ( '', '', '', '', '', 0 );
	
	if ( $itemnumber ) {
		my ( $coteactive, $cotemagasin, $cotefree ) = GetCallnumbers( $itemnumber );
		
		# Active callnum is the store callnum
		if ( $coteactive eq $cotemagasin ) {
		    if ( C4::Callnumber::StoreCallnumber::IsRetroCallnumber( $cotemagasin ) ) {
		    	# it is a manullaly entered callnum, it can't be cut
		    } else {
		        my ($branch, $mention, $type, $format, $number) = C4::Callnumber::StoreCallnumber::StoreCallnumberCut( $cotemagasin );
		        $level   = $mention;
		        $geo     = $type;
		        $classif = $format;
		        $cplt    = $number; 
		        $magasin = 1;
		    }
		}
		# Active callnum is the free access callnum
		elsif ( $coteactive eq $cotefree ) {
		    if ( C4::Callnumber::FreeAccessCallnumber::IsFreeInputCallnumber( $cotefree ) ) {
		    	# it is a manullaly entered callnum, it can't be cut
		    } else {
		    	$level = GetLocation( $itemnumber );
		        ( $geo, $classif, $cplt, $tome ) = C4::Callnumber::FreeAccessCallnumber::FreeAccessCallnumberCut( $cotefree );
		        $magasin = 0;
		    }
		} else {
		}
	} elsif ( $subscription_id ) {
		my $coteserial = GetSubscription( $subscription_id )->{ 'callnumber' };
	
		if ( C4::Callnumber::FreeAccessCallnumber::IsSerialCallnumber( $coteserial ) ) {
			$level = $subscription_location;
			( $geo, $classif, $cplt, $tome ) = C4::Callnumber::FreeAccessCallnumber::FreeAccessCallnumberCut( $coteserial );
			$tome = $serialseq;
		}
	} else {
	}
	
	return ( $magasin, $level, $geo, $cplt, $classif, $tome );
}

1;
__END__