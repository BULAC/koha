package C4::Stack::Rules;

##
# B03X : Rules
##

use strict;

use vars qw($VERSION @ISA @EXPORT);

use Date::Calc qw(
    Today
    Add_Delta_YM
    Add_Delta_Days
    Date_to_Days
    Delta_Days
);
use C4::Biblio qw(GetBiblioFromItemNumber);
use C4::Callnumber::Utils;
use C4::Circulation qw(GetIssuingRule);
use C4::Context;
use C4::Dates qw(format_date format_date_in_iso);
use C4::Items qw(GetItemsCount GetItem IsItemAvailable);
use C4::Members qw(GetMember GetMemberDetails CheckBorrowerDebarred2);
use C4::Reserves;
use C4::Serials qw(GetSubscriptionsFromBiblionumber);
#use C4::Spaces::Connector;
use C4::Stack::Desk;
use C4::Stack::Search;
use C4::Utils::Constants;

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &CanRequestStackOnBiblio
        &CanRequestStackOnItem
        &CanCancelRequestStack
        &CanRenewRequestStack
        
        &GetBorrowerControls
        &GetIssuingControls
        
        &GetDefaultDateForStackRequest
        &GetSpaceReservationFromDate
        &GetIssuingRuleForStack        
        &GetEndDateWithGuardPeriod
        
        &IsInstantStackRequest
        
        &ComputeStackEndDate
        &IsBranchOpen
    );
}

##
# Get borrower raisons why he can't create a stack request
# 
# param : borrower infos from GetMemberDetails
# return : array of hashs containing error codes
##
sub GetBorrowerControls($){
    
    # input args
    my $borrower = shift;
    
    # local vars
    my @ret;
    
    #
    # Check expiration
    # (see circulation.pl)
    #
    # Warningdate is the date that the warning starts appearing
    my (  $today_year,   $today_month,   $today_day) = Today();
    my ($warning_year, $warning_month, $warning_day) = split /-/, $borrower->{'dateexpiry'};
    my (  $enrol_year,   $enrol_month,   $enrol_day) = split /-/, $borrower->{'dateenrolled'};
    # Renew day is calculated by adding the enrolment period to today
    my (  $renew_year,   $renew_month,   $renew_day);
    if ($enrol_year*$enrol_month*$enrol_day>0) {
        (  $renew_year,   $renew_month,   $renew_day) =
        Add_Delta_YM( $enrol_year, $enrol_month, $enrol_day,
            0 , $borrower->{'enrolmentperiod'});
    }
    # if the expiry date is before today ie they have expired
    if ( $warning_year*$warning_month*$warning_day==0 
        || Date_to_Days($today_year,     $today_month, $today_day  ) 
         > Date_to_Days($warning_year, $warning_month, $warning_day) )
    {
        # borrowercard expired
        push(@ret, {
            'EXPIRED' => format_date($borrower->{'dateexpiry'})
        });
    }
    
    #
    # Flags
    #
    my $flags = $borrower->{'flags'};
    foreach my $flag ( sort keys %$flags ) {
        if ( $flag eq 'GNA' ) {
            push(@ret, {
                $flag => 1
            });
        }
        elsif ( $flag eq 'LOST' ) {
            push(@ret, {
                $flag => 1
            });
        }
        elsif ( $flag eq 'DOCS' ) {
            push(@ret, {
                $flag => 1
            });
        }
        elsif ( $flag eq 'DBARRED2' ) {
            push(@ret, {
                DEBARRED2 => 1,
                nb_overdue => $flags->{$flag}->{'nb_overdue'}
            });
            if ( $flags->{$flag}->{'dateend'} ne "9999-12-31" ) {
            	push(@ret, {
                    userdebarred2date => format_date($flags->{$flag}->{'dateend'})
                });
            }
        }
    }
    
    return \@ret;
}

