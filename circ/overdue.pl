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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;
use C4::Context;
use C4::Output;
use CGI qw(-oldstyle_urls);
use C4::Auth;
use C4::Branch;
use C4::Debug;
use C4::Dates qw/format_date/;
use Date::Calc qw/Today/;
use Text::CSV_XS;
use C4::Overdues;
use C4::Members;
use C4::Jasper::JasperReport;

my $input = new CGI;
my $order           = $input->param( 'order' ) || '';
my $order_direction = $input->param( 'order_direction' ) eq 'DESC' ? 'DESC': 'ASC';
my $showall         = $input->param( 'showall' );
my $overduetype     = $input->param( 'overduetype' ) || 'issues';
my $overdue_level   = $input->param( 'level' ) || '';
my $borcatfilter    = $input->param( 'borcat' ) || '';
my $branchfilter    = $input->param( 'branch' ) || '';
my $op              = $input->param( 'op' ) || '';
my $isfiltered      = $op =~ /apply/i && $op =~ /filter/i;
my $noreport        = C4::Context->preference( 'FilterBeforeOverdueReport' ) && ! $isfiltered && $op ne "csv" && $op ne 'send_email' && $op ne 'print_noemail';

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "circ/overdue.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { reports => 1, circulate => "circulate_remaining_permissions" },
        debug           => 1,
    }
);

my $dbh = C4::Context->dbh;

my $req;
$req = $dbh->prepare( "select categorycode, description from categories order by description");
$req->execute;
my @borcatloop;
while (my ($catcode, $description) =$req->fetchrow) {
    push @borcatloop, {
        value    => $catcode,
        selected => $catcode eq $borcatfilter ? 1 : 0,
        catname  => $description,
    };
}

my $onlymine=C4::Context->preference('IndependantBranches') && 
             C4::Context->userenv &&
             C4::Context->userenv->{flags} % 2 !=1 &&
             C4::Context->userenv->{branch};

$branchfilter = C4::Context->userenv->{'branch'} if ($onlymine && !$branchfilter);

my @sort_roots = qw(borrower title barcode date_due);
#push @sort_roots, map {$_ . " desc"} @sort_roots;
my @order_loop = ({selected => $order ? 0 : 1});   # initial blank row
foreach (@sort_roots) {
    my $tmpl_name = $_;
    $tmpl_name =~ s/\s/_/g;
    push @order_loop, {
        selected => $order eq $_ ? 1 : 0,
        ordervalue => $_,
        'order_' . $tmpl_name => 1,
    };
}

$template->param(ORDER_LOOP => \@order_loop);

$template->param(
	'overduetype_'.$overduetype => 1,
	'level_'.$overdue_level => 1,
	branchfilter => $branchfilter,
    branchloop   => GetBranchesLoop($branchfilter, $onlymine),
    borcatloop=> \@borcatloop,
    'orderdirection_'.$order_direction => 1,
    showall => $showall);

