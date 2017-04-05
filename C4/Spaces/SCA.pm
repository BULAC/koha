package C4::Spaces::SCA;

##
# B037 : Connector via web service for spaces management
##

use strict;
use warnings;

use vars qw($VERSION @ISA @EXPORT);
use C4::Context;
use C4::Utils::Constants;

use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;
use Time::Local;

use vars qw($debug);

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 3.2.0;
    require Exporter;
    $debug = $ENV{DEBUG};
    @ISA    = qw(Exporter);
    @EXPORT = qw(
    	&AddScaUser
    	&ModScaUser
        &DelScaUser
        &DelScaExpiredUserINALCO
    );
}


my $hostname = (C4::Context->preference('ScaUrl') || '') . '/WebSdk';
#my $username = 'admin;KxsD11z743Hf5Gq9mv3+5ekxzemlCiUXkTFY5ba1NOGcLCmGstt2n0zYE9NsNimv';
my $username = (C4::Context->preference('ScaUser') || '') . ';' . (C4::Context->preference('ScaKey') || '');
my $password = C4::Context->preference('ScaPassword');

my $format = 'STID3CA';
my $facility = '';

my $xml = new XML::Simple;


sub call_rest {
    my ( $rest_method, $rest_service ) = @_;

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new( $rest_method => $hostname . '/' . $rest_service );
    
    $debug and warn "SCA request : ".Dumper($req);
    $debug and print STDERR "SCA request : ".Dumper($req)."\n";
    
    $req->header( 'Content-Length' => 0 );
    $req->authorization_basic( $username, $password );
    
    my $result = $ua->request( $req )->content;
    
    $debug and warn "SCA result : ".Dumper($result);
    $debug and print STDERR "SCA result : ".Dumper($result)."\n";
    
    $result = $xml->XMLin( $result );
    return ( $result->{status} eq "ok", $result );
}

sub format_date_sca {
    my ( $year, $month, $day, $hour, $min, $sec ) = @_;
    $hour = 0 unless $hour;
    $min = 0 unless $min;
    $sec = 0 unless $sec;
    
    my $time = timelocal($sec, $min, $hour, $day, $month - 1, $year - 1900);
    ($sec, $min, $hour, $day, $month, $year, undef, undef, undef) = gmtime($time);
    
    $year += 1900;
    $month += 1;
    $month = sprintf("%02d", $month);
    $day = sprintf("%02d", $day);
    $min = sprintf("%02d", $min);
    $sec = sprintf("%02d", $sec);

    return "$year-$month-$day" ."T" . "$hour:$min:$sec";
}

#Return 1 if the sum of the bit is odd, 0 otherwise
sub compute_parity_bit {
    my ( $input ) = @_;

    my $count = $input =~ tr/1//;
    return ( $count % 2 );
}

sub bin2hex {
	my ( $input ) = @_;
	
	my $length = length( $input );
	my $nb_bytes = 0;
    
    if ($length % 8 == 0) {
        $nb_bytes = $length / 8;
    } else {
        $nb_bytes = int($length / 8) + 1;
    }
	
    $input = sprintf( '%0*s', $nb_bytes * 8, $input );
    
    my $hex = '';
    for (my $i=0; $i < $nb_bytes; $i++) {
        my $part = substr( $input, $i * 8, 8);
        $hex = $hex . sprintf('%02X', oct( '0b' . $part ) );
    } 
    
    return $hex;
}

sub hex2dec {
    my ( $input ) = @_;
        
    my $length = length( $input );
    my $nb_bytes = 0;                                                                                                                                                            
                                                                                                                                                                                            
    if ($length % 2 == 0) {                                                                                                                                                                 
        $nb_bytes = $length / 2;                                                                                                                                                            
    } else {                                                                                                                                                                                
        $nb_bytes = ($length + 1) / 2;                                                                                                                                                   
    }
        
    $input = sprintf( '%0*s', $nb_bytes * 2, $input );  
        
    my $dec = 0;                                                                                                                                                           
    for (my $i=0; $i < $nb_bytes; $i++) {                                                                                                                                                   
        my $part = substr( $input, $i * 2, 2);                                                                                                                                              
        $dec = 256 * $dec + hex($part);                                                                                                                                                          
    } 
    
    return $dec;
}
   
