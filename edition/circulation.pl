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
use Date::Calc qw(check_date);
use Time::Local;
use C4::Jasper::JasperReport;

my $input = new CGI;
my $op = $input->param( 'op' ) || '';

my $reportname = $input->param( 'select_report' ) || '';
my $exporttype = $input->param( 'exporttype' ) || 'pdf';

my $branch    = $input->param( 'branch' )    || 'BULAC';
my $location  = $input->param( 'location' )  || '';
my $desk      = $input->param( 'desk' )      || '';
my $spacetype = $input->param( 'spacetype' ) || '';
my $category  = $input->param( 'category' )  || '';
my $bsort2    = $input->param( 'bsort2' )    || '';
my $bsort1    = $input->param( 'bsort1' )    || '';
my $bsort3    = $input->param( 'bsort3' )    || '';
my $ccode     = $input->param( 'ccode' )     || '';
my $itemtype  = $input->param( 'itemtype' )  || '';
my $language  = $input->param( 'language' )  || '';
my $writing   = $input->param( 'writing' )   || '';
my $country   = $input->param( 'country' )   || '';

my $start_date = $input->param( 'start_date' ) || '';
my $end_date   = $input->param( 'end_date' )   || '';
my $date_group = $input->param( 'date_group' ) || 'NONE';

my %reports_name = (
	'stackrequests'                 => 'statistiques_communications',
	'reserves'                      => 'statistiques_reservations',
	'issues'                        => 'statistiques_prets',
	'most_reserved_references'      => 'statistiques_references_plus_reservees',
	'most_stackrequest_references'  => 'statistiques_references_plus_communiquees',
	'most_issued_references'        => 'statistiques_references_plus_pretees',
	'stackrequests_follow_by_issue' => 'statistiques_communications_puis_pret',
	'stackrequests_on_absent'       => 'statistiques_communications_sur_absent',
	'average_time_stackrequests'    => 'statistiques_duree_moyenne_communications',
	'average_time_issues'           => 'statistiques_duree_moyenne_prets',
	'average_time_reserves'         => 'statistiques_duree_moyenne_reservations',
	'unsatisfied_stackrequests'     => 'statistiques_communications_non_satisfaite',
	'borrowers'                     => 'statistiques_usagers',
	'duplications'                  => 'statistiques_reproductions',
	'spaces'                        => 'statistiques_espaces',
	'average_time_spaces'           => 'statistiques_duree_moyenne_espaces',
	'temporary_items'               => 'statistiques_exemplarisations',
);

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
	{
		template_name => "reports/circulation_stats.tmpl",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => {reports => '*'},
		debug => 1,
	}
);

my $ok = 1;
my $start;
my $end;
my @error_loop;

