#! /usr/bin/perl

##
# B034 : items retievals
##

use strict;
use warnings;

use CGI;
use C4::Context;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use C4::Stack::Search;
use C4::Spaces::Connector;
use C4::Stack::Manager;
use C4::Utils::Constants;
use C4::Circulation;
use C4::Members;
use C4::Biblio;
use C4::Items qw(ModItem ModDateLastSeen GetItemnumberFromBarcode);

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
        print $query->redirect("/cgi-bin/koha/desk/selectdesk.pl?oldreferer=/cgi-bin/koha/stack/stack-retrieval.pl");
        exit;
    }
} 

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "stack/stack-retrieval.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
        debug           => 1,
    }
);

# common variables
my $result;
my $space_name;

my $error;
my $error_status;
my $exist_results;
my @errmsgloop;

my @tab;

# Set up the item stack ....
my %retrievalitems;
my @inputloop;

foreach ( $query->param ) {
    my $counter;
    if (/retrieval-(\d*)/) {
        $counter = $1;
        if ($counter > 20) {
            next;
        }
    } else {
        next;
    }

    my %input;
    my $stack = $query->param("retrieval-$counter");
    $counter++;

    $retrievalitems{$counter} = $stack;
}

#
# input params
#
my $inp_item      = $query->param('item_barcode');
my $inp_stack     = $query->param('stack_barcode');
my $inp_retrieval = $query->param('retrieval_barcode');
my $op            = $query->param('op');

# modify barcode
my $opmodify            = $query->param('modify');
my $modify_barcode      = $query->param('modify_barcode') || '';

my $item_temp = $query->param('item_temp');

#
# Retrieve items
#            
my $flyBiblio;
my $flyItem;
my $ItemBarcode;

# current desk code
my $desk_code = C4::Context->userenv->{'desk'};