sub compute_wiegand_standard {
    my ( $cardnumber, $facility ) = @_;

    my $raw_facility = sprintf( '%0*b', 8, $facility );
    my $raw_cardnumber = sprintf( '%0*b', 16, $cardnumber );

    my $raw_begin = $raw_facility . substr( $raw_cardnumber, 0, 4 );
    my $raw_end = substr( $raw_cardnumber, 4 );

    $raw_begin = compute_parity_bit( $raw_begin ) . $raw_begin;
    $raw_end = $raw_end . (1 - compute_parity_bit( $raw_end ) );

    my $raw = bin2hex( $raw_begin . $raw_end );
    $raw = sprintf( '%0*s', 32, $raw );
    
    return $raw;
}

sub compute_wiegand_h10302 {
    my ( $cardnumber ) = @_;

    my $raw_cardnumber = sprintf( '%0*b', 35, $cardnumber );

    my $raw_begin = substr( $raw_cardnumber, 0, 18 );
    my $raw_end = substr( $raw_cardnumber, -18 );

    $raw_begin = compute_parity_bit( $raw_begin ) . $raw_begin;
    $raw_end = $raw_end . (1 - compute_parity_bit( $raw_end ) );

    my $raw = bin2hex( $raw_begin . substr( $raw_end, 1 ) );
    $raw = sprintf( '%0*s', 32, $raw );
    
    return $raw;
}

sub compute_stid3ca {                                                                                                                                                                           
    my ( $cardnumber ) = @_;
    my $parity = '0';
    foreach my $byte (split //, $cardnumber) {
        $parity = sprintf '%01x', hex($parity) ^ hex($byte);
    }
    $cardnumber = $cardnumber . $parity;
    $cardnumber = sprintf( '%0*s', 32, $cardnumber );
    return $cardnumber;
}

sub build_card_format {
    my ( $format, $cardnumber, $compute, $facility ) = @_;

    my $format_xml = '';
    my $raw = '';

    if ( $format eq 'KEYPAD' ) {
        $format_xml = '<Keypad><Code>' . $cardnumber . '</Code></Keypad>';
    } elsif ( $format eq 'WIEGAND_STANDARD' ) {
        my $bitlength = 26;
        my $format = '00000000-0000-0000-0000-000000000200';
        if ( $compute ) {
            $cardnumber = hex2dec( $cardnumber );
            $raw = compute_wiegand_standard( $cardnumber, $facility );
        } else {
        	$raw = sprintf( '%0*s', 32, $raw );
        }
    
        $format_xml = '<UndecodedWiegand><BitLength>' .$bitlength . '</BitLength><FormatType>' . $format . '</FormatType><Raw>' . $raw . '</Raw></UndecodedWiegand>';
    } elsif ( $format eq 'WIEGAND_H10302' ) {
        my $bitlength = 37;
        my $format = '00000000-0000-0000-0000-000000000400';
        if ( $compute ) {
            $cardnumber = hex2dec( $cardnumber );
            $raw = compute_wiegand_h10302( $cardnumber );
        } else {
            $raw = sprintf( '%0*s', 32, $raw );
        }
    
        $format_xml = '<UndecodedWiegand><BitLength>' .$bitlength . '</BitLength><FormatType>' . $format . '</FormatType><Raw>' . $raw . '</Raw></UndecodedWiegand>';
    } elsif ( $format eq 'STID3CA' ) {
        my $bitlength = 36;
        #id format Progilone
		#my $format = '6655ce03-3048-4999-9db9-9c526cb75a77';
		#id format prod BULAC
		my $format = '1f0094ce-2bc3-46f2-b934-ad6759d78b2a';
        if ( $compute ) {
            $raw = compute_stid3ca( $cardnumber );
        } else {
            $raw = sprintf( '%0*s', 32, $raw );
        }
    
        $format_xml = '<UndecodedWiegand><BitLength>' .$bitlength . '</BitLength><FormatType>' . $format . '</FormatType><Raw>' . $raw . '</Raw></UndecodedWiegand>';
    }

    return $format_xml;
}