if ( $noreport || ( $overduetype ne 'issues' && $overduetype ne 'stackrequests' ) ) {
    # la de dah ... page comes up presto-quicko
    $template->param( noreport  => $noreport );
} else {
	my $notify_level = 0;
	if ( $overdue_level eq 'first' ) {
		$notify_level = 1;
	} elsif ( $overdue_level eq 'second' ) {
		$notify_level = 2;
	} elsif ( $overdue_level eq 'third' ) {
		$notify_level = 3;
	}
	
	my @overduedata = _get_overdues( $notify_level, $order, $order_direction );

    if ($op eq 'csv') {
        binmode(STDOUT, ":utf8");
        my $csv = build_csv(\@overduedata);
        print $input->header(-type => 'application/vnd.sun.xml.calc',
                             -encoding    => 'utf-8',
                             -attachment=>"overdues.csv",
                             -filename=>"overdues.csv" );
        print $csv;
        exit;
    } elsif ( $op eq 'send_email' ) {
    	my %borrower_overdues = ();
    	my $report_directory = 'exports';
    	my $report_name = ($overduetype eq 'issues') ? 'relance_prets' : 'relance_communications';
    	my @report_errors = ();
    	
    	#Retrieve each borrower with email
    	foreach my $overdue ( @overduedata ) {
    		if ( !$overdue->{ 'notify_method' } && $overdue->{ 'email' } ) {
	        	if ( !defined $borrower_overdues{ $overdue->{ 'borrowernumber' } } ) {
	        		$borrower_overdues{ $overdue->{ 'borrowernumber' } } = [];
	        	}
	        	push @{ $borrower_overdues{ $overdue->{ 'borrowernumber' } } }, $overdue->{ 'itemnum' };
    		}
    	}
    	
    	foreach my $borrowernumber ( keys %borrower_overdues ) {
        	my $report_result = SendEmail( $report_directory, $report_name, { borrower_number => $borrowernumber, notify_level => $notify_level }, _get_notify_letter( $borrowernumber, $overduetype, $notify_level ), $borrowernumber, '', GetFirstValidEmailAddress( $borrowernumber ) );
        	
        	if ( $report_result == 1) {
        		foreach my $itemnumber ( @{ $borrower_overdues{ $borrowernumber } } ) {
		    		#AddNotify
	        		AddNotifyLine ( $borrowernumber, $itemnumber, $notify_level, $overduetype, 'mail', 1 );
        		}
    		} else {
    			my $member = GetMember( borrowernumber => $borrowernumber );
    			push @report_errors, { report_name => $report_name, borrower => $member->{'firstname'} . ' ' . $member->{'surname'} }; 
    		}
    	}
	    
	    if ( scalar @report_errors ) {
	    	$template->param(
			    report_errors => \@report_errors,
			);
	    }
	    
	    #Refresh Data
		@overduedata = _get_overdues( $notify_level, $order, $order_direction );
    } elsif ( $op eq 'print_noemail' ) {
    	my %borrower_overdues = ();
    	my ( $report_directory, $report_name, $report_action ) = ( 'exports', $overduetype eq 'issues' ? 'relance_prets' : 'relance_communications', 'visualization' );
    	my @report_parameters_list = ();
    	my @report_errors = ();
    	
    	#Retrieve each borrower without email
    	foreach my $overdue ( @overduedata ) {
    		if ( !$overdue->{ 'notify_method' } && !$overdue->{ 'email' } ) {
	        	if ( !defined $borrower_overdues{ $overdue->{ 'borrowernumber' } } ) {
	        		$borrower_overdues{ $overdue->{ 'borrowernumber' } } = [];
	        	}
	        	push @{ $borrower_overdues{ $overdue->{ 'borrowernumber' } } }, $overdue->{ 'itemnum' };
    		}
    	}
    	
    	foreach my $borrowernumber ( keys %borrower_overdues ) {
        	push( @report_parameters_list, { borrower_number => $borrowernumber, notify_level => $notify_level } );
        	
        	C4::Letters::EnqueueLetter( {
            letter => _get_notify_letter( $borrowernumber, $overduetype, $notify_level ),
            borrowernumber => $borrowernumber,
            message_transport_type => 'print',
            } );
        
	    }
	    
    	my ( $report_zipdirectory, $report_zipfile, @report_results ) = GenerateZip( $report_directory, $report_name, $report_action, \@report_parameters_list );
    	    	
	    
		for ( my $i = 0; $i < scalar( @report_parameters_list ); $i++ ) {
			if ( $report_results[$i] == 1) {
				foreach my $itemnumber ( @{ $borrower_overdues{ $report_parameters_list[$i]->{ 'borrower_number' } } } ) {
					#AddNotify
					AddNotifyLine ( $report_parameters_list[$i]->{ 'borrower_number' }, $itemnumber, $notify_level, $overduetype, 'letter', 1 );
				}
			} else {
				my $member = GetMember( borrowernumber => $report_parameters_list[$i] );
				push @report_errors, { report_name => $report_name, borrower => $member->{'firstname'} . ' ' . $member->{'surname'} }; 
			}
		}
	    
	    #Refresh Data
	    @overduedata = _get_overdues( $notify_level, $order, $order_direction );
		
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

    # generate parameter list for CSV download link
    my $new_cgi = CGI->new($input);
    $new_cgi->delete('op');
    my $csv_param_string = $new_cgi->query_string();

    $template->param(
        csv_param_string        => $csv_param_string,
        todaysdate              => format_date(sprintf("%-04.4d-%-02.2d-%02.2d", Today())),
        overdueloop             => \@overduedata,
        nnoverdue               => scalar(@overduedata),
        noverdue_is_plural      => scalar(@overduedata) != 1,
        noreport                => $noreport,
        isfiltered              => $isfiltered,
    );

}

output_html_with_http_headers $input, $cookie, $template->output;


sub build_csv {
    my $overdues = shift;

    return "" if scalar(@$overdues) == 0;

    my @lines = ();

    # build header ...
    my @keys = sort keys %{ $overdues->[0] };
    my $csv = Text::CSV_XS->new();
    $csv->combine(@keys);
    push @lines, $csv->string();

    # ... and rest of report
    foreach my $overdue ( @{ $overdues } ) {
        push @lines, $csv->string() if $csv->combine(map { $overdue->{$_} } @keys);
    }

    return join("\n", @lines) . "\n";
}

sub _get_overdues {
	my ( $notify_level, $order, $order_direction ) = @_;
	
	my @where_clause = ();
	my $end_date_name = '';
	if ( $overduetype eq 'issues' ) {
		$end_date_name = 'date_due';
	} else {
		$end_date_name = 'end_date';
	}
	
	unless ( $showall ) {
		if ( $notify_level == 1 ) {
			push @where_clause, "delay1 > 0";
			push @where_clause, "DATEDIFF(CURRENT_DATE(), $end_date_name) >= delay1";
			push @where_clause, "(delay2 = 0 OR DATEDIFF(CURRENT_DATE(), $end_date_name) < delay2)";
		} elsif ( $notify_level == 2 ) {
			push @where_clause, "delay2 > 0";
			push @where_clause, "DATEDIFF(CURRENT_DATE(), $end_date_name) >= delay2";
			push @where_clause, "(delay3 = 0 OR DATEDIFF(CURRENT_DATE(), $end_date_name) < delay3)";
		} elsif ( $notify_level == 3 ) {
			push @where_clause, "delay3 > 0";
			push @where_clause, "DATEDIFF(CURRENT_DATE(), $end_date_name) >= delay3";
		}
	}
	
	push @where_clause, "overduerules.branchcode = IF((SELECT COUNT(*) FROM overduerules WHERE overduetype = '".$overduetype."' AND branchcode = borrowers.branchcode AND categorycode = borrowers.categorycode), borrowers.branchcode, '')";
	push @where_clause, "borrowers.categorycode = '".$borcatfilter."'" if ( $borcatfilter );
	push @where_clause, "borrowers.branchcode = '".$branchfilter."'" if ( $branchfilter );
	
	my $order_clause = ' ORDER BY ';
	if ( $order eq 'borrower' ) {
		$order_clause .= "borrower $order_direction, $end_date_name";
	} elsif ( $order eq 'title' ) {
		$order_clause .= "title $order_direction, $end_date_name, borrower";
	} elsif ( $order eq 'barcode' ) {
		$order_clause .= "items.barcode $order_direction, $end_date_name, borrower";
	} elsif ( $order eq 'date_due' ) {
		$order_clause .= "$end_date_name $order_direction, borrower";
	} else {
		$order_clause .= "$end_date_name, borrower";
	}
	
	my $strsth = 'SELECT
			concat(borrowers.surname,\' \', borrowers.firstname) as borrower, 
	        borrowers.phone,
	        borrowers.email,
	        borrowers.emailpro,
	        borrowers.B_email,
	        items.barcode,
	        biblio.title,
	        biblio.author,
	        borrowers.borrowernumber,
	        biblio.biblionumber,
	        borrowers.branchcode,
	        items.itemcallnumber,
	        items.replacementprice,
	        notifys.notify_send_date,
	        notifys.method,
	      ';
	        
	if ( $overduetype eq 'issues' ) {
	    $strsth .= ' 
	    	date_due,
	    	issues.itemnumber
	      FROM issues
	      INNER JOIN borrowers    ON ( issues.borrowernumber = borrowers.borrowernumber )
	      LEFT OUTER JOIN items        ON ( issues.itemnumber = items.itemnumber )
	      LEFT OUTER JOIN biblioitems  ON ( biblioitems.biblioitemnumber = items.biblioitemnumber )
	      LEFT OUTER JOIN biblio       ON ( biblio.biblionumber = items.biblionumber )
	      LEFT OUTER JOIN overduerules ON ( borrowers.categorycode = overduerules.categorycode AND overduerules.overduetype = ? )
	      LEFT OUTER JOIN notifys ON ( issues.borrowernumber = notifys.borrowernumber AND issues.itemnumber = notifys.itemnumber AND notifys.overduetype = overduerules.overduetype AND notify_level = ? )
	    ';
	} elsif ( $overduetype eq 'stackrequests' ) {
		$strsth .= ' 
	    	end_date,
	        stack_requests.itemnumber
	      FROM stack_requests
	      INNER JOIN borrowers    ON ( stack_requests.borrowernumber = borrowers.borrowernumber )
	      LEFT OUTER JOIN items        ON ( stack_requests.itemnumber = items.itemnumber )
	      LEFT OUTER JOIN biblioitems  ON ( biblioitems.biblioitemnumber = items.biblioitemnumber )
	      LEFT OUTER JOIN biblio       ON ( biblio.biblionumber = items.biblionumber )
	      LEFT OUTER JOIN overduerules ON ( borrowers.categorycode = overduerules.categorycode AND overduerules.overduetype = ? )
	      LEFT OUTER JOIN notifys ON ( stack_requests.borrowernumber = notifys.borrowernumber AND stack_requests.itemnumber = notifys.itemnumber AND notifys.overduetype = overduerules.overduetype AND notify_level = ? )
	    ';
	    push @where_clause, "stack_requests.state = 'R'";
	    push @where_clause, "items.istate = 'ON_STACK'";
	}
	
	$strsth .= " WHERE " . join(' AND ', @where_clause ) if @where_clause;
    $strsth .= $order_clause;
    
    $template->param( sql => $strsth );
    my $sth = $dbh->prepare( $strsth );
    
    $sth->execute( $overduetype, $notify_level );

	my @overduedata = ();
    while (my $data = $sth->fetchrow_hashref) {
        
        my $which_email = C4::Context->preference('AutoEmailPrimaryAddress');
        
        push @overduedata, {
            duedate                => $data->{date_due} ? format_date($data->{date_due}) : format_date($data->{end_date}),
            borrowernumber         => $data->{borrowernumber},
            barcode                => $data->{barcode},
            itemnum                => $data->{itemnumber},
            name                   => $data->{borrower},
            phone                  => $data->{phone},
            email                  => ( ( $which_email eq 'OFF' ) ? GetFirstValidEmailAddress( $data->{borrowernumber} ) : $data->{ $which_email } ),
            biblionumber           => $data->{biblionumber},
            title                  => $data->{title},
            author                 => $data->{author},
            branchcode             => $data->{branchcode},
            itemcallnumber         => $data->{itemcallnumber},
            replacementprice       => $data->{replacementprice},
            notify_method          => $data->{method},
            "notify_method_" . $data->{method} => 1,
            notify_date            => $data->{notify_send_date},
        };
    }
    
    
    
    return @overduedata;
}

sub _get_notify_letter {
	my ( $borrowernumber, $overduetype, $notify_level ) = @_;
	
	my $query ="SELECT overduerules.letter1, overduerules.letter2, overduerules.letter3, borrowers.branchcode 
				FROM borrowers
				INNER JOIN overduerules ON ( borrowers.categorycode = overduerules.categorycode ) 
				WHERE borrowers.borrowernumber = ? AND overduerules.overduetype = ?
				AND overduerules.branchcode = IF((SELECT COUNT(*) FROM overduerules WHERE overduetype = ? AND branchcode = borrowers.branchcode AND categorycode = borrowers.categorycode), borrowers.branchcode, '')";
	
	my $sth = $dbh->prepare( $query );
    $sth->execute( $borrowernumber, $overduetype, $overduetype );
    
	my $data = $sth->fetchrow_hashref;
	my $letter_code = $data->{ 'letter'.$notify_level } || '';
	
	my $letter = C4::Letters::getletter( 'circulation', $letter_code );
    die "Could not find a letter called '$letter_code' in the 'circulation' module" unless( $letter );

    C4::Letters::parseletter( $letter, 'branches', $data->{ 'branchcode' } );
    C4::Letters::parseletter( $letter, 'borrowers', $borrowernumber );

    my $today = C4::Dates->new()->output();
    $letter->{'title'} =~ s/<<today>>/$today/g;
    $letter->{'content'} =~ s/<<today>>/$today/g;
    $letter->{'content'} =~ s/<<[a-z0-9_]+\.[a-z0-9]+>>//g; #remove any stragglers
    
    return $letter;
}