if ($op eq 'export' ) {
	
	unless ($reportname) {
		$ok = 0;
        push(@error_loop, { 'REPORT_EMPTY' => 1 });
	}
	
	unless ($start_date) {
		$ok = 0;
		push(@error_loop, { 'START_EMPTY' => 1 });
	} else {
		my ( $day, $month, $year ) = split( /\//, $start_date );
		if (!check_date($year, $month, $day)) {
		    $ok = 0;
		    push(@error_loop, { 'START_INVALID' => 1 });
		} else {
		    $start = timegm( 0, 0, 12, $day, $month - 1, $year - 1900 );
		    $start = $start * 1000; #Time in millisecond
		}
	}
	
	unless ($end_date) {
	    $ok = 0;
	    push(@error_loop, { 'END_EMPTY' => 1 });
	} else {
		my ( $day, $month, $year ) = split( /\//, $end_date );
		if (!check_date($year, $month, $day)) {
		    $ok = 0;
		    push(@error_loop, { 'END_INVALID' => 1 });
		} else {
		    $end = timegm( 0, 0, 12, $day, $month - 1, $year - 1900 );
		    $end = $end * 1000; #Time in millisecond
		}
	}
}

if ( $ok && $op eq 'export' ) {
	my $report = '';
	if ( exists( $reports_name{ $reportname } ) ) {
		$report = $reports_name{ $reportname };
	}
	
	my @report_parameters_list = ();
	my ( $report_directory, $report_name, $report_action ) = ( 'stats', $report, 'visualization' );
	my @report_errors = ();
	
	push ( @report_parameters_list, 
		{
			start_date    => $start,
			end_date      => $end,
			date_group    => $date_group,
			branch        => $branch,
			location      => $location,
			desk          => $desk,
			space_type    => $spacetype,
			category      => $category,
			Bsort2        => $bsort2,
			Bsort1        => $bsort1,
			Bsort3        => $bsort3,
			document_type => $ccode,
			itype         => $itemtype,
			lang          => $language,
			unim_ecrit    => $writing,
			pays          => $country,
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

my $branch_loop = GetBranchesLoop( $branch );
my $location_loop = GetAuthorisedValues( 'LOC', $location );
my $desk_loop = GetDesksLoop( $desk );
my $spacetype_loop = GetSpaceTypesLoop( $spacetype );
my $category_loop = GetBorrowercategoryList();
my $bsort2_loop = GetAuthorisedValues( 'Bsort2', $bsort2 );
my $bsort1_loop = GetAuthorisedValues( 'Bsort1', $bsort1 );
my $bsort3_loop = GetAuthorisedValues( 'Bsort3', $bsort3 );
my $ccode_loop = GetAuthorisedValues( 'CCODE', $ccode );
my @itemtype_loop = C4::ItemType->all;
my $language_loop = GetAuthorisedValues( 'LANG', $language );
my $writing_loop = GetAuthorisedValues( 'UNIM_ECRIT', $writing );
my $country_loop = GetAuthorisedValues( 'country', $country );

my @exporttype_loop = GetExportTypes( $exporttype );

foreach my $elem ( @$category_loop ) {
	if ( $elem->{'categorycode'} eq $category ) {
		$elem->{'selected'} = 'selected';
	}
}

foreach my $elem ( @itemtype_loop ) {
	if ( $elem->{'itemtype'} eq $itemtype ) {
		$elem->{'selected'} = 'selected';
	}
}

$template->param(
    input_error               => \@error_loop,
	start_date                => $start_date,
	end_date                  => $end_date,
	'date_group_'.$date_group => 1,
	branchloop                => $branch_loop,
	locationloop              => $location_loop,
	deskloop                  => $desk_loop,
	spacetypeloop             => $spacetype_loop,
	categoryloop              => $category_loop,
	bsort2loop                => $bsort2_loop,
	bsort1loop                => $bsort1_loop,
	bsort3loop                => $bsort3_loop,
	ccodeloop                 => $ccode_loop,
	itemtypeloop              => \@itemtype_loop,
	languageloop              => $language_loop,
	writingloop               => $writing_loop,
	countryloop               => $country_loop,
	$reportname               => 1,
	exporttypeloop            => \@exporttype_loop,
	DHTMLcalendar_dateformat  => C4::Dates->DHTMLcalendar(),
	branch_all_selected       => $branch eq '*' ? 1 : 0,
	location_all_selected     => $location eq '*' ? 1 : 0,
	desk_all_selected         => $desk eq '*' ? 1 : 0,
	spacetype_all_selected    => $spacetype eq '*' ? 1 : 0,
	category_all_selected     => $category eq '*' ? 1 : 0,
	bsort2_all_selected       => $bsort2 eq '*' ? 1 : 0,
	bsort1_all_selected       => $bsort1 eq '*' ? 1 : 0,
	bsort3_all_selected       => $bsort3 eq '*' ? 1 : 0,
	ccode_all_selected        => $ccode eq '*' ? 1 : 0,
	itemtype_all_selected     => $itemtype eq '*' ? 1 : 0,
	language_all_selected     => $language eq '*' ? 1 : 0,
	writing_all_selected      => $writing eq '*' ? 1 : 0,
	country_all_selected      => $country eq '*' ? 1 : 0,
);

output_html_with_http_headers $input, $cookie, $template->output;