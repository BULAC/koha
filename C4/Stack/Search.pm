package C4::Stack::Search;

##
# B03X : Search stacks
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use C4::Context;
use C4::Dates qw(format_date);
use C4::Koha qw(GetAuthorisedValuesMap);
use C4::Utils::Constants;
use C4::Stack::Desk qw(GetDesksMap);
use C4::Serials qw/GetSubscriptionsFromBiblionumber/;
use C4::Biblio qw/GetBiblio/;

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &GetStackById
        &GetCurrentStackByItemnumber
        &GetAllOperationsStackByItemnumber
        
        &GetStacksByItemnumber
      	&GetStacksOfBorrower
      	&GetBiblioStacks
      	&CountStacksOfSpace
      	&GetStacksByCriteria
      	
      	&GetTodayInstantStackrequest
      	&GetBlockingStackRequest
    );
}

##
# Search stacks by  :
#  - id
#  - borrower
#  - item
#  - itemcurr
#
# param : search_by
# param : input hash
# param : with_old : search in finished requests, optional, default false
# param : order by
# param : limit rows number
#
# return an array of hash
##
sub _search_stacks($$;$$$) {

    # getting input args.
    my $search_by = shift;
    my $input = shift;
    my $with_old  = shift;
    my $order = shift;
    my $limit = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $where;
    my $ret = [];
    
    # params
    my @params;
    
    #
    # Build Query
    #
    
    # WHERE part        
    if ( $search_by eq 'id' ) {
        
        $where = 'stack_requests.request_number = ?';
        $limit = '1';
        push @params, $input->{'value'};
        
    } elsif ( $search_by eq 'borrower' ) {    
        
        $where = 'stack_requests.borrowernumber = ?';
        push @params, $input->{'value'};
        
    } elsif ( $search_by eq 'item' ) {
        
        $where = 'stack_requests.itemnumber = ?';
        push @params, $input->{'value'};
        
    } elsif ( $search_by eq 'itemcurr' ) {
        
        $where = 'stack_requests.itemnumber = ? AND (stack_requests.state = ? OR stack_requests.state = ?)';
        $limit = '1';
        push @params, $input->{'value'};
        push @params, $STACK_STATE_EDITED;
        push @params, $STACK_STATE_RUNNING;
        
    } elsif ( $search_by eq 'allop' ) {
        
        $where = 'stack_requests.itemnumber = ?';
        $limit = '1';
        push @params, $input->{'value'};

    } elsif ( $search_by eq 'biblio' ) {
        
        $where = 'items.biblionumber = ? AND (stack_requests.state <> ?)';
        push @params, $input->{'value'};
        push @params, $STACK_STATE_ASKED;
        
    } elsif ( $search_by eq 'criteria' ) {
        
        if ($input->{'begin_date'}) {
            $where .= 'begin_date >= ? AND ';
            push @params, $input->{'begin_date'};
        }
        if ($input->{'end_date'}) {
            $where .= 'end_date <= ? AND ';
            push @params, $input->{'end_date'};
        }
        if ($input->{'state'}) {
            $where .= 'state = ? AND ';
            push @params, $input->{'state'};
        }
        if ($input->{'canceled'}) {
            $where .= 'cancel_code is not null AND ';
        }
        if ($input->{'desk'}) {
            if ($input->{'desk'} =~ /^\^.*/ ) {
                $where .= '(delivery_desk <> ? OR delivery_desk IS NULL) AND ';
                push @params, substr($input->{'desk'}, 1);
            } else {                
                $where .= 'delivery_desk = ? AND ';
                push @params, $input->{'desk'};
            }
        }
        if ($input->{'begin_date_max'}) {
            $where .= 'begin_date <= ? AND ';
            push @params, $input->{'begin_date_max'};
        }
        
        $where .= ' true';
     
    } else {
        warn 'Unknown search mode';
        return $ret; # wrong search_by
    }
    
    my $query = '
            SELECT
                NULL AS isold,
                stack_requests.*,
                DATE(stack_requests.renew_ts) AS renew_date,
                
                IFNULL(items.biblionumber, deleteditems.biblionumber) AS biblionumber,
                IFNULL(items.itemcallnumber, deleteditems.itemcallnumber) AS itemcallnumber,
                IFNULL(items.cn_sort, deleteditems.cn_sort) AS cn_sort,
                IFNULL(items.barcode, deleteditems.barcode) AS barcode,
                IFNULL(items.itype, deleteditems.itype) AS itype,
                IFNULL(items.homebranch, deleteditems.homebranch) AS homebranch,
                IFNULL(items.holdingbranch, deleteditems.holdingbranch) AS holdingbranch,
                IFNULL(items.istate, deleteditems.istate) AS istate,
                IFNULL(items.holdingdesk, deleteditems.holdingdesk) AS holdingdesk,
                IFNULL(items.materials, deleteditems.materials) AS materials,
                IFNULL(items.enumchron, deleteditems.enumchron) AS enumchron,
                
                IFNULL(biblio.title, IFNULL(biblio_serial.title, deletedbiblio.title)) AS title,
                IFNULL(biblio.author, IFNULL(biblio_serial.author, deletedbiblio.author)) AS author,
                
                
                biblioitems.volume,
                biblioitems.number,
                biblioitems.itemtype,
                biblioitems.isbn,
                biblioitems.issn,
                biblioitems.publicationyear,
                biblioitems.publishercode,
                biblioitems.volumedate,
                biblioitems.volumedesc,
                
                borrowers.cardnumber,
                borrowers.surname,
                borrowers.firstname
            FROM stack_requests
                LEFT JOIN items                   ON (stack_requests.itemnumber          = items.itemnumber)
                LEFT JOIN deleteditems            ON (stack_requests.itemnumber          = deleteditems.itemnumber)
                LEFT JOIN borrowers               ON (stack_requests.borrowernumber      = borrowers.borrowernumber)
                LEFT JOIN biblio                  ON (items.biblionumber                 = biblio.biblionumber)
                LEFT JOIN deletedbiblio           ON (deleteditems.biblionumber          = deletedbiblio.biblionumber)
                LEFT JOIN biblio AS biblio_serial ON (stack_requests.serial_biblionumber = biblio_serial.biblionumber)
                LEFT JOIN biblioitems             ON (biblioitems.biblionumber           = IFNULL(biblio.biblionumber, biblio_serial.biblionumber))
            WHERE '.$where;
    
    # use old table
    if ($with_old) {
        my $old_query = $query;
        $old_query =~ s/NULL AS isold/1 AS isold/i; # isold field = true
        $old_query =~ s/stack_requests/old_stack_requests/ig;
        $query .= ' UNION ALL '.$old_query;
    }
    
    # sort order
    if ( $order ) {
        $query .= ' ORDER BY '.$order;
    }
    else{
    	$query .= ' ORDER BY 9 DESC'; # begin_date
    }
    
    # limit
    if ( $limit ) {
        $query .= ' LIMIT '.$limit;
    }
   
    #
    # Execute query
    #
    my $sth = $dbh->prepare($query);
    if ($with_old) { 
        $sth->execute(@params, @params);
    } else {
        $sth->execute(@params);
    }
    
    $ret = $sth->fetchall_arrayref({});
    
    #
    # Convert some datas into UI value
    #
    my $cancels_map = GetAuthorisedValuesMap($AV_SR_CANCEL);
    my $desks_map   = GetDesksMap();
    foreach (@$ret) {
        
        # dates format
        $_->{'begin_date_ui'} = format_date($_->{'begin_date'});
        $_->{'end_date_ui'}   = format_date($_->{'end_date'});
        $_->{'renew_date_ui'} = format_date($_->{'renew_date'}) if ($_->{'renew_date'} && $_->{'renew_date'} ne '0000-00-00');
        
        # desks name
        $_->{'holdingdesk_ui'}   = $desks_map->{ $_->{'holdingdesk'} }   if ($_->{'holdingdesk'});
        $_->{'delivery_desk_ui'} = $desks_map->{ $_->{'delivery_desk'} } if ($_->{'delivery_desk'});
        $_->{'return_desk_ui'}   = $desks_map->{ $_->{'return_desk'} }   if ($_->{'return_desk'});
        
        # cancel code
        $_->{'cancel_code_ui'} = $cancels_map->{ $_->{'cancel_code'} } if ($_->{'cancel_code'});
        
        # stack on serial without flying item yet
        if ($_->{'onserial'} && !$_->{'itemnumber'}) {
            my $serialinfo = GetSubscriptionsFromBiblionumber($_->{'serial_biblionumber'});
            if (scalar @$serialinfo) {
                $_->{'biblionumber'}    = $$serialinfo[0]->{'biblionumber'};
                $_->{'title'}           = $$serialinfo[0]->{'bibliotitle'};
                $_->{'author'}          = $$serialinfo[0]->{'biblioauthor'};
                $_->{'itemcallnumber'}  = $$serialinfo[0]->{'callnumber'} unless $_->{'onserial'} == 2;
            } else {
                # for a generic without subscription
                my ($count, @biblios) = GetBiblio($_->{'serial_biblionumber'});
                $_->{'biblionumber'}    = $_->{'serial_biblionumber'};
                $_->{'title'}           = $biblios[0]->{'title'};
                $_->{'author'}          = $biblios[0]->{'author'};
                # item callnumber is stored in nc_callnumber
            }
        }
    }
    
    return $ret;
}

