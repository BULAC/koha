#! /usr/bin/perl

##
# B031 - Stack request form page
##

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use CGI;
use Date::Calc qw(
    Today
    Add_Delta_Days
    Delta_Days
);
use C4::Auth qw(:DEFAULT get_session);
use C4::Context;
use C4::Output;
use C4::Dates qw(format_date format_date_in_iso);
use C4::Biblio;
use C4::Members;
use C4::Serials;
use C4::Stack::Desk;
use C4::Stack::Rules;
use C4::Stack::Manager;
use C4::Stack::Search;
use C4::Callnumber::Utils;
use C4::Spaces::Connector;
use C4::Utils::Constants;

#
# Trim string
#
sub trim($){
    my $str = shift;
    if ($str) {
        $str =~ s/^\s+//;
        $str =~ s/\s+$//;
    }
    return $str;
}

#
# Constants
#

# can't request errors
my $NOT_AVAILABLE_ERR       = 'NOT_AVAILABLE';
my $WRONG_BRANCH            = 'WRONG_BRANCH';

# alerts
my $NO_DELIVERY_ERR         = 'NO_DELIVERY';
my $QUOTA_ZERO              = 'QUOTA_ZERO';

# post errors
my $NO_TITLE_ERR            = 'NO_TITLE';
my $NO_CALLNUMBER_ERR       = 'NO_CALLNUMBER';
my $NO_YEARS_ERR            = 'NO_YEARS';
my $NO_NUMBERS_ERR          = 'NO_NUMBERS';
my $INVALID_DATE_FORMAT_ERR = 'INVALID_DATE_FORMAT';
my $INVALID_DATE_MIN_ERR    = 'INVALID_DATE_MIN';
my $DESK_DATE_ERR           = 'DESK_DATE_ERR';
my $CLOSED_LIB_ERR          = 'CLOSED_LIB'; # MAN204
my $INVALID_DATE_MAX_ERR    = 'INVALID_DATE_MAX';

#
# Template
#
my $query = new CGI;
my $dbh = C4::Context->dbh;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-stack-request.tmpl",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

# MAN296
unless (C4::Context->preference('UseStackrequest')) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}
# END MAN296

#
# Input params
#

# indicates the form post
my $dorequest    = $query->param('dorequest')    || '';
my $dodesk       = $query->param('dodesk')       || '';

my $itemnumber   = $query->param('itemnumber')   || undef;
my $biblionumber = $query->param('biblionumber') || undef;

#
# Common vars
#
my @cantrq_loop;
my $borrinfo;

my $isgeneric;

my $onitem;   #request on item
my $onserial; # request on a serial without item
my $onempty;  # request on item not in digital catalog

my $instantrq; # is an instant request (else a delayed)
my $allow_instantrq; # allow instant request
my $c4_default_begdate;
my $default_begdate_is_today;
my $c4_max_begdate;

my $iteminfo;
my $serialinfo;

my $is_item_in_res_store;

my $spaces;

my $itemtype;
my $title;
my $author;
my $pubyear;
my $callnumber;
my $barcode;
my $years;
my $numbers;
my $begdate;
my $notes;

my $must_choose_desk;
my $desks_loop;
my $desk;

my $borrbranch;

#
# Get borrower infos
#
if ($borrowernumber) {
    $borrinfo = GetMemberDetails( $borrowernumber, undef );
    $borrbranch = $borrinfo->{'branchcode'};
    
    # pre-subscripted borrower
    if ($borrinfo->{'categorycode'} && $borrinfo->{'categorycode'} eq $PRE_REG_CATEGORY) {
        
        $template->param(
            borr_is_preins => 1,
        );
        output_html_with_http_headers $query, $cookie, $template->output;
        exit;
    }
}

#
# Can borrower create stack request ?
#
my $borr_loop = GetBorrowerControls($borrinfo);
push(@cantrq_loop, @$borr_loop);

