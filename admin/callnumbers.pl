#! /usr/bin/perl

#
# Progilone B10: Callnumber rules
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
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Koha;
use C4::Branch;

use C4::Callnumber::StoreCallnumber;
use C4::Utils::String qw/TrimStr/;

sub _search  {
	my ( $rulenumber, $filterBranch, $filterType, $filterActive ) = @_;
	my $dbh = C4::Context->dbh;
	my $query = 'SELECT rulenumber, branch, mention, type, format, number, auto, active FROM callnumberrules WHERE ';
	
	if ( $rulenumber ) {
		$query = "$query rulenumber = $rulenumber AND";
	}
	
	if ( $filterBranch ) {
        $query = "$query branch = '$filterBranch' AND";
    }
    
    if ( $filterType ) {
        $query = "$query type = '$filterType' AND";
    }
    
    if ( $filterActive ) {
        if ( $filterActive eq 'active' ) {
            $query = "$query active = 1 AND";
        } elsif ( $filterActive eq 'inactive' ) {
            $query = "$query active = 0 AND";
        }
    }
	
	$query = "$query geo_index = '' AND complement = '' ORDER BY rulenumber";
	my $sth = $dbh->prepare( $query );
	$sth->execute();
	warn $query;
	
	return $sth->fetchall_arrayref( {} );
}

my $input = new CGI;
my $script_name   = "/cgi-bin/koha/admin/callnumbers.pl";
my $rulenumber    = $input->param( 'rulenumber' ) || 0;
my $offset        = $input->param( 'offset' ) || 0;
my $op            = $input->param( 'op' ) || 'list';
my $pagesize      = 20;

#Filter parameter
my $filterBranch = $input->param( 'filterBranch' ) || '';
my $filterType   = $input->param( 'filterType' ) || '';
my $filterActive = $input->param( 'filterActive' ) || '';

my $branch  = $input->param( 'branch' ) || '';
my $mention = $input->param( 'mention' );
my $type    = $input->param( 'type' ) || '';
my $format  = $input->param( 'format' ) || '';
my $number  = int($input->param( 'number' )) || 1;
($branch, $mention, $type, $format, $number) = FormatStoreCallnumberFields($branch, $mention, $type, $format, $number);

my $last_op        = $input->param( 'current_op' ) || 'list';
my $current_number = int( $input->param( 'current_number' ) ) || 1;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
	{
		template_name => "admin/callnumbers.tmpl",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => {advanced_callnumber_management => '*'},
		debug => 1,
	}
);

$template->param( script_name  => $script_name );
$template->param( $op => 1 );

my $dbh = C4::Context->dbh;

if ( $op eq 'save' ) {
	my $branchdetail = GetBranchDetail( TrimStr( $branch ) );
	if ( $branchdetail && !$branchdetail->{'branchcallnumberauto'} ) {
		$op = $last_op;
		$template->param( 'error' => 1 );
		$template->param( 'error_message' => "The selected branch does not have automatic generation of callnumbers." );
	} elsif ( $current_number > $number ) {
		$op = $last_op;
		$template->param( 'rulenumber'=> $rulenumber );
		$template->param( 'current_op' => $last_op );
		$template->param( 'error' => 1 );
		$template->param( 'error_message' => "The next sequence number must be greater or equal to $current_number" );
	} else {
		$op = 'list';
		my $dbh = C4::Context->dbh;
		if ( $last_op eq 'edit_form' ) {
			#Update rule
			my $query = 'UPDATE callnumberrules SET number = ? WHERE rulenumber = ?';
			my $sth = $dbh->prepare( $query );
			$sth->execute( $number, $rulenumber );
		} elsif ( $last_op eq 'add_form' ) {
			#Check if the rule does not already exists
			my $query = 'SELECT COUNT(*) FROM callnumberrules WHERE branch = ? AND mention = ? AND type = ? AND format = ?';
			my $sth = $dbh->prepare( $query );
			$sth->execute( $branch, $mention, $type, $format);
			
			my $canChooseNumber = int( $sth->fetchrow );
			if ( $canChooseNumber ) {
				$op = $last_op;
				$template->param( 'rulenumber'=> $rulenumber );
				$template->param( 'current_op' => $last_op );
				$template->param( 'error' => 1 );
				$template->param( 'error_message' => 'This callnumber rule already exists.' );
			} else {
				#Insert new rule
				my $query = 'INSERT INTO callnumberrules (mention, branch, type, format, number, auto, active) VALUES (?, ?, ?, ?, ?, 1, 1)';
				my $sth = $dbh->prepare( $query );
				$sth->execute( $mention, $branch, $type, $format, $number );
			}
		}
	}
	$template->param( $op => 1 );
}

