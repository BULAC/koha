#!/usr/bin/perl

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
#-----------------------------------

=head1 NAME

duplications_expired.pl  cron script to set duplications to state ANNULE if date_expiration = date_system.
                  Execute without options for help.

=cut

use strict;
use warnings;

BEGIN {

    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}
use C4::Context;
my $dbh = C4::Context->dbh();
my $query  = "
            UPDATE duplication
            SET state = 'ANNULEE', expirationdate = null
            WHERE expirationdate <= now()
        ";
        my $sth    = $dbh->prepare($query);
        $sth->execute();
$sth->finish;

