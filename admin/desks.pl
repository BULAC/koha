#!/usr/bin/perl
#
# Copyright (C) 2011 Progilone
# Copyright (C) 2015 BULAC
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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use Modern::Perl;
use CGI;
use C4::Output;			# contains gettemplate
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Branch;
use C4::Desks;

# Fixed variables
my $script_name = "/cgi-bin/koha/admin/desks.pl";

################################################################################
# Main loop....
my $input           = new CGI;
my $deskcode        = $input->param('deskcode');
my $branchcode      = $input->param('branchcode');
my $deskname        = $input->param('deskname');
my $deskdescription = $input->param('deskdescription');
my $op              = $input->param('op') || '';

my $branches = GetBranches;
my @branches = keys $branches;
my @branchloop;
foreach my $thisbranch (sort keys %$branches) {
    my $selected = 1 if $thisbranch eq $branchcode;
    my %row =(value => $thisbranch,
	      selected => $selected,
	      branchname => $branches->{$thisbranch}->{branchname},
	     );
    push @branchloop, \%row;
}


my ( $template, $borrowernumber, $cookie ) = get_template_and_user({
								    template_name   => "admin/desks.tt",
								    query           => $input,
								    type            => "intranet",
								    authnotrequired => 0,
								    flagsrequired   => { parameters => 'parameters_remaining_permissions'},
								    debug           => 1,});

$template->param(branchloop => \@branchloop);

$template->param(script_name => $script_name);
if ($op) {
    $template->param($op  => 1); # we show only the TMPL_VAR names $op
} else {
    $template->param(else => 1);
}

################## ADD_VALIDATE ##################################
# called by add_form, used to insert/modify data in DB
my $desk = {
	    'deskcode' => $deskcode,
	    'deskname'  => $deskname,
	    'deskdescription' => $deskdescription,
	    'branchcode' => $branchcode,
	   };
if ( $op eq 'add_validate' ) {
    if ( GetDesks($deskcode) ) {		# it's a modification
	ModDesk($desk);
    }
    else {
	AddDesk($desk);
    }
    print $input->redirect('desks.pl');
    exit;
}


output_html_with_http_headers $input, $cookie, $template->output;
