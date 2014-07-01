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
#

use strict;
use warnings;

use CGI;
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Context;
use C4::Biblio;
use C4::Accounts;
use C4::Circulation;
use C4::Members;
use C4::Items;
use C4::Stats;
use C4::UploadedFile;
use C4::BackgroundJob;
use C4::Stack::Search;
use C4::Stack::Manager;
use C4::Stack::Rules;
use C4::Utils::Constants;
use C4::Callnumber::Utils;

use Date::Calc qw(
    Today
    Add_Delta_Days
    Date_to_Days
);

use constant DEBUG => 0;

# this is the file version number that we're coded against.
my $FILE_VERSION = '1.0';

our $query = CGI->new;

my ($template, $loggedinuser, $cookie)
  = get_template_and_user( { template_name => "offline_circ/process_koc_spec.tmpl",
				query => $query,
				type => "intranet",
				authnotrequired => 0,
				flagsrequired   => { circulate => "circulate_remaining_permissions" },
				});


my $fileID=$query->param('uploadedfileid');
my $runinbackground = $query->param('runinbackground');
my $completedJobID = $query->param('completedJobID');
my %cookies = parse CGI::Cookie($cookie);
my $sessionID = $cookies{'CGISESSID'}->value;
my @messagesCsv = $query->param('messagesCsv');
## 'Local' globals.
our $dbh = C4::Context->dbh();
our @output = (); ## For storing messages to be displayed to the user

if ($completedJobID) {
    my $job = C4::BackgroundJob->fetch($sessionID, $completedJobID);
    my $results = $job->results();
    my $result = $results->{results};
    $template->param(transactions_loaded => 1);
    $template->param(messages => $result);
    
    # Number of successed operations
    my $numberIssue;
    my $numberRenew;
    my $numberReturn;
    my $numberComm;
    my $numberProlong;
    foreach my $data(@$result) {
    	$numberIssue = $numberIssue + $data->{numberIssue};
    	$numberRenew = $numberRenew + $data->{numberRenew};
    	$numberReturn = $numberReturn + $data->{numberReturn};
    	$numberComm = $numberComm + $data->{numberComm};
    	$numberProlong = $numberProlong + $data->{numberProlong};
    }
    $template->param(numberIssue => $numberIssue,
                     numberRenew => $numberRenew,
                     numberReturn => $numberReturn,
                     numberComm => $numberComm,
                     numberProlong => $numberProlong);
    
} elsif (@messagesCsv) {
	my @csvInfos;
	foreach my $temp(@messagesCsv){
		my @csvInfo = split(/;/, $temp);
        push @csvInfos,\@csvInfo;
    }
	
    # export csv
    _export_csv($query,@csvInfos);
	
} elsif ($fileID) {
    my $uploaded_file = C4::UploadedFile->fetch($sessionID, $fileID);
    my $fh = $uploaded_file->fh();
    my @input_lines = <$fh>;
  
    my $filename = $uploaded_file->name(); 
    my $job = undef;

    if ($runinbackground) {
        my $job_size = scalar(@input_lines);
        $job = C4::BackgroundJob->new($sessionID, $filename, $ENV{'SCRIPT_NAME'}, $job_size);
        my $jobID = $job->id();

        # fork off
        if (my $pid = fork) {
            # parent
            # return job ID as JSON

            # prevent parent exiting from
            # destroying the kid's database handle
            # FIXME: according to DBI doc, this may not work for Oracle
            $dbh->{InactiveDestroy}  = 1;

            my $reply = CGI->new("");
            print $reply->header(-type => 'text/html');
            print "{ jobID: '$jobID' }";
            exit 0;
        } elsif (defined $pid) {
            # child
            # close STDOUT to signal to Apache that
            # we're now running in the background
            close STDOUT;
            close STDERR;
        } else {
            # fork failed, so exit immediately
            # fork failed, so exit immediately
            warn "fork failed while attempting to run $ENV{'SCRIPT_NAME'} as a background job";
            exit 0;
        }

        # if we get here, we're a child that has detached
        # itself from Apache

    }     


    my $header_line = shift @input_lines;
    my $file_info   = parse_header_line($header_line);
    if ($file_info->{'Version'} ne $FILE_VERSION) {
        push( @output, {errorfile => 1,
					    ERROR_file_version => 1,
					    upload_version => $file_info->{'Version'},
					    current_version => $FILE_VERSION } );
    }
    
    warn "pré-bouvle foreeach";
    my $i = 0;
    foreach  my $line (@input_lines)  {
    
        $i++;
        my $command_line = parse_command_line($line);
        
        # map command names in the file to subroutine names
        my %dispatch_table = (
            issue     => \&kocIssueItem,
            'return'  => \&kocReturnItem,
            comm      => \&kocCommItem,
            prolong   => \&kocCommItem,
            payment   => \&kocMakePayment,
        );

        # call the right sub name, passing the hashref of command_line to it.
        if ( exists $dispatch_table{ $command_line->{'command'} } ) {
            $dispatch_table{ $command_line->{'command'} }->($command_line);
        } else {
            #warn "unknown command: '$command_line->{command}' not processed";
            my $line_number_with_header = $i + 1;
            push( @output, { error => 1,
            	             ERROR_parsing_line => 1,
                             error_line => $line_number_with_header,
                             error_content => $line
            } );
        }

        if ($runinbackground) {
            $job->progress($i);
        }
    }

    if ($runinbackground) {
        $job->finish({ results => \@output }) if defined($job);
    } else {
        $template->param(transactions_loaded => 1);
        $template->param(messages => \@output);
    }
}