if ( $op eq 'add_form' || $op eq 'edit_form' ) {
	$template->param( 'rulenumber'=> $rulenumber );
	$template->param( 'current_op' => $op );
	
	my @branch_data;
	if ( $op eq 'edit_form' && $last_op eq 'list' ) {
		my $results     = _search( $rulenumber, '', '', '' );
		$branch         = $results->[0]{'branch'};
		$mention        = $results->[0]{'mention'};
		$type           = $results->[0]{'type'};
		$format         = $results->[0]{'format'};
		$number         = $results->[0]{'number'};
		$current_number = $results->[0]{'number'};
	} elsif ( $op eq 'add_form' ) {
		@branch_data = GetBranchValues( $branch, 1 );
	}
	
	my @type_auth_values_hash   = GetTypeAuthValues( $type, 1 );
	my @format_auth_values_hash = GetFormatAuthValues( $format, 1 );
	
	$template->param(
		'branch'                  => $branch,
		'branch_data'             => \@branch_data,
		'mention'                 => TrimStr( $mention ),
		'type_auth_values_hash'   => \@type_auth_values_hash,
		'format_auth_values_hash' => \@format_auth_values_hash,
		'type'                    => TrimStr( $type ),
		'format'                  => TrimStr( $format ),
		'number'                  => TrimStr( $number ),
		'current_number'          => $current_number,
        "filterBranch"            => $filterBranch,
        "filterType"              => $filterType,
        "filterActive"            => $filterActive,
	);
}

if ( $op eq 'auto_form' ) {
	my $auto = int( $input->param( 'auto' ) );
	my $dbh = C4::Context->dbh;
	
	my $query = 'UPDATE callnumberrules SET auto = ? WHERE rulenumber = ?';
	my $sth = $dbh->prepare( $query );
	$sth->execute( $auto, $rulenumber );
	
	$op = 'list';
	$template->param( $op => 1 );
}

if ( $op eq 'active_form' ) {
	my $active = int( $input->param( 'active' ) );
	my $dbh = C4::Context->dbh;
	
	my $query = 'UPDATE callnumberrules SET active = ? WHERE rulenumber = ?';
	my $sth = $dbh->prepare( $query );
	$sth->execute( $active, $rulenumber );
	
	$op = 'list';
	$template->param( $op => 1 );
}

if ( $op eq 'list' || $op eq 'filter' ) {
	my $results = _search( '', , $filterBranch, $filterType, $filterActive );
	my $count = scalar( @$results );
	
	my @loop_data;
	for ( my $i=$offset; $i < ($offset+$pagesize<$count?$offset+$pagesize:$count); $i++ ){
		push @loop_data, {
			'rulenumber' => $results->[$i]{'rulenumber'},
			'branch'     => $results->[$i]{'branch'},
			'mention'    => $results->[$i]{'mention'},
			'type'       => $results->[$i]{'type'},
			'format'     => $results->[$i]{'format'},
			'number'     => $results->[$i]{'number'},
			'auto'       => $results->[$i]{'auto'},
			'active'     => $results->[$i]{'active'},
		};
	}
	
	$template->param( loop => \@loop_data );
	if ( $offset > 0 ) {
		my $prevpage = $offset-$pagesize;
		$template->param( previous => "$script_name?offset=".$prevpage );
	}
	if ( $offset + $pagesize < $count ) {
		my $nextpage = $offset + $pagesize;
		$template->param( next => "$script_name?offset=".$nextpage );
	}
	
	#Retrieve filter values
	my @branch_data           = GetBranchValues( $filterBranch, 0 );
    my @type_auth_values_hash = GetTypeAuthValues( $filterType, 0 );
    
    if ( $filterActive ) {
    	$template->param(
    	   $filterActive => 1,
    	)
    } else {
    	$template->param(
           "noFilterActive" => 1,
        )
    }
    
    $template->param(
        "branch_values_hash"    => \@branch_data,
        "type_auth_values_hash" => \@type_auth_values_hash,
        "filterBranch"          => $filterBranch,
        "filterType"            => $filterType,
        "filterActive"          => $filterActive,
    );
    
    $template->param( 'list' => 1 );
}

output_html_with_http_headers $input, $cookie, $template->output;
