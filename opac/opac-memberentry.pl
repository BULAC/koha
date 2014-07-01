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
use Authen::Captcha;

# internal modules
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Members;
use C4::Dates qw/format_date format_date_in_iso/;
use C4::Letters;
use C4::Utils::Constants;
use C4::Utils::String;

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

# Force branch and category of new user
my $branchcode   = $DEFAULT_BRANCH;
my $categorycode = $PRE_REG_CATEGORY;

my $email_pattern = '^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$';
my $phone_pattern = '^(\s?\d\s?){10}$';

#
# Template and user
#
my ($template, $loggedinuser, $cookie) = get_template_and_user({
        template_name => "opac-memberentrygen.tmpl",
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
my $minPasswordLength = C4::Context->preference('minPasswordLength') || 3;
my $AutoEmailOpacUser = C4::Context->preference("AutoEmailOpacUser") || 0;

# designate mandatory fields
my $BorrowerMandatoryField = C4::Context->preference("BorrowerMandatoryField") || '';
my @field_check = split(/\|/, $BorrowerMandatoryField);

my @member_fields = qw(
        password
        surname
        othernames
        firstname
        dateofbirth
        sex
        streetnumber
        address
        city
        zipcode
        country
        phone
        mobile
        email
);

#
# Captcha
#

# Prepare folders
my $cap_data_dir    = '/var/cache/apache2/koha';
my $cap_img_dir     = '/tmp/koha';
my $cap_www_img_dir = '/tmp'; # Apache config must declare an alias
mkdir "$cap_data_dir" unless (-d $cap_data_dir);
mkdir "$cap_img_dir"  unless (-d $cap_img_dir);

# create captcha
my $captcha = Authen::Captcha->new;
$captcha->data_folder($cap_data_dir);
$captcha->output_folder($cap_img_dir);
$captcha->expire(5 * 60); # 5 min
my $md5sum = $captcha->generate_code(4); # 4 characters

#
# Post of form
#
if ($op) {
    
    #
    # Input vars
    #
    my %user_data;
    
    my $capmd5 = $input->param('capmd5') || '';
    my $intext = $input->param('intext') || '';

    foreach (@member_fields) {
        $user_data{"$_"} = $input->param("$_") || '';
    }
    
    #
    # Local vars
    #
    my $borrowernumber;
    my $userid;
    my $nok; # to know if an error has occured
    
    my $userdateofbirth = $user_data{'dateofbirth'};
    
    #
    # Check validity of captcha
    #
	my $captchacheck = Authen::Captcha->new;
    $captchacheck->data_folder($cap_data_dir);
    my $result = $captchacheck->check_code($intext,$capmd5);
    if ($result != 1) {
        $template->param( "ERROR_captcha" => 1 );  
        $nok = 1;
    }
    # remove captcha image
    unlink($cap_img_dir.'/'.$capmd5.".png");	
    
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
        # Password
        #
        unless ( length($user_data{'password'}) >= $minPasswordLength ) {
            $template->param( "ERROR_short_password" => 1 );
            $nok = 1;
        }
        
        #
        # Surname
        #
        if ( $user_data{'surname'} && $uppercasesurnames ) {
            $user_data{'surname'} = ToUppercase( $user_data{'surname'} );
        }
        
        #
        # Email
        #
        if ( $user_data{'email'} && !($user_data{'email'} =~ /$email_pattern/) ) {
            $template->param( "ERROR_email" => 1 );
            $nok = 1;
        }
        # B014 - BUG 68
		# Check if the email is unique
		my $email = $input->param('email');
		if ( $email ) {
			my $query = "
			       		SELECT email
			       		FROM borrowers 
			       		WHERE email = ?
			   			";
			my $sth = $dbh->prepare($query);
			$sth->execute($email);
			
			my $row = $sth->fetchall_arrayref({});
			warn $row->[0];
			if ( $row->[0] ) {
			    $template->param( "ERROR_email_exist" => 1 );
            	$nok = 1;
			}
		}
		# END B014 - BUG 68
        
        #
        # Phones
        #
        if ( $user_data{'phone'} && !($user_data{'phone'} =~ /$phone_pattern/) ) {
            $template->param( "ERROR_phone" => 1 );
            $nok = 1;
        }
        if ( $user_data{'mobile'} && !($user_data{'mobile'} =~ /$phone_pattern/) ) {
            $template->param( "ERROR_mobile" => 1 );
            $nok = 1;
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
            
            unless ($nok) {
                #
                # Age
                #
                my $age = GetAge($user_data{'dateofbirth'});
                my $category_data = GetBorrowercategory($categorycode);
                my ($low,$high) = ($category_data->{'dateofbirthrequired'}, $category_data->{'upperagelimit'});
                
                if (($high && ($age > $high)) || ($low && $age < $low)) {
                    $template->param( 'ERROR_age_limitations' => "$low-$high" );
                    $nok = 1;
                }
            }
        }
        
        if ( !$nok && $user_data{'surname'} && $user_data{'firstname'} && $user_data{'dateofbirth'} ) {
            #
            # Test if the borrower already exist(=>1) or not (=>0)
            #
            my ($check_member, $check_category) = checkuniquemember(
                '', 
                $user_data{'surname'},
                $user_data{'firstname'},
                $user_data{'dateofbirth'}
            );
            if ($check_member) {
                $template->param(
                    check_member => $check_member,
                );
                $nok = 1;
            }
        }
        
        #
        # Build default login
        #
        if ( !$nok && $user_data{'email'} ) {
            
            my $userid_fromemail = lc( NormalizeStr( $user_data{'email'} ) );
            if (Check_Userid($userid_fromemail,'') ) {
                $user_data{'userid'} = $userid_fromemail;
            } else {
                $template->param( "ERROR_login_exists" => 1 );
                $nok = 1;
            }
            
        } else {
            $user_data{'userid'} = Generate_Userid(
                '',
                $user_data{'firstname'},
                $user_data{'surname'}
            );
        }
        
        #
        # Create borrower
        #
        unless ($nok) {
        
            #
            # Fill datas
            #
            my %new_data = %user_data;
            
            $new_data{'categorycode'} = $categorycode;
            $new_data{'branchcode'}   = $branchcode;
        
            # today dates
            my $today = C4::Dates->today('iso');
            $new_data{'dateenrolled'} = $today;
            $new_data{'dateexpiry'}   = $today;
            
            #
        	# Insert in database
        	#
            $borrowernumber = &AddMember(%new_data);
            
            # If 'AutoEmailOpacUser' syspref is on, email user their account details from the 'notice' that matches the user's branchcode.
            if ( $AutoEmailOpacUser == 1 ) {
                # if we manage to find a valid email address, send notice 
                if ( $new_data{'email'} ) {
                    $new_data{'emailaddr'} = $new_data{'email'};
                    my $letter = getletter('members', "ACCTDETAILS:$new_data{'branchcode'}") ;
                    #  if $branch notice fails, then email a default notice instead.
                    $letter = getletter('members', "ACCTDETAILS")  if !$letter;
                    SendAlerts( 'members' , \%new_data , $letter ) if $letter;
                }
            }
            
            $userid = $new_data{'userid'};
                 
        }
    }
    
    #
    # Ouptut vars
    #
    if ($nok) {
                
        $template->param(
            post_err => 1,
            
            # don't send password
            surname      => $user_data{'surname'},
            othernames   => $user_data{'othernames'},
            firstname    => $user_data{'firstname'},
            dateofbirth  => $userdateofbirth,
            streetnumber => $user_data{'streetnumber'},
            address      => $user_data{'address'},
            city         => $user_data{'city'},
            zipcode      => $user_data{'zipcode'},
            country      => $user_data{'country'},
            phone        => $user_data{'phone'},
            mobile       => $user_data{'mobile'},
            email        => $user_data{'email'},
        );       
        if ($user_data{'sex'} eq 'F') {
            $template->param( female => 1 );
        }
        if ($user_data{'sex'} eq 'M') {            
            $template->param( male => 1 );
        }
        
    } else {
        $template->param(
            post_ok        => 1,
            
            userid         => $userid,
            borrowernumber => $borrowernumber,
        );
    }
    
}

#
# Ouptut vars
#
$template->param(
    uppercasesurnames      => $uppercasesurnames, 
    minPasswordLength      => $minPasswordLength,
    BorrowerMandatoryField => $BorrowerMandatoryField,
);

foreach (@field_check) {
    $template->param( "mandatory$_" => 1 );    
}

$template->param(
    DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
    C4::Context->preference('dateformat') => 1,
  
    md5sum      => $md5sum,
    cap_img_src => $cap_www_img_dir.'/'.$md5sum.'.png', # path to captcha image
    
    email_pattern => $email_pattern,
    phone_pattern => $phone_pattern,
);
  
output_html_with_http_headers($input, $cookie, $template->output);
