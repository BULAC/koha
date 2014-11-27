#!/usr/bin/perl

#
# B03
#

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
use Date::Calc qw(Today Add_Delta_YM Add_Delta_Days);

use C4::Auth qw(:DEFAULT get_session);
use C4::Context;
use C4::Dates qw(format_date format_date_in_iso);
use C4::Items;
use C4::Output;
use C4::Koha;

use C4::Stack::Desk;
use C4::Stack::Manager;
use C4::Stack::Search;
use C4::Utils::Constants;
#use C4::Jasper::JasperReport;
#use C4::Spaces::Connector;

my $input = new CGI;

my $startdate = $input->param('from');
my $enddate   = $input->param('to');
my $canceled  = $input->param('canceled');
my $state     = $input->param('state');
my $desk      = $input->param('desk');
my $reprint_stack = $input->param('reprint_stack');
my $opdelayed = $input->param('opdelayed');
my $opinstant = $input->param('opinstant');
my $opprint   = $input->param('opprint');

# avoid undef for string comparaisons
$startdate = '' unless defined $startdate;
$enddate   = '' unless defined $enddate;
$canceled  = '' unless defined $canceled;
$state     = '' unless defined $state;
$desk      = '' unless defined $desk;
$opdelayed = '' unless defined $opdelayed;
$opinstant = '' unless defined $opinstant;
$opprint   = '' unless defined $opprint;

if (!C4::Context->userenv){
    my $sessionID = $input->cookie("CGISESSID");
    my $session = get_session($sessionID);
    if ($session->param('branch') eq 'NO_LIBRARY_SET'){
        # no branch set we can't return
        print $input->redirect("/cgi-bin/koha/circ/selectbranchprinter.pl");
        exit;
    }
    if ($session->param('desk') eq 'NO_DESK_SET'){
        # no branch set we can't return
        print $input->redirect("/cgi-bin/koha/desk/selectdesk.pl?oldreferer=/cgi-bin/koha/stack/search-stacks.pl");
        exit;
    }
} 

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "stack/search-stacks.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
        debug           => 1,
    }
);

#
# Trim string
#
sub trim($){
    my $str = shift;
    if ($str) {
        $str =~ s/^\s+//;
        $str =~ s/\s+$//;
    }
    return $str;
}

my ( $nowyear, $nowmonth, $nowday ) = Today();
my $today_iso = sprintf("%04d-%02d-%02d", $nowyear, $nowmonth, $nowday);
    
##
# Default values
##
# Find yesterday for the default shelf pull start date
my $startdate_default = format_date(sprintf("%04d-%02d-%02d", Add_Delta_Days($nowyear, $nowmonth, $nowday, -1)));

# Find +7 days for the default shelf pull end date
my $enddate_default = format_date(sprintf("%04d-%02d-%02d", Add_Delta_Days($nowyear, $nowmonth, $nowday, 7)));

##
# Criterias
## 

# dates
unless ($startdate && $startdate =~ C4::Dates->regexp('syspref')) {
    # incorrect date input, use default
    $startdate = $startdate_default;
}
unless ($enddate && $enddate =~ C4::Dates->regexp('syspref')) {
    # incorrect date input, use default
    $enddate = $enddate_default;
}

# states
my @states_loop;
foreach ( ($STACK_STATE_ASKED, $STACK_STATE_EDITED, $STACK_STATE_RUNNING) ) {
    push (@states_loop, {
        'state' => $_,
        selected => ($state eq $_) ? 1 : undef,
    });
}


# desks
my $desks_loop = GetDesksLoop($desk);

##
# Search stacks
##
my $stack_requests = GetStacksByCriteria(format_date_in_iso($startdate),
                                         format_date_in_iso($enddate),
                                         $state,
                                         $canceled,
                                         $desk
                                         );
# MAN212
# foreach my $stack (@$stack_requests) {
#     my $borrowernumber = $stack->{'borrowernumber'};
#     if ( $stack->{'space_booking_id'} && $stack->{'delivery_desk_ui'} ) {
#         my $space_name = C4::Spaces::Connector::GetSpaceNameByBookingId($stack->{'space_booking_id'},$stack->{'begin_date'});
#         if ($space_name) {
#             $stack->{'delivery_desk_ui'} = $space_name;
#         }
#     }
# }