#
# Stack on item, biblio or empty
#
if ($itemnumber) {
    
    # Control if item exists
    $iteminfo = GetBiblioFromItemNumber($itemnumber); # join on bilio and biblioitems table
    unless ($iteminfo) {
        print $query->redirect("/cgi-bin/koha/errors/404.pl");
        exit;
    }
    
    # MAN106 serial generic item
    if (defined $iteminfo->{'notforloan'} && $iteminfo->{'notforloan'} eq $AV_ETAT_GENERIC) {
        $isgeneric = 1;
    }

    # Control if item can be requested
    # (usually useless because done before, but database can have changed)
    unless (CanRequestStackOnItem($itemnumber)) {
        push(@cantrq_loop, {
            $NOT_AVAILABLE_ERR => 1
        });
    }
    
    # MAN205 can't request an item of another branch
    unless ($iteminfo->{'holdingbranch'} && $iteminfo->{'holdingbranch'} eq $borrbranch) {
        push(@cantrq_loop, {
            $WRONG_BRANCH => 1
        });
    }
    
    $itemtype = (C4::Context->preference('item-level_itypes')) ? $iteminfo->{'itype'} : $iteminfo->{'itemtype'};
    $title      = $iteminfo->{'title'};
    $author     = $iteminfo->{'author'};
    $pubyear    = $iteminfo->{'publicationyear'};
    $callnumber = $iteminfo->{'itemcallnumber'};
    $barcode    = $iteminfo->{'barcode'};
    
    # location
    $is_item_in_res_store = IsItemInResStore($itemnumber);
    
    unless ($isgeneric) {
        $onitem = 1;
    }
}
if (!$onitem && ($biblionumber || $isgeneric)) {
    
    $onserial = 2;
    if ($isgeneric) {
        $biblionumber = $iteminfo->{'biblionumber'};
    }
    $serialinfo = GetSubscriptionsFromBiblionumber($biblionumber);
    
    # dont make serial tests if generic
    if (!$isgeneric) {
        
        $onserial = 1;
        
        # Control if serial exists
        unless (scalar @$serialinfo) {
            print $query->redirect("/cgi-bin/koha/errors/404.pl");
            exit;
        }
        
        # Control if biblio can be requested
        # (usually useless because done before, but database can have changed)
        unless ( CanRequestStackOnBiblio($biblionumber) ) {
            push(@cantrq_loop, {
                $NOT_AVAILABLE_ERR => 1
            });
        }
        
        if (scalar @$serialinfo) {
	        $title      = $$serialinfo[0]->{'bibliotitle'};
	        $author     = $$serialinfo[0]->{'biblioauthor'};
	        $callnumber = $$serialinfo[0]->{'callnumber'};
	    }
    }
    
    # if generic datas will comme from item
    
}
if (!$onitem && !$onserial) {
    $onempty = 1;
}

if (scalar @cantrq_loop) {
    
    $template->param(
        cantrq_loop => \@cantrq_loop,
    );
    output_html_with_http_headers $query, $cookie, $template->output;
    exit;
}

#
# Retrieve space reservations with impact on stackrequest
# for reserve item, don't allow space selection MAN201
#
unless ($is_item_in_res_store) {
    $spaces = GetReservedSpaces($borrowernumber, 1);
}

# 
# Check if borrower is allowed to create request for this item type, before form post
# MAN091
# 
my $issuingrule = GetIssuingRuleForStack($borrowernumber, $itemnumber);
if ($issuingrule->{'maxstackqty'} == 0) {
    push(@cantrq_loop, {
        $QUOTA_ZERO => 1
    });
}

#
# Max begin date
#

my $iso_begin_max_date = ComputeStackEndDate( sprintf("%04d-%02d-%02d", Today()), $SR_BEGIN_MAX_DAYS, $borrbranch );
$c4_max_begdate = C4::Dates->new($iso_begin_max_date, 'iso');

#
# Default begin date
#
($c4_default_begdate, $default_begdate_is_today) = GetDefaultDateForStackRequest($borrbranch, $itemtype, $spaces);
unless ($c4_default_begdate) {
    
    push(@cantrq_loop, {
        $NO_DELIVERY_ERR => 1
    });
}
else {
    # apply default value
    $begdate = $c4_default_begdate->output();
    
    if ($default_begdate_is_today) {
        # instant request
        $instantrq = 1;
        # min begdate is today so allow to create instant request
        $allow_instantrq = 1;
    }
}

#
# Can't request case
#
if (scalar @cantrq_loop) {
    
    $template->param(
        cantrq_loop => \@cantrq_loop,
        max_begdate => ($c4_max_begdate) ? $c4_max_begdate->output() : undef,
    );
    output_html_with_http_headers $query, $cookie, $template->output;
    exit;
}