output_html_with_http_headers $query, $cookie, $template->output;

=head3 parse_header_line

parses the header line from a .koc file. This is the line that
specifies things such as the file version, and the name and version of
the offline circulation tool that generated the file. See
L<http://wiki.koha-community.org/wiki/Koha_offline_circulation_file_format>
for more information.

pass in a string containing the header line (the first line from th
file).

returns a hashref containing the information from the header.

=cut

sub parse_header_line {
    my $header_line = shift;
    chomp($header_line);
    $header_line =~ s/\r//g;

    my @fields = split( /\t/, $header_line );
    my %header_info = map { split( /=/, $_ ) } @fields;
    return \%header_info;
}

=head3 parse_command_line

=cut

sub parse_command_line {
    my $command_line = shift;
    chomp($command_line);
    $command_line =~ s/\r//g;
    
    my ( $timestamp, $command, @args ) = split( /\t/, $command_line );
    my ( $date,      $time,    $id )   = split( /\s/, $timestamp );

    my %command = (
        date    => $date,
        time    => $time,
        id      => $id,
        command => $command,
    );

    # set the rest of the keys using a hash slice
    my $argument_names = arguments_for_command($command);
    if (defined $argument_names ) {
        @command{@$argument_names} = @args;
    }

    return \%command;

}

=head3 arguments_for_command

fetches the names of the columns (and function arguments) found in the
.koc file for a particular command name. For instance, the C<issue>
command requires a C<cardnumber> and C<barcode>. In that case this
function returns a reference to the list C<qw( cardnumber barcode )>.

parameters: the command name

returns: listref of column names.

=cut

sub arguments_for_command {
    my $command = shift;

    # define the fields for this version of the file.
    my %format = (
        issue   => [qw( cardnumber barcode )],
        comm    => [qw( cardnumber barcode )],
        prolong => [qw( cardnumber barcode )],
        return  => [qw( barcode )],
        payment => [qw( cardnumber amount )],
    );

    return $format{$command};
}

