#! /usr/bin/perl

##
# B06 - Temporary items
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
use C4::Context;
use C4::Auth qw(:DEFAULT get_session);
use C4::Output;
use C4::Stack::StackItemsTemp;

#
# Build output
#
my $query = new CGI;

if (!C4::Context->userenv){
    my $sessionID = $query->cookie("CGISESSID");
    my $session = get_session($sessionID);
    if ($session->param('branch') eq 'NO_LIBRARY_SET'){
        # no branch set we can't return
        print $query->redirect("/cgi-bin/koha/circ/selectbranchprinter.pl");
        exit;
    }
    if ($session->param('desk') eq 'NO_DESK_SET'){
        # no branch set we can't return
        print $query->redirect("/cgi-bin/koha/desk/selectdesk.pl?oldreferer=/cgi-bin/koha/stack/search-items-temp.pl");
        exit;
    }
} 

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "stack/search-items-temp.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
        debug           => 1,
    }
);

my $op = $query->param('op');

# operation
if ( $op eq 'delete_confirm' ) {
    my $itemnumber = $query->param('itemnumber');
    my $error;
    
    # delete 
    if (CanDelStackItemsTemp($itemnumber)) {
        $error = DelStackItemsTempAndItem($itemnumber);
    }
    else {
        $error = 'forbiden_delete';
    }
    # special case in DelItemCheck, 1 means no error
    if ($error eq '1') {
        $error = '';
    }
    
    $template->param(
        asked_itemnumber => $itemnumber,
        error            => $error,
    );
}

my $itemLoop = GetStackItemsTemp();
	
#
# Set params to template
#
$template->param(
    itemLoop    => $itemLoop,
);

#
# Print the page
#
output_html_with_http_headers $query, $cookie, $template->output;