##
# Search by request id
#
# param : request id
# param : search in old requests
##
sub GetStackById($;$) {
    
    # getting input args.
    my $inp_id = shift;
    my $with_olds = shift;
    
    if ($inp_id) {
    	my $rows = _search_stacks('id', { value => $inp_id }, $with_olds);
        if (scalar @$rows){
            return $$rows[0];
        }
    }
   
    return undef;
}

##
# Get stack on item with status edited or runnning
#
# param : item id
##
sub GetCurrentStackByItemnumber($) {
    
    # getting input args.
    my $inp_itemnumber = shift;
    
    if ($inp_itemnumber) {
        my $rows = _search_stacks('itemcurr', { value => $inp_itemnumber });
        if (scalar @$rows){
            return $$rows[0];
        }
    }
   
    return undef;
}

##
# Get stack on item for all operations
# Will return the current active request or next asked request
#
# param : item id
##
sub GetAllOperationsStackByItemnumber($) {
    
    # getting input args.
    my $inp_itemnumber = shift;
    
    if ($inp_itemnumber) {
        my $rows = _search_stacks('allop', { value => $inp_itemnumber });
        if (scalar @$rows){
            return $$rows[0];
        }
    }
   
    return undef;
}

##
# Search all stacks of an itemnumber
#
# param : item id
##
sub GetStacksByItemnumber($) {
    
    # getting input args
    my $inp_itemnumber = shift;
    
    my $ret = [];
    
    if ($inp_itemnumber) {
        $ret = _search_stacks('item', { value => $inp_itemnumber });
    }
   
    return $ret;
}