sub kocIssueItem {
  my $circ = shift;

  $circ->{ 'barcode' } = barcodedecode($circ->{'barcode'}) if( $circ->{'barcode'} && C4::Context->preference('itemBarcodeInputFilter'));
  my $borrower = GetMember( 'cardnumber'=>$circ->{ 'cardnumber' } );
  my $item = GetBiblioFromItemNumber( undef, $circ->{ 'barcode' } );
  
  # bad barcode item
  if (!$item) {
    push( @output, {ERROR_no_barcode_from_item => 1,
				    issue => 1,
				    barcode => $circ->{ 'barcode' },
				    firstname => $borrower->{ 'firstname' },
				    surname => $borrower->{ 'surname' },
				    borrowernumber => $borrower->{'borrowernumber'},
				    cardnumber => $borrower->{'cardnumber'},
				    date =>$circ->{'date'},
				    time =>$circ->{'time'} } );
  } else {
  
    my $branchcode = C4::Context->userenv->{branch};
    my $issue = GetItemIssue( $item->{'itemnumber'} );

    my $issuingrule = GetIssuingRule( $borrower->{ 'categorycode' }, $item->{ 'itemtype' }, $branchcode );
    my $issuelength = $issuingrule->{ 'issuelength' };
    my ( $year, $month, $day ) = split( /-/, $circ->{'date'} );
    ( $year, $month, $day ) = Add_Delta_Days( $year, $month, $day, $issuelength );
    my $date_due = sprintf("%04d-%02d-%02d", $year, $month, $day);

    if ( $issue->{ 'date_due' } ) { ## Item is currently checked out to another person.
      my $issue = GetOpenIssue( $item->{'itemnumber'} );
    
      if ( $issue->{'borrowernumber'} eq $borrower->{'borrowernumber'} ) { 
      	# Issued to this person already, renew it.
    
        my $date_due_object = C4::Dates->new($date_due ,'iso');
        C4::Circulation::AddRenewal(
          $issue->{'borrowernumber'},    # borrowernumber
          $item->{'itemnumber'},         # itemnumber
          undef,                         # branch
          $date_due_object,              # datedue
          $circ->{'date'},               # issuedate
        ) unless ($DEBUG);

        push( @output, { renew => 1,
    	                 numberRenew => 1,
				         title => $item->{ 'title' },
				         biblionumber => $item->{'biblionumber'},
				         barcode => $item->{ 'barcode' },
				         firstname => $borrower->{ 'firstname' },
				         surname => $borrower->{ 'surname' },
				         borrowernumber => $borrower->{'borrowernumber'},
				         cardnumber => $borrower->{'cardnumber'},
				         date =>$circ->{'date'},
				         time =>$circ->{'time'} } );

      } else {
        my ( $i_y, $i_m, $i_d ) = split( /-/, $issue->{'issuedate'} );
        my ( $c_y, $c_m, $c_d ) = split( /-/, $circ->{'date'} );
      
        if ( Date_to_Days( $i_y, $i_m, $i_d ) < Date_to_Days( $c_y, $c_m, $c_d ) ) { 
          # Current issue to a different person is older than this issue, return and issue.
          push( @output, {ERROR_item_already_issued => 1,
	                      issue => 1,
                          title => $item->{ 'title' },
                          biblionumber => $item->{'biblionumber'},
	                      barcode => $item->{ 'barcode' },
	                      firstname => $borrower->{ 'firstname' },
	                      surname => $borrower->{ 'surname' },
	                      borrowernumber => $borrower->{'borrowernumber'},
	                      cardnumber => $borrower->{'cardnumber'},
	                      date =>$circ->{'date'},
	                      time =>$circ->{'time'} } 
	          );
        #my $date_due_object = C4::Dates->new($date_due ,'iso');
        #C4::Circulation::AddIssue( $borrower, $circ->{'barcode'}, $date_due_object ) unless ( DEBUG );
        #push( @output, {issue => 1,
		#			    title => $item->{ 'title' },
        #    		    biblionumber => $item->{'biblionumber'},
		#			    barcode => $item->{ 'barcode' },
		#			    firstname => $borrower->{ 'firstname' },
		#			    surname => $borrower->{ 'surname' },
		#			    borrowernumber => $borrower->{'borrowernumber'},
		#			    cardnumber => $borrower->{'cardnumber'},
		#			    date =>$circ->{'date'},
		#			    time =>$circ->{'time'} } );

        } else {
      	  # Current issue is *newer* than this issue, write a 'returned' issue, as the item is most likely in the hands of someone else now.
          push( @output, {ERROR_item_issued => 1,
                          issue => 1,
                          title => $item->{ 'title' },
                          biblionumber => $item->{'biblionumber'},
                          barcode => $item->{ 'barcode' },
                          firstname => $borrower->{ 'firstname' },
                          surname => $borrower->{ 'surname' },
                          borrowernumber => $borrower->{'borrowernumber'},
                          cardnumber => $borrower->{'cardnumber'},
                          date =>$circ->{'date'},
                          time =>$circ->{'time'} } );
        }
    
      }
    } else { ## Item is not checked out to anyone at the moment, go ahead and issue it
        
      #Check if there was a stack request from the same user
      my $stack_to_convert = GetCurrentStackByItemnumber($item->{ 'itemnumber' });
      
      if ( IsItemInStore( $item->{ 'itemnumber' } ) && defined $stack_to_convert ) {
        
        #Place cancel code, asked request will be archived
        CancelStackRequest(undef, $stack_to_convert, $AV_SR_CANCEL_CHECKOUT);
                   
        #Reload from database
        $stack_to_convert = GetStackById($stack_to_convert->{'request_number'});
                   
        if ($stack_to_convert->{'state'} eq $STACK_STATE_EDITED) {
          # Perform retrieval on a canceled request, it will be archived
          RetrieveStackRequest($stack_to_convert, undef);
        } elsif ($stack_to_convert->{'state'} eq $STACK_STATE_RUNNING) {
          #Perform return of request, it will be archived
          AddReturnStack($stack_to_convert, undef);
        }
        
        # Add issue
        my $date_due_object = C4::Dates->new($date_due ,'iso');
        C4::Circulation::AddIssue( $borrower, $circ->{'barcode'}, $date_due_object ) unless ( DEBUG );
        push( @output, {issue => 1,
                        numberIssue => 1,
                        title => $item->{ 'title' },
                        biblionumber => $item->{'biblionumber'},
                        barcode => $item->{ 'barcode' },
                        firstname => $borrower->{ 'firstname' },
                        surname => $borrower->{ 'surname' },
                        borrowernumber => $borrower->{'borrowernumber'},
                        cardnumber => $borrower->{'cardnumber'},
                        date =>$circ->{'date'},
                        time =>$circ->{'time'} } );
        
      } elsif ( IsItemInFreeAccess( $item->{ 'itemnumber' } ) ) {
        my $date_due_object = C4::Dates->new($date_due ,'iso');
        C4::Circulation::AddIssue( $borrower, $circ->{'barcode'}, $date_due_object ) unless ( DEBUG );
        push( @output, {issue => 1,
                        numberIssue => 1,
                        title => $item->{ 'title' },
                        biblionumber => $item->{'biblionumber'},
                        barcode => $item->{ 'barcode' },
                        firstname => $borrower->{ 'firstname' },
                        surname => $borrower->{ 'surname' },
                        borrowernumber => $borrower->{'borrowernumber'},
                        cardnumber => $borrower->{'cardnumber'},
                        date =>$circ->{'date'},
                        time =>$circ->{'time'} } );
                        
      } elsif ( IsItemInStore( $item->{ 'itemnumber' } ) && not defined $stack_to_convert ) {
      	push( @output, {ERROR_item_issued_from_store => 1,
                        issue => 1,
                        barcode => $circ->{ 'barcode' },
                        firstname => $borrower->{ 'firstname' },
                        surname => $borrower->{ 'surname' },
                        borrowernumber => $borrower->{'borrowernumber'},
                        cardnumber => $borrower->{'cardnumber'},
                        date =>$circ->{'date'},
                        time =>$circ->{'time'} } );
      }
    }
  }  
}

