#!/usr/bin/perl

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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use warnings;

use CGI;
use List::MoreUtils qw/any/;

use C4::Output;    # contains gettemplate
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Branch;
use C4::Utils::Constants;
use C4::Stack::Desk;

my $input = new CGI;
my $script_name = "/cgi-bin/koha/admin/desk/desk.pl";
my $offset      = $input->param('offset') || 0;
my $op          = $input->param('op') || 'list';
my $pagesize    = 20;

my $deskcode   = $input->param('deskcode') || '';
my $deskname   = $input->param('deskname') || '';
my $active     = $input->param('active') || 0;
my $branchcode = $input->param('branchcode') || '';

my ($template, $borrowernumber, $cookie)
    = get_template_and_user({template_name => "desk/desk.tmpl",
			     query => $input,
			     type => "intranet",
			     authnotrequired => 0,
			     flagsrequired => {parameters => 1},
			     debug => 1,
			     });

if ($op eq 'save') {
	$op = 'list';
	
	my $dbh = C4::Context->dbh;
	my $query;
	
	if ($deskcode and $deskcode ne '') {
		$query = 'UPDATE desk SET deskname=?, branchcode=?, active=? WHERE deskcode=?';
		my $sth=$dbh->prepare($query);
		$sth->execute($deskname, $branchcode, $active, $deskcode);
	} else {
		my $newdeskcode = $input->param('newdeskcode') || '';
		#Check if deskcode is not null
		if ($newdeskcode) {
			#Check if deskcode already exists
			$query = 'SELECT COUNT(*) FROM desk WHERE deskcode = ?';
			my $sth = $dbh->prepare( $query );
			$sth->execute( $newdeskcode );
	
			my $canChooseDeskCode = int( $sth->fetchrow );
			if ( $canChooseDeskCode ) {
				$template->param(
					message        => 1,
					EXISTING_CODE  => 1,
					newdeskcode    => $newdeskcode,
				);
				$op = 'add_form';
			} else {
				$query = 'INSERT INTO desk (deskcode, deskname, branchcode, active) VALUES (?, ?, ?, ?)';
				my $sth=$dbh->prepare($query);
				$sth->execute($newdeskcode, $deskname, $branchcode, $active);
				$deskcode = $newdeskcode;
			}
		} else {
			$template->param(
			     message     => 1,
			     EMPTY_CODE  => 1,
			);
			$op = 'add_form';
		}
	}
	
	if ( $op ne 'add_form' ) {
		#Save itemtypes for the desk
		my $itemtypes = GetItemTypes;
	    my @itemtypeloop = ();
	    my @deskitemtypes = GetDeskNotManagedItemTypes($deskcode);
	    foreach my $type (sort keys %$itemtypes) {
	        my $is_associated_to_desk = $input->param($type) || 0;
	        if ($is_associated_to_desk) {
	        	$query = 'INSERT INTO deskitemtype (deskcode, itemtype) VALUES (?, ?)';
				my $sth=$dbh->prepare($query);
				$sth->execute($deskcode, $type);
	        } else {
	        	$query = 'DELETE FROM deskitemtype WHERE deskcode=? AND itemtype=?';
				my $sth=$dbh->prepare($query);
				$sth->execute($deskcode, $type);
	        }
	    }
	}
	
}

if ($op eq 'add_form' || $op eq 'edit_form') {
	
	if ($op eq 'edit_form') {
		my $result = GetDesk($deskcode);
        $deskname   = $result->{'deskname'};
        $active     = $result->{'active'};
        $branchcode = $result->{'branchcode'};
	} elsif ($op eq 'add_form') {
	
	}
	
	#retrieve Branches
	my $branches = GetBranches;
	my @branchloop = ();
	my $first_branch;
    foreach (keys %$branches) {
        my $selected = "";
        if ( $branchcode eq $_ ) {
            $selected = "selected=\"selected\"";
        }
        my $entry = {
            branchcode => $_,
            branchname => $branches->{$_}->{'branchname'},
            selected   => $selected,
        };
        if ( $BULAC_BRANCH eq $_) {
            $first_branch = $entry;
        } else{
            push @branchloop, $entry;
        }
    }
	# force BULAC branch first
    unshift @branchloop, $first_branch if $first_branch;
    # sort by name
    @branchloop = sort { $a->{'branchname'} cmp $b->{'branchname'} } @branchloop ;
	
	#retrieve ItemTypes
	my $itemtypes = GetItemTypes;
    my @itemtypeloop = ();
    my @deskitemtypes = GetDeskNotManagedItemTypes($deskcode);
    foreach my $type (keys %$itemtypes) {
        my $checked = "";
        if ( any { $type eq $_ } @deskitemtypes ) {
            $checked = "checked=\"checked\"";
        }
        push @itemtypeloop, {
            itemtype    => $type,
            description => $itemtypes->{$type}->{'description'},
            checked     => $checked,
        };
    }
    # sort by name
    @itemtypeloop = sort { $a->{'description'} cmp $b->{'description'} } @itemtypeloop ;

	$template->param(
        'deskcode'   => $deskcode,
        'deskname'     => $deskname,
        'active'       => $active,
        'branchcode'   => $branchcode,
        'itemtypeloop' => \@itemtypeloop,
        'branchloop'   => \@branchloop,
    );
	
}

