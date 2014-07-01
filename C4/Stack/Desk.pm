package C4::Stack::Desk;

##
# B03X : stack desks
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use Date::Calc qw(
    Today
    Add_Delta_Days
    Delta_Days
);
use List::MoreUtils qw/any/;

use C4::Calendar;
use C4::Context;
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
      &GetDesk
      &GetDesks
      &GetDesksLoop
      &GetAvailableDesksLoop
      &GetDesksMap
      
      &GetDeskNotManagedItemTypes
      &GetDeskNextOpenDay
      
      &IsDeskOpen
      &GetCurrentHourAndMinute
    );
}

##
# Get desk by code
# 
# param : desk code
##
sub GetDesk($) {
    my $code = shift;
    
    my $res;
    
    my $query = '
        SELECT *
        FROM desk
        WHERE deskcode = ?
    ';
    my $sth = C4::Context->dbh->prepare($query);
    $sth->execute($code);
    $res = $sth->fetchrow_hashref;
    
    return $res;
}

##
# Get all desks
#
# param : branch code (optional)
# param : only actives (optional)
# param : only those who manage item type (optional)
##
sub GetDesks(;$;$;$)  {
    
    # getting input args
    my $branch   = shift;
    my $actives  = shift;
    my $itemtype = shift;
    
    # local vars
    my $dbh = C4::Context->dbh;
    my $sth;
    my @params;
    my $ret = [];
    
    my $where = '';
    my $query = '
        SELECT
            deskcode,
            branchcode,
            deskname,
            active
        FROM desk
    ';
    
    if (defined $branch) {
        $where .= 'branchcode = ?';
        push @params, $branch;
    }
    
    if ($actives) {
        # where active = 1
        $where .= ' AND ' if $where;
        $where .= 'active = ?';
        push @params, 1;
    }
    
    if (defined $itemtype) {
        # where itemtype is not excluded
        $where .= ' AND ' if $where;
        $where .= 'deskcode NOT IN (
                SELECT DISTINCT(deskitemtype.deskcode)
                FROM deskitemtype
                WHERE deskitemtype.itemtype = ?
            )
        ';
        push @params, $itemtype;
    }
    
    # Execute query
    $query .= ' WHERE '.$where if ($where);
    $sth = $dbh->prepare($query);
    $sth->execute(@params);
    $ret = $sth->fetchall_arrayref({});
    
    return $ret;
}


##
# Get itemtype not managed by desk
#
# param : deskcode
##
sub GetDeskNotManagedItemTypes($) {
    
    my $deskcode = shift;
    my $dbh = C4::Context->dbh;
    
    my $query= 'SELECT itemtype FROM deskitemtype WHERE deskcode = ?';
    my $sth=$dbh->prepare($query);
    $sth->execute($deskcode);
    
    my @types = ();
    while ( my ($type) = $sth->fetchrow_array ) {
        push( @types, $type );
    }
    
    return @types;
}

##
# Gest a hash with desk code as key and desk name as value
##
sub GetDesksMap() {
    
    my $ret;
    
    my $desks = GetDesks();
    foreach my $desk (@$desks) {
        my $code = $desk->{'deskcode'};
        if (defined $code) {
            $ret->{"$code"} = $desk->{'deskname'};
        }
    }
    
    return $ret;
}

##
# Get desks loop for templates loop tag (for HTML select) that are available :
# - active
# - managing item type
# - open at specified date :
#   + if hour and minute are not defined : at any time of the secified day
#   + if hour and minute are defined     : after specified hour and minute
#
# param : date in ISO
# param : branch
# param : item type
# param : selected desk code (optionnal)
# param : hour (optionnal)
# param : minute (optionnal)
##
sub GetAvailableDesksLoop($$$;$;$;$) {

    # getting input args
    my $date     = shift;
    my $branch   = shift;
    my $itemtype = shift;
    my $selcode  = shift;
    my $hour     = shift;
    my $minute   = shift;
    
    my @ret;
    
    my $desks = GetDesks($branch, 1, $itemtype);
    
    foreach (@$desks) {
        if (IsDeskOpen($_->{'deskcode'}, $date, $hour, $minute)) {
            push @ret, {
                deskcode    => $_->{'deskcode'},
                deskname    => $_->{'deskname'},
                branchcode  => $_->{'branchcode'},
                selected    => ( defined $selcode && $selcode eq $_->{'deskcode'} ) ? 1 : undef,
            };
        }
    }
    
    return \@ret;
}

##
# Is desk open for circulation :
# - if hour and minute are not defined : at any time of the secified day
# - if hour and minute are defined     : at any time of the secified day, AFTER the specified hour and minute
# 
# Desk's branch calendar will be checked
# 
# param : desk code
# param : date in ISO
# param : hour (optionnal)
# param : minute (optionnal)
#
# return : undef or 1
##
sub IsDeskOpen($$;$;$) {
    
    # getting input args.
    my $deskcode = shift;
    my $date     = shift;
    my $hour     = shift;
    my $minute   = shift;
    
    my $desk = GetDesk($deskcode);
    
    my ( $year, $month, $day ) = split(/-/, $date);
    
    # Test if branch is opened
    my $calendar = C4::Calendar->new( branchcode => $desk->{'branchcode'} );
    my $holiday = $calendar->isHoliday($day, $month, $year);
    if ($holiday) {
        return undef;
    }
    
    # Test if desk is opened
    my $deskcalendar = C4::Calendar->new( deskcode => $deskcode );
    
    return $deskcalendar->isDeskOpen($day, $month, $year, $hour, $minute);
}

##
# Get desks for templates loop tag (for HTML select)
# optionnal argument is selected desk code
##
sub GetDesksLoop(;$) {

    my $selcode = shift;

    my @desks_loop;

    my $desks = GetDesks();
    foreach (@$desks) {
        push @desks_loop, {
            deskcode    => $_->{'deskcode'},
            deskname    => $_->{'deskname'},
            branchcode  => $_->{'branchcode'},
            selected    => ( defined $selcode && $selcode eq $_->{'deskcode'} ) ? 1 : undef,
        };
    }

    return \@desks_loop;
}

##
# Get the next open day
#
# param : branch code (optional)
# param : itemtype (optional)
# return : ISO date
##
sub GetDeskNextOpenDay(;$;$) {
    
    my $branch = shift;
    my $itemtype = shift;
    
    my $valid_desks = GetDesks($branch, 1, $itemtype);
    
    # Look for an open day
    my $max_date = C4::Stack::Rules::ComputeStackEndDate( sprintf("%04d-%02d-%02d", Today()), $SR_BEGIN_MAX_DAYS, $branch);
    my ($max_year, $max_month, $max_day ) = split(/-/, $max_date);
    my $nb_days = Delta_Days( Today(), $max_year, $max_month, $max_day );
    
    for ( my $i = 1 ; $i <= $nb_days ; $i++ ) {
        my ( $nyear, $nmonth, $nday ) = Add_Delta_Days( Today(), $i );
        my $iso_date = sprintf( "%04d-%02d-%02d", $nyear, $nmonth, $nday );
        foreach (@$valid_desks) {
            if (IsDeskOpen($_->{'deskcode'}, $iso_date)) {
                return $iso_date;
            }
        }
    }
    
    return undef;
}

##
# Get current time elements
#
# return : (hour, minute)
##
sub GetCurrentHourAndMinute() {
    
    my ( $test_a, $current_minute, $current_hour, $current_day, $current_month, $current_year, $test_b, $test_c, $test_d) = localtime(time);
    $current_month = $current_month + 1;
    $current_year = $current_year + 1900;
    
    return ($current_hour, $current_minute);
}

1;
__END__
