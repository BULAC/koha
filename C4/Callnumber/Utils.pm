package C4::Callnumber::Utils;

##
# B10X : callnumber utils
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use C4::Context;
use C4::Utils::Constants;

#
# Declarations
#
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &IsItemInStore
        &IsItemInResStore
        &IsItemInFreeAccess
        &GetCallnumbers
        &GetLocation
        
        &GetPaddedAuthValues
    );
}

##
# Is item is free access
#
# $itemnumber : item id
# return : 1 if true, undef if false
##
sub IsItemInFreeAccess($) {
    
    # input args
    my $itemnumber = shift;
    
    my ($active_callnum, $store_callnum, $free_callnum) = GetCallnumbers($itemnumber);
    
    #
    # Item is in free access if active callnumber is free access callnumber
    #
    if ($active_callnum && $free_callnum && $active_callnum eq $free_callnum) {
        return 1;
    }
    
    return undef;
}

##
# Is item is store
#
# $itemnumber : item id
# return : 1 if true, undef if false
##
sub IsItemInStore($) {
    
    # input args
    my $itemnumber = shift;
    
    my ($active_callnum, $store_callnum, $free_callnum) = GetCallnumbers($itemnumber);
    
    #
    # Item is in store if active callnumber is store callnumber
    #
    if ($active_callnum && $store_callnum && $active_callnum eq $store_callnum) {
        return 1;
    }
    
    return undef;
}

##
# Is item is the store of reserve
#
# $itemnumber : item id
# return : 1 if true, undef if false
##
sub IsItemInResStore($) {
    
    # input args
    my $itemnumber = shift;
    
    # MAN 201
    my $item = C4::Items::GetItem($itemnumber);
    if ($RES_ITEM_TYPE eq $item->{'itype'}) {
        return 1;
    }
    # END MAN 201
    
    return undef;
}

##
# $itemnumber : item id
# return : active, store and free access callnumber
##
sub GetCallnumbers($) {
    
    # input args
    my $itemnumber = shift;
    
    my $active_callnum;
    my $store_callnum;
    my $free_callnum;
    
    my $biblionumber = C4::Biblio::GetBiblionumberFromItemnumber($itemnumber);
    if ($biblionumber) {
        my $item_record = C4::Items::GetMarcItem( $biblionumber, $itemnumber );
        if ($item_record) {
            my $item_field = $item_record->field( '995' ) || '';
            if ( $item_field ) {
                $active_callnum = $item_field->subfield( 'k' ) || ''; #Active Callnumber
                $store_callnum  = $item_field->subfield( 'K' ) || ''; #StoreCallnumber
                $free_callnum   = $item_field->subfield( 'B' ) || ''; #FreeAccessCallnumber
            }
        }
    }
    
    return ($active_callnum, $store_callnum, $free_callnum);
}

sub GetLocation($) {
    
    # input args
    my $itemnumber = shift;
    
    my $location;
    
    my $biblionumber = C4::Biblio::GetBiblionumberFromItemnumber($itemnumber);
    if ($biblionumber) {
        my $item_record = C4::Items::GetMarcItem( $biblionumber, $itemnumber );
        if ($item_record) {
            my $item_field = $item_record->field( '995' ) || '';
            if ( $item_field ) {
                $location = $item_field->subfield( 'e' ) || '';
            }
        }
    }
    
    return $location;
}

sub GetPaddedAuthValues {
    my ( $selected_value, $auth_values_name, $length ) = @_;
    my $first = 1;
    
    my $auth_values = C4::Koha::GetAuthorisedValues( $auth_values_name );
    my @auth_values_hash = ();
    foreach my $value ( @$auth_values ) {
        my %data;
        my $padded_value = sprintf( "%*s", -$length, $value->{'authorised_value'} );
        
        $data{"value"} = $padded_value;
        $data{"label"} = $value->{'lib'};
        $data{"selected"} = 'selected="selected"' if ($padded_value eq $selected_value) || ($selected_value eq '' && $first);
        push ( @auth_values_hash, \%data );
        
        $first = 0,
    }
    
    return @auth_values_hash;
}

1;
__END__