sub add_to_public_partition {
    my ( $uuid ) = @_;
    my $message = undef;
    
    my $rest_service = 'entity?q=entity=' . $uuid . ',InsertIntoPartition(00000000-0000-0000-0000-00000000000b)';
    my ($status, undef) = call_rest( 'POST', $rest_service);
    
    unless ($status) {
    	$message = 'ERROR_ADD_PARTITION';
    }
    
    return ($status, $message, undef);
}

sub retrieve_card_uuid {
    my ( $cardnumber ) = @_;

    my $cardnumber_name = hex2dec( $cardnumber );
    my $rest_service = 'report/EntityConfiguration?q=EntityTypes@Credential,Name=' . $cardnumber_name;
    my ($status, $result) = call_rest( 'GET', $rest_service);
    my $card_uuid = $result->{QueryResult}->{Row};

    if ($status) {
        if ( ref( $card_uuid ) eq 'ARRAY' ) {
            foreach my $card ( @$card_uuid ) {
                my $uuid = $card->{Cell}->{content};
                $rest_service = 'entity?q=entity=' . $uuid . ',Name';
                (undef, $result) = call_rest( 'GET', $rest_service);
                my $name = $result->{Name};
                if ( $name eq $cardnumber_name ) {
                    return ($status, undef, $uuid);
                }
            }
            return ($status, 'NO_CARD_FOUND', undef);
        } elsif ( ref( $card_uuid ) eq 'HASH' ) {
            return ($status, undef, $card_uuid->{Cell}->{content});
        } else {
            return ($status, 'NO_CARD_FOUND', undef);
        }
    } else {
        return ($status, 'ERROR_RETRIEVE_CARD', undef);
    }
}

sub create_card {
    my ( $cardholder_uuid, $format, $cardnumber, $compute, $facility ) = @_;
    my $message = undef;
    
    unless ( $facility ) {
        $facility = '';
    }
    
    unless ( $compute ) {
    	$compute = 0;
    }

    my $name = $facility . hex2dec( $cardnumber );
    $format = build_card_format( $format, $cardnumber, $compute, $facility );

    my $rest_service = 'entity?q=entity=NewEntity(Credential),Name=' . $name . ',CardholderGuid=' . $cardholder_uuid . ',Format=' . $format . ',Guid';
    my ($status, $result) = call_rest( 'POST', $rest_service);
    my $card_uuid = $result->{Guid};
    
    if ($status) {
        ($status, $message, undef) = add_to_public_partition( $card_uuid );
        return ($status, $message, $card_uuid);
    } else {
        return ($status, 'ERROR_CREATE_CARD', undef);	
    }
}

sub remove_card {
    my ( $card_uuid ) = @_;
    my $message = undef;

    my $rest_service = 'entity/' . $card_uuid;
    my ($status, undef) = call_rest( 'DELETE', $rest_service );

    unless ($status) {
    	$message = 'ERROR_REMOVE_CARD';
    }
    
    return ( $status, $message, undef );
}

sub retrieve_cardholder_uuid {
    my ( $card_uuid ) = @_;
    my $message = undef;

    my $rest_service = 'entity?q=entity=' . $card_uuid. ',Cardholder.Guid';
    my ($status, $result) = call_rest( 'GET', $rest_service);
    my $cardholder_uuid = $result->{Guid};
    
    unless ($status) {
        $message = 'ERROR_RETRIEVE_CARDHOLDER';
    }
    
    return ($status, $message, $cardholder_uuid);
}

sub create_cardholder {
    my ( $firstname, $lastname ) = @_;
    my $message = undef;

    my $rest_service = 'entity?q=entity=NewEntity(Cardholder),FirstName=' . $firstname . ',LastName=' . $lastname . ',Name=' .$firstname . ' ' . $lastname .',Guid';
    my ($status, $result) = call_rest( 'POST', $rest_service);
    my $cardholder_uuid = $result->{Guid};
    
    if ($status) {
        ($status, $message, undef) = add_to_public_partition( $cardholder_uuid );
        return ($status, $message, $cardholder_uuid);
    } else {
        return ($status, 'ERROR_CREATE_CARDHOLDER', undef);   
    }
}

