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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use warnings;
use CGI;

use C4::Context;
use C4::Output;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Koha;
use C4::Stack::Desk;

# this will be the script that chooses desk 

my $query = CGI->new();
my ( $template, $borrowernumber, $cookie ) = get_template_and_user({
    template_name   => "desk/selectdesk.tmpl",
    query           => $query,
    type            => "intranet",
    debug           => 1,
    authnotrequired => 0,
    flagsrequired   => { circulate => 'circulate_remaining_permissions' },
});

my $sessionID = $query->cookie("CGISESSID");
my $session = get_session($sessionID);

# try to get desk settings from http, fallback to userenv
my $desk   = $query->param('desk') || '';

# fallbacks for $desk after possible session updates

my $userenv_desk  = C4::Context->userenv->{'desk'}        || '';
my @updated;

# $session lddines here are doing the updating
if ($desk) {
    if (! $userenv_desk || $userenv_desk ne $desk ) {
        my $newdesk = GetDesk($desk);
        $template->param(LoginDeskname => $newdesk->{'deskname'});
        $template->param(LoginDeskcode => $newdesk->{'deskcode'});
        $session->param('deskname', $newdesk->{'deskname'});       # update sesssion in DB
        $session->param('desk',     $newdesk->{'deskcode'});       # update sesssion in DB
        push @updated, {
            updated_desk => 1,
                old_desk => $userenv_desk,
        };
    }
} else {
    $desk = $userenv_desk;  
}

$template->param(updated => \@updated) if (scalar @updated);

my @recycle_loop;
foreach ($query->param()) {
    $_ or next;                   # disclude blanks
    $_ eq "desk"     and next;  # disclude branch
    $_ eq "oldreferer" and next;  # disclude oldreferer
    push @recycle_loop, {
        param => $_,
        value => $query->param($_),
    };
}

my $referer =  $query->param('oldreferer') || $ENV{HTTP_REFERER};
$referer =~ /selectdesk\.pl/ and undef $referer;   # avoid sending them back to this same page.

if (scalar @updated) {
    # we updated something: quick redirect
    my $parameters = '?';
    foreach ($query->param()) {
	    $_ or next;                   # disclude blanks
	    if ($parameters ne '?') {
	    	$parameters = $parameters.'&'.$_.'='.$query->param($_);
	    } else {
	    	$parameters = $parameters.$_.'='.$query->param($_);
	    }
	}
    # redirect
    if ($referer) {
        print $query->redirect($referer.$parameters);
        exit;
	}
    print $query->redirect('/cgi-bin/koha/mainpage.pl');
    exit;
}

$template->param(
    referer      => $referer,
    recycle_loop => \@recycle_loop,
    desks_loop   => GetDesksLoop($desk),
);

output_html_with_http_headers $query, $cookie, $template->output;
