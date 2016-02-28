package C4::Spaces::Connector;

##
# B037 : Connector via web service for spaces management
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use C4::Context;
use C4::Dates qw(format_date);
use SOAP::Lite;

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &GetReservedSpaces
        &GetReservedSpaceById
        &GetReservedSpaceByDate
        &GetSpaceTypes
        &NotifyRetrieval
        &NotifyDelivery
    );
}

my $hostname = C4::Context->preference('SpacesURL') || '';
my $address = $hostname.'/espaces-ear-espaces-ejb/WebServiceBooking';
my $namespace = 'http://webservice.espaces.progilone.fr/';
my $prefix = 'espaces';

##
# Retrieve currently reserved space for a borrower, ordered by begin date
#
# param : borrowernumber
# param : only with stackrequest impact (optional)
##
sub GetReservedSpaces($;$) {
 
    my $borrowernumber = shift;
    my $only4stack = shift;
    my @spaceloop;
        
    unless ($hostname) {
        return \@spaceloop; # Service is not declared
    }
    
    # connexion may fail
    eval {        
        my $method = 'getBookingListFromBorrower';
        my @args = ();
        push( @args, SOAP::Data->name('borrowernumber' => $borrowernumber) );
        
        my $service = SOAP::Lite ->uri($namespace)
                                 ->ns($namespace, $prefix)
                                 ->proxy($address);
            
        my @result = $service -> call( $method => @args ) -> paramsall();
        
        foreach my $hash (@result) {
            my @fields = split (/\|/, $hash);
            
            my $space;
            $space->{'space_id'}     = $fields[0];
            $space->{'space_lib'}    = $fields[1];
            $space->{'stack_impact'} = $fields[2];
            $space->{'begin_date'}   = $fields[3];
            $space->{'end_date'}     = $fields[4];
            
            # formatted dates
            $space->{'begin_date_ui'} = format_date($space->{'begin_date'});
            $space->{'end_date_ui'}   = format_date($space->{'end_date'});
            
            if ( !$only4stack || $space->{'stack_impact'} ) {
                push @spaceloop, $space;
            }
        }
    };
    
    @spaceloop = sort { $a->{'begin_date'} cmp $b->{'begin_date'} } @spaceloop;
    
    return \@spaceloop;
}

##
# Get space by id
# 
# param : borrower id
# param : space id
##
sub GetReservedSpaceById($$) {
    
    #input args
    my $borrowernumber = shift;
    my $space_id   = shift;
    
    my $all_spaces = GetReservedSpaces($borrowernumber);
    
    if ($space_id && scalar @$all_spaces) {
        foreach my $space (@$all_spaces) {
            if ($space_id == $space->{'space_id'}) {
                return $space;
            }
        }
    }
    
    return undef;
}

##
# Get space containing specified date, or undef
# 
# param : borrower id
# param : date in ISO
# param : only with stackrequest impact (optional)
##
sub GetReservedSpaceByDate($$;$) {
    
    #input args
    my $borrowernumber = shift;
    my $date = shift;
    my $only4stack = shift;
    
    my $all_spaces = GetReservedSpaces($borrowernumber, $only4stack);
    
    if ($date && scalar @$all_spaces) {
        foreach my $space (@$all_spaces) {
            if ($space->{'begin_date'} le $date && $date le $space->{'end_date'}) {
                return $space;
            }
        }
    }
    
    return undef;
}

##
# Get space types
##
sub GetSpaceTypes() {
    
    my @spacetypeloop;
        
    unless ($hostname) {
        return \@spacetypeloop; # Service is not declared
    }
    
    # connexion may fail
    eval {        
        my $method = 'getSpaceTypeList';
        
        my $service = SOAP::Lite ->uri($namespace)
                                 ->ns($namespace, $prefix)
                                 ->proxy($address);
            
        my @result = $service -> call( $method, {} ) -> paramsall();

        foreach my $hash (@result) {
            my @spacetype_parts = split (/\|/, $hash);
            
            my $spacetype;
            $spacetype->{spacetype_id} = $spacetype_parts[0];
            $spacetype->{spacetype_name} = $spacetype_parts[1];
            
            push @spacetypeloop, $spacetype;
        }
    };
    
    return \@spacetypeloop;
}

##
# Get space name
##
sub GetSpaceNameByBookingId($$) {
    
    #input args
    my $booking_id   = shift;
    my $begin_date   = shift;
    
    my $spacename;
        
    unless ($hostname) {
        return $spacename; # Service is not declared
    }

    # connexion may fail
    eval {        
        my $method = 'getSpaceNameForBooking';
        
        my @args = ();
        push( @args, SOAP::Data->name('bookingid' => $booking_id, ) );
        push( @args, SOAP::Data->name('startdate' => $begin_date) );
        
        my $service = SOAP::Lite ->uri($namespace)
                                 ->ns($namespace, $prefix)
                                 ->proxy($address);
            
        $spacename = $service -> call( $method => @args ) -> result();
        
    };

    return $spacename;

}

##
# Notify a retrieval
# 
# param : borrower id
##
sub NotifyRetrieval($) {
    
    #input args
    my $borrowernumber = shift;
    
    unless ($hostname) {
        return; # Service is not declared
    }
    
    # connexion may fail
    eval {        
        my $method = 'notifyRetrieval';
        my @args = ();
        push( @args, SOAP::Data->name('borrowernumber' => $borrowernumber) );
        
        my $service = SOAP::Lite ->uri($namespace)
                                 ->ns($namespace, $prefix)
                                 ->proxy($address);
            
        $service -> call( $method => @args ) -> paramsall();
        
    };
}

##
# Notify a delivery
# 
# param : borrower id
##
sub NotifyDelivery($) {
    
    #input args
    my $borrowernumber = shift;
    
    unless ($hostname) {
        return; # Service is not declared
    }
    
    # connexion may fail
    eval {        
        my $method = 'notifyDelivery';
        my @args = ();
        push( @args, SOAP::Data->name('borrowernumber' => $borrowernumber) );
        
        my $service = SOAP::Lite ->uri($namespace)
                                 ->ns($namespace, $prefix)
                                 ->proxy($address);
            
        $service -> call( $method => @args ) -> paramsall();
        
    };
}

1;
__END__