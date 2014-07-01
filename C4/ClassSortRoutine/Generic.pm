package C4::ClassSortRoutine::Generic;

# Copyright (C) 2007 LibLime
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

use C4::Utils::Constants;

use vars qw($VERSION);

# set the version for version checking
$VERSION = 3.00;

=head1 NAME 

C4::ClassSortRoutine::Generic - generic call number sorting key routine

=head1 SYNOPSIS

use C4::ClassSortRoutine;

my $cn_sort = GetClassSortKey('Generic', $cn_class, $cn_item);

=head1 FUNCTIONS

=head2 get_class_sort_key

  my $cn_sort = C4::ClassSortRoutine::Generic::Generic($cn_class, $cn_item);

=cut

sub get_class_sort_key {
    my $cn_class = shift;
    my $cn_itemcallnumber = shift;
    my $cn_itemnumber = shift || undef;
    
    my $key;
    
    if ( defined $cn_itemcallnumber ) {
        if ( C4::Callnumber::Utils::IsItemInStore( $cn_itemnumber ) ) {
            if ( C4::Callnumber::StoreCallnumber::IsRetroCallnumber( $cn_itemcallnumber ) ) {
                my ( $base, $sequence, $rest ) =  C4::Callnumber::StoreCallnumber::GetBaseAndSequenceFromStoreCallnumber( $cn_itemcallnumber, 0 );
                $base = substr sprintf("%-*s", 16, $base), 0, 16;
                $sequence = sprintf("%0*d", 7, $sequence);
                $rest = substr sprintf("%-*s", 7, $rest), 0, 7;
                $key = $base . $sequence . $rest;
            } else {
                #Remove intercalate space between elements as the maximum size is 30
                my ( $branch, $mention, $type, $format, $number ) = C4::Callnumber::StoreCallnumber::StoreCallnumberCut( $cn_itemcallnumber );
                
                $branch  = sprintf( "%-*s", $BRANCH_LEN - 1,  $branch );
                $mention = sprintf( "%-*s", $MENTION_LEN - 1, $mention );
                $type    = sprintf( "%-*s", $TYPE_LEN - 1,    $type );
                $format  = sprintf( "%-*s", $FORMAT_LEN - 1,  $format );
                $number  = sprintf( "%0*s", $NUMBER_LEN,      $number );
                
                $key = $branch . $mention . $type . $format . $number;
            }
        } else {
            if ( C4::Callnumber::FreeAccessCallnumber::IsFreeInputCallnumber( $cn_itemcallnumber) ) {
                $key = $cn_itemcallnumber;
            } else {
                my ( $geo_index, $classification, $complement, $volume ) = C4::Callnumber::FreeAccessCallnumber::FreeAccessCallnumberCut( $cn_itemcallnumber );
                
                if ( C4::Callnumber::FreeAccessCallnumber::IsSerialCallnumber( $cn_itemcallnumber ) ) {
                    my ( $base_complement, $number ) = C4::Callnumber::FreeAccessCallnumber::CutSerialComplement( $complement );
                    $base_complement  = sprintf( "%-*s", $SERIAL_COMPLEMENT_LEN,  $base_complement );
                    $number  = sprintf( "%0*s", $SERIAL_NUMBER_LEN - 1, $number );
                    $complement = $base_complement . $number;
                } else {
                    $complement = sprintf( "%-*s", $COMPLEMENT_LEN - 1, $complement );
                }
                
                $geo_index      = sprintf( "%-*s", $GEO_INDEX_LEN - 1,      $geo_index );
                $classification = sprintf( "%-*s", $CLASSIFICATION_LEN - 1, $classification );
                $volume         = sprintf( "%0*s", $VOLUME_LEN,             $volume );
                
                $key = $geo_index . $classification . $complement . $volume;
            }
        }
    } else {
        $key = uc "$cn_class $cn_itemcallnumber";
        $key =~ s/\s+/_/;
        $key =~ s/[^A-Z_0-9]//g;
    }
    
    return $key;
}

1;

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

