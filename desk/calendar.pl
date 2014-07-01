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

use C4::Output;    # contains gettemplate
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Branch;

my $dbh = C4::Context->dbh;

my $input = new CGI;
my $script_name = "/cgi-bin/koha/admin/desk/calendar.pl";
my $op          = $input->param('op') || 'calendar';
my $operation   = $input->param('showOperation') || $input->param('newOperation') || 0;

my $deskcode = $input->param('deskcode') || '';
my $deskname   = $input->param('deskname') || '';

my ($template, $borrowernumber, $cookie)
    = get_template_and_user({template_name => "desk/desk.tmpl",
			     query => $input,
			     type => "intranet",
			     authnotrequired => 0,
			     flagsrequired => {parameters => 1},
			     debug => 1,
			     });

sub _search  {
	my ($deskcode) = @_;
	my $dbh = C4::Context->dbh;
	
	my $query = 'SELECT deskcode, deskname, active, branchcode FROM desk';
	if ($deskcode) {
		$query = "$query WHERE deskcode = $deskcode";
	}
	
	my $sth=$dbh->prepare($query);
	$sth->execute();
    return $sth->fetchall_arrayref({});
}

if ($op eq 'add') {
	$deskcode = $input->param('newHolidayDeskName');
	
	my $description  = $input->param('newDescription');
	my $dayName      = $input->param('newWeekday');
	my $day          = $input->param('newDay');
	my $month        = $input->param('newMonth');
	my $year         = $input->param('newYear');
	my $start_hour   = $input->param('newStartHour');
	my $start_minute = $input->param('newStartMinute');
	my $end_hour     = $input->param('newEndHour');
	my $end_minute   = $input->param('newEndMinute');
	
	my $allDesks = $input->param('allDesks') || 0;
	my @desks;
	
	if ( $allDesks ) {
		my $results = _search();
		my $count = scalar(@$results);
		for (my $i=0; $i < $count; $i++){
			push (@desks, $results->[$i]{'deskcode'});
		}
	} else {
		push (@desks, $deskcode);
	}
	
	foreach my $code (@desks) {
		if ($operation eq 'holiday') {
			my $query = 'INSERT INTO desk_special_holidays (deskcode, isexception, title, description, day, month, year, start_hour, start_minute, end_hour, end_minute) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
			my $sth=$dbh->prepare($query);
			$sth->execute($code, 0, '', $description, $day, $month, $year, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
			
		} elsif ($operation eq 'weekday') {
			my $query = 'INSERT INTO desk_repeatable_holidays (deskcode, title, description, weekday, start_hour, start_minute, end_hour, end_minute) VALUES (?, ?, ?, ?, ?, ?, ?, ?)';
			my $sth=$dbh->prepare($query);
			$sth->execute($code, '', $description, $dayName, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
			
		} elsif ($operation eq 'repeatable') {
			my $query = 'INSERT INTO desk_repeatable_holidays (deskcode, title, description, day, month, start_hour, start_minute, end_hour, end_minute) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';
			my $sth=$dbh->prepare($query);
			$sth->execute($code, '', $description, $day, $month, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
			
		}
	}
	
	$op = 'calendar';
}

if ($op eq 'edit') {
	
	$deskcode = $input->param('showHolidayDeskName');
	my $holidayType = $input->param('showHolidayType');
	
	my $title        = $input->param('showTitle');
	my $description  = $input->param('showDescription');
	my $dayName      = $input->param('showWeekday');
	my $day          = $input->param('showDay');
	my $month        = $input->param('showMonth');
	my $year         = $input->param('showYear');
	my $start_hour   = $input->param('showStartHour');
	my $start_minute = $input->param('showStartMinute');
	my $end_hour     = $input->param('showEndHour');
	my $end_minute   = $input->param('showEndMinute');
	
	if ($operation eq 'exception') {
		my $query = 'INSERT INTO desk_special_holidays (deskcode, isexception, title, description, day, month, year, start_hour, start_minute, end_hour, end_minute) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
		my $sth=$dbh->prepare($query);
		$sth->execute($deskcode, 1, $title, $description, $day, $month, $year, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
	
	} elsif ($operation eq 'delete') {
		if ($holidayType eq 'ymd' || $holidayType eq 'exception') {
			my $isexception = ($holidayType eq 'exception') ? 1 : 0;
			my $query = 'DELETE FROM desk_special_holidays WHERE deskcode=? AND isexception=? AND day=? AND month=? AND year=? AND start_hour=? AND start_minute=? AND end_hour=? AND end_minute=?';
			my $sth=$dbh->prepare($query);
			$sth->execute($deskcode, $isexception, $day, $month, $year, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
			
		} elsif ($holidayType eq 'daymonth') {
			my $query = 'DELETE FROM desk_repeatable_holidays WHERE deskcode=? AND day=? AND month=? AND start_hour=? AND start_minute=? AND end_hour=? AND end_minute=?';
			my $sth=$dbh->prepare($query);
			$sth->execute($deskcode, $day, $month, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
		
		} elsif ($holidayType eq 'weekday') {
			my $query = 'DELETE FROM desk_repeatable_holidays WHERE deskcode=? AND weekday=? AND start_hour=? AND start_minute=? AND end_hour=? AND end_minute=?';
			my $sth=$dbh->prepare($query);
			$sth->execute($deskcode, $dayName, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
			
		}
	
	} elsif ($operation eq 'edit') {
		#Only the description can be edited
		
		if ($holidayType eq 'ymd' || $holidayType eq 'exception') {
			my $isexception = ($holidayType eq 'exception') ? 1 : 0;
			my $query = 'UPDATE desk_special_holidays SET description=? WHERE deskcode=? AND isexception=? AND day=? AND month=? AND year=? AND start_hour=? AND start_minute=? AND end_hour=? AND end_minute=?';
			my $sth=$dbh->prepare($query);
			$sth->execute($description, $deskcode, $isexception, $day, $month, $year, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
			
		} elsif ($holidayType eq 'daymonth') {
			my $query = 'UPDATE desk_repeatable_holidays SET description=? WHERE deskcode=? AND day=? AND month=? AND start_hour=? AND start_minute=? AND end_hour=? AND end_minute=?';
			my $sth=$dbh->prepare($query);
			$sth->execute($description, $deskcode, $day, $month, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
		
		} elsif ($holidayType eq 'weekday') {
			my $query = 'UPDATE desk_repeatable_holidays SET description=? WHERE deskcode=? AND weekday=? AND start_hour=? AND start_minute=? AND end_hour=? AND end_minute=?';
			my $sth=$dbh->prepare($query);
			$sth->execute($description, $deskcode, $dayName, int($start_hour), int($start_minute), int($end_hour), int($end_minute));
			
		}
	}
	
	$op = 'calendar';
}

if ($op eq 'calendar') {
	
	my $results = _search();
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
	        'selected'   => ($results->[$i]{'deskcode'} eq $deskcode),
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

$template->param( script_name => $script_name);
$template->param($op => 1);

output_html_with_http_headers $input, $cookie, $template->output;
