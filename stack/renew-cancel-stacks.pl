#! /usr/bin/perl

##
# B034 : Cancel or renew a stack request
# MAN122
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
use C4::Koha;
use C4::Output;
use C4::Stack::Rules qw(CanCancelRequestStack CanRenewRequestStack);
use C4::Stack::Manager qw(CancelStackRequest RenewStackRequest);
use C4::Items;
use C4::Stack::Search;

#
# Build output
#
my $query = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "stack/stack-renew.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
        debug           => 1,
    }
);

#
# Input args
#

# all operations
my $inp_barcode     = $query->param('inp_barcode') || '';
my $do_store        = $query->param('store') || '';

my $destination     = $query->param('destination') || '';
my $borrowernumber  = $query->param('borrowernumber') || '';

my $override_limit  = $query->param('stack_override_limit');
my $cancel_code     = $query->param('sortCancel') || '';

my @renew_requests  = $query->param('stack_renew');
my @cancel_requets  = $query->param('stack_cancel');
my $do_renew        = $query->param('stack_renew_checked');
my $do_cancel       = $query->param('stack_cancel_checked');

my $renew_material  = 0;
my $op_materials    = $query->param('op_materials') || 0;
my $materialsinfo   = $query->param('materialsinfo');
my $missinginfo     = $query->param('missinginfo');
my $failedmaterialsinfo;

my $desk_code = C4::Context->userenv->{'desk'};

if ($do_renew) {
    #
    # Renew stack request
    #
    my $ignore_istate = $do_store ? 1 : undef;
        
    foreach my $request_number (@renew_requests) {
        
        my ($end_date_renewal, $renew_impossible, $renew_confirm) = CanRenewRequestStack($request_number, undef, $ignore_istate);
        
        if (!scalar keys %$renew_impossible) {  
            if (!scalar keys %$renew_confirm || $override_limit) {
                
                my $stack = GetStackById( $request_number );
                my $item = GetItem( $stack->{'itemnumber'} );
                if ( $item->{'materials'} && $item->{'materials'} ne '' &&  !$op_materials ) {
                	if ( $destination eq 'allop' ) {
                		my $materialsinfo_loop = GetAuthorisedValues( 'ABS_MATER', $item->{'materialsinfo'} );
            
			            $template->param(
			                'requestnumber'  => $request_number,
			                'barcode'        => $item->{'barcode'},
			                'materials_loop' => $materialsinfo_loop,
			                'materials'      => $item->{'materials'}, 
			                'missinginfo'    => $item->{'missinginfo'},
			                'do_store'       => $do_store
			            );
			            
			            $renew_material = 1;
                	} else {
                        $failedmaterialsinfo.="&failedmaterialsinfo=".$item->{'barcode'};
                	}
		        } else {
                    if ( $op_materials ) {
		                ModItem( { materialsinfo => $materialsinfo, missinginfo => $materialsinfo eq 'A' ? '' : $missinginfo }, undef, $item->{'itemnumber'} );
		            }
		            
                    if ($do_store) {
	                    # set item in desk and renew
	                    RenewStackRequest($request_number, undef, $end_date_renewal, 1, $desk_code);
	                } else {
	                    # only renew
	                    RenewStackRequest($request_number, undef, $end_date_renewal);
	                }
		        }
                
            }
        }
    
    }
}

if ($do_cancel) {
    #
    # Cancel stack requests
    #
    foreach my $request_number (@cancel_requets) {
        if (CanCancelRequestStack($request_number)){
            CancelStackRequest($request_number, undef, $cancel_code);
        }
    }
}

#
# Redirect
#
if ( $destination eq 'allop' ){
	if ($renew_material > 0) {
		output_html_with_http_headers $query, $cookie, $template->output;
	} else {
        print $query->redirect("/cgi-bin/koha/stack/all-operations.pl?input=$inp_barcode");
	}
}
elsif ( $destination eq 'circ' ){
    print $query->redirect("/cgi-bin/koha/circ/circulation.pl?borrowernumber=$borrowernumber$failedmaterialsinfo#stacks"); #MAN123
}
else{
    print $query->redirect("/cgi-bin/koha/members/moremember.pl?borrowernumber=$borrowernumber$failedmaterialsinfo#onstack"); #MAN123
}