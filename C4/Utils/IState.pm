package C4::Utils::IState;

##
# B03X : Constants
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use C4::Context;
use C4::Dates qw/format_date format_date_in_iso/;
use C4::Circulation;
use C4::Members;

use C4::Utils::Constants;
use C4::Stack::Search;
use C4::Stack::Desk qw(GetDesksMap);

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &AddIStateInfos
    );
}

##
# Add istate infos on item
#
# param : item
##
sub AddIStateInfos($) {
    
    # input args
    my $item = shift;
        
    # local vars
    my $itemnumber = $item->{'itemnumber'};

    unless ($itemnumber) {
        return;
    }
    
    my $istate = $item->{'istate'} || '';
 
    # Borrower of stack request
    my $request;
    if ($istate eq $ISTATE_STACKREQ) {
        my $blo_request_number = GetBlockingStackRequest($itemnumber);
        $request = GetStackById($blo_request_number) if ($blo_request_number);
    } else {
        $request = GetCurrentStackByItemnumber($itemnumber);
    }
    if ($request) {
        $item->{'istate_borrowernumber'} = $request->{'borrowernumber'};
        $item->{'istate_firstname'}      = $request->{'firstname'};
        $item->{'istate_surname'}        = $request->{'surname'};
        $item->{'istate_end_date'}       = $request->{'end_date'};
        $item->{'istate_end_date_ui'}    = format_date($request->{'end_date'});
    }
    
    # UI layer
    if ($item->{'holdingdesk'}) {
        my $desks_map = GetDesksMap();
        $item->{'holdingdesk_ui'} = $desks_map->{ $item->{'holdingdesk'} };
    }
}

1;
__END__