package C4::Callnumber::StoreCallnumber;

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

use C4::Context;
use C4::Koha;
use C4::Callnumber::Utils;
use C4::Utils::String;
use C4::Utils::Constants;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
	$VERSION = 3.2.0;
	require Exporter;
	@ISA    = qw(Exporter);
	@EXPORT = qw(
		&GenerateStoreCallnumber
		&IsRetroCallnumber
		&StoreCallnumberCut
		&FindNextNumber
		&FormatStoreCallnumberFields
		&GetTypeAuthValues
		&GetFormatAuthValues
		&GetBranchValues
		&CanChooseNumber
		&GetBaseAndSequenceFromStoreCallnumber
	);
}

my $TOTAL_LENGTH = $BRANCH_LEN + $MENTION_LEN + $TYPE_LEN + $FORMAT_LEN + $NUMBER_LEN;

=head2 GenerateStoreCallnumber

  $callnumber = GenerateStoreCallnumber($branch, $mention, $type, $format, $number);

Return the computed callnumber from the fields of the callnumber. 
Each field is padded to fit the max length of the field.

=cut

sub GenerateStoreCallnumber {
    my ( $branch, $mention, $type, $format, $number ) = @_;
    ( $branch, $mention, $type, $format, $number ) = FormatStoreCallnumberFields( $branch, $mention, $type, $format, $number );
    
    my $callnumber = "$branch$mention$type$format$number";
    
    return $callnumber;
}

sub IsRetroCallnumber {
	my ( $callnumber ) = @_;
	
	if ( length( TrimStr( $callnumber ) ) == 0) {
		return 0;
	}
	
	if ( length( $callnumber ) > $TOTAL_LENGTH ) {
		return 1;
	}
	
	my ( $branch, $mention, $type, $format, $number ) = StoreCallnumberCut( $callnumber );
	
	if ( !_findBranchValue( $branch ) ) {
		warn 'branch --'.$branch.'-- not found';
		return 1;
	}
	if ( !_findTypeValue( $type ) ) {
		warn 'type --'.$type.'-- not found';
        return 1;
    }
    if ( TrimStr( $format ) ne '' && !_findFormatValue( $format ) ) {
    	warn 'format --'.$format.'-- not found';
        return 1;
    }
	
	return 0;
}

sub StoreCallnumberCut {
	my ( $callnumber ) = @_;
	
	if ( length( $callnumber ) < $TOTAL_LENGTH ) {
		$callnumber = sprintf( "%*s", -$TOTAL_LENGTH, $callnumber );
	} 
	
	my $branch  = TrimStr( substr( $callnumber, 0, $BRANCH_LEN ) );
    my $mention = TrimStr( substr( $callnumber, $BRANCH_LEN, $MENTION_LEN ) );
    my $type    = TrimStr( substr( $callnumber, $BRANCH_LEN + $MENTION_LEN, $TYPE_LEN ) );
    my $format  = TrimStr( substr( $callnumber, $BRANCH_LEN + $MENTION_LEN + $TYPE_LEN, $FORMAT_LEN ) );
    my $number  = TrimStr( substr( $callnumber, $BRANCH_LEN + $MENTION_LEN + $TYPE_LEN + $FORMAT_LEN, $NUMBER_LEN ) );
    
    return ( $branch, $mention, $type, $format, $number );
}

sub FindNextNumber {
	my ( $branch, $mention, $type, $format ) = @_;
	( $branch, $mention, $type, $format,  ) = FormatStoreCallnumberFields( $branch, $mention, $type, $format, 0 );
	
	my $number  = 0;
	my $error = 0;
	
	my $dbh = C4::Context->dbh;
	my $query = 'SELECT number, auto, active FROM callnumberrules WHERE branch = ? AND mention = ? AND type = ? AND format = ?';
	my $sth = $dbh->prepare( $query );
	$sth->execute( $branch, $mention, $type, $format );
	
	my $row = $sth->fetchall_arrayref({});
	if ( $row->[0] ) {
		if ( $row->[0]{'auto'} && $row->[0]{'active'}) {
			$number = $row->[0]{'number'};
		} elsif ( $row->[0]{'active'} ) {
			$number = 0;
		} else {
			#This callnumber rule is not active.
			$number = -1;
			$error = 1;
		}
	} else {
		#This callnumber rule does not exist.
		$number = -1;
		$error = 2;
	}

	return ( $number, $error );
}

sub FormatStoreCallnumberFields {
	my ( $branch, $mention, $type, $format, $number ) = @_;
    
	$branch  = sprintf( "%*s", -$BRANCH_LEN,  TrimStr( $branch ) );
	$mention = sprintf( "%*s", -$MENTION_LEN, TrimStr( $mention ) );
	$type    = sprintf( "%*s", -$TYPE_LEN,    TrimStr( $type ) );
	$format  = sprintf( "%*s", -$FORMAT_LEN,  TrimStr( $format ) );
	$number  = sprintf( "%*s", -$NUMBER_LEN,  TrimStr( $number ) );
	
	return ( $branch, $mention, $type, $format, $number );
}