sub update_cardholder {
    my ( $cardholder_uuid, $firstname, $lastname ) = @_;
    my $message = undef;

    my $rest_service = 'entity?q=entity=' . $cardholder_uuid . ',FirstName=' . $firstname . ',LastName=' . $lastname . ',Name=' .$firstname . ' ' . $lastname;
    my ($status, undef) = call_rest( 'POST', $rest_service );

    unless ($status) {
        $message = 'ERROR_UPDATE_CARDHOLDER';
    }
    
    return ($status, $message, undef);
}

sub remove_cardholder {
    my ( $cardholder_uuid ) = @_;
    my $message = undef;

    my $rest_service = 'entity/' . $cardholder_uuid;
    my ($status, undef) = call_rest( 'DELETE', $rest_service );

    unless ($status) {
        $message = 'ERROR_REMOVE_CARDHOLDER';
    }
    
    return ( $status, $message, undef );
}

sub retrieve_state_entity {
	my ( $entity_uuid ) = @_;
	my $message = undef;
	
	my $rest_service = 'entity?q=entity=' . $entity_uuid. ',State';
    my ($status, $result) = call_rest( 'GET', $rest_service);
    my $entity_state = $result->{State};
    
    unless ($status) {
        $message = 'ERROR_RETRIEVE_STATE_ENTITY';
    }
    
    return ($status, $message, $entity_state);
}

sub set_state_entity {
    my ( $entity_uuid, $state, $start, $end ) = @_;
    my $message = undef;
    
    if ( defined $start && $start ne '' ) {
    	my ( $year, $month, $day ) = split (/-/, $start);
    	$start = format_date_sca($year, $month, $day, 0, 0, 0);
    }
    if ( defined $end && $end ne '' ) {
        my ( $year, $month, $day ) = split (/-/, $end);
        $end = format_date_sca($year, $month, $day, 23, 59, 59);
    }
    
    my $rest_service = 'entity?q=entity=' . $entity_uuid . ',State=' . $state;
    if ($state eq 'Active' ) {
        if ( defined $start && defined $end && $start ne '' && $end ne '' ) {
            $rest_service = $rest_service . ',ActivationMode=SpecificActivationPeriod(' . $start . ',' . $end . ')';
        } elsif ( defined $end && $end ne '' ) {
            $rest_service = $rest_service . ',ActivationMode=SpecificDeactivation(' . $end . ')';
        }
    }
    my ($status, undef) = call_rest( 'POST', $rest_service );
    
    unless ($status) {
        $message = 'ERROR_SET_STATE_ENTITY';
    }
    
    return ($status, $message, undef);
}

sub retrieve_group_uuid {
    my ( $group_name ) = @_;
    
    my $rest_service = 'report/EntityConfiguration?q=EntityTypes@Cardholdergroup,Name=' . $group_name;
    my ($status, $result) = call_rest( 'GET', $rest_service);
    my $group_uuid = $result->{QueryResult}->{Row};

    if ($status) {
        if ( ref( $group_uuid ) eq 'ARRAY' ) {
            foreach my $group ( @$group_uuid ) {
                my $uuid = $group->{Cell}->{content};
                $rest_service = 'entity?q=entity=' . $uuid . ',Name';
                (undef, $result) = call_rest( 'GET', $rest_service);
                my $name = $result->{Name};
                if ( $name eq $group_name ) {
                    return ($status, undef, $uuid);
                }
            }
            return ($status, 'NO_GROUP_FOUND', undef);
        } elsif ( ref( $group_uuid ) eq 'HASH' ) {
            return ($status, undef, $group_uuid->{Cell}->{content});
        } else {
            return ($status, 'NO_GROUP_FOUND', undef);
        }
    } else {
        return ($status, 'ERROR_RETRIEVE_GROUP', undef);
    }
}

sub add_group_to_cardholder {
    my ( $cardholder_uuid, $group_uuid ) = @_;
    
    #If the group is already on the borrower we must remove it first as we can not add it again. (It is faster than to check the existence of the group on the borrower)
    my ($status, $message, undef) = remove_group_to_cardholder( $cardholder_uuid, $group_uuid);
    unless ($status) {
        return ($status, $message, undef);
    }
    
    my $rest_service = 'entity?q=entity=' . $cardholder_uuid . ',Groups@' . $group_uuid;
    ($status, undef) = call_rest( 'POST', $rest_service );

    unless ($status) {
        $message = 'ERROR_ADD_GROUP_TO_CARDHOLDER';
    }
    
    return ($status, $message, undef);
} 

