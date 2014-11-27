#! /usr/bin/perl

##
# B034 : Delivery
##

use strict;
use warnings;

use CGI;
use C4::Context;
use C4::Auth qw(:DEFAULT get_session);
use C4::Koha;
use C4::Output;
use C4::Stack::Search;
use C4::Stack::Manager;
use C4::Circulation;
use C4::Members;
use C4::Biblio;
use C4::Utils::Constants;
use C4::Items qw(GetItemnumberFromBarcode GetItem ModItem);

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
        print $query->redirect("/cgi-bin/koha/desk/selectdesk.pl?oldreferer=/cgi-bin/koha/stack/stack-delivery.pl");
        exit;
    }
} 

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "stack/stack-delivery.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
        debug           => 1,
    }
);

# common variables
my $result;

my @tab;
my @errmsgloop;

#
# input params
#
my $inp_barcode     = $query->param('barcode');
my $op              = $query->param('op');
my $op_materials    = $query->param('op_materials') || 0;
my $cancel          = $query->param('cancel');
my $request_number  = $query->param('request_number');
my $materialsinfo   = $query->param('materialsinfo');
my $missinginfo     = $query->param('missinginfo');

# current desk
my $desk_code = C4::Context->userenv->{'desk'};

if ( $op ){
    #
    # Deliver item 
    #
    
    my $itemnumber = GetItemnumberFromBarcode($inp_barcode);
    unless ( $itemnumber ){
        push(@errmsgloop, { 'badItemBarcode' => 1, 'msg' => $inp_barcode });
    } else {
        $result = GetCurrentStackByItemnumber($itemnumber);
        
        # stack must be running to deliver
        unless ( $result && $result->{'state'} eq $STACK_STATE_RUNNING ){
            push(@errmsgloop, { 'noStack' => 1, 'msg' => $inp_barcode });
        }
    }

    if ( $result ){
    	
    	my $item = GetItem( $itemnumber );
    	if ( $item->{'materials'} && $item->{'materials'} ne '' &&  !$op_materials ) {
    		my $materialsinfo_loop = GetAuthorisedValues( 'ABS_MATER', $item->{'materialsinfo'} );
    		
    		$template->param( 
    		                  'barcode'            => $item->{'barcode'},
    		                  'materials'          => 1,
    		                  'materials_loop' => $materialsinfo_loop,
                              'missinginfo' => $item->{'missinginfo'} 
    		                );
    		push(@errmsgloop, { 
    			                 'item' => $item->{'barcode'}, 
    			                 'msg' => $item->{'materials'}, 
    		                  });
    	} else {
            
            if ( $op_materials ) {
            	ModItem( { materialsinfo => $materialsinfo, missinginfo => $materialsinfo eq 'A' ? '' : $missinginfo }, undef, $itemnumber );
            }
            
	        # Perform delivery
	        DeliverStackRequest($result, $desk_code);
	        
	        # reload result
	        $result = GetStackById($result->{'request_number'});
	        $result->{'units'} = (index $result->{'enumchron'}, 'Volume') > 0 ? (substr $result->{'enumchron'}, 0, (index $result->{'enumchron'}, 'Volume')) : '1',
	        
	        push (@tab, $result);
    	}
    }
}

if ( $cancel ){
    
    #
    # Undeliver item 
    #
    
    $result = GetStackById($request_number);
    if ($result) {
       UndeliverStackRequest($result, $desk_code);
    }
    
    push(@errmsgloop, { 'canceled' => 1, 'msg' => $request_number });
}

#
# Set params to template
#
$template->param(
    op           => $op,
    errmsgloop   => \@errmsgloop,
    loop_results => \@tab,
    has_results  => (scalar @tab) ? 1 : undef,
);

#
# Print the page
#
output_html_with_http_headers $query, $cookie, $template->output;