sub kocReturnItem {
    my ( $circ ) = @_;
    $circ->{'barcode'} = barcodedecode($circ->{'barcode'}) if( $circ->{'barcode'} && C4::Context->preference('itemBarcodeInputFilter'));
    my $item = GetBiblioFromItemNumber( undef, $circ->{ 'barcode' } );
    #warn( Data::Dumper->Dump( [ $circ, $item ], [ qw( circ item ) ] ) );
    my ($borrowernumber, $is_issue) = _get_borrowernumber_from_barcode( $circ->{'barcode'} );
    if ( $borrowernumber ) {
    	my $borrower = GetMember( 'borrowernumber' => $borrowernumber );
    	    	
    	if ( $is_issue == 1 ) {
	        
	        C4::Circulation::MarkIssueReturned($borrowernumber,
	                                           $item->{'itemnumber'},
	                                           undef,
	                                           $circ->{'date'} );
	        
	        ModItem({ onloan => undef }, $item->{'biblionumber'}, $item->{'itemnumber'} );
	        
	        ModDateLastSeen( $item->{'itemnumber'} );
	        
	        CheckItemAvailability(undef, $item); 
		    
    	} else {
            
            #Return stack request
            my $stack = C4::Stack::Search::GetCurrentStackByItemnumber( $item->{'itemnumber'} );
            C4::Stack::Manager::AddReturnStack( $stack, undef );
                		
    	} 
    	
    	push( @output, {return => 1,
                        numberReturn => 1,
                        title => $item->{ 'title' },
                        biblionumber => $item->{'biblionumber'},
                        barcode => $item->{ 'barcode' },
                        borrowernumber => $borrower->{'borrowernumber'},
                        firstname => $borrower->{'firstname'},
                        surname => $borrower->{'surname'},
                        cardnumber => $borrower->{'cardnumber'},
                        date =>$circ->{'date'},
                        time =>$circ->{'time'} } );
   
    } else {# Item is not checked out.
        push( @output, {ERROR_no_borrower_from_item => 1,
        	            return => 1,
        	            title => $item->{ 'title' },
                        biblionumber => $item->{'biblionumber'},
        	            barcode => $item->{ 'barcode' },
                        date =>$circ->{'date'},
                        time =>$circ->{'time'} } );

    }
}

