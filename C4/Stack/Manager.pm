package C4::Stack::Manager;

##
# B03X : Add, mod and delete stacks
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use Data::Dumper;
use LWP::Simple qw(get);
use Date::Calc qw(Add_Delta_Days Delta_Days Today);
use Time::HiRes qw(time);

use C4::Branch qw(GetBranchDetail GetBranches);
use C4::Circulation qw(GetTransfers GetIssuingRule);
use C4::Context;
use C4::Dates qw(format_date format_date_in_iso);
use C4::Debug;
use C4::Items;
use C4::Log qw(logaction);
use C4::Members;
use C4::Reserves qw(CheckReserves GetReservesFromItemnumber CancelReserve);
use C4::Stats qw(UpdateStats);
use C4::Stack::Search;
use C4::Stack::Rules;
use C4::Stack::StackItemsTemp;
use C4::Utils::Constants;
#use C4::Spaces::Connector;

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &CreateStackRequest
        &CancelStackRequest
        &CancelStackRequestFromOPAC

        &RetrieveStackRequest
        &DeliverStackRequest
        &UndeliverStackRequest
        &RenewStackRequest
        &AddReturnStack
        &EditStackRequest
        
        &CancelStackRequestBySpace
        &RenewStackRequestBySpace
        &EndStackRequestBySpace
        
        &ExpireStacks
        &AutoReturnPrevStacks
        &CheckBlockingStacks
        
        &SetItemNumber
    );
}

##
# Create stack request
#
# param : hash of field/value
# return : request id
##
sub CreateStackRequest($) {
    
    # input args
    my $fields = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    
    my $query;
    my $query_fields;
    my $query_params;
    my @params;
        
    my $result;
    
    # Concerned space
    my $space = $fields->{'space'};
    
    #
    # Compose query
    #
    
    # request_number uses timestamp on 13 digits for unicity
    my $ts = (0 + time) * 1000; # convert seconds in milliseconds
    my $id = sprintf('%.0f', $ts); # round to integer
    
    $query_fields = 'request_number';
    $query_params = '?';
    push(@params, $id);
    
    # borrower
    $query_fields .= ',borrowernumber';
    $query_params .= ',?';
    push(@params, $fields->{'borrowernumber'});

    # item
    if ($fields->{'onitem'}) {
        $query_fields .= ',itemnumber';
        $query_params .= ',?';
        push(@params, $fields->{'itemnumber'});
    }
    
    # init state
    $query_fields .= ',state';
    $query_params .= ',?';
    push(@params, $STACK_STATE_ASKED);
    
    
    # begin/end date
    $query_fields .= ',begin_date,end_date';
    $query_params .= ',?,?';
    
    if ($space) {
        # if reservation space, use the space end date
        # the begin date was computed in the calling method.
        push(@params, $fields->{'begin_date'});
        push(@params, $space->{'end_date'});
    }
    else {
        # else request expires the begin day + stacklength
        push(@params, $fields->{'begin_date'});
        my $issuingrule;
        if ($fields->{'onitem'}) {
            $issuingrule = GetIssuingRuleForStack($fields->{'borrowernumber'}, $fields->{'itemnumber'});
        } else {
            $issuingrule = GetIssuingRuleForStack($fields->{'borrowernumber'});
        }
        my $end_date = sprintf( "%04d-%02d-%02d", Add_Delta_Days( split(/-/, $fields->{'begin_date'}), $issuingrule->{'stacklength'} - 1) );
        push(@params, $end_date);
    }
    
    # delivery desk/space
    if ($space) {  
        $query_fields .= ',space_booking_id';
        $query_params .= ',?';
        push(@params, $space->{'space_id'});
    }
    else {
        $query_fields .= ',delivery_desk';
        $query_params .= ',?';
        push(@params, $fields->{'delivery_desk'});
    }
    
    # biblio
    if ($fields->{'onserial'}) {
        $query_fields .= ',serial_biblionumber';
        $query_params .= ',?';
        push(@params, $fields->{'biblionumber'});
    }
    
    # notes
    $query_fields .= ',notes';
    $query_params .= ',?';
    push(@params, $fields->{'notes'});
        
    # years
    $query_fields .= ',nc_years';
    $query_params .= ',?';
    push(@params, $fields->{'nc_years'});
    
    # volums, numbers
    $query_fields .= ',nc_numbers';
    $query_params .= ',?';
    push(@params, $fields->{'nc_numbers'});
    
    # on non-digital catalog
    if ($fields->{'onempty'}) {
    
        # title 
        $query_fields .= ',nc_title';
        $query_params .= ',?';
        push(@params, $fields->{'nc_title'});
        
        # author
        $query_fields .= ',nc_author';
        $query_params .= ',?';
        push(@params, $fields->{'nc_author'});
        
        # publication year
        $query_fields .= ',nc_pubyear';
        $query_params .= ',?';
        push(@params, $fields->{'nc_pubyear'});
        
        # store address
        $query_fields .= ',nc_address';
        $query_params .= ',?';
        push(@params, $fields->{'nc_address'});
    }
    
    # on non-digital catalog or generic
    if ($fields->{'onempty'} || $fields->{'isgeneric'}) {
        
        # call number
        $query_fields .= ',nc_callnumber';
        $query_params .= ',?';
        push(@params, $fields->{'nc_callnumber'});
    }
    
    # on what
    if ($fields->{'onitem'}) {
        
        $query_fields .= ',onitem';
        $query_params .= ',?';
        push(@params, 1);
        
    } elsif ($fields->{'onserial'}) {
        
        $query_fields .= ',onserial';
        $query_params .= ',?';
        push(@params, $fields->{'onserial'});
        
    } elsif ($fields->{'onempty'}) {
        
        $query_fields .= ',onempty';
        $query_params .= ',?';
        push(@params, 1);
    }
    
    $query = 'INSERT INTO stack_requests ('.$query_fields.') VALUES ('.$query_params.')';
    
    #
    # Execute
    #
    
    my $sth = $dbh->prepare($query);	  
   	$sth->execute(@params);
    
    if ($fields->{'onitem'}) {
        # Change item state
        if ($fields->{'instantrq'}) {
            setItemOnStackRequest($fields->{'itemnumber'});
        } else {
            # stack request may be bocking, else item is available
            CheckItemAvailability($fields->{'itemnumber'}, undef);
        }
    }
    
    return $id;
}

