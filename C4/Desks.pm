# This file is part of Koha.
#
# Copyright (C) 2011 Progilone
# Copyright (C) 2015 BULAC
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

package C4::Desks;

use Modern::Perl;

use C4::Context;
use vars qw(@ISA @EXPORT);

BEGIN {
    require Exporter;
    @ISA       = qw(Exporter);
    @EXPORT = qw(
		       &AddDesk
		       &ModDesk
		       &DelDesk
		       &GetDesk
		       &GetDesks
		  );
}

=head1 NAME

C4::Desks - Desk management functions

=head1 DESCRIPTION

This module contains an API for manipulating issue desks in Koha. It
is used by circulation.

=head1 HISTORICAL NOTE

Developped by Progilone on a customised Koha 3.2 for BULAC
library. The module is ported to Koha 3.19 and up by the BULAC.

=cut

=head2 AddDesk

  AddDesk({
    'deskcode'        => $deskcode,
    'deskname'        => $deskname,
    'deskdescription' => $deskdescription
    'branchcode'      => $branchcode });

  returns 1 on success, undef on error. A return value greater than 1
  or just -1 means something went wrong.

=cut

sub AddDesk {
    my ($args) = @_;
    C4::Context->dbh->do
	    ('INSERT INTO desks ' .
	     '(deskcode, deskname, deskdescription, branchcode) ' .
	     'VALUES (?,?,?,?)' ,
	     undef,
	     $args->{'deskcode'},
	     $args->{'deskname'},
	     $args->{'deskdescription'},
	     $args->{'branchcode'},
	    );
}

=head2 DelDesk

  DelDesk($deskcode)

  returns 1 on success, undef on error. A return value greater than 1
  or just -1 means something went wrong.

=cut

sub DelDesk {
    my $deskcode = shift;
    C4::Context->dbh->do
	    ('DELETE FROM desks WHERE deskcode = ?',
	     undef,
	     $deskcode
	    );
}

=head2 GetDesk

  $desk_href = GetDesk($deskcode);

  returns undef when no desk matches $deskcode, return a href
  containing desk parameters:
    {'deskcode' => $deskcode,
     'deskname' => $deskname,
     'deskdescription' => $deskdescription,
     'branchcode' => $branchcode }

=cut

sub GetDesk {
    my $deskcode = shift;
    my $query = '
        SELECT *
        FROM desks
        WHERE deskcode = ?';

    my $sth = C4::Context->dbh->prepare($query);
    $sth->execute($deskcode);
    $sth->fetchrow_hashref;
}

=head2 GetDesks

    $desk_aref = GetDesks([$branch])

    returns an array ref containing deskcodes. If no desks are
    available, the array is empty.

=cut

sub GetDesks  {
    my $branchcode   = shift || '';
    my $retaref = [];
    my $query = 'SELECT deskcode FROM desks';
    if ($branchcode) {
        $query = $query . ' WHERE branchcode = ?';
    }
    my $sth = C4::Context->dbh->prepare($query);
    if ($branchcode) {
	$sth->execute($branchcode);
    } else {
	$sth->execute();
    }
    while (my $rowaref = $sth->fetchrow_arrayref()) {
	push @{ $retaref }, $rowaref->[0];
    }
    return $retaref;
}

=head2 ModDesks

    $deskhref = {
       'deskcode' => $deskcode,
       'deskname' => $deskname,
       'deskdescription' => $deskdescription,
       'branchcode' => $branchcode
    }
    ModDesks($deskhref)

    Modify desk with $deskcode with values contained in various
    $deskhref fields. Returns 1 on success, 0 if no desk were
    modified, undef, -1 or an int greater than 1 if something went
    terribly wrong.

=cut

sub ModDesk {
    my ($args) = @_;
    C4::Context->dbh->do('UPDATE desks SET deskname = ? , ' .
			 'deskdescription = ? , ' .
			 'branchcode = ? ' .
			 'WHERE deskcode = ?' ,
			 undef,
			 $args->{'deskname'},
			 $args->{'deskdescription'},
			 $args->{'branchcode'},
			 $args->{'deskcode'}
			);
}

1;
