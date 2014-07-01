#!/usr/bin/perl

#
# B014
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
use CGI;
use C4::Context;

my $input   = new CGI;
my $type   = $input->param('type');
my $query   = $input->param('query');

binmode STDOUT, ":utf8";
print $input->header(-type => 'text/plain', -charset => 'UTF-8');

warn "TEST";
warn "query : $query";
warn "type = $type";

my $dbh = C4::Context->dbh;
if ($type eq 'zip') {
    my $sql = qq(SELECT city_name, city_zipcode 
                 FROM cities
                 WHERE city_zipcode LIKE ?
                 ORDER BY city_zipcode);
    my $sth = $dbh->prepare( $sql );
    $sth->execute("$query%");
    
     
    while ( my $rec = $sth->fetchrow_hashref ) {
        print "$rec->{'city_name'}\t$rec->{'city_zipcode'}\n" ;
    }
} elsif ($type eq 'country') {
    my $sql = qq(SELECT lib
                 FROM authorised_values
                 WHERE category='COUNTRY' and lib LIKE ?
                 ORDER BY lib);
                 
    my $sth = $dbh->prepare( $sql );
    $sth->execute("$query%");
    
     
    while ( my $rec = $sth->fetchrow_hashref ) {
        print "$rec->{'lib'}\n" ;
    }
}