if ($op eq 'calendar') {
	
	my $results = GetDesks();
	my $count = scalar(@$results);
	my $calendardate = $input->param('calendardate') || 0;
	my $keydate;
	
	unless ( $calendardate ) {
		my $today = C4::Dates->new();
		$calendardate = $today->output('syspref');
		
		my $calendarinput = C4::Dates->new($input->param('calendardate')) || $today;
		unless($calendardate = $calendarinput->output('syspref')) {
			$calendardate = $today->output('syspref');
		}
		unless($keydate = $calendarinput->output('iso')) {
			$keydate = $today->output('iso');
		}
		$keydate =~ s/-/\//g;
	}
	
	my @desk;
	for (my $i=0; $i < $count; $i++){
		push @desk, {
	        'deskcode' => $results->[$i]{'deskcode'},
	        'deskname'   => $results->[$i]{'deskname'},
	        'active'     => $results->[$i]{'active'},
	        'branchcode' => $results->[$i]{'branchcode'},
	        'branchname' => GetBranchName($results->[$i]{'branchcode'}),
	        'selected'   => ($results->[$i]{'deskcode'} eq $deskcode) ? 1 : undef,
	    };
	}
	
	$template->param(
		'desk' => \@desk,
		'deskcode' => $deskcode,
		'calendardate' => $calendardate,
		'keydate'      => $keydate,
	);
	
	my $calendar = C4::Calendar->new(deskcode => $deskcode);
	
	if ($calendar) {
		
		my $week_days_holidays = $calendar->get_week_days_holidays();
		my @week_days;
		foreach my $weekday (keys %$week_days_holidays) {
	    	my %week_day;
	    	%week_day = (
	    		KEY => $weekday,
	    		CALENDAR_DATE => $week_days_holidays->{$weekday}{weekday},
	    		TITLE => $week_days_holidays->{$weekday}{title},
	    		DESCRIPTION => $week_days_holidays->{$weekday}{description},
	    		WEEKDAY => $week_days_holidays->{$weekday}{weekday},
	    		STARTHOUR => $week_days_holidays->{$weekday}{start_hour},
	    		STARTMINUTE => $week_days_holidays->{$weekday}{start_minute},
	    		ENDHOUR => $week_days_holidays->{$weekday}{end_hour},
	    		ENDMINUTE => $week_days_holidays->{$weekday}{end_minute},
	    	);
	    	push @week_days, \%week_day;
		}
	
		my $day_month_holidays = $calendar->get_day_month_holidays();
		my @day_month_holidays;
		foreach my $monthDay (keys %$day_month_holidays) {
	    	
	    	#Determine date format on month and day.
	    	my $day_monthdate;
	    	if (C4::Context->preference("dateformat") eq "metric") {
	      		$day_monthdate = "$day_month_holidays->{$monthDay}{day}/$day_month_holidays->{$monthDay}{month}";
	    	} elsif (C4::Context->preference("dateformat") eq "us") {
	      		$day_monthdate = "$day_month_holidays->{$monthDay}{month}/$day_month_holidays->{$monthDay}{day}";
	    	} else {
	      		$day_monthdate = "$day_month_holidays->{$monthDay}{month}-$day_month_holidays->{$monthDay}{day}";
	    	}
	    	
	    	my %day_month;
	    	%day_month = (
	    		KEY => $monthDay,
	    		CALENDAR_DATE => $day_monthdate,
	    		DATE => $day_monthdate,
	    		TITLE => $day_month_holidays->{$monthDay}{title},
	    		DESCRIPTION => $day_month_holidays->{$monthDay}{description},
	    		DAY => $day_month_holidays->{$monthDay}{day},
	    		MONTH => $day_month_holidays->{$monthDay}{month},
	    		STARTHOUR => $day_month_holidays->{$monthDay}{start_hour},
	    		STARTMINUTE => $day_month_holidays->{$monthDay}{start_minute},
	    		ENDHOUR => $day_month_holidays->{$monthDay}{end_hour},
	    		ENDMINUTE => $day_month_holidays->{$monthDay}{end_minute},
	    	);
	    	push @day_month_holidays, \%day_month;
		}
	
		my $exception_holidays = $calendar->get_exception_holidays();
		my @exception_holidays;
		foreach my $yearMonthDay (keys %$exception_holidays) {
			my $date = "$exception_holidays->{$yearMonthDay}{year}/$exception_holidays->{$yearMonthDay}{month}/$exception_holidays->{$yearMonthDay}{day}";
	    	my $exceptiondate = C4::Dates->new($date, "iso");
	    	
	    	my %exception_holiday;
	    	%exception_holiday = (
	    		KEY => $yearMonthDay,
	    		CALENDAR_DATE => $date,
	    		DATE => $exceptiondate->output("syspref"),
	    		TITLE => $exception_holidays->{$yearMonthDay}{title},
	    		DESCRIPTION => $exception_holidays->{$yearMonthDay}{description},
	    		YEAR => $exception_holidays->{$yearMonthDay}{year},
	    		MONTH => $exception_holidays->{$yearMonthDay}{month},
	    		DAY => $exception_holidays->{$yearMonthDay}{day},
	    		STARTHOUR => $exception_holidays->{$yearMonthDay}{start_hour},
	    		STARTMINUTE => $exception_holidays->{$yearMonthDay}{start_minute},
	    		ENDHOUR => $exception_holidays->{$yearMonthDay}{end_hour},
	    		ENDMINUTE => $exception_holidays->{$yearMonthDay}{end_minute},
	    	);
	    	push @exception_holidays, \%exception_holiday;
		}
	
		my $single_holidays = $calendar->get_single_holidays();
		my @holidays;
		foreach my $yearMonthDay (keys %$single_holidays) {
			my $date = "$single_holidays->{$yearMonthDay}{year}/$single_holidays->{$yearMonthDay}{month}/$single_holidays->{$yearMonthDay}{day}";
	    	my $holidaydate = C4::Dates->new($date, "iso");
			
			my %holiday;
			%holiday = (
				KEY => $yearMonthDay,
				CALENDAR_DATE => $date,
				DATE => $holidaydate->output("syspref"),
				TITLE => $single_holidays->{$yearMonthDay}{title},
				DESCRIPTION => $single_holidays->{$yearMonthDay}{description},
				YEAR => $single_holidays->{$yearMonthDay}{year},
	    		MONTH => $single_holidays->{$yearMonthDay}{month},
	    		DAY => $single_holidays->{$yearMonthDay}{day},
	    		STARTHOUR => $single_holidays->{$yearMonthDay}{start_hour},
	    		STARTMINUTE => $single_holidays->{$yearMonthDay}{start_minute},
	    		ENDHOUR => $single_holidays->{$yearMonthDay}{end_hour},
	    		ENDMINUTE => $single_holidays->{$yearMonthDay}{end_minute},
			);
	    	push @holidays, \%holiday;
		}
	
		$template->param(
			'WEEK_DAYS_LOOP'          => \@week_days,
			'HOLIDAYS_LOOP'           => \@holidays,
			'EXCEPTION_HOLIDAYS_LOOP' => \@exception_holidays,
			'DAY_MONTH_HOLIDAYS_LOOP' => \@day_month_holidays,
		);
	}
}

if ($op eq 'list') {
	my $results = GetDesks();
	my $count = scalar(@$results);
	my @loop_data;
	
	for (my $i=$offset; $i < ($offset+$pagesize<$count?$offset+$pagesize:$count); $i++){
		push @loop_data, {
	        'deskcode' => $results->[$i]{'deskcode'},
	        'deskname'   => $results->[$i]{'deskname'},
	        'active'     => $results->[$i]{'active'},
	        'branchcode' => $results->[$i]{'branchcode'},
	        'branchname' => GetBranchName($results->[$i]{'branchcode'}),
	    };
	}
	
	$template->param(loop => \@loop_data);
	
	if ($offset>0) {
		my $prevpage = $offset-$pagesize;
		$template->param(previous => "$script_name?offset=".$prevpage);
	}
	if ($offset+$pagesize<$count) {
		my $nextpage =$offset+$pagesize;
		$template->param(next => "$script_name?offset=".$nextpage);
	}
}

$template->param( script_name => $script_name);
$template->param($op => 1);

output_html_with_http_headers $input, $cookie, $template->output;