sub remove_group_to_cardholder {
    my ( $cardholder_uuid, $group_uuid ) = @_;
    my $message = undef;

    my $rest_service = 'entity?q=entity=' . $cardholder_uuid . ',Groups-' . $group_uuid;
    my ($status, undef) = call_rest( 'POST', $rest_service );

    unless ($status) {
        $message = 'ERROR_REMOVE_GROUP_TO_CARDHOLDER';
    }
    
    return ($status, $message, undef);
}

sub desactivate_card {
    my ( $old_cardnumber ) = @_;
        
    my ($status, $message, $old_card_uuid) = retrieve_card_uuid( $old_cardnumber );
    unless ($status) { return ($status, $message); }
        
    if ( defined $old_card_uuid ) {
        #Disabled the old card
        ($status, $message, undef) = set_state_entity( $old_card_uuid, 'Inactive' );
        unless ($status) { return ($status, $message); }
    }
    
    return ($status, $message);
}

sub retrieve_borrower_info {
	my ( $borrowernumber, $isOld ) = @_;
	
	my ( $firstname, $lastname, $cardnumber, $category, $start, $end, $lost, $enrolled_by ) = ( '', '', '', '', '', '', '', '' );
	
	my $borrower_table = 'borrowers';
	if ( $isOld ) {
		$borrower_table = 'deletedborrowers';
	}
	
	my $dbh = C4::Context->dbh;
	my $query = 'SELECT firstname, surname, cardnumber, categorycode, dateenrolled, dateexpiry, lost, sca_enrolled_by FROM ' .$borrower_table . ' WHERE borrowernumber = ?';
	my $sth = $dbh->prepare( $query );
	$sth->execute( $borrowernumber );
	
	my $row = $sth->fetchall_arrayref({});
	if ( $row->[0] ) {
		$firstname  = $row->[0]{'firstname'};
		$lastname   = $row->[0]{'surname'};
		$cardnumber = $row->[0]{'cardnumber'};
		$category   = $row->[0]{'categorycode'};
		$lost       = $row->[0]{'lost'};
		$start      = $row->[0]{'dateenrolled'};
        $end        = $row->[0]{'dateexpiry'};
        $enrolled_by= $row->[0]{'sca_enrolled_by'};
	}
	
	return ( $firstname, $lastname, $cardnumber, $category, $start, $end, $lost, $enrolled_by );
}

sub AddScaUser {
	my ( $borrowernumber ) = @_;
	my ( $firstname, $lastname, $cardnumber, $category, $start, $end, $lost, $old_enrolled_by ) = retrieve_borrower_info( $borrowernumber, 0 );
	my $status = 1;
	my $message = undef;
	my $enrolled_by;
	
	if ($old_enrolled_by ne '') {
	   return ($status, $message, $old_enrolled_by);
	}
	eval {
		#Check if the card exists in the SCA
		my $card_uuid = undef;
		($status, $message, $card_uuid) = retrieve_card_uuid( $cardnumber );
		unless ($status) { return ($status, $message); }
		
		unless ( $card_uuid ) {
			#The card does not exist. We create the CardHolder and the Credential
			my $cardholder_uuid = undef;
			($status, $message, $cardholder_uuid) = create_cardholder( $firstname, $lastname );
			unless ($status) { return ($status, $message); }
			
			($status, $message, $card_uuid) = create_card( $cardholder_uuid, $format, $cardnumber, 1, $facility );
			unless ($status) { return ($status, $message); }
			
			#Set end date for CardHolder and Credential
            ($status, $message, undef) = set_state_entity( $cardholder_uuid, 'Active', $start, $end );
            unless ($status) { return ($status, $message); }
            ($status, $message, undef) = set_state_entity( $card_uuid, 'Active', $start, $end );
            unless ($status) { return ($status, $message); }
            
            $enrolled_by = $ENROLLED_BY_BULAC;
		} else {
            $enrolled_by = $ENROLLED_BY_INALCO;
        }
		
		my $cardholder_uuid = undef;
		($status, $message, $cardholder_uuid) = retrieve_cardholder_uuid( $card_uuid );
		unless ($status) { return ($status, $message); }
		
        #FIXME: Ajouter préférence système pour groupe de base
		my $group_uuid = undef;
		($status, $message, $group_uuid) = retrieve_group_uuid( 'Usager' );
		unless ($status) { return ($status, $message); }
		if ( $group_uuid ) {
			($status, $message, undef) = add_group_to_cardholder( $cardholder_uuid, $group_uuid );
			unless ($status) { return ($status, $message); }
		}
		
		($status, $message, $group_uuid) = retrieve_group_uuid( $category );
		unless ($status) { return ($status, $message); }
        if ( $group_uuid ) {
            ($status, $message, undef) = add_group_to_cardholder( $cardholder_uuid, $group_uuid );
            unless ($status) { return ($status, $message); }
        }
	};
	
	return ($status, $message, $enrolled_by);
}

