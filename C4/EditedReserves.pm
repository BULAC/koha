package C4::EditedReserves;

# Copyright   2017 BULAC
#
# This file is part of Koha.
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


use strict;
#use warnings; FIXME - Bug 2505
use C4::Context;
use C4::Biblio;
use C4::Members;
use C4::Items;
use C4::Circulation;
use C4::Accounts;
use C4::Reserves;

# for _koha_notify_reserve
use C4::Members::Messaging;
use C4::Members qw();
use C4::Letters;
use C4::Log;
use C4::Desks;

use Koha::DateUtils;
use Koha::Calendar;
use Koha::Database;
use Koha::Hold;
use Koha::Old::Hold;
use Koha::Holds;
use Koha::Libraries;
use Koha::IssuingRules;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Patrons;

use List::MoreUtils qw( firstidx any );
use Carp;
use Data::Dumper;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

=head1 NAME

C4::EditedReserves - Koha functions for dealing with edited reservation.

=head1 SYNOPSIS

  use C4::EditedReserves;

=head1 DESCRIPTION

This modules provides somes functions to deal with edited reservations.

=cut

BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw(
    EditReserves
    ListReservesByStatus
    ModResStatusByResID
    );
    @EXPORT_OK = qw( MergeHolds );
}


=head2 EditReserves

    my $EditedCount = EditReserves( $branchcode, $deskcode );

    Changes the status for a reservation from ask (A) to edited (E),
    depending on desk setted.

    Returns -1 or -2 on SQL errors. Returns number of edited reserves
    otherwise.

=cut

sub EditReserves {
    my $branchcode = shift;
    my $deskcode   = shift;
    my $itypes = GetDeskItypes($deskcode);
    my $query = 'SELECT reserve_id, itemnumber, borrowernumber FROM reserves WHERE found ="A" AND branchcode = ?';
    my $sth = C4::Context->dbh->prepare($query);
    my $ret = $sth->execute($branchcode);
    return -1 if (! defined $ret);
    my $EditedCount = 0;
    my $EditedReserves = [];
    while (my $row = $sth->fetchrow_arrayref ) {
        my $reserve_id = $row->[0];
	my $itemnumber = $row->[1];
	my $borrowernumber = $row->[2];
	my $itemquery = 'SELECT itype, ccode FROM items WHERE itemnumber = ?';
	my $itemsth = C4::Context->dbh->prepare($itemquery);
	return -2 if (! defined $itemsth->execute($itemnumber));
	my $itype = $itemsth->fetchall_arrayref->[0][0];
	my $ccode = $itemsth->fetchall_arrayref->[1][0];
	if ((grep {/^$itype$/} @{ $itypes }) || $itype eq '') {
	    ModReserveAffect( $itemnumber, $borrowernumber, '', $deskcode);
	    ModResStatusByResID($reserve_id, 'E');
	    $EditedCount++;
	    push @$EditedReserves, $reserve_id;
	    use C4::Stats;
	    UpdateStats (
	    {
		branch             => $branchcode,
		type               => 'editedreserve',
		borrowernumber     => $borrowernumber,
		associatedborrower => $reserve_id,
		itemnumber         => $itemnumber,
		itemtype           => $itype,
		ccode              => $ccode,
	    }
	    );
	}
    }
    return ($EditedCount, $EditedReserves);
}

=head2 ListReservesByStatus

    my $reserves_arrayref = ListReservesByStatus( $status);

    List all reserves whith given $status.

    Return an array ref with all given reserve as a hashref.

=cut

sub ListReservesByStatus {
    my $status = shift;
    my $branchcode = shift || '';
    die "Usage: ListReservesByStatus(\$status, [$branchcode])" unless ($status);
    my $query = "SELECT * FROM reserves WHERE found = ?";
    $query = $query . " AND branchcode = ?"
	if ($branchcode);
    my $sth = C4::Context->dbh->prepare($query);
    ($branchcode) ?
	$sth->execute($status, $branchcode) : $sth->execute($status);
    my $res = [];
    while (my $row = $sth->fetchrow_hashref) {
	push @{ $res }, $row;
    }
    return $res;
}

=head2 ModResStatusByResID

  ModReserveStatus($reserve_id, $newstatus);

Update the reserve status for the reserve.

$reserve_id is the reserve id the reserve is on

$newstatus is the new status.

=cut

sub ModResStatusByResID {

    #first : check if we have a reservation for this item .
    my ($reserve_id, $newstatus) = @_;
    my $dbh = C4::Context->dbh;

    #    my $query = "UPDATE reserves SET found = ?, waitingdate = NOW() WHERE itemnumber = ? AND (found IS NULL OR found = 'A') AND (priority = 0 OR found = 'A')";
        my $query = "UPDATE reserves SET found = ?, waitingdate = NOW() WHERE reserve_id = ?";
    my $sth_set = $dbh->prepare($query);
    $sth_set->execute( $newstatus, $reserve_id );

}

=head1 AUTHOR

BULAC <http://www.bulac.fr/>

=cut

1;
