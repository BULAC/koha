#! /usr/bin/perl

#
# B014
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

# pragma
use strict;
use warnings;

# external modules
use CGI;
use File::Path;

# internal modules
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Members;
use C4::Dates qw/format_date format_date_in_iso/;
use C4::Letters;

#
# Is field mandatory
#
sub _isMandatoryField($$) {
    my ($field_check, $fieldname) = @_;
    return (scalar grep {$_ eq $fieldname} @$field_check) ? 1 : undef;
}

#
# Common vars
#
my $input = new CGI;
my $dbh = C4::Context->dbh;

#
# Template and user
#
my ($template, $loggedinuser, $cookie) = get_template_and_user({
        template_name => "opac-passwd-ask.tmpl",
        query => $input,
        type => "opac",
        authnotrequired => 1,
});

#
# Input vars
#
my $op = $input->param('op') || '';

#
# Local vars
#
my $uppercasesurnames = C4::Context->preference('uppercasesurnames') || '';

# designate mandatory fields
my $BorrowerMandatoryField = C4::Context->preference("BorrowerMandatoryField") || '';
my @field_check = split(/\|/, $BorrowerMandatoryField);

my @member_fields = qw(
        surname
        firstname
        dateofbirth
);

#
# Post of form
#
if ($op) {
    
    #
    # Input vars
    #
    my %user_data;
    
    foreach (@member_fields) {
        $user_data{"$_"} = $input->param("$_") || '';
    }
    
    #
    # Local vars
    #
    my $userid;
    my $nok; # to know if an error has occured
    
    my $userdateofbirth = $user_data{'dateofbirth'};
    
    unless ($nok) {
        
        #
        # Mandatory fields
        #
        foreach (@member_fields) {
            if ( _isMandatoryField(\@field_check, $_) && !$user_data{"$_"} ) {
                $template->param( "ERROR_mandatory" => 1 );
                $nok = 1;
                last;
            }
        }
        
        #
        # Surname
        #
        if ( $user_data{'surname'} && $uppercasesurnames ) {
            $user_data{'surname'} = uc($user_data{'surname'});
        }
        
        #
        # Check date of birth
        #
        if ($userdateofbirth) {
            
            my $dateobject = C4::Dates->new();
            my $syspref = $dateobject->regexp(); # same syspref format for all dates
            my $iso     = $dateobject->regexp('iso');
            
            if ( $userdateofbirth =~ /$syspref/ ) {
                $user_data{'dateofbirth'} = format_date_in_iso($userdateofbirth);  # if they match syspref format, then convert to ISO
            } elsif ( $userdateofbirth =~ /$iso/ ) {
                warn "Date dateofbirth ($userdateofbirth) is already in ISO format";
            } else {
                ($userdateofbirth eq '0000-00-00') and warn "Data error: $_ is '0000-00-00'";
                
                $user_data{'dateofbirth'} = ''; # don't restore input date
                
                $template->param( "ERROR_dateofbirth" => 1 );   # else ERROR!
                $nok = 1;
            }
        }
        
        #
        # Send email
        #
        unless ($nok) {
        
            # Get Borrowers in database
            my @data = ();
            push @data, 'surname'=>$user_data{'surname'};
            push @data, 'firstname'=>$user_data{'firstname'};
            push @data, 'dateofbirth'=>$user_data{'dateofbirth'};
            
            my $borrower = GetMember(@data);
            my $email;
            if ($borrower) {
                $email = $borrower->{'email'} || $borrower->{'emailpro'} || $borrower->{'B_email'};
            }
            
            if (!$borrower) {
                $template->param( "ERROR_borrower" => 1 );   # ERROR!
                $nok = 1;
                
            } elsif ( $email ) {
                # find new password
                $borrower->{'password'} = int(rand(100000));
    
                # modify password in database
                ModMember(%$borrower);
                                        
                # send mail
                $borrower->{'emailaddr'} = $email;
                my $letter = getletter ('members', "ACCTDETAILS:$borrower->{'branchcode'}") ;
                # if $branch notice fails, then email a default notice instead.
                $letter = getletter ('members', "ACCTDETAILS")  if !$letter;
                SendAlerts ( 'members' , $borrower , $letter ) if $letter;
                
                # output vars
                $template->param(
                    email  => $email,
                );
                
            } else {
                $template->param( "ERROR_email" => 1 );   # else ERROR!
                $nok = 1;
            }
        }
    }
    
    #
    # Ouptut vars
    #
    if ($nok) {
                
        $template->param(
            post_err => 1,
            surname      => $user_data{'surname'},
            firstname    => $user_data{'firstname'},
            dateofbirth  => $userdateofbirth,
        );       
        
    } else {
        $template->param(
            post_ok        => 1,
        );
    }
}

#
# Ouptut vars
#
$template->param(
    uppercasesurnames      => $uppercasesurnames, 
    BorrowerMandatoryField => $BorrowerMandatoryField,
);

foreach (@field_check) {
    $template->param( "mandatory$_" => 1 );    
}

$template->param(
    DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
    C4::Context->preference('dateformat') => 1,
);
  
output_html_with_http_headers($input, $cookie, $template->output);
