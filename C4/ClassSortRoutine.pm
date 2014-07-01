package C4::ClassSortRoutine;

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

require Exporter;
use Class::Factory::Util;
use C4::Context;
use C4::Koha;
use C4::Utils::Constants;
use C4::Callnumber::FreeAccessCallnumber;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# set the version for version checking
$VERSION = 3.00;

=head1 NAME 

C4::ClassSortRoutine - base object for creation of classification sorting
                       key generation routines

=head1 SYNOPSIS

use C4::ClassSortRoutine;

=head1 FUNCTIONS

=cut

@ISA    = qw(Exporter);
@EXPORT = qw(
   &GetSortRoutineNames
   &GetClassSortKey
);

# intialization code
my %loaded_routines = ();
my @sort_routines = GetSortRoutineNames();
foreach my $sort_routine (@sort_routines) {
    if (eval "require C4::ClassSortRoutine::$sort_routine") {
        my $ref;
        eval "\$ref = \\\&C4::ClassSortRoutine::${sort_routine}::get_class_sort_key";
        if (eval "\$ref->(\"a\", \"b\")") {
            $loaded_routines{$sort_routine} = $ref;
        } else {
            $loaded_routines{$sort_routine} = \&_get_class_sort_key;
        }
    } else {
        $loaded_routines{$sort_routine} = \&_get_class_sort_key;
    }
}

=head2 GetSortRoutineNames

  my @routines = GetSortRoutineNames();

Get names of all modules under C4::ClassSortRoutine::*.  Adding
a new classification sorting routine can therefore be done 
simply by writing a new submodule under C4::ClassSortRoutine and
placing it in the C4/ClassSortRoutine directory.

=cut

sub GetSortRoutineNames {
    return C4::ClassSortRoutine->subclasses();
}

=head2  GetClassSortKey

  my $cn_sort = GetClassSortKey($sort_routine, $cn_class, $cn_item);

Generates classification sorting key.  If $sort_routine does not point
to a valid submodule in C4::ClassSortRoutine, default to a basic
normalization routine.

=cut

sub GetClassSortKey($$$;$) {
	my $sort_routine = shift;
    my $cn_class = shift;
    my $cn_item = shift;
    my $cn_itemnumber = shift || undef;
    
    unless (exists $loaded_routines{$sort_routine}) {
        warn "attempting to use non-existent class sorting routine $sort_routine\n";
        $loaded_routines{$sort_routine} = \&_get_class_sort_key;
    }
    my $key = $loaded_routines{$sort_routine}->($cn_class, $cn_item, $cn_itemnumber);
    # FIXME -- hardcoded length for cn_sort
    # should replace with some way of getting column widths from
    # the DB schema -- since doing this should ideally be
    # independent of the DBMS, deferring for the moment.
    return substr($key, 0, 30);
}

=head2 _get_class_sort_key 

Basic sorting function.  Concatenates classification part 
and item, converts to uppercase, changes each run of
whitespace to '_', and removes any non-digit, non-latin
letter characters.

=cut

#sub _get_class_sort_key {
#    my ($cn_class, $cn_item) = @_;
#    my $key = uc "$cn_class $cn_item";
#    $key =~ s/\s+/_/;
#    $key =~ s/[^A-Z_0-9]//g;
#    return $key;
#}

sub _get_class_sort_key($$;$) {
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
	    	if ( IsFreeInputCallnumber( $cn_itemcallnumber) ) {
	    		$key = $cn_itemcallnumber;
	    	} else {
	    		my ( $geo_index, $classification, $complement, $volume ) = FreeAccessCallnumberCut( $cn_itemcallnumber );
	    		
	    		if ( IsSerialCallnumber( $cn_itemcallnumber ) ) {
	    			my ( $base_complement, $number ) = CutSerialComplement( $complement );
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

