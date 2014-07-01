#!/usr/bin/perl

#
# Progilone B10: StoreCallnumber
#

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
use Time::Local;
use C4::Auth;
use C4::Context;
use C4::Dates;
use C4::Output;
use C4::Koha;
use C4::Members;
use C4::Spaces::SCA;

my $input = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/borrowerSCABatch.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => '*' },
        debug           => 1,
    }
);

my $op = $input->param( 'op' ) || '';

my $end_date   = $input->param( 'end_date' ) || '';
my $category = $input->param( 'category' ) || '';

my $error_sca = 0;

my $end;

my @scaCsv = $input->param('scaCsv');
if (@scaCsv) {
	my @csvInfos;
    foreach my $temp(@scaCsv){
        my @csvInfo = split(/;/, $temp);
        push @csvInfos,\@csvInfo;
    }
    
    # export csv
    _export_csv($input,@csvInfos);
} else {

	if ($op eq 'op') {
		if ($end_date) {
			$end = C4::Dates::format_date_in_iso( $end_date )
		} else {
			$error_sca = 1;
			$template->param( error_sca => 1);
			$template->param( error_message => 'MISSING_DATE');
		}
		
		unless ( $category ) {
			$error_sca = 1;
		    $template->param( error_sca => 1);
		    $template->param( error_message => 'MISSING_CATEGORY');
		}
	}
	
	if ( $error_sca == 0 && $op eq 'op' ) {
		
		my $dbh = C4::Context->dbh;
	    my $query = "SELECT borrowernumber, cardnumber, surname, firstname, dateenrolled, dateexpiry FROM borrowers WHERE categorycode = ? AND dateenrolled <= ? AND sca_enrolled_by = ''";
	    my $sth = $dbh->prepare( $query );
	    $sth->execute( $category, $end );
	    
	    my @sca_ok_loop;
	    my @sca_fail_loop;
	    
	    my $rows = $sth->fetchall_arrayref({});
	    foreach my $row ( @{$rows} ) {
	        my $borrowernumber = @$row{'borrowernumber'};
	        my $cardnumber = @$row{'cardnumber'};
	        my $surname = @$row{'surname'};
	        my $firstname = @$row{'firstname'};
	        my $dateenrolled = @$row{'dateenrolled'};
	        my $dateexpiry = @$row{'dateexpiry'};
	        
	        my ($status, $message, $enrolled_by) = AddScaUser( $borrowernumber );
	        
	        if ($status) {
	            ModMember(
                    borrowernumber => $borrowernumber, 
                    sca_enrolled_by => $enrolled_by
                );
	        	my %borrower = (
	        	   cardnumber => $cardnumber,
	        	   surname => $surname,
	        	   firstname => $firstname,
	        	   dateenrolled => $dateenrolled,
	        	   dateexpiry => $dateexpiry,
	            );
	            push @sca_ok_loop, \%borrower;
	        } else {
	        	my %borrower = (
	               cardnumber => $cardnumber,
	               surname => $surname,
	               firstname => $firstname,
	               dateenrolled => $dateenrolled,
	               dateexpiry => $dateexpiry,
	               message => $message,
	            );
	            push @sca_fail_loop, \%borrower;
	        }
	        
	    }
	        
	    if (scalar( @sca_ok_loop ) > 0) {
	    	$template->param( sca_ok => 1);
	        $template->param( sca_ok_loop => \@sca_ok_loop);
	    }
	    if (scalar( @sca_fail_loop ) > 0) {
	    	$template->param( sca_fail => 1);
	        $template->param( sca_fail_loop => \@sca_fail_loop);
	    }
	    
	}
	
	my $category_loop = GetBorrowercategoryList();
	my @filtered_category_loop = ();
	
	foreach my $elem ( @$category_loop ) {
	    if ( $elem->{'categorycode'} eq '07BULAC' || $elem->{'categorycode'} eq '08PEB' || $elem->{'categorycode'} eq '09ASSOC' || $elem->{'categorycode'} eq '10PART' || $elem->{'categorycode'} eq '11PREINS') {
            next;
        }
	    if ( $elem->{'categorycode'} eq $category ) {
	        $elem->{'selected'} = 'selected';
	    }
	    push(@filtered_category_loop, $elem);
	}
	
	$template->param(
	    'end_date' => $end_date,
	    'category'   => $category,
	    'category_loop'    => \@filtered_category_loop,
	    DHTMLcalendar_dateformat  => C4::Dates->DHTMLcalendar(),
	);
	
	output_html_with_http_headers $input, $cookie, $template->output;
	exit;
}

sub _export_csv {
    my ($input,@resexport) = @_;
    
    eval {use Text::CSV};
    eval {use Text::CSV::Encoded};
    my $csv = Text::CSV::Encoded->new ({ encoding_in  => "utf8", encoding_out => "iso-8859-1" }) or
            die Text::CSV->error_diag ();
    print $input->header(
        -type       => 'text/csv',
        -charset    => 'utf-8',
        -attachment => 'sca_borrower_enlistment.csv',
    );
    
    # lignes
    foreach my $row ( @resexport ) {
        $csv->combine(@$row);
        print $csv->string, "\n";
    }
    exit;
}