sub ModScaUser {
    my ( $borrowernumber, $old_cardnumber, $old_category, $old_enrolled_by ) = @_;
    my ( $firstname, $lastname, $cardnumber, $category, $start, $end, $lost, $enrolled_by ) = retrieve_borrower_info( $borrowernumber, 0 );
    my $status = 1;
    my $message = undef;
    my $card_uuid = undef;
    my $cardholder_uuid = undef;
    eval {
        if ($old_enrolled_by ne $enrolled_by) {
            if ($enrolled_by eq $ENROLLED_BY_BULAC) {
                ($status, $message, $enrolled_by) = ModBULAC( $borrowernumber, $old_cardnumber );
                unless ($status) { return ($status, $message); }
            } elsif ($enrolled_by eq $ENROLLED_BY_INALCO) {
                if ($old_cardnumber ne $cardnumber) {
                    ($status, $message) = desactivate_card( $old_cardnumber );
                    unless ($status) { return ($status, $message); }
                }
                
                ($status, $message, $enrolled_by) = ModINALCO( $borrowernumber );
                unless ($status) { return ($status, $message); }
            }
        } else {
            if ($enrolled_by eq $ENROLLED_BY_BULAC) {
                if ($old_cardnumber ne $cardnumber) {
                    ($status, $message) = desactivate_card( $old_cardnumber );
                    unless ($status) { return ($status, $message); }
                    
                    ($status, $message, $card_uuid) = retrieve_card_uuid( $cardnumber );
                    unless ($status) { return ($status, $message); }
                    if (defined $card_uuid) {
                        ($status, $message, $enrolled_by) = ModINALCO( $borrowernumber );
                        unless ($status) { return ($status, $message); }
                    } else {
                        ($status, $message, $enrolled_by) = ModBULAC( $borrowernumber, $old_cardnumber );
                        unless ($status) { return ($status, $message); }
                    }
                } else {
                     ($status, $message, $enrolled_by) = ModBULAC( $borrowernumber, $old_cardnumber );
                     unless ($status) { return ($status, $message); }
                }
            } elsif ($enrolled_by eq $ENROLLED_BY_INALCO) {
                if ($old_cardnumber ne $cardnumber) {
                    ($status, $message, $card_uuid) = retrieve_card_uuid( $cardnumber );
                    unless ($status) { return ($status, $message); }
                    
                    if (defined $card_uuid) {
                        ($status, $message, $enrolled_by) = ModINALCO( $borrowernumber );
                        unless ($status) { return ($status, $message); }
                    } else {
                        ($status, $message, $enrolled_by) = ModBULAC( $borrowernumber, $old_cardnumber );
                        unless ($status) { return ($status, $message); }
                    }
                } else {
                    ($status, $message, $enrolled_by) = ModINALCO( $borrowernumber );
                    unless ($status) { return ($status, $message); }
                }
            } elsif ($enrolled_by eq '') {
                ($status, $message, $enrolled_by) = AddScaUser($borrowernumber);
                unless ($status) { return ($status, $message); }
            } 
        }
        
        #Retrieve borrower informations
        ($status, $message, $card_uuid) = retrieve_card_uuid( $cardnumber );
        unless ($status) { return ($status, $message); }
        ($status, $message, $cardholder_uuid) = retrieve_cardholder_uuid( $card_uuid );
        unless ($status) { return ($status, $message); }
        
        #FIXME: Ajouter préférence système pour groupe de base
        my $group_uuid = undef;
        ($status, $message, $group_uuid) = retrieve_group_uuid( 'Usager' );
        unless ($status) { return ($status, $message); }
        
        if ( $group_uuid ) {
            ($status, $message, undef) = add_group_to_cardholder( $cardholder_uuid, $group_uuid );
            unless ($status) { return ($status, $message); }
        }
        
        if ( $category ne $old_category ) {
            my $old_group_uuid = undef;
            ($status, $message, $old_group_uuid) = retrieve_group_uuid( $old_category );
            unless ($status) { return ($status, $message); }
            if ( $old_group_uuid ) {
                ($status, $message, undef) = remove_group_to_cardholder( $cardholder_uuid, $old_group_uuid );
                unless ($status) { return ($status, $message); }
            }
            
            my $group_uuid = undef;
            ($status, $message, $group_uuid) = retrieve_group_uuid( $category );
            unless ($status) { return ($status, $message); }
            if ( $group_uuid ) {
                ($status, $message, undef) = add_group_to_cardholder( $cardholder_uuid, $group_uuid );
                unless ($status) { return ($status, $message); }
            }
        }
        
    };
    
    return ($status, $message, $enrolled_by);
}
        