##
# Search stacks of a borrower
#
# param : borrower id
##
sub GetStacksOfBorrower($;$$$) {
    
    # getting input args.$inp_value
    my $inp_borrowernumber = shift;
    my $with_old = shift;    
    my $order = shift;
    my $limit = shift;
    
    my $ret = [];
    
    if ($inp_borrowernumber) {
    	if ( $with_old ){
        	$ret = _search_stacks('borrower', { value => $inp_borrowernumber }, $with_old, $order, $limit);
    	}
    	else{
    		$ret = _search_stacks('borrower', { value => $inp_borrowernumber });
    	}
    }
   
    return $ret;
}

##
# Get stack requests of biblio, including olds
#
# param : biblio id
##
sub GetBiblioStacks($) {
    
    # getting input args.
    my $inp_id = shift;
    
    my $ret = [];
    
    if ($inp_id) {
        $ret = _search_stacks('biblio', { value => $inp_id }, 1); # with olds
    }
    
    return $ret;    
}

##
# Get number of stack requests linked to speficied space
#
# param : space id
##
sub CountStacksOfSpace($) {
    
    # getting input args.
    my $space_id = shift;
    
    my $dbh = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
        SELECT COUNT(*) AS nb
        FROM stack_requests 
        WHERE space_booking_id = ?
    ');
    $sth->execute($space_id);
    my $data = $sth->fetchrow_hashref;
    
    return 0 + $data->{'nb'};
}

##
# Get stacks by criteria 
# params
#  $begin_date
#  $end_date
#  $state
#  $canceled
#  $desk (use ^CODE to filter on all desks but this one)
#  $begin_date_max
##
sub GetStacksByCriteria(;$;$;$;$;$;$) {
    my $begin_date = shift;
    my $end_date = shift;
    my $state = shift;
    my $canceled = shift;
    my $desk = shift;
    my $begin_date_max = shift;
    
    return _search_stacks('criteria', {
        begin_date         => $begin_date,
        end_date           => $end_date,
        'state'            => $state,
        canceled           => $canceled,
        desk               => $desk,
        begin_date_max  => $begin_date_max
    });
}

##
# Get instant today stack
#
# return : instant stack request or undef
##
sub GetTodayInstantStackrequest() {
   
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    $sth = $dbh->prepare('
            SELECT * 
            FROM stack_requests
            WHERE
            	DATE(creation_ts) = begin_date
			    AND begin_date = CURDATE()
			    AND state = ?
            ORDER BY begin_date ASC
    ');
    $sth->execute($STACK_STATE_ASKED);
    my $data = $sth->fetchall_arrayref({});
    
    return $data;
}

##
# Get blocking stack request on item :
# asked today or nearby future request (secure days)
# or edited or running request
#
# param  : item id
# return : stack request id or undef
##
sub GetBlockingStackRequest($) {
    
    # getting input args.
    my $itemnumber = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    
    my $secure_days = C4::Context->preference('DelayBeforeDifferedStack') || 0;
    $secure_days += 1; # to find the first no blocking date
    
    $sth = $dbh->prepare('
            SELECT request_number
            FROM stack_requests
            WHERE
                itemnumber = ?
                AND (
                    ( state = ? AND begin_date < ADDDATE(CURDATE(), ?) )
                    OR ( state = ? )
                    OR ( state = ? )
                )
            ORDER BY begin_date ASC
            LIMIT 1
    ');
    $sth->execute(
        $itemnumber,
        $STACK_STATE_ASKED,
        $secure_days,
        $STACK_STATE_EDITED,
        $STACK_STATE_RUNNING
    );
    my $data = $sth->fetchrow_hashref();
    
    if ($data && $data->{'request_number'}){
        return $data->{'request_number'};
    }
    return undef;
}

1;
__END__