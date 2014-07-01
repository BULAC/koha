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
use C4::Context;
use C4::Output;
use C4::Branch;
use C4::Members;
use C4::Stack::Desk;
use C4::Spaces::Space;
use C4::Koha;
use C4::Dates;
use Time::Local;
use C4::Jasper::JasperReport;

my $input = new CGI;
my $op = $input->param( 'op' ) || '';

my $reportname = $input->param( 'select_report' ) || 'nombre_communications';
my $exporttype = $input->param( 'exporttype' ) || 'pdf';

my %reports_name = (
	'not_seen'          => 'recolement_non_vus',
	'unknown_barcode'   => 'recolement_codes_barres_inconnus',
	'two_barcodes'      => 'recolement_deux_codes_barres',
	'weeding'           => 'recolement_desherbage',
	'preservation_data' => 'recolement_conservation',
	'inadequacy'        => 'recolement_non_conformite',
	'scanning'          => 'recolement_numerisation',
	'seen'              => 'recolement_vus_depuis',
);

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
	{
		template_name => "reports/recolement_stats.tmpl",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => {reports => '*'},
		debug => 1,
	}
);

if ( $op eq 'export' ) {
	
#	my ( $day, $month, $year ) = split( /\//, $start_date );
#	my $start = timegm( 0 , 0, 0, $day, $month - 1, $year - 1900 );
#	$start = $start * 1000; #Time in millisecond
#	( $day, $month, $year ) = split( /\//, $end_date );
#	my $end = timegm( 59 , 59, 23, $day, $month - 1, $year - 1900 );
#	$end = $end * 1000 + 999; #Time in millisecond
	
	my $report = '';
	if ( exists( $reports_name{ $reportname } ) ) {
		$report = $reports_name{ $reportname };
	}
	
	my @report_parameters_list = ();
	my ( $report_directory, $report_name, $report_action ) = ( 'recolement', $report, 'visualization' );
	my @report_errors = ();
	
	push ( @report_parameters_list, 
		{}
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

my @exporttype_loop = GetExportTypes( $exporttype );

$template->param(
	$reportname               => 1,
	exporttypeloop            => \@exporttype_loop,
);

output_html_with_http_headers $input, $cookie, $template->output;