sub GetTypeAuthValues {
	my ( $selected_value, $use_default ) = @_;
	
	$selected_value = sprintf( "%*s", -$TYPE_LEN, $selected_value );
	my $empty_value = sprintf( "%*s", $TYPE_LEN, '');
	if ( $selected_value eq $empty_value && $use_default ) {
		$selected_value = 'MON   ';
	}
	
	return GetPaddedAuthValues( $selected_value, "BUL_TYPDOC", $TYPE_LEN );
}

sub GetFormatAuthValues {
	my ( $selected_value, $use_default ) = @_;
	
	$selected_value = sprintf( "%*s", -$FORMAT_LEN, $selected_value );
	my $empty_value = sprintf( "%*s", $FORMAT_LEN, '');
	if ( $selected_value eq $empty_value && $use_default ) {
		$selected_value = '';
	}
	
	return GetPaddedAuthValues( $selected_value, "BUL_FORMAT", $FORMAT_LEN );
}

sub GetBranchValues {
	my ( $selected_branch, $use_default ) = @_;
	
	$selected_branch = sprintf( "%*s", -$BRANCH_LEN, $selected_branch );
	my $empty_value = sprintf( "%*s", $BRANCH_LEN, '');
	if ( $selected_branch eq $empty_value && $use_default ) {
		$selected_branch = 'BULAC';
	}
	
	my $dbh = C4::Context->dbh;
	my $query = 'SELECT branchcode, branchname FROM branches ORDER BY branchname';
	my $sth = $dbh->prepare( $query );
	$sth->execute();
	
	my @branch_data;
	my $results = $sth->fetchall_arrayref( {} );
	my $count = scalar( @$results );
	for ( my $i=0; $i < $count; $i++ ){
		my $padded_value = sprintf( "%*s", -$BRANCH_LEN, $results->[$i]{'branchcode'} );
		push @branch_data, {
			'value'    => $padded_value,
			'label'    => $results->[$i]{'branchname'},
			'selected' => TrimStr($results->[$i]{'branchcode'} ) eq TrimStr( $selected_branch ) ? 'selected=\'selected\'' : '',
		};
	}
	
	return @branch_data;
}

sub CanChooseNumber {
	my ( $branch, $mention, $type, $format, $number ) = @_;
	my $callnumber = GenerateStoreCallnumber( $branch, $mention, $type, $format, $number );
	
	my $dbh = C4::Context->dbh;
	my $query = 'SELECT COUNT(*) FROM items WHERE itemcallnumber = ?';
	my $sth = $dbh->prepare( $query );
	$sth->execute( $callnumber );
	
	my $canChooseNumber = int( $sth->fetchrow );
	if ( $canChooseNumber ) {
		#There is already an item with this callnumber
		return ( 0, 'There is already an item with this callnumber. Please choose another sequence number.' );
	} else {
		return ( 1, '' );
	}
}

sub GetBaseAndSequenceFromStoreCallnumber {
	my ( $callnumber, $removeBranch ) = @_;
	
	my $regexp = '([\w\s\.-]+)[\s\.-](\d+)[\s\.-]?(\s*\([\w\s]*\))*';
	if ( $removeBranch ) {
		$regexp = '[\w]\s([\w\s\.-]+)[\s\.-](\d+)[\s\.-]?(\s*\([\w\s]*\))*';
	}
	
	if ( $callnumber =~ m/$regexp/ ) {
		my $base = $1;
		my $sequence = $2;
		my $rest = $3;
		
		$base =~ s/[\s\.-]//g;
		
		return ($base, $sequence, $rest);
	} else {
		return  (undef, undef, undef);
	}

}

sub _findBranchValue {
	my ( $branch ) = @_;
	
	my $dbh = C4::Context->dbh;
    my $query = 'SELECT COUNT(*) FROM branches WHERE branchcode = ?';
    my $sth = $dbh->prepare( $query );
    $sth->execute( TrimStr( $branch ) );
    
    return int( $sth->fetchrow );
}

sub _findTypeValue {
    my ( $type ) = @_;
    
    my $dbh = C4::Context->dbh;
    my $query = 'SELECT COUNT(*) FROM authorised_values WHERE category = ? AND authorised_value = ?';
    my $sth = $dbh->prepare( $query );
    $sth->execute( "BUL_TYPDOC", TrimStr( $type ) );
    
    return int( $sth->fetchrow );
}

sub _findFormatValue {
    my ( $format ) = @_;
    
    my $dbh = C4::Context->dbh;
    my $query = 'SELECT COUNT(*) FROM authorised_values WHERE category = ? AND authorised_value = ?';
    my $sth = $dbh->prepare( $query );
    $sth->execute( "BUL_FORMAT", TrimStr( $format ) );
    
    return int( $sth->fetchrow );
}

1;
__END__