sub ModBULAC {
    my ( $borrowernumber, $old_cardnumber ) = @_;
    my ( $firstname, $lastname, $cardnumber, $category, $start, $end, $lost, $enrolled_by ) = retrieve_borrower_info( $borrowernumber, 0 );
    my $status = 1;
    my $message = undef;
    my $cardholder_uuid = undef;
    
    eval {
		#Check if the new card exists
		my $card_uuid = undef;
		($status, $message, $card_uuid) = retrieve_card_uuid( $cardnumber );
		unless ($status) { return ($status, $message); }
		
		if ( not defined $card_uuid ) {
			#The card does not exist. Create the Credential
			my $old_card_uuid = undef;
			($status, $message, $old_card_uuid) = retrieve_card_uuid( $old_cardnumber );
            unless ($status) { return ($status, $message); }
            if (defined $old_card_uuid) {
				($status, $message, $cardholder_uuid) = retrieve_cardholder_uuid( $old_card_uuid );
	            unless ($status) { return ($status, $message); }
            }
			
			if ( defined $cardholder_uuid ) {
				($status, $message, $card_uuid) = create_card( $cardholder_uuid, $format, $cardnumber, 1, $facility );
				unless ($status) { return ($status, $message); }
				($status, $message, undef) = set_state_entity( $cardholder_uuid, 'Active', $start, $end );
				unless ($status) { return ($status, $message); }
				($status, $message, undef) = set_state_entity( $card_uuid, 'Active', $start, $end );
				unless ($status) { return ($status, $message); }
			} else {
				#We can't know if the user as been created before. Create a new one.
				($status, $message) = AddScaUser( $borrowernumber );
				unless ($status) { return ($status, $message); }
			}
		}
    	
    	($status, $message, $card_uuid) = retrieve_card_uuid( $cardnumber );
    	unless ($status) { return ($status, $message); }
    	($status, $message, $cardholder_uuid) = retrieve_cardholder_uuid( $card_uuid );
    	unless ($status) { return ($status, $message); }
    	($status, $message, undef) = update_cardholder( $cardholder_uuid, $firstname, $lastname );
    	unless ($status) { return ($status, $message); }
    
    	#Check if card is lost or not
    	if ( $lost ) {
    		($status, $message, undef) = set_state_entity( $card_uuid, 'Lost', '', '' );
    		unless ($status) { return ($status, $message); }
    	} else {
    		($status, $message, undef) = set_state_entity( $cardholder_uuid, 'Active', $start, $end );
    		unless ($status) { return ($status, $message); }
    		($status, $message, undef) = set_state_entity( $card_uuid, 'Active', $start, $end);
    		unless ($status) { return ($status, $message); }
    	}
    	
    };
    
    return ($status, $message, $ENROLLED_BY_BULAC);
}

