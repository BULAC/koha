package C4::Utils::Constants;

##
# B03X : Constants
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use C4::Context;

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        $ISTATE_NOT_AVAIL
        $ISTATE_ON_LOAN
        $ISTATE_ON_STACK
        $ISTATE_WAIT_STACK
        $ISTATE_WAIT_RENEW
        $ISTATE_RES_GUARD
        $ISTATE_STACKREQ
        
        $DESK_RESERVE_CODE
        $DESK_DEFAULT_CODE
    
        $STACK_STATE_ASKED
        $STACK_STATE_EDITED
        $STACK_STATE_RUNNING
        $STACK_STATE_FINISHED
        
        $AV_SR_CANCEL
        $AV_SR_CANCEL_USER
        $AV_SR_CANCEL_CHECKOUT
        $AV_SR_CANCEL_EXPIRED
        $AV_SR_CANCEL_AUTORET

        $AV_ETAT_LOAN
        $AV_ETAT_GENERIC
        $AV_ETAT_STACK
        
        $BULAC_BRANCH
        $DEFAULT_BRANCH
        
        $BRANCH_LEN
        $MENTION_LEN
        $TYPE_LEN
        $FORMAT_LEN
        $NUMBER_LEN
        $GEO_INDEX_LEN
        $CLASSIFICATION_LEN
        $COMPLEMENT_LEN
        $VOLUME_LEN
        $SERIAL_COMPLEMENT_LEN
        $SERIAL_NUMBER_LEN
        
        $RES_ITEM_TYPE
        $SR_BEGIN_MAX_DAYS
        $PRE_REG_CATEGORY
        
        $ENROLLED_BY_BULAC
        $ENROLLED_BY_INALCO
    );
}

##
# Item states
##
our $ISTATE_NOT_AVAIL  = 'NOT_AVAIL';  # not available
our $ISTATE_ON_LOAN    = 'ON_LOAN';    # on loan by a borrower
our $ISTATE_ON_STACK   = 'ON_STACK';   # on stack by a borrower
our $ISTATE_WAIT_STACK = 'WAIT_STACK'; # waiting in desk for stack begining
our $ISTATE_WAIT_RENEW = 'WAIT_RENEW'; # waiting in desk when stack renewal
our $ISTATE_RES_GUARD  = 'RES_GUARD';  # waiting in desk because of reserve
our $ISTATE_STACKREQ   = 'STACKREQ';   # blocking stack request exists

##
# Stack state
##
our $STACK_STATE_ASKED    = 'A'; # asked
our $STACK_STATE_EDITED   = 'E'; # edited
our $STACK_STATE_RUNNING  = 'R'; # running
our $STACK_STATE_FINISHED = 'F'; # finished

##
# Desk
##
our $DESK_RESERVE_CODE = 'RES'; # Reserve desk
our $DESK_DEFAULT_CODE = 'RDJ'; # Default desk

##
# Authorized values
##
our $AV_SR_CANCEL           = 'SR_CANCEL'; # Category for stack request cancel reason
our $AV_SR_CANCEL_USER      = '1';         # Value for authorized value corresponding to canceled from user
our $AV_SR_CANCEL_CHECKOUT  = '98';        # Value for authorized value corresponding to converted to checkout
our $AV_SR_CANCEL_EXPIRED   = '99';        # Value for authorized value corresponding to expiration
our $AV_SR_CANCEL_AUTORET   = '100';       # Value for authorized value corresponding to auto return

# authorised values "ETAT"
our $AV_ETAT_LOAN    = '0';  # available for loan
our $AV_ETAT_GENERIC = '98'; # MAN106 serial generic item
our $AV_ETAT_STACK   = '99'; # stack request only

# Branches
our $BULAC_BRANCH = 'BULAC'; # code of BULAC branch
our $DEFAULT_BRANCH = 'NOLOC'; # code of patron default branch

# Callnumber
our $BRANCH_LEN  = 5 + 1; #Ajout d'un espace entre les zones
our $MENTION_LEN = 3 + 1; #Ajout d'un espace entre les zones
our $TYPE_LEN    = 5 + 1; #Ajout d'un espace entre les zones
our $FORMAT_LEN  = 4 + 1; #Ajout d'un espace entre les zones
our $NUMBER_LEN  = 6;

our $GEO_INDEX_LEN      = 5 + 1;    #Ajout d'un espace entre les zones
our $CLASSIFICATION_LEN = 10 + 1;   #Ajout d'un espace entre les zones
our $COMPLEMENT_LEN     = 9 + 1;    #Ajout d'un espace entre les zones
our $VOLUME_LEN         = 5;

our $SERIAL_COMPLEMENT_LEN = 5;
our $SERIAL_NUMBER_LEN     = 4 + 1; #Ajout d'un espace entre les zones


##
# Other
##
our $RES_ITEM_TYPE = 'RESER'; # item type of reserve
our $SR_BEGIN_MAX_DAYS = 14; # max number of days in the future for delayed stack request
our $PRE_REG_CATEGORY = '11PREINS'; # pre-registration patron category

our $ENROLLED_BY_BULAC = "Koha";
our $ENROLLED_BY_INALCO = "INALCO";

1;
__END__