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
use C4::Auth;
use C4::Output;
use C4::Jasper::JasperReport;

my $input = new CGI;
my $op = $input->param( 'op' );
my $exporttype = $input->param( 'exporttype' ) || 'pdf';
my $first_criteria = $input->param( 'first_criteria' ) || '';
my $second_criteria = $input->param( 'second_criteria' ) || '';
my $third_criteria = $input->param( 'third_criteria' ) || '';
my $first_direction = $input->param( 'first_direction' ) || 'ASC';
my $second_direction = $input->param( 'second_direction' ) || 'ASC';
my $third_direction = $input->param( 'third_direction' ) || 'ASC';

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
	{
		template_name => "reports/nonreturnedstacks_sort.tmpl",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => {reports => '*'},
		debug => 1,
	}
);

my %criteria = (
	'borrower' => "borrowers.surname",
	'desk_or_space' => "CONCAT(IFNULL(desk.deskname, ''), IFNULL(spacenamebooking, ''), IFNULL(spacenameoldbooking, ''))",
	'end_date' => "stack_requests.end_date",
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

if ( $op eq 'report' ) {
	my $sort_field = '';
	if ( $first_criteria ) {
		$sort_field .= ' ORDER BY '.$first_criteria.' '.$first_direction;
		if ( $second_criteria ) {
			$sort_field .= ', '.$second_criteria.' '.$second_direction;
			if ( $third_criteria ) {
				$sort_field .= ', '.$third_criteria.' '.$third_direction;
			}
		}
	}
	
	my @report_parameters_list = ();
	my ( $report_directory, $report_name, $report_action ) = ( 'exports', 'liste_communications_non_restitues', 'visualization' );
	my @report_errors = ();
	
	push( @report_parameters_list, { sort_field => $sort_field } );
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

my @exporttype_loop = GetExportTypes( $exporttype );	
	
$template->param(
	report => 'nonreturnedstacks.pl',
	exporttypeloop => \@exporttype_loop,
);

output_html_with_http_headers $input, $cookie, $template->output;