#
# Barcode edition
#
if ($opmodify) {
    $result = GetStackById($inp_stack);
    if ($result) {
        $ItemBarcode = 0;
        my $itemnumber = GetItemnumberFromBarcode( $modify_barcode );
        
        if ( $itemnumber ) {
            #There is already an item with this itemnumber
            push(@errmsgloop, { 'modify_barcode_duplicate' => 1, 'msg' => $modify_barcode });
        } else {
            ModItem({ barcode => $modify_barcode }, undef, $result->{'itemnumber'});
            ModDateLastSeen($result->{'itemnumber'});
            
            # Perform action
            RetrieveStackRequest($result, $desk_code);
                
            # refresh
            $result = GetStackById($inp_stack);
            
            if ( $result->{'barcode'} ) {
                $ItemBarcode = 1;
            } else {
                #Fail to set barcode
                push(@errmsgloop, { 'modify_barcode_bad_barcode' => 1, 'msg' => $modify_barcode });
            }
        }
        
        $template->param(
            loop_results => [$result],
            has_results  => 1,
            ItemBarcode  => $ItemBarcode,
            errmsgloop   => \@errmsgloop,
        );
        
    }
    
} else {
    
    if ( $item_temp ) {
        # Come back itemp item
        $template->param(
            item_temp => 1,
        );
    }

    #
    # Retrieval
    #
    if ( $op ){
        
        if ( $inp_item ){
            # Test if item barcode request
            my $itemnumber = GetItemnumberFromBarcode($inp_item);
            if ( $itemnumber ){
                $result = GetCurrentStackByItemnumber($itemnumber);
                unless ( $result && $result->{'state'} eq $STACK_STATE_EDITED ){
                    push(@errmsgloop, { 'no_stack_request' => 1, 'msg' => $inp_item });
                }
            } else {
                push(@errmsgloop, { 'badItemBarcode' => 1, 'msg' => $inp_item });
            }
            
        } elsif( $inp_stack ){
            # Test if stack barcode request
            # Request may have been archived
            $result = GetStackById($inp_stack, 1);
            if ( $result ) {
                unless ( $result->{'state'} eq $STACK_STATE_EDITED ){
                    if ( $result->{'state'} eq $STACK_STATE_ASKED ){
                        # not edited yet
                        push(@errmsgloop, { 'notedited_yet' => 1, 'msg' => $inp_stack });
                    } else {
                        # already retrieved
                        push(@errmsgloop, { 'already_retrieved' => 1, 'msg' => $inp_stack });
                    }
                }
            } else {
                push(@errmsgloop, { 'badStackBarcode' => 1, 'msg' => $inp_stack });
            }
        } elsif( $inp_retrieval ) {
            my $result_item;
            my $result_stack;
        	
            # Test first item barcode
            my $itemnumber = GetItemnumberFromBarcode($inp_retrieval);
            if ( $itemnumber ) {
                $result_item = GetCurrentStackByItemnumber($itemnumber);
            }
            
            # Then test stack barcode
            $result_stack = GetStackById($inp_retrieval, 1);
            
            if ( $result_item && $result_item->{'state'} eq $STACK_STATE_EDITED ){
                $result = $result_item;
            } elsif ( $result_stack->{'state'} eq $STACK_STATE_EDITED ) {
            	$result = $result_stack;
            } elsif( $result_item && $result_item->{'state'} ne $STACK_STATE_EDITED ) {
            	push(@errmsgloop, { 'no_stack_request' => 1, 'msg' => $inp_retrieval });
            } elsif ( $result_stack && $result_stack->{'state'} eq $STACK_STATE_ASKED ) {
            	push(@errmsgloop, { 'notedited_yet' => 1, 'msg' => $inp_retrieval });
            } elsif ( $result_stack->{'state'} ) {
            	push(@errmsgloop, { 'already_retrieved' => 1, 'msg' => $inp_retrieval });
            } else {
            	push(@errmsgloop, { 'badItemBarcode' => 1, 'msg' => $inp_retrieval, 'badStackAndItem' => 1 });
            	push(@errmsgloop, { 'badStackBarcode' => 1, 'msg' => $inp_retrieval, 'badStackAndItem' => 1 });
            }

            
        }
        
        if ( $result && !(scalar @errmsgloop)) {
            
            # Test if canceled request
            if ( $result->{'cancel_code'} ){
                push(@errmsgloop, { 'canceled' => 1, 'msg' => $result->{'cancel_code_ui'} });
            }
        }
        
        if ( $result && !(scalar @errmsgloop)) {
            
            # Manage fly biblio and/or item
            if ( !$result->{'serial_biblionumber'} && !$result->{'itemnumber'} ){
                $flyBiblio = 1;
            } elsif ( $result->{'serial_biblionumber'} && !$result->{'itemnumber'} ){
                $flyItem = 1;
            } elsif ( !$result->{'barcode'} ){
                # Dont perform action
            } else {
                # Perform action
                RetrieveStackRequest($result, $desk_code);
                
                # reload result
                $result = GetStackById($result->{'request_number'});
            }
            
            # Test Item Barcode
            if ( $result->{'itemnumber'} && $result->{'barcode'} ){
                $ItemBarcode = 1;
            }
            
            # MAN212
            if ($result->{'space_booking_id'}) {
                my $space = GetReservedSpaceById($result->{'borrowernumber'}, $result->{'space_booking_id'});
                if ($space) {
                    $space_name = $space->{'space_lib'};
                }
            }
            # END MAN212
            
            $result->{'flyBiblio'} = $flyBiblio;
            $result->{'flyItem'} = $flyItem;
            
            my @previous_keys = grep { $retrievalitems{$_} == $result->{'request_number'} } keys %retrievalitems;
            foreach ( @previous_keys ) {
                delete $retrievalitems{$_};
            }
            
            $retrievalitems{0} = $result->{'request_number'};
            
    
            # Show in tab
            push (@tab, $result);
        }    
    }
    
    #
    # Set params to template
    #
    $template->param(
        op           => $op,
        error        => $error,
        errmsgloop   => \@errmsgloop,
        loop_results => \@tab,
        has_results  => ( scalar @tab ) ? 1 : ( ( scalar keys %retrievalitems ) ? 1 : undef ),
        ItemBarcode  => $ItemBarcode,
        space_name    => $space_name,
    );

}

#set up so only the last 8 returned items display (make for faster loading pages)
my $returned_counter = ( C4::Context->preference('numReturnedItemsToShow') ) ? C4::Context->preference('numReturnedItemsToShow') : 8;
my $count = 0;
my @riloop;
foreach ( sort { $a <=> $b } keys %retrievalitems ) {
    my %ri;
    if ( $count++ < $returned_counter ) {
        my $stack = $retrievalitems{$_};
        if ( $_ == 0 ) {
            $result = $tab[0];
            $result->{counter} = 0;
        } else {
            $result = GetStackById($stack, 1);
            $result->{counter} = $count - 1;
            
            if ( !$result->{'serial_biblionumber'} && !$result->{'itemnumber'} ){
                $result->{'flyBiblio'} = 1;
            } elsif ( $result->{'serial_biblionumber'} && !$result->{'itemnumber'} ){
                $result->{'flyItem'} = 1;
            }
            
        }
        
        push @riloop, $result;
        push @inputloop, {counter => $count - 1, request_number => $stack};
    }
    else {
        last;
    }
}

foreach ( @riloop ) {
    @{$_->{'inputloop'}} = @inputloop;
}

$template->param(
    inputloop => \@inputloop,
    riloop => \@riloop,
);

#
# Print the page
#
output_html_with_http_headers $query, $cookie, $template->output;