##
# If posted form
##
if ($dorequest || $dodesk) {

    #
    # Local vars
    #   
    my @post_err_loop;
    my $asked_begdate_iso;
    my $reserved_space;
    
    #
    # Input params
    #
    if ($onempty) {
        $title      = trim($query->param('title'))      || '';
        $author     = trim($query->param('author'))     || '';
        $pubyear    = trim($query->param('pubyear'))    || '';
        $callnumber = trim($query->param('callnumber')) || '';
    }
    
    $years   = trim($query->param('years'))   || '';
    $numbers = trim($query->param('numbers')) || '';
    
    # begin date
    $begdate = trim($query->param('begdate')) || '';
    
    $notes = trim($query->param('notes')) || '';
    
    #
    # Form errors
    #
    
    # Mandatory fields
    if ($onempty) {
        unless ($title) {
            push(@post_err_loop, { $NO_TITLE_ERR => 1 }); 
        }
        unless ($callnumber) {
            push(@post_err_loop, { $NO_CALLNUMBER_ERR => 1 }); 
        }
    }
    if ($onserial) {
        unless ($years) {
            push(@post_err_loop, { $NO_YEARS_ERR => 1 }); 
        }
        unless ($numbers) {
            push(@post_err_loop, { $NO_NUMBERS_ERR => 1 }); 
        }
    }
    
    # date
    if ($begdate =~ C4::Dates->regexp('syspref')) {
        $asked_begdate_iso = C4::Dates->new($begdate)->output('iso');
    } else {
        push(@post_err_loop, { $INVALID_DATE_FORMAT_ERR => 1 });
    }
    
    unless (scalar @post_err_loop) {
        
        unless ($is_item_in_res_store) {
            #
            # Look for booked space concerned at choosen date
            #
            $reserved_space = GetReservedSpaceByDate($borrowernumber, $asked_begdate_iso, 1);
        }
        
        #
        # Control begin date
        #
        if ($asked_begdate_iso ne $c4_default_begdate->output('iso') || !$default_begdate_is_today ) {
            $instantrq = undef;
        }
        
        unless ($reserved_space) {
            
            if ($asked_begdate_iso lt C4::Dates->today('iso')) {
                # can't request in the past
                push(@post_err_loop, { $INVALID_DATE_MIN_ERR => 1 });
            }
            elsif ($asked_begdate_iso gt $c4_max_begdate->output('iso')) {
                # can't request in more than 15 days
                push(@post_err_loop, { $INVALID_DATE_MAX_ERR => 1 });
            }
            elsif ( !IsBranchOpen($borrbranch, $asked_begdate_iso) ) {
                # branch is not open
                push(@post_err_loop, { $CLOSED_LIB_ERR => 1 });
            }
        
        } else {
            
            # look for first open day in space booking period, beginning with asked date
            
            my $inspace_begdate_iso = undef;
            my $inspace_date_iso = $asked_begdate_iso;
            while ( $inspace_date_iso le $reserved_space->{'end_date'} ) {
                if (IsBranchOpen($borrbranch, $inspace_date_iso)) {
                    # open date found
                    $inspace_begdate_iso = $inspace_date_iso;
                    last;
                }
                # branch is not open, try next day
                my ($year, $month, $day) = Add_Delta_Days( split(/-/, $inspace_date_iso), 1 );
                $inspace_date_iso = sprintf("%04d-%02d-%02d", $year, $month, $day);
            }
            
            if ($inspace_begdate_iso) {
                $asked_begdate_iso = $inspace_begdate_iso;
            } else {
                push(@post_err_loop, { $CLOSED_LIB_ERR => 1 });
            }
        }
    }
    
    unless (scalar @post_err_loop) {
        
        #
        # Desk or space
        #
        
        # if request is for a space reservation => no desk
        unless ($reserved_space) {
           
           # For instant request, chech availability with time
           my ($hour, $minute);
           if ($instantrq || $asked_begdate_iso eq C4::Dates->today('iso')) {
               ($hour, $minute) = GetCurrentHourAndMinute();
           }
           
           if ($onitem && $is_item_in_res_store) {
               
               # force reserve desk
               $desk = $DESK_RESERVE_CODE;
               
               # Test if desk is available at this date
               unless (IsDeskOpen($desk, $asked_begdate_iso, $hour, $minute)) {
                   push(@post_err_loop, { $DESK_DATE_ERR => 1 });
               }
               
           } else {
               
               # show all active desk
               $desks_loop = GetAvailableDesksLoop(
                    $asked_begdate_iso,
                    $borrbranch,
                    $itemtype,
                    $DESK_DEFAULT_CODE,
                    $hour,
                    $minute,
                );
               
               if (scalar @$desks_loop == 0){
                   push(@post_err_loop, { $DESK_DATE_ERR => 1 });
               }
               elsif (scalar @$desks_loop == 1) {
                   $desk = $$desks_loop[0]->{'deskcode'};
               }
               else {
                   $must_choose_desk = 1;
               }
           }
        }
        
        #
        # No form errors,
        # Check if request is possible
        #
        my ($can_req, $needs_confirm) = GetIssuingControls(
            $borrowernumber,
            $itemnumber,
            $instantrq,
            $asked_begdate_iso,
            $reserved_space,
            $is_item_in_res_store
        );
        push(@post_err_loop, @$can_req);
        push(@post_err_loop, @$needs_confirm);
    }
    
    unless (scalar @post_err_loop) {
    
        ##
        # If mustn't choose desk or posted desk form
        ##
        if (!$must_choose_desk || $dodesk) {
            
            ##
            # Request will be created
            ##
            
            my $instant_wait_min = C4::Context->preference('StackRequestWaitingTime');
            my $item_desc = "$title [$callnumber]";
            
            if ($reserved_space) {
                
                $template->param(
                    space_lib => $reserved_space->{'space_lib'},
                );
                
            } else {
                
                my $desk_name;
                my $desk_not_open_yet;
                my $desk_delivery_hour;
                my $desk_delivery_min;
                
                # Choosen desk
                if ($dodesk) {
                    $desk = $query->param('desk');
                }
                $desk_name = GetDesk($desk)->{'deskname'};
                
                # opening time
                my $deskcalendar = C4::Calendar->new( deskcode => $desk );
                my ($byear, $bmonth, $bday) = split(/-/, $asked_begdate_iso);
                if ($instantrq) {
                    my $curr_hour;
                    my $curr_min;
                    ($curr_hour, $curr_min) = GetCurrentHourAndMinute();
                    ($desk_delivery_hour, $desk_delivery_min) = $deskcalendar->getOpeningTime($bday, $bmonth, $byear, $curr_hour, $curr_min);
                    unless ($desk_delivery_hour == $curr_hour && $desk_delivery_min == $curr_min) {
                        $desk_not_open_yet = 1;
                    }
                } else {
                    ($desk_delivery_hour, $desk_delivery_min) = $deskcalendar->getOpeningTime($bday, $bmonth, $byear);
                }
                
                # MAN337 add waiting time to opening time
                if (defined $desk_delivery_hour && defined $desk_delivery_min) {
                    my $tmp_minutes = $desk_delivery_hour * 60 + $desk_delivery_min + $instant_wait_min;
                    $desk_delivery_min  = $tmp_minutes % 60;
                    $desk_delivery_hour = ($tmp_minutes - $desk_delivery_min) / 60;
                }
                
                $template->param(
                    desk_name           => $desk_name,
                    desk_not_open_yet   => $desk_not_open_yet,
                    desk_delivery_hour  => sprintf( "%02d", $desk_delivery_hour),
                    desk_delivery_min   => sprintf( "%02d", $desk_delivery_min),
                );
            }
            
            $template->param(
                item_desc        => $item_desc,
                instant_wait_min => $instant_wait_min,
            );
            
            # MAN202
            # read session variables
            my $session = get_session($query->cookie("CGISESSID"));
            if ($session) {
                $template->param(
                    currentsearchurl => $session->param( 'currentsearchurl' ),
                );
            }
            # END MAN202
            
            #
            # Create request
            #
            my $id = CreateStackRequest({ 
                borrowernumber  => $borrowernumber,
                space           => $reserved_space,
                biblionumber    => $biblionumber,
                itemnumber      => $itemnumber,
                
                delivery_desk   => $desk,
                begin_date      => $asked_begdate_iso,
                
                notes           => $notes,
                nc_title        => $title,
                nc_author       => $author,
                nc_pubyear      => $pubyear,
                nc_callnumber   => $callnumber,
                nc_years        => $years,
                nc_numbers      => $numbers,
                
                onitem          => $onitem,
                onserial        => $onserial,
                onempty         => $onempty,
                
                isgeneric       => $isgeneric,
                instantrq       => $instantrq,
            });
            
            my $stack = GetStackById($id);
            die "Impossible to create stack request in database" unless $stack;
            
            $template->param(
                confirmed_begdate => $stack->{'begin_date_ui'},
            );
            
        } else {
            
            $template->param(
                desks_loop       => $desks_loop,
                must_choose_desk => $must_choose_desk,
            );
        }
        
        $template->param(
            post_ok => 1,
        );
        
    } else {
        
        $template->param(
            post_err_loop => \@post_err_loop,
        );
    }
    
    #
    # Output vars
    #
    $template->param(
        post => 1,
    );
}

#
# Output vars
#
$template->param(
    onempty         => $onempty,
    
    onitem          => $onitem,
    itemnumber      => $itemnumber,
    
    onserial        => $onserial,
    biblionumber    => $biblionumber, 
    
    title           => $title,
    author          => $author,
    pubyear         => $pubyear,
    callnumber      => $callnumber,
    barcode         => $barcode,
    
    years           => $years,
    numbers         => $numbers,
    
    DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
    begdate         => $begdate,
    default_begdate => ($c4_default_begdate) ? $c4_default_begdate->output() : undef,
    max_begdate     => ($c4_max_begdate)     ? $c4_max_begdate->output() : undef,
    today_date      => C4::Dates->today(),
    
    instantrq       => $instantrq,
    allow_instantrq => $allow_instantrq,
    
    notes           => $notes,
    
    spaces_loop     => $spaces,
    spaces_count    => (defined $spaces) ? scalar @$spaces : 0,
);

output_html_with_http_headers $query, $cookie, $template->output;