sub kocMakePayment {
    my ( $circ ) = @_;
    my $borrower = GetMember( 'cardnumber'=>$circ->{ 'cardnumber' } );
    recordpayment( $borrower->{'borrowernumber'}, $circ->{'amount'} );
    push( @output, {payment => 1,
				    amount => $circ->{'amount'},
				    firstname => $borrower->{'firstname'},
				    surname => $borrower->{'surname'},
				    cardnumber => $circ->{'cardnumber'},
				    borrower => $borrower->{'borrowernumber'} } );
}

sub kocCommItem {
    my ( $circ ) = @_;
    $circ->{ 'barcode' } = barcodedecode($circ->{'barcode'}) if( $circ->{'barcode'} && C4::Context->preference('itemBarcodeInputFilter'));
    my $borrower = GetMember( 'cardnumber'=>$circ->{ 'cardnumber' } );
    my $item = GetBiblioFromItemNumber( undef, $circ->{ 'barcode' } );
  
    my $commandComm;
    my $commandProlong;
    if ($circ->{ 'command' } eq 'comm') {
    	$commandComm = "Communication";
    } elsif ($circ->{ 'command' } eq 'prolong') {
        $commandProlong = "Prolongation";
    }
    	
    # bad barcode item
    if (!$item) {
        push( @output, {ERROR_no_barcode_from_item => 1,
	                    $circ->{ 'command' } => 1,
	                    barcode => $circ->{ 'barcode' },
	                    firstname => $borrower->{ 'firstname' },
	                    surname => $borrower->{ 'surname' },
	                    borrowernumber => $borrower->{'borrowernumber'},
	                    cardnumber => $borrower->{'cardnumber'},
	                    date =>$circ->{'date'},
	                    time =>$circ->{'time'} } );
    
    } else {
    	my $stack = GetCurrentStackByItemnumber($item->{ 'itemnumber' });
    	if (!$stack) {
    		# Item is not stacked.
    		push( @output, {ERROR_no_comm_from_barcode => "Unable to determine stack from barcode",
                            $circ->{ 'command' } => 1,
	                        barcode => $circ->{ 'barcode' },
	                        firstname => $borrower->{ 'firstname' },
	                        surname => $borrower->{ 'surname' },
	                        borrowernumber => $borrower->{'borrowernumber'},
	                        cardnumber => $borrower->{'cardnumber'},
	                        date =>$circ->{'date'},
	                        time =>$circ->{'time'} } );
    	} else {
            if ( $stack->{'borrowernumber'} ne $borrower->{'borrowernumber'} ) {
            	# Item is communicated to another person.
            	push( @output, {ERROR_comm_from_borrower => "Item communicated to a different person",
                                $circ->{ 'command' } => 1,
	                            barcode => $circ->{ 'barcode' },
	                            firstname => $borrower->{ 'firstname' },
	                            surname => $borrower->{ 'surname' },
	                            borrowernumber => $borrower->{'borrowernumber'},
	                            cardnumber => $borrower->{'cardnumber'},
	                            date =>$circ->{'date'},
	                            time =>$circ->{'time'} } );
            } else {
            	if ($commandComm) {	                            
		            # mise à jour de l'état de la comm
		            if ( $stack->{'state'}  eq $STACK_STATE_EDITED ) {
    		            C4::Stack::Manager::RetrieveStackRequest( $stack, undef, 1 );
		            }
		            C4::Stack::Manager::DeliverStackRequest( $stack, undef );
		            
			        push( @output, {comm => 1,
	                                numberComm => 1,
			                        title => $item->{ 'title' },
			                        biblionumber => $item->{'biblionumber'},
			                        barcode => $item->{ 'barcode' },
			                        firstname => $borrower->{ 'firstname' },
			                        surname => $borrower->{ 'surname' },
			                        borrowernumber => $borrower->{'borrowernumber'},
			                        cardnumber => $borrower->{'cardnumber'},
			                        date =>$circ->{'date'},
			                        time =>$circ->{'time'} } );
                
            	} elsif ($commandProlong) {
                    my $do_store = 1;
                    my $ignore_istate = $do_store ? 1 : undef;
        
			        my ($end_date_renewal, $renew_impossible, $renew_confirm) = CanRenewRequestStack($stack->{'request_number'}, undef, $ignore_istate);
			        if (scalar keys %$renew_impossible) {  
			        	my ( $year, $month, $day ) = Add_Delta_Days( Today(), 1 );
                        $end_date_renewal = sprintf( "%04d-%02d-%02d", $year, $month, $day );
			        }
			        # set item in desk and renew
                    RenewStackRequest($stack->{'request_number'}, undef, $end_date_renewal, 1, undef);
                    
                    push( @output, {prolong => 1,
                                    numberProlong => 1,
                                    title => $item->{ 'title' },
                                    biblionumber => $item->{'biblionumber'},
                                    barcode => $item->{ 'barcode' },
                                    firstname => $borrower->{ 'firstname' },
                                    surname => $borrower->{ 'surname' },
                                    borrowernumber => $borrower->{'borrowernumber'},
                                    cardnumber => $borrower->{'cardnumber'},
                                    date =>$circ->{'date'},
                                    time =>$circ->{'time'} } );
            	}
            }
    	}
    }
}

