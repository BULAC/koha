#!/usr/bin/perl
#
# B11
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
use CGI;
use Time::Local;
use C4::Auth;
use C4::Koha;
use C4::Output;
use C4::Jasper::JasperReport;
use C4::Utils::String;
use C4::Callnumber::FreeAccessCallnumber;
use C4::Callnumber::StoreCallnumber;
use C4::Callnumber::Utils;


my $input = new CGI;
my $export = $input->param( 'export' );
my $display = $input->param( 'display' );

my $exporttype = $input->param( 'exporttype' ) || 'pdf';

my $location          = $input->param( 'location' )  || '';

my $callnumber_type = $input->param( 'callnumber_type' ) || 'store_callnumber'; 
my $callnumber_prefix = $input->param( 'callnumber_prefix' ) || '';
my $callnumber_min = $input->param( 'callnumber_min' ) || '';
my $callnumber_max = $input->param( 'callnumber_max' ) || '';

my $start_date = $input->param( 'start_date' ) || '';
my $end_date   = $input->param( 'end_date' )   || '';

my $first_criteria = $input->param( 'first_criteria' ) || '';
my $second_criteria = $input->param( 'second_criteria' ) || '';
my $third_criteria = $input->param( 'third_criteria' ) || '';
my $first_direction = $input->param( 'first_direction' ) || 'ASC';
my $second_direction = $input->param( 'second_direction' ) || 'ASC';
my $third_direction = $input->param( 'third_direction' ) || 'ASC';

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
	{
		template_name => "tools/callnumber_register.tmpl",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => {reports => '*'},
		debug => 1,
	}
);

my %criteria = (
	'callnumber' => 'items.cn_sort',
	'title' => 'biblio.title',
);

if ( exists $criteria{ $first_criteria } ){
  $first_criteria =  $criteria{ $first_criteria} ;
} else {
	$first_criteria = '';
}

if ( exists $criteria{ $second_criteria } ){
  $second_criteria =  $criteria{ $second_criteria} ;
} else {
	$second_criteria = '';
}

if ( exists $criteria{ $third_criteria } ){
  $third_criteria =  $criteria{ $third_criteria} ;
} else {
	$third_criteria = '';
}

unless ( $first_direction eq 'DESC' ) {
	$first_direction = 'ASC';
}
unless ( $second_direction eq 'DESC' ) {
	$second_direction = 'ASC';
}
unless ( $third_direction eq 'DESC' ) {
	$third_direction = 'ASC';
}

