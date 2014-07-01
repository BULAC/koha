#! /usr/bin/perl

##
# B034 : all operations
##

use strict;
use warnings;

use CGI;
use CGI::Session;

use C4::Auth qw(:DEFAULT get_session);
use C4::Biblio;
use C4::Callnumber::Utils;
use C4::Circulation;
use C4::Context;
use C4::Dates qw(format_date);
use C4::Items;
use C4::Koha;
use C4::Members;
use C4::Output;
use C4::Stack::Rules;
use C4::Spaces::Connector;
use C4::Stack::Search;
use C4::Utils::Constants;
use C4::Utils::Components;

use C4::Stack::Search;

#
# String equals method allowing undef
# return : 1 or undef
#
sub streq($$) {
    
    # input args
    my ($stra, $strb) = @_;
    
    if (!defined $stra && !defined $strb) {
        return 1; # null == null
    } elsif (!defined $stra || !defined $strb) {
        return undef; # not null != null
    } else {
        return ($stra eq $strb); # current string equals
    }
}

#
# Constants
#
my $NO_ITEM_FOUND_ERR = 'NO_ITEM_FOUND';
my $NO_SR_FOUND_ERR   = 'NO_SR_FOUND';

my $ALERT_CANCELED = 'CANCELED';
my $ALERT_IN_STORE = 'IN_STORE';

my $IMP_NOT_LOANABLE      = 'NOT_LOANABLE';
my $IMP_NOT_AVAILABLE     = 'NOT_AVAILABLE';

#
# Common vars
#
my $query = new CGI;
my $dbh = C4::Context->dbh;
my $branch;
my $desk_code;

my $today = C4::Dates->new()->output('iso');

#
# Control a library is set
#
if (!C4::Context->userenv){
    my $sessionID = $query->cookie("CGISESSID");
    my $session = get_session($sessionID);
    
    if ($session->param('branch') eq 'NO_LIBRARY_SET'){
        # no branch set
        print $query->redirect("/cgi-bin/koha/circ/selectbranchprinter.pl");
        exit;
    }
    
    if ($session->param('desk') eq 'NO_DESK_SET'){
        # no desk set
        my $parameters = '';
        foreach ($query->param()) {
            $_ or next; # disclude blanks
            $parameters = $parameters.'&'.$_.'='.$query->param($_);
        }
        print $query->redirect("/cgi-bin/koha/desk/selectdesk.pl?oldreferer=/cgi-bin/koha/stack/all-operations.pl".$parameters);
        exit;
    }
}

#
# Get template and logged in user
#
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "stack/all-operations.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
        debug           => 1,
    }
);
$branch    = C4::Context->userenv->{'branch'} || '';
$desk_code = C4::Context->userenv->{'desk'};

#
# Input params
#
my $opwait      = $query->param('opwait') || ''; # wait operation form
my $inp_barcode = $query->param('input')  || ''; # first form input
$inp_barcode =~  s/^\s*|\s*$//g; # remove leading/trailing whitespace

#
# Local vars
#
my @post_err_loop;
my @alert_loop;
my @impossible_loop;
    
my $itemnumber; # may be undef
my $item_details; # may be undef
my $item_barcode;
my $item_state;
my $item_notforloan;
my $item_in_desk;

my $stackrq_details;
my $stackrq_state;
my $stackrq_canceled;
my $issue_details;

my $borrowernumber;
my $borr_details;

my $space_name;

# allowed operations
my $allow_stack_deliver;
my $allow_stack_return;
my $allow_stack_renew;
my $allow_stack_checkout;

my $allow_stack_retriev;
my $allow_stack_wait;
my $allow_stack_cancel;

my $allow_loan_checkout;
my $allow_loan_return;
my $allow_loan_renew;