=head3 _get_borrowernumber_from_barcode

pass in a barcode
get back the borrowernumber of the patron who has it checked out.
undef if that can't be found

=cut

sub _get_borrowernumber_from_barcode {
    my $barcode = shift;
    my $is_issue = 0;

    return (undef, undef) unless $barcode;

    my $item = GetBiblioFromItemNumber( undef, $barcode );
    return (undef, undef) unless $item->{'itemnumber'};
    
    my $issue = C4::Circulation::GetItemIssue( $item->{'itemnumber'} );
    if ( defined $issue ) {
    	$is_issue = 1;
    	return ( $issue->{'borrowernumber'}, $is_issue );
    }
    my $stack = C4::Stack::Search::GetCurrentStackByItemnumber( $item->{'itemnumber'} );
    if ( defined $stack ) {
        return ( $stack->{'borrowernumber'}, $is_issue );
    }
    
    return (undef, undef);
}

sub _export_csv {
    my ($input,@resexport) = @_;
    
    if ($input->param('CSVexport') eq 'on'){
        eval {use Text::CSV};
        eval {use Text::CSV::Encoded};
        my $csv = Text::CSV::Encoded->new ({ encoding_in  => "utf8", encoding_out => "iso-8859-1" }) or
                die Text::CSV->error_diag ();
        print $input->header(
            -type       => 'text/csv',
            -charset    => 'utf-8',
            -attachment => 'offline_circulation.csv',
        );
        # titres
        my @titre = ( 'Date','Heure','Opération','Numéro de carte','Code à barres','Problème' );
        $csv->combine(@titre);
        my $string = $csv->string;
        print $string, "\n";
        
        # lignes
        foreach my $row ( @resexport ) {
            $csv->combine(@$row);
            $string = $csv->string;
            print $string, "\n";
        }
        exit;
    }
}