if ( $export ) {
	my $sort_field = '';
	if ( $first_criteria ) {
		$sort_field .= ' ORDER BY ';
	}
	if ( $first_criteria ) {
		$sort_field .= $first_criteria.' '.$first_direction;
		if ( $second_criteria ) {
			$sort_field .= ', '.$second_criteria.' '.$second_direction;
			if ( $third_criteria ) {
				$sort_field .= ', '.$third_criteria.' '.$third_direction;
			}
		}
	}
	
	$callnumber_prefix = TrimStr( $callnumber_prefix );
	#my $callnumber_prefix = '';
	#if ( $prefix_callnumber ne '' ) {
	#	my @prefix_parts = do { local $_ = $callnumber_prefix; split };
	#	$callnumber_prefix = join(' *', @prefix_parts);
	#	$callnumber_prefix = '^' . $callnumber_prefix;
	#	$callnumber_prefix =~ s/\./\\\./g;
	#}
	
	my $start;
	if ($start_date) {
		my ( $day, $month, $year ) = split( /\//, $start_date );
		$start = timegm( 0, 0, 12, $day, $month - 1, $year - 1900 );
		$start = $start * 1000; #Time in millisecond
	}
	
	my $end;
	if ($end_date) {
	    my ( $day, $month, $year ) = split( /\//, $end_date );
	    $end = timegm( 0, 0, 12, $day, $month - 1, $year - 1900 );
	    $end = $end * 1000; #Time in millisecond
	}
	
	my @report_parameters_list = ();
	my ( $report_directory, $report_name, $report_action ) = ( 'exports', 'registre_cotes', 'visualization' );
	my @report_errors = ();
	
	push( @report_parameters_list, 
	       { 
	       	   sort_field => $sort_field , 
	       	   location => $location,
	       	   callnumber_type => $callnumber_type,
	       	   callnumber_prefix => $callnumber_prefix,
	       	   callnumber_start => $callnumber_min,
	       	   callnumber_end => $callnumber_max,
	       	   start_date    => $start_date ? $start : '',
               end_date      => $end_date ? $end : '',
	       } 
	    );
	my ( $report_zipdirectory, $report_zipfile, @report_results ) = GenerateZip( $report_directory, $report_name, $report_action, \@report_parameters_list, $exporttype );
	
	for ( my $i = 0; $i < scalar( @report_parameters_list ); $i++ ) {
		if ( $report_results[$i] == 0) {
			push @report_errors, { report_name => $report_name, no_report_param => 1 }; 
		}
	}
	
	if ( ( scalar @report_errors ) < ( scalar @report_parameters_list ) ) {
		#At least one report to send
		$template->param(
		    report_zipdirectory => $report_zipdirectory,
			report_zipfile      => $report_zipfile,
			report_print        => $report_action eq 'print' ? 1 : 0,
		);
	}
		    
	if ( scalar @report_errors ) {
		$template->param(
			report_errors => \@report_errors,
		);
	}
	
}

if ( $display ) {
    my $sort_field = '';
    if ( $first_criteria ) {
        $sort_field .= ' ORDER BY ';
    }
    if ( $first_criteria ) {
        $sort_field .= $first_criteria.' '.$first_direction;
        if ( $second_criteria ) {
            $sort_field .= ', '.$second_criteria.' '.$second_direction;
            if ( $third_criteria ) {
                $sort_field .= ', '.$third_criteria.' '.$third_direction;
            }
        }
    }
    
    $callnumber_prefix = TrimStr( $callnumber_prefix );
    
    my $start;
    if ($start_date) {
        my ( $day, $month, $year ) = split( /\//, $start_date );
        $start = timegm( 0, 0, 12, $day, $month - 1, $year - 1900 );
        $start = $start * 1000; #Time in millisecond
    }
    
    my $end;
    if ($end_date) {
        my ( $day, $month, $year ) = split( /\//, $end_date );
        $end = timegm( 0, 0, 12, $day, $month - 1, $year - 1900 );
        $end = $end * 1000; #Time in millisecond
    }
    
    
    my $dbh = C4::Context->dbh;
    
    my @params;
    my $query = "
        SELECT items.itemnumber,
               items.itemcallnumber,
               items.cn_sort,
               biblioitems.volume,
               biblioitems.pages,
               biblio.title,
               biblio.author,
               biblioitems.publicationyear,
               aqorders.entrydate,
               aqorders.datereceived,
               items.itemnotes,
               items.stocknumber
        FROM items
            left outer join biblio on biblio.biblionumber = items.biblionumber
            left outer join biblioitems on biblioitems.biblioitemnumber = items.biblioitemnumber
            left outer join aqorders on aqorders.biblionumber = items.biblionumber
        WHERE 1=1";
        
     if ( $location && $location ne '' ) {
     	$query = $query . " AND items.location = ?";
     	push @params, $location;
     }
     if ( $start ) {
        $query = $query . " AND aqorders.datereceived >= ?";
        push @params, $start;
     }
     if ( $end ) {
        $query = $query . " AND aqorders.datereceived <= ?";
        push @params, $end;
     }

    my $sth = $dbh->prepare( $query . $sort_field );
    $sth->execute(@params);
    
    my $rows = $sth->fetchall_arrayref({});
    my @results;
    
    my $prefix = $callnumber_prefix;
    $prefix =~ s/[\s\.-]//g;
    my $min_value = int( $callnumber_min || 0);
    my $max_value = int( $callnumber_max || 999999 );
    
    foreach my $row ( @{$rows} ) {
        if ( C4::Callnumber::Utils::IsItemInStore($row->{itemnumber}) ) {
            my ( $base, $sequence, $rest ) =  C4::Callnumber::StoreCallnumber::GetBaseAndSequenceFromStoreCallnumber( $row->{itemcallnumber}, 0 );
            if ( $base =~ m/^$prefix/ && $sequence >= $min_value && $sequence <= $max_value ) {
            } else {
                next;
            }

        } else {
            my ( $base, $sequence ) =  C4::Callnumber::FreeAccessCallnumber::GetBaseAndSequenceFromFreeAccessCallnumber( $row->{itemcallnumber} );
            if ( $base eq $prefix && C4::Callnumber::FreeAccessCallnumber::IsSequenceBetweenMinMax( $sequence, $min_value, $max_value ) ) {

            } else {
                next;
            }
        }

        push (@results, $row);
    }
    
    if ( scalar @results ) {
        $template->param(
            results => \@results,
        );
    }
}

my $location_loop = GetAuthorisedValues( 'LOC', $location );
my @exporttype_loop = GetExportTypes( $exporttype );

$template->param(
    start_date => $start_date,
    end_date   => $end_date,
    locationloop      => $location_loop,
    callnumber_prefix => $callnumber_prefix,
    callnumber_min    => $callnumber_min,
    callnumber_max    => $callnumber_max,
    exporttypeloop => \@exporttype_loop,
    DHTMLcalendar_dateformat  => C4::Dates->DHTMLcalendar(),
    display =>  $display,
    
    'first_'.$first_criteria => 1,
    'first_'.$first_direction => 1,
    'second_'.$second_criteria => 1,
    'second_'.$second_direction => 1,
    
);

output_html_with_http_headers $input, $cookie, $template->output;