#
# First form post
#
if ($inp_barcode) {
    
    #
    # Find item or stack request from input barcode
    #
    $itemnumber = GetItemnumberFromBarcode($inp_barcode);
    
    unless ($itemnumber) {
        
        # item not found, look for stack request
        $stackrq_details = GetStackById($inp_barcode, 1);
        
        # id old show only if edited
        if ($stackrq_details)
        {
            $itemnumber = $stackrq_details->{'itemnumber'};
        } else {
            push (@post_err_loop, { $NO_ITEM_FOUND_ERR => 1 });
            push (@post_err_loop, { $NO_SR_FOUND_ERR   => 1 });
            
            $template->param(
                post_err_loop => \@post_err_loop,
                inp_barcode    => $inp_barcode,
            );
            
            # End script
            output_html_with_http_headers $query, $cookie, $template->output;
            exit;
        }
        
        if ($stackrq_details->{'onserial'}) {
            unless ($stackrq_details->{'nc_title'}) {
                $template->param(
                    title => $stackrq_details->{'title'} ,
                );
            }
            unless ($stackrq_details->{'nc_author'}) {
                $template->param(
                    author => $stackrq_details->{'author'},
                );
            }
        }
        
    }
    
    if ($itemnumber) {
        
        #
        # Find item details
        #
        $item_details = GetBiblioFromItemNumber($itemnumber);
        
        # Get item barecode
        # Don't use inp_barcode because it can be a stack id
        $item_barcode    = $item_details->{'barcode'};
        
        $item_state      = $item_details->{'istate'};     # beware : can be null
        $item_notforloan = $item_details->{'notforloan'}; # beware : can be null and '0'
        
        if ( streq($item_state, $ISTATE_WAIT_RENEW)
          || streq($item_state, $ISTATE_WAIT_STACK) ){
            $item_in_desk = 1;
        }
        
        $template->param(
            itemnumber      => $itemnumber,
            item_barcode    => $item_barcode,
            itemcallnumber  => $item_details->{'itemcallnumber'},
            biblionumber    => $item_details->{'biblionumber'},            
            title           => $item_details->{'title'},
            author          => $item_details->{'author'},
            itemnotes       => $item_details->{'itemnotes'},
            ccode           => $item_details->{'ccode'},
            publishercode   => $item_details->{'publishercode'},
            publicationyear => $item_details->{'publicationyear'},
            itemtype        => C4::Context->preference('item-level_itypes') ? $item_details->{'itype'} : $item_details->{'itemtype'},
            istate          => $item_state,
            item_in_desk    => $item_in_desk,
        );
    }
         
    if (!$stackrq_details && $itemnumber) {
        #
        # Look for current stack request on item
        #
        $stackrq_details = GetAllOperationsStackByItemnumber($itemnumber);
    }
    if (!$stackrq_details && $itemnumber) {
        #
        # No stack request,
        # look for current issue
        #
        $issue_details = GetOpenIssue($itemnumber);
    }
    
    #
    # If item on circulation
    #
    if ($stackrq_details || $issue_details) {
        
        if ($stackrq_details) {
            
            #
            # If wait operation post
            #
            if ($opwait && $itemnumber) {
                
                # Set item on wait in desk
                setItemWaitRenew($itemnumber, $desk_code);
                
                # Reshow page
                print $query->redirect("/cgi-bin/koha/stack/all-operations.pl?input=$inp_barcode");
                exit;
            }

            # concerned borrower
            $borrowernumber = $stackrq_details->{'borrowernumber'};
            $borr_details = GetMemberDetails( $borrowernumber, undef );
            
            $stackrq_state    = $stackrq_details->{'state'};
            $stackrq_canceled = $stackrq_details->{'cancel_code'} ? 1 : undef;
            
            # MAN212            
            if ( $stackrq_details->{'space_booking_id'} && $stackrq_details->{'delivery_desk_ui'} ) {

                $space_name = C4::Spaces::Connector::GetSpaceNameByBookingId($stackrq_details->{'space_booking_id'},$stackrq_details->{'begin_date'});

                if ($space_name) {
                    $stackrq_details->{'delivery_desk_ui'} = $space_name;
                }
            }
            # END MAN212
            
            $template->param(
                on_stackrq    => 1,
                
                request_number  => $stackrq_details->{'request_number'},
                stackrq_notes   => $stackrq_details->{'notes'},
                'state'         => $stackrq_details->{'state'},
                begin_date_ui   => $stackrq_details->{'begin_date_ui'},
                end_date_ui     => $stackrq_details->{'end_date_ui'},
                renewals        => $stackrq_details->{'renewals'},
                renew_date_ui   => $stackrq_details->{'renew_date_ui'},
                delivery_desk_ui => $stackrq_details->{'delivery_desk_ui'},
                cancel_code     => $stackrq_details->{'cancel_code'},
                cancel_code_ui  => $stackrq_details->{'cancel_code_ui'},
                
                nc_years        => $stackrq_details->{'nc_years'},
                nc_units        => (index $stackrq_details->{'enumchron'}, 'Volume') > 0 ? (substr $stackrq_details->{'enumchron'}, 0, (index $stackrq_details->{'enumchron'}, 'Volume')) : '1',
                nc_numbers      => $stackrq_details->{'nc_numbers'},
                
                nc_title        => $stackrq_details->{'nc_title'},
                nc_author       => $stackrq_details->{'nc_author'},
                nc_pubyear      => $stackrq_details->{'nc_pubyear'},
                nc_callnumber   => $stackrq_details->{'nc_callnumber'},
                
                onitem          => $stackrq_details->{'onitem'},
                onserial        => $stackrq_details->{'onserial'},
                onempty         => $stackrq_details->{'onempty'},
            );
            
            # Alert if canceled
            if ($stackrq_canceled) {
                push @alert_loop, { $ALERT_CANCELED => 1 }
            }
            
            # don't display operations if old stack request
            if (!$stackrq_details->{'isold'}) {
                
                #
                # Allow cancel
                #
                if ( CanCancelRequestStack(undef, $stackrq_details) ) {
                    $allow_stack_cancel = 1;
                    
                    # Listbox of cancel codes (with multiple)
                    my $CGIcancel = buildCGIcancelStack('sortCancel', undef, undef, '1', 5);
                    $template->param( CGIcancel => $CGIcancel );
                }
                
                #
                # Allow renew
                #
                my ($end_date_renewal, $renew_impossible, $renew_confirm) = CanRenewRequestStack(undef, $stackrq_details, 1);
                unless (scalar keys %$renew_impossible) {
                    
                    $allow_stack_renew = 1;
                    
                    $template->param(
                        end_date_renewal    => $end_date_renewal,
                        end_date_renewal_ui => format_date($end_date_renewal),
                        
                        renew_confirm       => [$renew_confirm],
                        renewMustConfirm    => (scalar keys %$renew_confirm) ? 1 : undef,
                    );
                }
                
                $template->param(
                    renew_impossible    => [$renew_impossible],
                );
                
                #
                # Allow retrieve if stack is edited
                #
                if (streq($stackrq_state, $STACK_STATE_EDITED))
                {
                    $allow_stack_retriev = 1;
                }
                
                #
                # Allow transform in check-out if item is loanable, can be issued, and can be converted into issue
                #
                my ($issuingimpossible, $needsconfirmation) = CanBookBeIssued($borr_details, $item_barcode, undef, undef);
                if (!$stackrq_canceled
                 && streq($item_notforloan, $AV_ETAT_LOAN)
                 && scalar keys %$issuingimpossible == 0
                 && !(defined $renew_impossible->{'ON_RESERVE'})
                 #&& $needsconfirmation->{'CONVERT_STACK'}
                )
                {
                    $allow_stack_checkout = 1;
                }
                
                #
                # Stack running operations
                #
                if (streq($stackrq_state, $STACK_STATE_RUNNING)) {
                    
                    #
                    # Allow stack return
                    #
                    $allow_stack_return = 1;
                    
                    #
                    # Allow stack wait if item is on stack
                    #
                    #if (streq($item_state, $ISTATE_ON_STACK)) {
                    #    # MAN217 only allow if cant renew because of comming circulation
                    #    if (!$allow_stack_renew && ($renew_impossible->{'ON_RESERVE'} || $renew_impossible->{'BLOCKING_SR'})) {
                    #        $allow_stack_wait = 1;
                    #    }
                    #}
                    
                    #
                    # Allow deliver if item waiting in desk
                    #
                    if (!$stackrq_canceled
                     && (streq($item_state, $ISTATE_WAIT_STACK)
                      || streq($item_state, $ISTATE_WAIT_RENEW)))
                    {
                        $allow_stack_deliver = 1;
                    }
                }
            }
        }
        if ($issue_details) {
            
            # concerned borrower
            $borrowernumber = $issue_details->{'borrowernumber'};            
            $borr_details = GetMemberDetails( $borrowernumber, undef );
            
            $template->param(
                on_issue     => 1,
                
                begin_date_ui => format_date($issue_details->{'issuedate'}),
                end_date_ui   => format_date($issue_details->{'date_due'}),
                overdue       => ($issue_details->{'date_due'} lt $today) ? 1 : undef, # should have been returned
                
                renewals      => $issue_details->{'renewals'},
                renew_date_ui => format_date($issue_details->{'lastreneweddate'}),
            );
            
            #
            # Allow checkin
            #
            $allow_loan_return = 1;
            
            #
            # Allow renew
            #
            my ($renewpossible, $renewerror) = CanBookBeRenewed($borrowernumber, $itemnumber);
            if ($renewpossible) {
                $allow_loan_renew = 1;
            }
        }
        
        #
        # Borrower details 
        #        
        if ($borr_details) {                
            $template->param(
                borrowernumber  => $borrowernumber,
                
                borcategorycode => $borr_details->{'categorycode'},
                borfirstname    => $borr_details->{'firstname'},
                borsurname      => $borr_details->{'surname'},
                borcardnumber   => $borr_details->{'cardnumber'},
                bornotes        => $borr_details->{'borrowernotes'},
            );
        }
        
    } else {
        
        # Not on circulation
        
        #
        # Allow checkout if item is loanable and available and not in store
        # (Cant use C4::Circulation because borrower is unknown)
        #
        my $is_loanable   = streq($item_notforloan, $AV_ETAT_LOAN);
        my $is_available  = IsItemAvailable($item_details);
        my $is_instore    = IsItemInStore($itemnumber);
        
        if ($is_loanable && $is_available && !$is_instore)
        {
            $allow_loan_checkout = 1;
        } else {
            # messages
            unless ($is_loanable) {
                my $nflvalue = '?';
                if (defined $item_notforloan) {                    
                    $nflvalue = get_notforloan_label_of()->{ "$item_notforloan" };
                }
                push(@impossible_loop, { $IMP_NOT_LOANABLE => $nflvalue }) 
            }
            unless ($is_available) {
                push(@impossible_loop, { $IMP_NOT_AVAILABLE   => 1 })
            }
            if ($is_instore) {
                push @alert_loop, { $ALERT_IN_STORE => 1 }
            }
        }
    }

    #    
    # Output vars
    #
    $template->param(
        post => 1,        
    );
    
    if (scalar @post_err_loop) {
        $template->param(
            post_err_loop => \@post_err_loop,
        );
    } else {
        $template->param(
            post_ok => 1,
            
        );
    }
}

#
# Output vars
#
$template->param(
    inp_barcode          => $inp_barcode,
    branch               => $branch,
    
    allow_stack_deliver  => $allow_stack_deliver,
    allow_stack_return   => $allow_stack_return,
    allow_stack_renew    => $allow_stack_renew,
    allow_stack_checkout => $allow_stack_checkout,
    allow_stack_retriev  => $allow_stack_retriev,
    allow_stack_wait     => $allow_stack_wait,
    allow_stack_cancel   => $allow_stack_cancel,
    allow_loan_checkout  => $allow_loan_checkout,
    allow_loan_return    => $allow_loan_return,
    allow_loan_renew     => $allow_loan_renew,
    
    alert_loop           => \@alert_loop,
    impossible_loop      => \@impossible_loop,
    
    AllowRenewalLimitOverride => C4::Context->preference("AllowRenewalLimitOverride"),
);

#
# Print the page
#
output_html_with_http_headers $query, $cookie, $template->output;
