#! /usr/bin/perl

##
# B033 : Renew a stack request
##

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

use CGI;
use C4::Items qw/setItemWaitRenew/;

use C4::Auth;
use C4::Search;
use C4::Stack::Rules qw(CanRenewRequestStack);
use C4::Stack::Manager qw(RenewStackRequest);

#
# Build output
#
my $query = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "members/moremember.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { circulate => 1 },
        debug           => 1,
    }
);

my $desk_code = C4::Context->userenv->{'desk'};
        
my $op                      = $query->param('op') || '';
my $request_number          = $query->param('request_number') || '';
my $destination             = $query->param('destination') || '';
my $borrowernumber          = $query->param('borrowernumber') || '';
# all operations
my $store                   = $query->param('store') || '';
my $inp_barcode             = $query->param('inp_barcode') || '';

if ($op && $request_number) {
    #
    # Renew stack request
    #
    my $ignore_istate = $store ? 1 : undef;
    my $end_date_renewal = CanRenewRequestStack($request_number, undef, $ignore_istate);
    
    if ($end_date_renewal) {
        if ($store) {
            RenewStackRequest($request_number, undef, $end_date_renewal, 1, $desk_code);
        } else {
            RenewStackRequest($request_number, undef, $end_date_renewal);
        }
    }
}

if ( $destination eq 'allop' ){
    print $query->redirect("/cgi-bin/koha/stack/all-operations.pl?input=$inp_barcode");
}
elsif ( $destination eq 'circ' ){
    print $query->redirect("/cgi-bin/koha/circ/circulation.pl?borrowernumber=$borrowernumber#stacks"); #MAN123
}
else{
    print $query->redirect("/cgi-bin/koha/members/moremember.pl?borrowernumber=$borrowernumber#onstack"); #MAN123
}