##
# Get issuing rules raisons why he can't create a stack request
# 
# param : borrower id
# param : item id (may be undef)
# param : is a instant request
# param : begin date in ISO (useless if space)
# param : space (optionnal)
# param : item is in reserve (optionnal)
# return : error codes and confirmation codes
##
sub GetIssuingControls($$$$;$$){
    
    my ($borrowernumber, $itemnumber, $instantrq, $begdate, $reserved_space, $item_in_reserve) = @_;
    my @cant_request;
    my @needs_confirm;
    
    my $itemtype;
    if ($itemnumber) {
        my $item = GetBiblioFromItemNumber($itemnumber, undef);
        $itemtype = (C4::Context->preference('item-level_itypes')) ? $item->{'itype'} : $item->{'itemtype'};
    }
    
    my $all_itype_issuingrule = GetIssuingRuleForStack($borrowernumber, undef);
    my $exact_itype_issuingrule;
    if ($itemnumber) {
        $exact_itype_issuingrule = GetIssuingRuleForStack($borrowernumber, $itemnumber);
    }
    
    my $item_in_reserve_for_space = 0;
    if ($item_in_reserve) {
    	if ( GetReservedSpaceByDate($borrowernumber, $begdate, 1) ) {
    		$item_in_reserve_for_space = 1;
    	}
    }
    
    #
    # Check number of stack requests
    #
    my $too_many_stacks;
    my $bor_stacks_nb;
    my $max_stacks_nb;
    my $matching_rule;
    
    if ($itemtype) {
        $bor_stacks_nb = _countStacksOfBorrower('all', $borrowernumber, $itemtype);
        if ($reserved_space || $item_in_reserve_for_space) {
            # Quota for a stack into a space
            $max_stacks_nb = $exact_itype_issuingrule->{'spacemaxstackqty'};
        } else {
            $max_stacks_nb = $exact_itype_issuingrule->{'maxstackqty'};
        }
        if ($bor_stacks_nb >= $max_stacks_nb) {
            $too_many_stacks = 1;
            $matching_rule = $exact_itype_issuingrule;
        }
    }
    unless ($too_many_stacks) {
        # all item types
        $bor_stacks_nb = _countStacksOfBorrower('all', $borrowernumber);
        if ($reserved_space || $item_in_reserve_for_space) {
            # Quota for a stack into a space
            $max_stacks_nb = $all_itype_issuingrule->{'spacemaxstackqty'};
        } else {
            $max_stacks_nb = $all_itype_issuingrule->{'maxstackqty'};
        }
        if ($bor_stacks_nb >= $max_stacks_nb) {
            $too_many_stacks = 1;
            $matching_rule = $all_itype_issuingrule;
        }
    }
    if ($too_many_stacks) {
        push(@needs_confirm, {
            'TOO_MANY_SR' => "$bor_stacks_nb/$max_stacks_nb [".$matching_rule->{'branchcode'}."-".$matching_rule->{'itemtype'}."]"
        });
    }
    
    if ($instantrq) {
        
        #
        # Check number of instant stack requests
        #
        undef $too_many_stacks;
        undef $bor_stacks_nb;
        undef $max_stacks_nb;
        undef $matching_rule;
        
        if ($itemtype) {
            $bor_stacks_nb = _countStacksOfBorrower('instant', $borrowernumber, $itemtype);
            if ($reserved_space || $item_in_reserve_for_space) {
                # Quota for a stack into a space
                $max_stacks_nb = $exact_itype_issuingrule->{'spacemaxinstantstackqty'};
            } else {
                $max_stacks_nb = $exact_itype_issuingrule->{'maxinstantstackqty'};
            }
            if ($bor_stacks_nb >= $max_stacks_nb) {
                $too_many_stacks = 1;
                $matching_rule = $exact_itype_issuingrule;
            }
        }
        unless ($too_many_stacks) {
            # all item types
            $bor_stacks_nb = _countStacksOfBorrower('instant', $borrowernumber);
            if ($reserved_space || $item_in_reserve_for_space) {
                # Quota for a stack into a space
                $max_stacks_nb = $all_itype_issuingrule->{'spacemaxinstantstackqty'};
            } else {
                $max_stacks_nb = $all_itype_issuingrule->{'maxinstantstackqty'};
            }
            if ($bor_stacks_nb >= $max_stacks_nb) {
                $too_many_stacks = 1;
                $matching_rule = $all_itype_issuingrule;
            }
        }
        if ($too_many_stacks) {
            push(@needs_confirm, {
                'TOO_MANY_INST' => "$bor_stacks_nb/$max_stacks_nb [".$matching_rule->{'branchcode'}."-".$matching_rule->{'itemtype'}."]"
            });
        }
        
    } else {
        
        #
        # Check number of delayed stack requests
        #
        undef $too_many_stacks;
        undef $bor_stacks_nb;
        undef $max_stacks_nb;
        undef $matching_rule;
        
        if ($itemtype) {
            $bor_stacks_nb = _countStacksOfBorrower('delayed', $borrowernumber, $itemtype);
            if ($reserved_space || $item_in_reserve_for_space) {
                # Quota for a stack into a space
                $max_stacks_nb = $exact_itype_issuingrule->{'spacemaxdelayedstackqty'};
            } else {
                $max_stacks_nb = $exact_itype_issuingrule->{'maxdelayedstackqty'};
            }
            if ($bor_stacks_nb >= $max_stacks_nb) {
                $too_many_stacks = 1;
                $matching_rule = $exact_itype_issuingrule;
            }
        }
        unless ($too_many_stacks) {
            # all item types
            $bor_stacks_nb = _countStacksOfBorrower('delayed', $borrowernumber);
            if ($reserved_space || $item_in_reserve_for_space) {
                # Quota for a stack into a space
                $max_stacks_nb = $all_itype_issuingrule->{'spacemaxdelayedstackqty'};
            } else {
                $max_stacks_nb = $all_itype_issuingrule->{'maxdelayedstackqty'};
            }
            if ($bor_stacks_nb >= $max_stacks_nb) {
                $too_many_stacks = 1;
                $matching_rule = $all_itype_issuingrule;
            }
        }
        if ($too_many_stacks) {
            push(@needs_confirm, {
                'TOO_MANY_DELAY' => "$bor_stacks_nb/$max_stacks_nb [".$matching_rule->{'branchcode'}."-".$matching_rule->{'itemtype'}."]"
            });
        }
    }
    
    #
    # Check other requests
    #
    
        
    if ($instantrq) {
        # Instant request
        if (GetBlockingStackRequest($itemnumber)) {
            push(@cant_request, {
                'BLOCKING_SR' => 1
            });
        }
    } else {
        # Delayed request
        unless (_canCreateDelayedAtDate($itemnumber, $begdate)) {
            push(@cant_request, {
                'BLOCKING_SR' => 1
            });
        }
    }

    
    return \@cant_request, \@needs_confirm;
}

