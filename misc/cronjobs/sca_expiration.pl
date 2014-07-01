#!/usr/bin/perl

# Progilone 2012
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

BEGIN {

    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Context;
use C4::Utils::Constants;
use C4::Spaces::SCA;
use C4::Dates qw/format_date/;
use Getopt::Long;

sub usage {
    print STDERR <<USAGE;
Usage: $0 [ -d DATE ]
  Retire le groupe Usagers dans le SCA à tous les usagers (borrowers) arrivant à expiration aujourd'hui et dont la colonne sca_enrolled_by vaut INALCO.
  Si on précise une date via l'option -d (format AAAA-MM-JJ), on utilise cette date à la place de la date du jour
USAGE
    exit $_[0];
}

my ( $date, $help );

GetOptions(
    'd|date=s' => \$date,
    'h|help' => \$help,
);

usage( 0 ) if ( $help );

if (not defined $date) {
    $date = C4::Dates->today('iso');
}

DelScaExpiredUserINALCO($date);