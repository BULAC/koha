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
use C4::Output;
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Branch;
use C4::Desks;

my $script_name = "/cgi-bin/koha/admin/desks.pl";

my $input           = new CGI;
my $deskcode        = $input->param('deskcode');
my $branchcode      = $input->param('branchcode');
my $deskname        = $input->param('deskname');
my $deskdescription = $input->param('deskdescription');
my $op              = $input->param('op') || '';

my @deskloop;
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


my ( $template, $borrowernumber, $cookie ) =
  get_template_and_user(
			{
			 template_name   => "admin/desks.tt",
			 query           => $input,
			 type            => "intranet",
			 authnotrequired => 0,
			 flagsrequired   => {
					     parameters => 'parameters_remaining_permissions'
					    },
			 debug           => 1,
			}
		       );

$template->param(branchloop => \@branchloop);

$template->param(script_name => $script_name);
if ($op) {
    $template->param($op  => 1);
} else {
    $template->param(else => 1);
}
$template->param(deskcode => $deskcode);

my $desk;

if ( $op eq 'add_form' || $op eq 'delete_confirm') {
    $desk = GetDesk($deskcode);
}
elsif ( $op eq 'add_validate' ) {
    $desk = {
	     'deskcode' => $deskcode,
	     'deskname'  => $deskname,
	     'deskdescription' => $deskdescription,
	     'branchcode' => $branchcode,
	    };
    if ( GetDesk($deskcode) ) {
	$template->param(error => 'ALREADY_EXISTS');
	print $input->redirect('desks.pl');
	exit;
    }
    if (AddDesk($desk) != 1) {
	$template->param(error => 'CANT_ADD');
    }
    print $input->redirect('desks.pl');
    exit;
}
elsif ( $op eq 'modify_validate' ) {
    $desk = {
	     'deskcode' => $deskcode,
	     'deskname'  => $deskname,
	     'deskdescription' => $deskdescription,
	     'branchcode' => $branchcode,
	    };
    if (ModDesk($desk) != 1) {
	$template->param(error => 'CANT_MODIFY');
    }
    print $input->redirect('desks.pl');
    exit;
}
elsif ( $op eq 'delete_confirmed' ) {
    if ( DelDesk($deskcode) != 1) {
	    $template->param(error => 'CANT_DELETE');
    }
    print $input->redirect('desks.pl');
    exit;
}
else {
    my $userenv = C4::Context->userenv;
    my $desksaref = GetDesks();
    foreach my $d (@$desksaref) {
	push @deskloop, GetDesk($d);
    }
     $template->param(deskloop  => \@deskloop);
}

$template->param(desk => $desk);

output_html_with_http_headers $input, $cookie, $template->output;
