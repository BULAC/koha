#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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

# PROGILONE - A1 : corrections

use strict;
use warnings;

use CGI;
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Koha;
use C4::Branch;
use C4::Circulation qw{ IsBranchTransferAllowed DeleteBranchTransferLimits CreateBranchTransferLimit };

my $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name => "admin/branch_transfer_limits.tmpl",
        query         => $input,
        type          => "intranet",
        flagsrequired => { borrowers => 1 },
        debug         => 1,
    }
);

my $dbh = C4::Context->dbh;

# if branch code is not in input params, use the currently set branch code
my $to_branch_code = $input->param('branchcode') || mybranch();

if ($to_branch_code) {
    
    my $query;
    my @codes;
    my @from_branch_codes;
    my $sth;
    
    ## Array of codes (item type or ccode)
    my $limit_on_ccode = 0;
    my $limit_type = C4::Context->preference("BranchTransferLimitsType") || 'ccode';
    if ( $limit_type eq 'ccode' ) {
        $limit_on_ccode = 1;
    	$query = 'SELECT authorised_value AS ccode FROM authorised_values WHERE category = "CCODE" ORDER BY authorised_value + 0'; # + 0 for sorting strings as numbers
    } else {
    	$query = 'SELECT itemtype FROM itemtypes ORDER BY itemtype + 0'; # + 0 for sorting strings as numbers
    }
    
    $sth = $dbh->prepare($query);
    $sth->execute();
    while ( my $row = $sth->fetchrow_hashref ) {
    	push( @codes, $row->{ $limit_type } );
    }
    
    ## All from branch codes
    $sth = $dbh->prepare('SELECT branchcode FROM branches WHERE branchcode <> ? ORDER BY branchname');
    $sth->execute($to_branch_code);
    while ( my $row = $sth->fetchrow_hashref ) {
    	push( @from_branch_codes, $row->{'branchcode'} );
    }
    
    ## If Form Data Passed, Update the Database
    if ( $input->param('updateLimits') ) {
    	DeleteBranchTransferLimits($to_branch_code);
    
    	foreach my $code ( @codes ) {
    		foreach my $from_branch ( @from_branch_codes ) {
    			unless ( $input->param( $code . "_" . $from_branch) ) {
    			    CreateBranchTransferLimit( $to_branch_code, $from_branch, $code );
    			}
    		}
    	}
    }
    
    ## Read database to build main loop
    my @codes_loop;
    foreach my $code ( @codes ) {
    	my @from_branch_loop;
    	my %row_data;
    	
    	$row_data{ code } = $code;
    	
    	# Description of code
    	if ($limit_on_ccode) {
            my $sth = C4::Context->dbh->prepare('SELECT lib FROM authorised_values WHERE category = ? AND authorised_value = ? LIMIT 1');
            $sth->execute( 'CCODE', $code );
            my $row = $sth->fetchrow_hashref;
            $row_data{ description } = $$row{'lib'} if $row;
    	} else {	    
            $row_data{ description } = getitemtypeinfo($code)->{'description'};
    	}
    	
    	$row_data{ from_branch_loop } = \@from_branch_loop;
    	
    	foreach my $from_branch ( @from_branch_codes ) {
    		my %row_data;
    		$row_data{ code }             = $code;
    		$row_data{ from_branch }      = $from_branch;
    		$row_data{ is_checked }       = IsBranchTransferAllowed( $to_branch_code, $from_branch, $code );	
    		$row_data{ from_branch_name } = GetBranchName($from_branch);	
    		push( @from_branch_loop, \%row_data );
    	}
    
    	push( @codes_loop, \%row_data );
    }
    
    
    $template->param(
    		codes_loop     => \@codes_loop,
    		to_branch_code => $to_branch_code,
    		limit_on_ccode => $limit_on_ccode,
    		);
}

$template->param(
		branch_loop => GetBranchesLoop($to_branch_code, 0),
        );

output_html_with_http_headers $input, $cookie, $template->output;

