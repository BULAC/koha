#! /usr/bin/perl

##
# B034 : Cancel a stack request
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
use C4::Auth;
use C4::Stack::Rules qw(CanCancelRequestStack);
use C4::Stack::Manager qw(CancelStackRequestFromOPAC);

#
# Template and logged in user
#

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
          template_name   => 'opac-user.tmpl',
          query           => $query,
          type            => 'opac',
          authnotrequired => 0,
          flagsrequired   => { borrow => 1 },
          debug           => 1,
    }
);

#
# Input params
#
my $request_number = $query->param('request_number') || '';
my $op             = $query->param('op') || '';

#
# Cancel stack request
#
if ($op && $request_number && CanCancelRequestStack($request_number)) {
	CancelStackRequestFromOPAC($request_number);
}

print $query->redirect("/cgi-bin/koha/opac-user.pl#opac-user-stacks");