sub ModINALCO {
    my ( $borrowernumber ) = @_;
    my ( $firstname, $lastname, $cardnumber, $category, $start, $end, $lost, $enrolled_by ) = retrieve_borrower_info( $borrowernumber, 0 );
    my $status = 1;
    my $message = undef;
    
    #Check if the card exists
    my $card_uuid = undef;
    ($status, $message, $card_uuid) = retrieve_card_uuid( $cardnumber );
    unless ($status) { return ($status, $message); }
        
    if ( defined $card_uuid ) {
        return ($status, $message, $ENROLLED_BY_INALCO);
    } else {
        return (0, 'ERROR_INALCO_CARD_NOT_EXIST');
    }
}

sub DelScaUser {
    my ( $borrowernumber ) = @_;
    my ( $firstname, $lastname, $cardnumber, $category, $start, $end, $lost, $enrolled_by ) = retrieve_borrower_info( $borrowernumber, 1 );
    my $status = 1;
    my $message = undef;
    
    eval {
        my $card_uuid = undef;
        ($status, $message, $card_uuid) = retrieve_card_uuid( $cardnumber );
        unless ($status) { return ($status, $message); }
        
        my $cardholder_uuid = undef;
        ($status, $message, $cardholder_uuid) = retrieve_cardholder_uuid( $card_uuid );
        unless ($status) { return ($status, $message); }
        
        if ($enrolled_by eq $ENROLLED_BY_BULAC) {
        	#Disabled the user in the SCA
        	($status, $message, undef) = set_state_entity( $card_uuid, 'Inactive', '', '' );
        	unless ($status) { return ($status, $message); }
        	($status, $message, undef) = set_state_entity( $cardholder_uuid, 'Inactive', '', '' );
        	unless ($status) { return ($status, $message); }
        } elsif ($enrolled_by eq $ENROLLED_BY_INALCO) {
            #Remove group Usager
            my $group_uuid = undef;
            ($status, $message, $group_uuid) = retrieve_group_uuid( 'Usager' );
            unless ($status) { return ($status, $message); }
            
            ($status, $message, undef) = remove_group_to_cardholder( $cardholder_uuid, $group_uuid);
            unless ($status) { return ($status, $message); }
        }
            
    };
	
	return ($status, $message);
}

sub DelScaExpiredUserINALCO {
    my ( $date ) = @_;
    my $status = 1;
    my $message = undef;
    my $group_uuid = undef;
    
    ($status, $message, $group_uuid) = retrieve_group_uuid( 'Usager' );
    unless ($status) { return ($status, $message); }
    
    my $dbh = C4::Context->dbh();
    my $query  = "SELECT * FROM borrowers
                WHERE dateexpiry = ?
                AND sca_enrolled_by = ?";
    my $sth    = $dbh->prepare($query);
    $sth->execute($date, $ENROLLED_BY_INALCO);
                
    while ( my $borrower = $sth->fetchrow_hashref ) {
        eval {
            my $card_uuid = undef;
            ($status, $message, $card_uuid) = retrieve_card_uuid( $borrower->{'cardnumber'} );
            
            if ($status) {
                if (defined $card_uuid) {
                    my $cardholder_uuid = undef;
                    ($status, $message, $cardholder_uuid) = retrieve_cardholder_uuid( $card_uuid );
                    
                    if ($status) {
                        if (defined $cardholder_uuid) {
                            #Remove group Usager
                            ($status, $message, undef) = remove_group_to_cardholder( $cardholder_uuid, $group_uuid);
                        } else {
                            print STDERR ($borrower->{'borrowernumber'}." : No card holder for card ".$borrower->{'cardnumber'}." in SCA.\n");
                        }
                    }
                } else {
                    print STDERR ($borrower->{'borrowernumber'}." : Card ".$borrower->{'cardnumber'}." not found in SCA.\n");
                }
                
            }
            
            unless ($status) { print STDERR ($borrower->{'borrowernumber'}." : ".$message."\n"); }
        };
    }
    
    return ($status, $message);
}

sub dec2bin {
    my ( $input ) = @_;

    my $result = '';
    while ($input != 0) {
        if ($input % 2 == 0) {
            $result = "0" . $result;
        } else {
            $result = "1" . $result;
        }
        $input = int($input / 2);
    }

    return $result;
}

1;
__END__
