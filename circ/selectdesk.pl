#!/usr/bin/perl

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

use Modern::Perl;
use CGI qw ( -utf8 );

use C4::Context;
use C4::Output;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Koha;
use C4::Desks;

my $query = CGI->new();

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "circ/selectdesk.tt",
        query           => $query,
        type            => "intranet",
        debug           => 1,
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1, },
    }
);

my $sessionID = $query->cookie("CGISESSID");
my $session   = get_session($sessionID);

my $branch = $query->param('branch');
my $desks;
if ($branch) {
    $desks = GetDesks($branch);
}
else {
    $desks = GetDesks();
}
my $deskloop = [];
for my $desk (@$desks) {
    push @$deskloop, GetDesk($desk);
}

my $deskcode = $query->param('deskcode');

my $userenv_desk = C4::Context->userenv->{'desk'} || '';
my $updated = '';

if ($deskcode) {
    if ( !$userenv_desk or $userenv_desk ne $deskcode ) {
        my $desk = GetDesk($deskcode);
        $template->param( LoginDeskname => $desk->{'deskname'} );
        $template->param( LoginDeskcode => $desk->{'deskcode'} );
        $session->param( deskname => $desk->{'deskname'} );
        $session->param( deskcode => $desk->{'deskcode'} );
        $updated = 1;
    }
}
else {
    $deskcode = $userenv_desk;
}

$template->param( updated => \$updated );

unless ( $deskcode ~~ $desks ) {
    $deskcode = @$desks[0];
}

my $referer = $query->param('oldreferer') || $ENV{HTTP_REFERER};
if ($updated) {
    print $query->redirect( $referer || '/cgi-bin/koha/mainpage.pl' );
}

$template->param(
    referer  => $referer,
    deskloop => $deskloop,
);

output_html_with_http_headers $query, $cookie, $template->output;