##
# Exists a stack request for this item (not canceled)
#
# param : item id
# param : only linked to a space
# return undef or the closest existing request
##
sub _existsStackRequestOnItem($;$) {
        
    my $itemnumber = shift;
    my $onlyonspace = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    my $query = '
            SELECT * FROM stack_requests
            WHERE
                itemnumber = ?
    ';
    if ($onlyonspace) {
        $query .= ' AND space_booking_id IS NOT NULL';
    }
    $query .= ' ORDER BY begin_date ASC LIMIT 1';
    
    $sth = $dbh->prepare($query);
    $sth->execute($itemnumber);
    my $data = $sth->fetchall_arrayref({});
    
    if (scalar @$data){
        return $$data[0];
    }
    
    return undef;
}

##
# Can create delayed stack request at specified date
#
# param  : item id
# param  : date in ISO
# return : 1 or undef
##
sub _canCreateDelayedAtDate($$) {
    
    my ($itemnumber, $begdate) = @_;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    my $daysbeforestack = C4::Context->preference('DelayBeforeDifferedStack') || 0;
    my $daysbetween = $daysbeforestack + 1; # Begin day doesn't count in delays
    
    # look for a too close request
    # you must ensure 1 renewal and days before a request begin
    $sth = $dbh->prepare('
            SELECT * FROM stack_requests
            WHERE
                itemnumber = ?
                AND ABS(DATEDIFF(begin_date, ?)) < ?
            ORDER BY begin_date ASC
            LIMIT 1
    ');
    $sth->execute($itemnumber, $begdate, $daysbetween);
    my $data = $sth->fetchall_arrayref({});
        
    return (scalar @$data) ? undef : 1;
}

##
# Can request stack on biblio ?
# 
# param  : biblio id
# return : 1 for allow, undef for don't allow
##
sub CanRequestStackOnBiblio($){
    
    # input args
    my $biblionumber = shift;
    
    # If items exists, then stack requests not on biblio but on items
    if (_getRealItemsCount($biblionumber)) {
        return undef;
    }
    
    # If serial then allow requests on biblio
    my $serials = GetSubscriptionsFromBiblionumber($biblionumber);
    unless ( scalar $serials) {
        return undef;
    }
    # MAN260 can't request out of BULAC branch (for the moment)
    my $bulac_serial;
    foreach my $branch ( map { $_->{'branchcode'} } @$serials ) {
       if ($branch && $branch eq $BULAC_BRANCH) {
           $bulac_serial = 1;
       }
    }
    unless ($bulac_serial) {
        return undef;
    }
    # END MAN260

    # All tests passed
    return 1;
}

##
# Get items count without temporaries
##
sub _getRealItemsCount {
    
    my $biblionumber = shift;
    my $dbh = C4::Context->dbh;
    
    my $query = '
        SELECT COUNT(*)
        FROM items
        LEFT JOIN stack_items_temp USING (itemnumber)
        WHERE stack_items_temp.itemnumber IS NULL
        AND items.biblionumber=?
    ';
    my $sth = $dbh->prepare($query);
    $sth->execute($biblionumber);
    my $count = $sth->fetchrow;  
    
    return $count;
}

##
# Can cancel request stack.
#
# Use one or the other input param.
# 
# param : request id
# param : request (must come from C4::Stack::Search)
# 
# return : 1 for allow, undef for don't allow
##
sub CanCancelRequestStack($;$) {
    
    # input args
    my ($request_number, $request) = @_;
    
    if ($request) {
        $request_number = $request->{'request_number'};
    } else {
        $request = GetStackById($request_number);
    }
    
    # Request doesn't exist
    unless ($request) {
        return undef;
    }
    
    # Can't cancel a canceled request
    if ( $request->{'cancel_code'} ) {
        return undef;
    }
        
    # Can't cancel a running request whose item is on stack
    if ( $request->{'state'}  eq $STACK_STATE_RUNNING
      && $request->{'istate'} eq $ISTATE_ON_STACK)
    {
        return undef;
    }

    # All tests passed
    return 1;
}

##
# Can request stack on item ?
# 
# param  : item id
# return : 1 for yes, undef for no
##
sub CanRequestStackOnItem($;$) {
    
    # input args
    my $itemnumber = shift;
    my $ignore_istates = shift;
    
    my $item = GetBiblioFromItemNumber($itemnumber);
    unless ($item->{'itemnumber'}) {
        return undef;
    }
    
    # MAN260 can't request out of BULAC branch (for the moment)
    unless ($item->{'holdingbranch'} && $item->{'holdingbranch'} eq $BULAC_BRANCH) {
        return undef;
    }
    # END MAN260
    
    # item must be stackable or loanable
    # MAN106 or serial generic item
    my $item_status = $item->{'notforloan'};
    unless (defined $item_status && (
        $item_status eq $AV_ETAT_LOAN
     || $item_status eq $AV_ETAT_STACK
     || $item_status eq $AV_ETAT_GENERIC
    )) {
        return undef;
    }
    
    # item must be in store
    my $is_in_store = IsItemInStore($itemnumber);
    unless ($is_in_store) {
        return undef;
    }
    
    # item must be available
    my $is_available = IsItemAvailable($item, $ignore_istates);
    unless ($is_available) {
        return undef;
    }
        
    # All tests passed
    return 1;
}

##
# Get default date for a stack request
#
# param : branch
# param : itemtype
# param : spaces array ref
# return : C4::Dates object and if it is today
##
sub GetDefaultDateForStackRequest($$;$) {
    
    my $branch   = shift;
    my $itemtype = shift; # may be undef
    my $spaces   = shift;
    
    # local vars
    my $c4_today = C4::Dates->new();
    
    # Get today available desks
    my ($chour, $cmin) = GetCurrentHourAndMinute();
    my $desks_loop = GetAvailableDesksLoop($c4_today->output('iso'), $branch, $itemtype, undef, $chour, $cmin); # MAN113
    
    if (scalar @$desks_loop) {
        # a desk is open so propose today
        return ($c4_today, 1);
    }
    
    # try next open day or look for an open day included in a space booking, begining with today
    my $dnod_date;
    
    my $dnod_iso_date = GetDeskNextOpenDay($branch, $itemtype);
    if (defined $dnod_iso_date) {
        $dnod_date = C4::Dates->new($dnod_iso_date, 'iso');
    }
    
    my $ret_is_today;
    if ( defined $dnod_date && $dnod_date->output('iso') eq $c4_today->output('iso') ) {
        $ret_is_today = 1;
    }
    
    return ($dnod_date, $ret_is_today);
}

##
# Is branch open at date ?
#
# param : branch
# param : date in ISO
# return : 1 if true
##
sub IsBranchOpen($$) {
    
    my $branch = shift;
    my $iso_date = shift;
    
    my $calendar = C4::Calendar->new( branchcode => $branch );
    my ($year, $month, $day) = split /-/, $iso_date;
    
    if ( $calendar->isHoliday($day, $month, $year) ) {
        return undef;
    }
    return 1;
}

##
# Can renew request stack.
#
# Use one or the other input param
# 
# param : request id
# param : request (must come from C4::Stack::Search)
# param : ignore item state (optional)
# param : if the request is from a space renewal (optional)
# param : end date of the space renewal (optional)
# 
# return : new end date ISO (undef if can't renew), can't renew hash, can renew with confirmation hash
##
sub CanRenewRequestStack($$;$$$) {
    
    # input args
    my $request_number = shift;
    my $request = shift;
    my $ignore_istate = shift;
    my $from_space_renew = shift;
    my $end_date_space_renew = shift;
    
    if ($request) {
        $request_number = $request->{'request_number'};
    } else {
        $request = GetStackById($request_number);
    }
    unless ($request){
        return (undef, undef, undef);
    }
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    my %renew_impossible;
    my %renew_confirm;
    my $end_date_renewal;
    
    unless ($from_space_renew) {
        # Can't renew a request linked to a space
        if ( $request->{'space_booking_id'} ) {
            $renew_impossible{'SPACE_BOOKING'} = 1;
        }
    }
    
    # Can't renew a canceled request
    if ( $request->{'cancel_code'} ) {
        $renew_impossible{'CANCELED'} = 1;
    }
    
    #
    # Can only renew running requests
    #
    if ( $request->{'state'} ne $STACK_STATE_RUNNING ) {
        $renew_impossible{'NOT_RUNNING'} = 1;
    }
    
    my $itemnumber  = $request->{'itemnumber'};
    
    #
    # If reserve exists, renewal is limited to 1 time
    #
    my @checkreserv = GetReservesFromItemnumber($itemnumber);
    if ( $checkreserv[0] ) {
        if ( $request->{'limit_renewal'} ) {
            # one allowed renewal already used
            $renew_impossible{'ON_RESERVE'} = 1;
        }
    }
    
    # Item must be waiting in desk
    unless ($ignore_istate) {
        if ($request->{'istate'} ne $ISTATE_WAIT_RENEW
         && $request->{'istate'} ne $ISTATE_WAIT_STACK)
        {
            $renew_impossible{'NOT_IN_DESK'} = 1;
        }
    }
    
    my ($debar2, $nb_overdue) = CheckBorrowerDebarred2($request->{'borrowernumber'});
    if ($debar2) {
	    $renew_impossible{'DEBARRED2'} = 1;
	}
	
    if (scalar keys %renew_impossible) {
        return (undef, \%renew_impossible, \%renew_confirm);
    }
    
    unless ($from_space_renew) {
        #  
        # If number of renewals allowed per stack exceeded
        #
        
        # Find issuing rule params
        my $issuingrule = GetIssuingRuleForStack($request->{'borrowernumber'}, $itemnumber);
        if ($request->{'renewals'} >= $issuingrule->{'stackrenewalsallowed'}) {
            # Too many renewals
            $renew_confirm{'TOO_MANY_RENEWALS'} = $request->{'renewals'}."/".$issuingrule->{'stackrenewalsallowed'};
        }
        
        #
        # If number of renewals allowed per borrower exceeded
        #
        my $itemtype = (C4::Context->preference('item-level_itypes')) ? $request->{'itype'} : $request->{'itemtype'};
        my $borr_stacks_renewals = _countRenewedStacksOfBorrower( $request->{'borrowernumber'}, $itemtype );
        if ($borr_stacks_renewals >= $issuingrule->{'maxstackrenewalqty'}) {
            $renew_confirm{'TOO_MANY_RENEWAL_QTY'} = $borr_stacks_renewals."/".$issuingrule->{'maxstackrenewalqty'};
        }
    }
    
    #
    # Find renew end date
    #
    my $renewalperiod = _getStackRenewalPeriod($itemnumber);
    my $max_end_date = undef;

    # you must ensure days before a request begin
    my $daysbeforestack = C4::Context->preference('DelayBeforeDifferedStack') || 0;
    
    #Retrieve the library
    my $borrinfo = GetMemberDetails( $request->{'borrowernumber'}, undef );
    my $borrbranch = $borrinfo->{'branchcode'};
    
    # get next request (not canceled)
    $sth = $dbh->prepare('
            SELECT * FROM stack_requests
            WHERE
                itemnumber = ?
                AND begin_date > NOW()
            ORDER BY begin_date ASC
            LIMIT 1
    ');
    $sth->execute($itemnumber);
    my $data = $sth->fetchall_arrayref({});

    if (scalar @$data) {

        # There is a next request
        my $next_request = $$data[0];
        my $next_begdate = $next_request->{'begin_date'};
        
        # -1 jour pour avoir une durée de garde stricte
        $max_end_date = ComputeStackEndDate( $next_begdate, -$daysbeforestack - 1, $borrbranch, sprintf("%04d-%02d-%02d", Today()) );
        my $next_available_date = ComputeStackEndDate( sprintf("%04d-%02d-%02d", Today()), 1, $borrbranch );

        if ($next_available_date ge $max_end_date) {
            # can't renew, next request is blocking
            $renew_impossible{'BLOCKING_SR'} = 1;
        }

    }

    if (defined($end_date_space_renew)) {
    	if (defined($max_end_date) && $max_end_date le $end_date_space_renew) {
            $end_date_renewal = ComputeStackEndDate( sprintf("%04d-%02d-%02d", Today()), 100000, $borrbranch, $max_end_date );
        } else {
            $end_date_renewal = ComputeStackEndDate( sprintf("%04d-%02d-%02d", Today()), 100000, $borrbranch, $end_date_space_renew );
        }
    } else {
        $end_date_renewal = ComputeStackEndDate( sprintf("%04d-%02d-%02d", Today()), $renewalperiod, $borrbranch, $max_end_date );
    }

    if ($end_date_renewal le $request->{'end_date'}) {
        $renew_impossible{'ALREADY_RENEWED'} = 1;
        $end_date_renewal = undef;
    }

    return ($end_date_renewal, \%renew_impossible, \%renew_confirm);
}

##
# Get number of stacks of borrower
#
# param  : request type : all, instant, delayed
# param  : borrower number
# param  : item type (optional)
# return : number
##
sub _countStacksOfBorrower($$;$) {
    
    my $request_type = shift;
    my $borrower_number = shift;
    my $itemtype = shift;
    
    # local vars
    my $count = 0;
    my $count_old = 0;
    my $dbh = C4::Context->dbh;
    my $sth;
    my $data;
    
    #
    # Count active requests
    #
    
    my $query = '
        SELECT COUNT(*) AS nb
        FROM stack_requests
    ';
            
    if ($itemtype) {
        # rule has specific item type, so count on that specific item type
        $query .= '
            LEFT JOIN items USING (itemnumber)
            ';
        if (C4::Context->preference('item-level_itypes')) {
            $query .= '
                WHERE items.itype = ?
            ';
        } else { 
            $query .= '
                LEFT JOIN  biblioitems USING (biblionumber) 
                WHERE biblioitems.itemtype= ?
            ';
        }
        $query .= '
            AND stack_requests.borrowernumber = ?
        ';
    } else {
        $query .= '
            WHERE stack_requests.borrowernumber = ?
        ';
    }
    
    if ($request_type eq 'instant') {
        $query .= '
            AND DATE(stack_requests.creation_ts) = stack_requests.begin_date
        ';
    } elsif ($request_type eq 'delayed') {
        $query .= '
            AND DATE(stack_requests.creation_ts) <> stack_requests.begin_date
        ';
    }
    
    $sth = $dbh->prepare($query);
    if ($itemtype) {
        $sth->execute($itemtype, $borrower_number);
    } else {
        $sth->execute($borrower_number);
    }
    $data = $sth->fetchrow_hashref;
    $count = $data->{'nb'};
    
    #
    # MAN149
    # Count today returned requests
    # MAN203 unless canceled when asked
    # MAN507 unless stack linked to space
    #
    
    $query =~ s/stack_requests/old_stack_requests/ig;
    
    $query .= '
        AND (
            DATE(old_stack_requests.return_ts) = CURDATE()
            OR
            DATE(old_stack_requests.cancel_ts) = CURDATE()
        )
        AND old_stack_requests.space_booking_id is NULL
        AND old_stack_requests.state <> ?
    ';
    
    $sth = $dbh->prepare($query);
    if ($itemtype) {
        $sth->execute($itemtype, $borrower_number, $STACK_STATE_ASKED);
    } else {
        $sth->execute($borrower_number, $STACK_STATE_ASKED);
    }
    $data = $sth->fetchrow_hashref;
    $count_old = $data->{'nb'};
    
    return 0 + $count + $count_old;
}

##
# Get number of renewed stacks of borrower
#
# param  : borrower number
# param  : item type
# return : number
##
sub _countRenewedStacksOfBorrower($$) {
    
    my $borrower_number = shift;
    my $itemtype = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    my $query = '
        SELECT COUNT(*) AS nb
        FROM stack_requests
    ';
    
    if ($itemtype) {
        # rule has specific item type, so count on that specific item type
        $query .= '
            LEFT JOIN items USING (itemnumber)
            ';
        if (C4::Context->preference('item-level_itypes')) {
            $query .= '
                WHERE items.itype = ?
            ';
        } else { 
            $query .= '
                LEFT JOIN biblioitems USING (biblionumber) 
                WHERE biblioitems.itemtype= ?
            ';
        }
        $query .= '
            AND stack_requests.borrowernumber = ?
        ';
    } else {
        $query .= '
            WHERE stack_requests.borrowernumber = ?
        ';
    }
    
    $query .= '
        AND stack_requests.renewals > 0
    ';
    
    $sth = $dbh->prepare($query);
    if ($itemtype) {
        $sth->execute($itemtype, $borrower_number);
    } else {
        $sth->execute($borrower_number);
    }
    my $data = $sth->fetchrow_hashref;
    
    return 0 + $data->{'nb'};
}

##
# Get issuing rule for stack request
# Branch code is tacken form item home/holding branch
# or form borrower if itemnumber is undefined (to get rule for all itemtypes)
#
# param : borrower number
# param : item number (optional)
# return : issuing rule (from C4::Circulation::GetIssuingRule)
##
sub GetIssuingRuleForStack($;$){
    
    # input param
    my ($borrowernumber, $itemnumber) = @_;
    
    my $itemtype;
    my $category;
    my $branch;
    
    if ($borrowernumber) {
        my $borrower = GetMember( 'borrowernumber' => $borrowernumber );
        $category = $borrower->{'categorycode'};
        
        unless ($itemnumber) {
            $branch = $borrower->{'branchcode'}; # MAN327
        }
    }
    
    if ($itemnumber) {
        my $item = GetBiblioFromItemNumber($itemnumber, undef);
        $itemtype = (C4::Context->preference('item-level_itypes')) ? $item->{'itype'} : $item->{'itemtype'};
        
        my $branchfield = C4::Context->preference('HomeOrHoldingBranch') || 'homebranch';
        $branch = $item->{$branchfield};
    }
    
    my $issuingrule = GetIssuingRule($category, $itemtype, $branch);
    
    return $issuingrule;
}

##
# Get strack renewal period form issuing rules
# Borrower category is not used because renewal period on an item
# must be the same for all borrowers to ensure communication schedule
#
# param : item number
# return : nb of days
##
sub _getStackRenewalPeriod($) {
    
    my $itemnumber = shift;
    
    my $issuingrule = GetIssuingRuleForStack(undef, $itemnumber);
    if ($issuingrule) {
        return $issuingrule->{'stackrenewalperiod'};
    }
    return 0;
}

##
# Is intant request ?
#
# param  : request number
# return : 1 or undef
##
sub IsInstantStackRequest($) {
    
    my $request_number = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
            SELECT COUNT(*) AS nb
            FROM stack_requests
            WHERE
                DATE(creation_ts) = begin_date
                AND request_number = ?
    ');
    $sth->execute($request_number);
    my $data = $sth->fetchrow_hashref;
    
    return ($data->{'nb'} == 1) ? 1 : undef;
}

##
# Get request end date with guard period
#
# param  : request
# return : date in ISO
##
sub GetEndDateWithGuardPeriod($) {
    
    my $request = shift;
    
    my $issuing_rule = GetIssuingRuleForStack($request->{'borrowernumber'}, $request->{'itemnumber'});
    my $guard_period = $issuing_rule->{'stackguardperiod'};
    if ($guard_period < 1) { 
        $guard_period = 1; 
    }    
          
    my $borrinfo = GetMemberDetails( $request->{'borrowernumber'}, undef );
    my $borrbranch = $borrinfo->{'branchcode'};

    my $new_end_date = ComputeStackEndDate( $request->{'begin_date'}, $guard_period, $borrbranch );

    return $new_end_date;
}

sub ComputeStackEndDate($$$;$) {

    my $start_date = shift;
    my $period = shift;
    my $branch = shift;
    my $max_date = shift || undef;
    my $towards_future = ($period > 0) ? 1 : -1; 

    my $end_date = $start_date;
    my $next_date = $start_date;

    while ( $period != 0 && (!defined $max_date || ($towards_future == 1 && $next_date lt $max_date) || ($towards_future == -1 && $next_date gt $max_date)) ) {
        $next_date = sprintf( "%04d-%02d-%02d", Add_Delta_Days( split(/-/, $next_date), $towards_future) );

        if ( IsBranchOpen( $branch, $next_date ) ) {
            $end_date = $next_date;
            $period = $period - $towards_future;
        }
    }

    return $end_date;
}



1;
__END__