##
# Retrieve item
#
# param : request from C4::Stack::Search
# param : desk code
# param (optionnal) : disable the sca notification
##
sub RetrieveStackRequest($$;$) {
    
    # input args
    my ($request, $retrieval_desk, $do_not_notify) = @_;
    
    # if no desk set, store undef
    if ($retrieval_desk && $retrieval_desk eq 'NO_DESK_SET') {
        undef $retrieval_desk;
    }
    
    my $dbh   = C4::Context->dbh;
    my $sth;
    my $new_end_date;
    
    # For delayed request, request expires the end date + guard period
    # Except if linked to a space
    if (!IsInstantStackRequest($request->{'request_number'}) && !$request->{'space_booking_id'}) {
        $new_end_date = GetEndDateWithGuardPeriod($request);
    }
    # For an instant request, don't modify end date
    
    my $query = '
            UPDATE stack_requests
            SET
                retrieval_ts = NOW(),
                delivery_desk = ?,
                state = ?
        ';
    my @params = ($retrieval_desk, $STACK_STATE_RUNNING);        
    if ($new_end_date) {
        $query .= ', end_date = ?';
        push(@params, $new_end_date);
    }
    $query .= ' WHERE request_number = ?';
    push(@params, $request->{'request_number'});
    
    $sth = $dbh->prepare($query);
    $sth->execute(@params);
    
    # Change item state
    if ( $request->{'space_booking_id'} ){
        # linked to a space
        setItemOnStack($request->{'itemnumber'});
    } else {
        setItemWaitStack($request->{'itemnumber'}, $retrieval_desk);
        
        #Notify the space booking application in case the GTC need to be informed
        NotifyRetrieval($request->{'borrowernumber'}) unless $do_not_notify;
    }
    
    # Udpate last seen date of item
    ModDateLastSeen( $request->{'itemnumber'} );
}