##
# Edit Instant Stack shown into table
##
if ($opinstant){
    
    my $count_edited = 0;
    
    my @report_parameters_list = ();
    foreach (@$stack_requests){
        
        # Edit only today not edited requests
        if ( $today_iso eq $_->{'begin_date'}
          && $STACK_STATE_ASKED eq $_->{'state'} 
        ) {
            
            # Stack set to "edited"
            EditStackRequest($_);
            
            #Progilone B10 : Retrieve physical address and location from OLIMP
            C4::Items::UpdateItemLocation( $_->{'itemnumber'} );
            push( @report_parameters_list, { request_number => $_->{'request_number'} } );
            
            $count_edited++;
        }
    }
    
    if ( $count_edited > 0) {
        # B11 Report: Generate zip file
        my ( $report_directory, $report_name, $report_action ) = ( 'exports', 'bordereau_accompagnement', 'visualization' );
        my @report_errors = ();
        my ( $report_zipdirectory, $report_zipfile, @report_results ) = GenerateZip( $report_directory, $report_name, $report_action, \@report_parameters_list );
        
        for ( my $i = 0; $i < scalar( @report_parameters_list ); $i++ ) {
            if ( $report_results[$i] == 0) {
                push @report_errors, { report_name => $report_name, stack_request => $report_parameters_list[$i]->{ 'request_number' } }; 
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
    
   $template->param(
        'print'             => 1,
        count_edited        => $count_edited,
   );
}

##
# Perform actions at end of day stack circulation :
#
# - Expire today stacks
# - Print future stacks (tomorow or next open day) of specified desk
# - Update item's state for blocking requests
##
if ($opdelayed) {
    my $count_expired = 0;
    my $count_edited = 0;
    my $count_not_edited = 0;
    
    # Expired stacks
    $count_expired = ExpireStacks();
    
    # Edit next delayed stacks
    my $edit_date = GetDeskNextOpenDay(C4::Context->userenv->{branch}); # MAN105
    
    if ($edit_date) {
        my $stack_requests_edit = GetStacksByCriteria(undef,
                                                      undef,
                                                      $STACK_STATE_ASKED,
                                                      undef,
                                                      $desk,
                                                      $edit_date);
        
        my @report_parameters_list = ();
        foreach (@$stack_requests_edit){
    
            my $count_returned = 0;
            my $count_not_returned = 0;
            
            # Clean previous stacks (should usually be none)
            ($count_returned, $count_not_returned) = AutoReturnPrevStacks($_);
            
            # If a stack can't be returned, can't edit next one
            unless ($count_not_returned) {
                
                # Stack set to "edited"
                EditStackRequest($_);
                
                #Progilone B10 : Retrieve physical address and location from OLIMP
                C4::Items::UpdateItemLocation( $_->{'itemnumber'} );
                push( @report_parameters_list, { request_number => $_->{'request_number'} } );
                
                $count_edited++;
                
            } else {
                
                $count_not_edited++;
            }
        }
        
        if ( $count_edited > 0) {
            # B11 Report: Generate zip file
            my ( $report_directory, $report_name, $report_action ) = ( 'exports', 'bordereau_accompagnement', 'visualization' );
            my @report_errors = ();
            my ( $report_zipdirectory, $report_zipfile, @report_results ) = GenerateZip( $report_directory, $report_name, $report_action, \@report_parameters_list );
            
            for ( my $i = 0; $i < scalar( @report_parameters_list ); $i++ ) {
                if ( $report_results[$i] == 0) {
                    push @report_errors, { report_name => $report_name, stack_request => $report_parameters_list[$i]->{ 'request_number' } }; 
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
       
    } else {
        $template->param(
            no_edit_date  => 1,
        );
    }
    
    # Update stacks becomming blocking
    CheckBlockingStacks();
    
    $template->param(
        'print'             => 1,
        count_expired       => $count_expired,
        count_edited        => $count_edited,
        count_not_edited    => $count_not_edited,
    );

}

# B11 Report: Reprint selected stack
if ($opprint) {
    my @report_parameters_list = ();
    my ( $report_directory, $report_name, $report_action ) = ( 'exports', 'bordereau_accompagnement', 'visualization' );
    my @report_errors = ();
    
    #Progilone B10 : Retrieve physical address and location from OLIMP
    my $request_to_print = GetStackById($reprint_stack);
    C4::Items::UpdateItemLocation( $request_to_print->{'itemnumber'} );
                
    push( @report_parameters_list, { request_number => $reprint_stack } );
    my ( $report_zipdirectory, $report_zipfile, @report_results ) = GenerateZip( $report_directory, $report_name, $report_action, \@report_parameters_list );
    
    for ( my $i = 0; $i < scalar( @report_parameters_list ); $i++ ) {
        if ( $report_results[$i] == 0) {
            push @report_errors, { report_name => $report_name, stack_request => $report_parameters_list[$i]->{ 'request_number' } }; 
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

# If operation made, get updated requests
if ($opinstant || $opdelayed) {
    $stack_requests = GetStacksByCriteria(format_date_in_iso($startdate),
                                         format_date_in_iso($enddate),
                                         $state,
                                         $canceled,
                                         $desk
                                         );
    # MAN212
    # foreach my $stack (@$stack_requests) {
    #     my $borrowernumber = $stack->{'borrowernumber'};
    #     if ( $stack->{'space_booking_id'} && $stack->{'delivery_desk_ui'} ) {
    #         my $space_name = C4::Spaces::Connector::GetSpaceNameByBookingId($stack->{'space_booking_id'},$stack->{'begin_date'});
    #         if ($space_name) {
    #             $stack->{'delivery_desk_ui'} = $space_name;
    #         }
    #     }
    # }

}

##
# Template params
##

$template->param(
    stackrq_total   => scalar @$stack_requests,
    stackrq_loop    => $stack_requests,

    states_loop     => \@states_loop,
    desks_loop      => $desks_loop,
    
    from            => $startdate,
    to              => $enddate,
    canceled        => $canceled,
    'state'         => $state,
    desk            => $desk,
    
    desk_not_res    => "^$DESK_RESERVE_CODE", # use ^CODE to filter on all desks but this one
    
    DHTMLcalendar_dateformat =>  C4::Dates->DHTMLcalendar(),
);

output_html_with_http_headers $input, $cookie, $template->output;