##
# Deliver item
#
# param : request from C4::Stack::Search
# param : desk code
# param (optionnal) : disable the sca notification
##
sub DeliverStackRequest($$;$) {
    
    # input args
    my ( $request, $delivery_desk, $do_not_notify ) = @_;
    
    # if no desk set, store undef
    if ($delivery_desk && $delivery_desk eq 'NO_DESK_SET') {
        undef $delivery_desk;
    }
    
    # Set has delivered
    # and reset end date to today MAN257
    my $query = '
        UPDATE stack_requests
        SET
            delivery_ts = NOW(),
            delivery_desk = ?,
            end_date = CURDATE()
        WHERE request_number = ?
    ';
    
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    
    $sth->execute($delivery_desk, $request->{'request_number'});
    
    # Change item state
    setItemOnStack($request->{'itemnumber'});
    
    #Notify the space booking application in case the GTC need to be informed
    NotifyDelivery($request->{'borrowernumber'}) unless $do_not_notify;
    
    # Udpate last seen date of item
    ModDateLastSeen( $request->{'itemnumber'} );
}

##
# Undeliver item
#
# param : request from C4::Stack::Search
# param : desk code
##
sub UndeliverStackRequest($$) {
    
    # input args
    my ($request, $desk_code) = @_;
    
        # if no desk set, store undef
    if ($desk_code && $desk_code eq 'NO_DESK_SET') {
        undef $desk_code;
    }
    
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare('
        UPDATE stack_requests
        SET
            delivery_ts = NULL,
            delivery_desk = ?
        WHERE request_number = ?
    ');
    $sth->execute($request->{'request_number'});
    
    # Change item state
    setItemWaitStack($request->{'itemnumber'}, $desk_code);
}

##
# Return item and end stack request
##
sub AddReturnStack($$) {
    
	my ($stack_request, $return_desk) = @_;
    
    # if no desk set, store undef
    if ($return_desk && $return_desk eq 'NO_DESK_SET') {
        undef $return_desk;
    }

    my $dbh = C4::Context->dbh;
    my $sth;
    
    my $messages;
    my $borrower;
    
    my $itemnumber = $stack_request->{'itemnumber'};
    my $item = GetItem($itemnumber);
    
    # Get borrower informations
    $borrower = GetMemberDetails($stack_request->{'borrowernumber'});
    
    # perform return
    $sth = $dbh->prepare('
    	UPDATE stack_requests
    	SET
         	return_ts = NOW(),
         	return_desk = ?,
         	state = ?
    	WHERE request_number = ?
	');

	$sth->execute(
	   $return_desk,
	   $STACK_STATE_FINISHED,
	   $stack_request->{'request_number'}
	);
	
	_archiveStack($stack_request->{'request_number'});
	LiftBorrowerDebarred2( $stack_request->{'borrowernumber'} );
    $messages->{'WasReturned'} = 1;
    
    if ($stack_request->{'onserial'} || $stack_request->{'onempty'}) {
        # item is temporary for circulation, delete it
        if (IsStackItemsTempTemporary($itemnumber)) {
            DelStackItemsTempAndItem($itemnumber);
        }
        # check if item is deleted
        my $check_item = GetItem( $itemnumber );
        $itemnumber = 0 unless $$check_item{ 'itemnumber' };
    }
    
    if ( $itemnumber > 0) {
	    # update item infos
	    ModItem({ 'onloan' => undef }, undef, $itemnumber);
	    ModDateLastSeen($itemnumber);
	    CheckItemAvailability(undef, $item, $return_desk); # istate
	
	    # find reserves
	    my ($resfound, $resrec) = CheckReserves($itemnumber);
	    if ($resfound) {
	          $resrec->{'ResFound'} = $resfound;
	        $messages->{'ResFound'} = $resrec;
	    }
    } else {
    	# Mantis 375 : Keep item information
    }
    
    # item infos
    if ( $item->{'wthdrawn'} ) {
        $messages->{'wthdrawn'} = 1;
    }
    if ($item->{'itemlost'}) {
        $messages->{'WasLost'} = 1;
    }

	return ( $messages, $stack_request, $borrower );
}

##
# Cancel request from OPAC
#
# Use one or the other input param
#
# param : request id
# param : request from C4::Stack::Search
##
sub CancelStackRequestFromOPAC($;$) {
    my ($request_number,$request) = @_;
    CancelStackRequest($request_number, $request, $AV_SR_CANCEL_USER);
}

##
# Cancel request
#
# Use one or the other two first input param
#
# param : request id
# param : request from C4::Stack::Search
# param : cancel code
##
sub CancelStackRequest($$$) {
    
    # input args
    my ($request_number, $request, $cancel_code) = @_;
    
    if ($request) {
        $request_number = $request->{'request_number'};
    } else {
        $request = GetStackById($request_number);
    }
    unless ($request){
        return undef;
    }
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    my $query;
    my @params;
    
    $query = '
        UPDATE stack_requests
        SET
            cancel_code = ?,
            cancel_ts = NOW()
    ';
    push(@params, $cancel_code);
    
    # For a running request whose item is in desk, short end date to today
    # (MAN347 also avoid date change on expiration)
    if ( $request->{'state'}  eq $STACK_STATE_RUNNING
      && $request->{'istate'} ne $ISTATE_ON_STACK
      && $request->{'end_date'} gt C4::Dates->new()->output("iso") )
    {
        $query .= ', end_date = CURDATE()';
    }
    
    $query .= ' WHERE request_number = ?';
    push(@params, $request_number);
    
    $sth = $dbh->prepare($query);
    $sth->execute(@params);
    
    #
    # If Asked or Edited state, archive
    #
    if ($request->{'state'} eq $STACK_STATE_ASKED || $request->{'state'} eq $STACK_STATE_EDITED) {
        _archiveStack($request_number);
        
        # Change item state
        CheckItemAvailability($request->{'itemnumber'}, undef);
    }
}

##
# Renew request 
#
# Use one or the other two first input param
#
# param : request id
# param : request from C4::Stack::Search
# param : new end date in ISO
# param : store in desk (optionnal)
# param : desk code (optionnal)
##
sub RenewStackRequest($$$;$;$) {
    
    # input args
    my ($request_number, $request, $new_end_date, $store, $desk_code) = @_;
    
    if ($request) {
        $request_number = $request->{'request_number'};
    } else {
        $request = GetStackById($request_number);
    }
    unless ($request){
        return undef;
    }
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
            UPDATE stack_requests SET
                renew_ts = NOW(),
                end_date = ?,
                renewals = renewals + 1
            WHERE request_number = ?
    ');
    $sth->execute(
        $new_end_date,
        $request_number
    );
    
    #
    # If reserve exists, limit renewal to 1 time
    #
    my @checkreserv = GetReservesFromItemnumber($request->{'itemnumber'});
    if ( $checkreserv[0] ) {
        _setLimitedRenewal($request_number);
    }
    
    if ($store) {
        # if no desk set, means undef
        if ($desk_code && $desk_code eq 'NO_DESK_SET') {
            undef $desk_code;
        }
        
        # Change item state
        setItemWaitRenew($request->{'itemnumber'}, $desk_code);
    }
}

##
# Limit renewal
#
# param : request id
##
sub _setLimitedRenewal($) {
    
    # input args
    my $request_number = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
            UPDATE stack_requests
            SET limit_renewal = 1
            WHERE request_number = ?
    ');
    $sth->execute($request_number);
}

##
# Cancel request by spaces application
#
# param : space id
##
sub CancelStackRequestBySpace($) {
    
    # input args
    my $space_id = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
            UPDATE stack_requests
            SET end_date = CURDATE()
            WHERE space_booking_id = ?
    ');
    $sth->execute(
        $space_id
    );
}

##
# Renew request by spaces application
#
# param : space id
# param : end date in ISO
##
sub RenewStackRequestBySpace($$) {
    
    # input args
    my ($space_id, $end_date) = @_;
    
    # local vars
    my $daysbeforestack = C4::Context->preference('DelayBeforeDifferedStack') || 0;
    my $dbh = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare("
        SELECT request_number
        FROM stack_requests AS strq
        WHERE space_booking_id = ? AND begin_date < NOW()
    ");
    
    $sth->execute($space_id);
    my $result = $sth->fetchall_arrayref({});
    
    my $total = 0;
    my $updated = 0;
    my $partially_updated = 0;
    
    foreach (@$result) {
        $total = $total + 1;
        my $request_number = $_->{'request_number'};
        
        my ($end_date_renewal, $renew_impossible, $renew_confirm) = CanRenewRequestStack($request_number, undef, 1, 1, $end_date);
    
        if (!scalar keys %$renew_impossible) {
            if (!scalar keys %$renew_confirm) {
            	RenewStackRequest($request_number, undef, $end_date_renewal);
            	if ($end_date eq $end_date_renewal) {
            	   $updated = $updated + 1;
            	} else {
            	   $partially_updated = $partially_updated + 1;
            	}
    	    }
        }
    }
    
    return ($updated, $partially_updated, $total);
    
}

##
# End or cancel request by spaces application
#
# param : space id
# param : end date in ISO
##
sub EndStackRequestBySpace($) {
    
    # input args
    my ($space_id) = @_;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    my $numberOfOpenStacks = 0;
    
    $sth = $dbh->prepare("SELECT request_number, state FROM stack_requests AS strq WHERE space_booking_id = ?");
    $sth->execute($space_id);
    
    my $rows = $sth->fetchall_arrayref({});
    foreach my $row ( @{$rows} ) {
        my $requestnumber = @$row{'request_number'};
        my $state = @$row{'state'};
        if ($state eq $STACK_STATE_ASKED || $state eq $STACK_STATE_EDITED) {
        	CancelStackRequest($requestnumber, undef, $AV_SR_CANCEL_USER);
        } else {
        	$sth = $dbh->prepare('UPDATE stack_requests SET renew_ts = NOW(), end_date = NOW() WHERE request_number = ?');
            $sth->execute($requestnumber);
            $numberOfOpenStacks++;
        }
    }
    
    return $numberOfOpenStacks;
}

##
# Change state
#
# param : request id
# param : character representing state (see C4::Stack::Constants)
##
sub _changeState($$) {
    
    # input args
    my ( $request_number, $state ) = @_;
    
    # local vars
    my $dbh   = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
            UPDATE stack_requests
            SET state = ?
            WHERE request_number = ?
        ');
    $sth->execute($state, $request_number);
    
}

##
# Save a stack into old stacks table
#
# param : request number
##
sub _archiveStack($) {
    
    # input args
    my $request_number = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    # Copy to olds table
    $sth = $dbh->prepare('
            INSERT INTO old_stack_requests
                (SELECT * FROM stack_requests sr WHERE sr.request_number = ?);
        ');
    $sth->execute($request_number);
    
    # Delete from current table
    $sth = $dbh->prepare('
            DELETE FROM stack_requests WHERE request_number = ?;
        ');
    $sth->execute($request_number);
    
}

##
# Expire stacks
# 
# return : number of expired
##
sub ExpireStacks() {

    my $stack_to_be_expired;
    my $today = C4::Dates->new()->output('iso');
    
    #
    # MAN347
    # Expire all stacks with end date lower or equal than yesterday
    #
    my ( $yyear, $ymonth, $yday ) = Add_Delta_Days( Today(), -1 );
    my $yesterday_iso = sprintf( "%04d-%02d-%02d", $yyear, $ymonth, $yday );
    my $stack_to_be_expired = GetStacksByCriteria(undef, $yesterday_iso);
    
    #
    # Cancel stacks with cancel_code « expired »,
    #
    my $expired_nb = 0;
    foreach my $stack (@$stack_to_be_expired) {
        # Test if already expired
        unless ($stack->{'cancel_code'} && $stack->{'cancel_code'} eq $AV_SR_CANCEL_EXPIRED) {
            CancelStackRequest(undef, $stack, $AV_SR_CANCEL_EXPIRED);
            $expired_nb++;
        }
    }
    
    return $expired_nb;
}

##
# Auto return stacks for a next request
# 
# param : next stack request
# return : returned count
# return : not returned count
##
sub AutoReturnPrevStacks($) {
    
    my $next_request = shift;
    
    my @stack_to_be_auto_returned;
    my $count_not_returned = 0;
    
    # Stacks on same item
    my $stacks = GetStacksByItemnumber($next_request->{'itemnumber'});
    
    foreach my $stack (@$stacks) {
        # begin date < next begin date
        if ( $stack->{'begin_date'} lt $next_request->{'begin_date'}) {
            # Stack to be cleaned
            if ($stack->{'istate'} eq $ISTATE_ON_STACK) {
                # item is not in desk, can't return
                $count_not_returned++;
            } else {
                push (@stack_to_be_auto_returned, $stack);              
            }
        }
    }
    
    #
    # Cancel stacks with cancel_code « returned auto » and return them
    #
    foreach my $stack (@stack_to_be_auto_returned) {
        CancelStackRequest(undef, $stack, $AV_SR_CANCEL_AUTORET);
        # If asked, already archived
        unless ($stack->{'state'} eq $STACK_STATE_ASKED) {            
            AddReturnStack($stack, undef);
        }
    }
    
    return (scalar @stack_to_be_auto_returned, $count_not_returned);
}

##
# Edit Stack
#
# param : request from C4::Stack::Search
##
sub EditStackRequest($) {
    
    # input args
    my $request = shift;
    
    my $dbh   = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
            UPDATE stack_requests
            SET state = ?,
                edition_ts = NOW()
            WHERE request_number = ?
        ');
    $sth->execute($STACK_STATE_EDITED, $request->{'request_number'});
    
    # Update item state
    # (already done on creation for instant request)
    setItemOnStackRequest($request->{'itemnumber'});
}


##
# Set itemnumber (for temp items)
#
# param : request id
# param : item id
##
sub SetItemNumber($$) {
    
    # input args
    my $request_number = shift;
    my $itemnumber = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
            UPDATE stack_requests
            SET itemnumber = ?
            WHERE request_number = ?
    ');
    $sth->execute( $itemnumber, $request_number );
}

#
# Update item istate of asked stack requests that will become blocking
# (begin date between tomorrow and tomorrow + secure days)
#
sub CheckBlockingStacks() {
    
    my ( $tyear, $tmonth, $tday ) = Add_Delta_Days( Today(), 1 );
    my $min_begin_date = sprintf( "%04d-%02d-%02d", $tyear, $tmonth, $tday );
    
    my $secure_days = C4::Context->preference('DelayBeforeDifferedStack') || 0;
    $secure_days += 1; # Begin day doesn't count in delay
    
    my ( $syear, $smonth, $sday ) = Add_Delta_Days( $tyear, $tmonth, $tday, $secure_days );
    my $max_begin_date = sprintf( "%04d-%02d-%02d", $syear, $smonth, $sday );
    
    my $blo_sr = GetStacksByCriteria($min_begin_date, $max_begin_date, $STACK_STATE_ASKED);
    foreach (@$blo_sr) {
        my $itemnumber = $_->{'itemnumber'};
        my $item = GetItem($itemnumber);
        my $istate = $item->{'istate'};
        if (undef $istate) {
            setItemOnStackRequest($itemnumber);
        } elsif ($istate eq $ISTATE_RES_GUARD) {
        	setItemOnStackRequest($itemnumber);
        	CancelReserve($item->{'biblionumber'}, $itemnumber, $_->{'borrowernumber'});
        }
    }
}

1;
__END__
