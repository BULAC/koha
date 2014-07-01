#!/usr/bin/perl

# Copyright 2006 SAN OUEST PROVENCE et Paul POULAIN
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
#use strict;
use warnings;
use File::Temp;
use File::Copy;
# external modules
use CGI;
# use Digest::MD5 qw(md5_base64);
use GD;
# internal modules
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Members;
use C4::Members::Attributes;
use C4::Members::AttributeTypes;
use C4::Koha;
use C4::Dates qw/format_date format_date_in_iso/;
use C4::Input;
use C4::Log;
use C4::Letters;
use C4::Branch; # GetBranches
use C4::Form::MessagingPreferences;
use C4::Utils::Constants;
use C4::Utils::String;
use C4::Spaces::SCA;

use vars qw($debug);

BEGIN {
	$debug = $ENV{DEBUG} || 0;
}
	
my $input = new CGI;
($debug) or $debug = $input->param('debug') || 0;
my %data;

my $dbh = C4::Context->dbh;

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/memberentrygen.tmpl",
           query => $input,
           type => "intranet",
           authnotrequired => 0,
           flagsrequired => {borrowers => 1},
           debug => ($debug) ? 1 : 0,
       });
my $guarantorid    = $input->param('guarantorid');
my $borrowernumber = $input->param('borrowernumber');
my $actionType     = $input->param('actionType') || '';
my $modify         = $input->param('modify');
my $delete         = $input->param('delete');
my $op             = $input->param('op');
my $destination    = $input->param('destination');
my $cardnumber     = $input->param('cardnumber');
my $check_member   = $input->param('check_member');
my $nodouble       = $input->param('nodouble');
$nodouble = 1 if $op eq 'modify'; # FIXME hack to represent fact that if we're
                                  # modifying an existing patron, it ipso facto
                                  # isn't a duplicate.  Marking FIXME because this
                                  # script needs to be refactored.
my $select_city    = $input->param('select_city');
my $nok            = $input->param('nok');
my $guarantorinfo  = $input->param('guarantorinfo');

# B014
my $uploadfilename      = $input->param('uploadfile');
my $uploadfile          = $input->upload('uploadfile');
my $filetype      = $input->param('filetype');
my $step           = $input->param('step') || 0;
my ( $total, $handled, @counts );
my $default_city;
# $check_categorytype contains the value of duplicate borrowers category type to redirect in good template in step =2
my $check_categorytype=$input->param('check_categorytype');
# NOTE: Alert for ethnicity and ethnotes fields, they are invalid in all borrowers form
my $borrower_data;
my $NoUpdateLogin;
my $userenv = C4::Context->userenv;
my @errors;
# END B014

my $print_confirmation = $input->param( 'print_confirmation' );

$template->param("uppercasesurnames" => C4::Context->preference('uppercasesurnames'));

my $minpw = C4::Context->preference('minPasswordLength');
$template->param("minPasswordLength" => $minpw);

# function to designate mandatory fields (visually with css)
my $check_BorrowerMandatoryField=C4::Context->preference("BorrowerMandatoryField");
my @field_check=split(/\|/,$check_BorrowerMandatoryField);
foreach (@field_check) {
	$template->param( "mandatory$_" => 1);    
}
$template->param("add"=>1) if ($op eq 'add');
$template->param("checked" => 1) if (defined($nodouble) && $nodouble eq 1);
($borrower_data = GetMember( 'borrowernumber'=>$borrowernumber )) if ($op eq 'modify' or $op eq 'save');
my $categorycode  = $input->param('categorycode') || $borrower_data->{'categorycode'};
my $category_type = $input->param('category_type');
my $new_c_type = $category_type; #if we have input param, then we've already chosen the cat_type.
unless ($category_type or !($categorycode)){
    my $borrowercategory = GetBorrowercategory($categorycode);
    $category_type    = $borrowercategory->{'category_type'};
    my $category_name = $borrowercategory->{'description'}; 
    $template->param("categoryname"=>$category_name);
}
$category_type="A" unless $category_type; # FIXME we should display a error message instead of a 500 error !

# Progilone B014
if ( $op eq 'add' && $categorycode eq $PRE_REG_CATEGORY ) {
	$template->param( "$categorycode" => $categorycode );
    $template->param( "dateenrolled" => C4::Dates->today('iso') );
}

# if a add or modify is requested => check validity of data.
%data = %$borrower_data if ($borrower_data);

# B014
my ($picture, $dberror) = GetPatronImage($data{'cardnumber'}) if ($borrower_data && $op ne 'insert');
$template->param( picture => 1 ) if $picture;
# END B014

# initialize %newdata
my %newdata;	# comes from $input->param()
if ($op eq 'insert' || $op eq 'modify' || $op eq 'save') {
    
    my @names= ($borrower_data && $op ne 'save') ? keys %$borrower_data : $input->param();
    foreach my $key (@names) {
        if (defined $input->param($key)) {
            $newdata{$key} = $input->param($key);
            $newdata{$key} =~ s/\"/&quot;/g unless $key eq 'borrowernotes' or $key eq 'opacnote';
        }
    }
	
	# B015
    ## Manipulate debarred
    if ( $newdata{debarred} ) {
        $newdata{debarred} = $newdata{datedebarred} ? $newdata{datedebarred} : "9999-12-31";
    } elsif ( exists( $newdata{debarred} ) && !( $newdata{debarred} ) ) {
        undef( $newdata{debarred} );
    }
    
    
     if ( $newdata{debarred2} ) {
        $newdata{debarred2} = $newdata{datedebarred2} ? $newdata{datedebarred2} : "9999-12-31";
    } elsif ( exists( $newdata{debarred2} ) && !( $newdata{debarred2} ) ) {
        undef( $newdata{debarred2} );
    }
    # END B015
    
    my $dateobject = C4::Dates->new();
    my $syspref = $dateobject->regexp();		# same syspref format for all 3 dates
    my $iso     = $dateobject->regexp('iso');	#
    foreach (qw(dateenrolled dateexpiry dateofbirth debarred debarred2)) { # B015
        next unless exists $newdata{$_};
        my $userdate = $newdata{$_} or next;
        if ($userdate =~ /$syspref/) {
            $newdata{$_} = format_date_in_iso($userdate);	# if they match syspref format, then convert to ISO
        } elsif ($userdate =~ /$iso/) {
            warn "Date $_ ($userdate) is already in ISO format";
        } else {
            ($userdate eq '0000-00-00') and warn "Data error: $_ is '0000-00-00'";
            $template->param( "ERROR_$_" => 1 );	# else ERROR!
            push(@errors,"ERROR_$_");
        }
    }
  # check permission to modify login info.
    if (ref($borrower_data) && ($borrower_data->{'category_type'} eq 'S') && ! (C4::Auth::haspermission($userenv->{'id'},{'staffaccess'=>1})) )  {
        $NoUpdateLogin = 1;
    }
}

# remove keys from %newdata that ModMember() doesn't like
{
    my @keys_to_delete = (
        qr/^BorrowerMandatoryField$/,
        qr/^category_type$/,
        qr/^check_member$/,
        qr/^destination$/,
        qr/^nodouble$/,
        qr/^op$/,
		qr/^datedebarred$/, # B015
		qr/^datedebarred2$/, # B015
        qr/^save$/,
        qr/^select_roadtype$/,
        qr/^updtype$/,
        qr/^SMSnumber$/,
        qr/^setting_extended_patron_attributes$/,
        qr/^setting_messaging_prefs$/,
        qr/^digest$/,
        qr/^modify$/,
        qr/^step$/,
        qr/^\d+$/,
        qr/^\d+-DAYS/,
        qr/^patron_attr_/,
    );
    for my $regexp (@keys_to_delete) {
        for (keys %newdata) {
            delete($newdata{$_}) if /$regexp/;
        }
    }
}

#############test for member being unique #############
if (($op eq 'insert') and !$nodouble){
        my $category_type_send=$category_type if ($category_type eq 'I'); 
        my $check_category; # recover the category code of the doublon suspect borrowers
			#   ($result,$categorycode) = checkuniquemember($collectivity,$surname,$firstname,$dateofbirth)
        ($check_member,$check_category) = checkuniquemember(
			$category_type_send, 
			($newdata{surname}     ? $newdata{surname}     : $data{surname}    ),
			($newdata{firstname}   ? $newdata{firstname}   : $data{firstname}  ),
			($newdata{dateofbirth} ? $newdata{dateofbirth} : $data{dateofbirth})
		);
        if(!$check_member){
            $nodouble = 1;
        }
  #   recover the category type if the borrowers is a doublon
    if ($check_category) {
      my $tmpborrowercategory=GetBorrowercategory($check_category);
      $check_categorytype=$tmpborrowercategory->{'category_type'};
    }   
}

  #recover all data from guarantor address phone ,fax... 
if ( defined($guarantorid) and
     ( $category_type eq 'C' || $category_type eq 'P' ) and
     $guarantorid ne ''  and
     $guarantorid ne '0' ) {
    if (my $guarantordata=GetMember(borrowernumber => $guarantorid)) {
        $guarantorinfo=$guarantordata->{'surname'}." , ".$guarantordata->{'firstname'};
        if ( !defined($data{'contactname'}) or $data{'contactname'} eq '' or
             $data{'contactname'} ne $guarantordata->{'surname'} ) {
            $newdata{'contactfirstname'}= $guarantordata->{'firstname'};
            $newdata{'contactname'}     = $guarantordata->{'surname'};
            $newdata{'contacttitle'}    = $guarantordata->{'title'};
	        foreach (qw(streetnumber address streettype address2
                        zipcode country city phone phonepro mobile fax email emailpro branchcode)) {
		        $newdata{$_} = $guarantordata->{$_};
	        }
        }
    }
}

###############test to take the right zipcode, country and city name ##############
if (!defined($guarantorid) or $guarantorid eq '' or $guarantorid eq '0') {
    # set only if parameter was passed from the form
    $newdata{'city'}    = $input->param('city')    if defined($input->param('city'));
    $newdata{'zipcode'} = $input->param('zipcode') if defined($input->param('zipcode'));
    $newdata{'country'} = $input->param('country') if defined($input->param('country'));
}

#builds default userid
my $old_userid = $input->param('old_userid');
if ( ($newdata{'userid'} eq '' && $old_userid eq '') && ( (defined $newdata{'userid'}) || ($newdata{ 'categorycode' } eq $PRE_REG_CATEGORY) ) ) {
	my $userid_fromemail = lc( NormalizeStr( $newdata{'email'} ) );
	
    if ($newdata{'email'} && Check_Userid($userid_fromemail,'') ) {
        $newdata{'userid'} = $userid_fromemail;
    } else {
        $newdata{'userid'} = Generate_Userid('', $newdata{'firstname'}, $newdata{'surname'} );
    }
} elsif ( $newdata{'userid'} eq '' && $op eq 'save' ) {
	$NoUpdateLogin = 1;
}
  
$debug and warn join "\t", map {"$_: $newdata{$_}"} qw(dateofbirth dateenrolled dateexpiry);
my $extended_patron_attributes = ();
if ($op eq 'save' || $op eq 'insert'){
  if (checkcardnumber($newdata{cardnumber},$newdata{borrowernumber})){ 
    push @errors, 'ERROR_cardnumber';
  } 
  my $dateofbirthmandatory = (scalar grep {$_ eq "dateofbirth"} @field_check) ? 1 : 0;
  if ($newdata{dateofbirth} && $dateofbirthmandatory) {
    my $age = GetAge($newdata{dateofbirth});
    my $borrowercategory=GetBorrowercategory($newdata{'categorycode'});   
	my ($low,$high) = ($borrowercategory->{'dateofbirthrequired'}, $borrowercategory->{'upperagelimit'});
    if (($high && ($age > $high)) or ($age < $low)) {
      push @errors, 'ERROR_age_limitations';
	  $template->param('ERROR_age_limitations' => "$low to $high");
    }
  }
  
    if($newdata{surname} && C4::Context->preference('uppercasesurnames')) {
        $newdata{'surname'} = ToUppercase( $newdata{'surname'} );
    }

  if (C4::Context->preference("IndependantBranches")) {
    if ($userenv && $userenv->{flags} % 2 != 1){
      $debug and print STDERR "  $newdata{'branchcode'} : ".$userenv->{flags}.":".$userenv->{branch};
      unless (!$newdata{'branchcode'} || $userenv->{branch} eq $newdata{'branchcode'}){
        push @errors, "ERROR_branch";
      }
    }
  }
  # Check if the userid is unique
  $newdata{'userid'} = lc( NormalizeStr ( $newdata{'userid'} ) );
  unless (Check_Userid($newdata{'userid'},$borrowernumber)) {
    push @errors, "ERROR_login_exist";
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
	  my $sth;
	  if ( $borrowernumber ) {
	  	$query = $query." AND borrowernumber <> ?";
		$sth = $dbh->prepare($query);
	  	$sth->execute($email, $borrowernumber);
	  } else {
	  	$sth = $dbh->prepare($query);
	  	$sth->execute($email);
	  }
	
	  my $row = $sth->fetchall_arrayref({});
	  warn $row->[0];
	  if ( $row->[0] ) {
	    push @errors, "ERROR_email_exist";
	  }
  }
  # END B014 - BUG 68
 
  my $password = $input->param('password');
  push @errors, "ERROR_short_password" if( $password && $minpw && $password ne '****' && (length($password) < $minpw) );

  if (C4::Context->preference('ExtendedPatronAttributes')) {
    $extended_patron_attributes = parse_extended_patron_attributes($input);
    foreach my $attr (@$extended_patron_attributes) {
        unless (C4::Members::Attributes::CheckUniqueness($attr->{code}, $attr->{value}, $borrowernumber)) {
            push @errors, "ERROR_extended_unique_id_failed";
            $template->param(ERROR_extended_unique_id_failed => "$attr->{code}/$attr->{value}");
        }
    }
  }
}

if ( ($op eq 'modify' || $op eq 'insert' || $op eq 'save') and ($step == 0 or $step == 3 )){
    if (exists ($newdata{'dateexpiry'}) && !($newdata{'dateexpiry'})){
        my $arg2 = $newdata{'dateenrolled'} || C4::Dates->today('iso');
        $newdata{'dateexpiry'} = GetExpiryDate($newdata{'categorycode'},$arg2);
    }
}

if ( ( defined $input->param('SMSnumber') ) && ( $input->param('SMSnumber') ne $newdata{'mobile'} ) ) {
    $newdata{smsalertnumber} = $input->param('SMSnumber');
}

###  Error checks should happen before this line.
$nok = $nok || scalar(@errors);
if ((!$nok) and $nodouble and ($op eq 'insert' or $op eq 'save')){
    $debug and warn "$op dates: " . join "\t", map {"$_: $newdata{$_}"} qw(dateofbirth dateenrolled dateexpiry);
    if ($op eq 'insert'){
    	# we know it's not a duplicate borrowernumber or there would already be an error
        $borrowernumber = &AddMember(%newdata);
        
        #SCA : add user
        if ( C4::Context->preference('UseSCA') ) {
            my ($status, $message, $enrolled_by) = AddScaUser( $borrowernumber );
            if ($status) {
                ModMember(
                    borrowernumber => $borrowernumber, 
                    sca_enrolled_by => $enrolled_by
                );
            } else {
                $nok = 1;
            	push @errors, $message;
            }
        }
        #End SCA
    
        # If 'AutoEmailOpacUser' syspref is on, email user their account details from the 'notice' that matches the user's branchcode.
        if ( C4::Context->preference("AutoEmailOpacUser") == 1 && $newdata{'userid'}  && $newdata{'password'}) {
            #look for defined primary email address, if blank - attempt to use borr.email and borr.emailpro instead
            my $emailaddr;
            if  (C4::Context->preference("AutoEmailPrimaryAddress") ne 'OFF'  && 
                $newdata{C4::Context->preference("AutoEmailPrimaryAddress")} =~  /\w\@\w/ ) {
                $emailaddr =   $newdata{C4::Context->preference("AutoEmailPrimaryAddress")} 
            } 
            elsif ($newdata{email} =~ /\w\@\w/) {
                $emailaddr = $newdata{email} 
            }
            elsif ($newdata{emailpro} =~ /\w\@\w/) {
                $emailaddr = $newdata{emailpro} 
            }
            elsif ($newdata{B_email} =~ /\w\@\w/) {
                $emailaddr = $newdata{B_email} 
            }
            # if we manage to find a valid email address, send notice 
            if ($emailaddr) {
                $newdata{emailaddr} = $emailaddr;
                my $letter = getletter ('members', "ACCTDETAILS:$newdata{'branchcode'}") ;
                # if $branch notice fails, then email a default notice instead.
                $letter = getletter ('members', "ACCTDETAILS")  if !$letter;
                SendAlerts ( 'members' , \%newdata , $letter ) if $letter
            }
        } 
    
    	if ($data{'organisations'}){            
    		# need to add the members organisations
    		my @orgs=split(/\|/,$data{'organisations'});
    		add_member_orgs($borrowernumber,\@orgs);
    	}
        if (C4::Context->preference('ExtendedPatronAttributes') and $input->param('setting_extended_patron_attributes')) {
            C4::Members::Attributes::SetBorrowerAttributes($borrowernumber, $extended_patron_attributes);
        }
        if (C4::Context->preference('EnhancedMessagingPreferences') and $input->param('setting_messaging_prefs')) {
            C4::Form::MessagingPreferences::handle_form_action($input, { borrowernumber => $borrowernumber }, $template);
        }
        
        #B11: Print Confirmation
        if ( $newdata{ 'categorycode' } ne $PRE_REG_CATEGORY ) {
    		$print_confirmation=1;
        }
        
        
    } elsif ($op eq 'save'){ 
    	if ($NoUpdateLogin) {
    		delete $newdata{'password'};
    		delete $newdata{'userid'};
    	}
    	# B014 : add enrolmentFee for pre-inscription
    	$newdata{'old_category'} = $input->param('old_category');
    	# END
    	&ModMember(%newdata) unless scalar(keys %newdata) <= 1; # bug 4508 - avoid crash if we're not
                                                                # updating any columns in the borrowers table,
                                                                # which can happen if we're only editing the
                                                                # patron attributes or messaging preferences sections
        if (C4::Context->preference('ExtendedPatronAttributes') and $input->param('setting_extended_patron_attributes')) {
            C4::Members::Attributes::SetBorrowerAttributes($borrowernumber, $extended_patron_attributes);
        }
        if (C4::Context->preference('EnhancedMessagingPreferences') and $input->param('setting_messaging_prefs')) {
            C4::Form::MessagingPreferences::handle_form_action($input, { borrowernumber => $borrowernumber }, $template);
        }
        
        #SCA : modify user if necessary
        my $old_category   = $input->param('old_category');
        my $old_cardnumber = $input->param('old_cardnumber');
        my $old_enrolled_by = $input->param('old_enrolled_by');
        if ( C4::Context->preference('UseSCA') ) {
            my ($status, $message, $enrolled_by) = ModScaUser( $borrowernumber, $old_cardnumber, $old_category, $old_enrolled_by );
            if ($status) {
                ModMember(
                    borrowernumber => $borrowernumber, 
                    sca_enrolled_by => $enrolled_by
                );
            } else {
                ModMember(
                    borrowernumber => $borrowernumber, 
                    sca_enrolled_by => $old_enrolled_by,
                    cardnumber => $old_cardnumber,
                );
                $nok = 1;
            	push @errors, $message;
            }
        }
        #End SCA
        
        #B11: Print Confirmation
        if ( ( $newdata{'old_category'} eq $PRE_REG_CATEGORY ) && ( $newdata{'categorycode'} ne $newdata{'old_category'} ) ) {
    		$print_confirmation=1;
        }
    }
    
# B014
	if ($uploadfile){

    my ($handled, $total) ; 
	
    my $dirname = File::Temp::tempdir( CLEANUP => 1);
    $debug and warn "dirname = $dirname";
    my $filesuffix = $1 if $uploadfilename =~ m/(\..+)$/i;
    my ( $tfh, $tempfile ) = File::Temp::tempfile( SUFFIX => $filesuffix, UNLINK => 1 );
    $debug and warn "tempfile = $tempfile";
    my ( @directories );
	if ( $uploadfilename !~ /\.zip$/i && $filetype =~ m/zip/i ){
	push @errors, "NOTZIP";
	push @errors, "IMGFILE";
	}
	
	 unless ( -w $dirname ){
    push @errors, "NOWRITETEMP" ;
	push @errors, "IMGFILE";}
	
	 unless ( length( $uploadfile ) > 0 ) {
    push @errors, "EMPTYUPLOAD";
	push @errors, "IMGFILE";}
	
	
	 if (scalar @errors) {
	     $nok =1;
	 }
	 else{
        while ( <$uploadfile> ) {
            print $tfh $_;
        }
	
        close $tfh;
		 my $results;
        if ( $filetype eq 'zip' ) {
            unless (system("unzip", $tempfile,  '-d', $dirname) == 0) {
			  $nok = 1;
                push @errors, "UZIPFAIL" ;
				$results=0;
                
            }
            push @directories, "$dirname";
			my $dir;	
            foreach  my $recursive_dir ( @directories ) {
                opendir $dir, $recursive_dir;
                while ( my $entry = readdir $dir ) {
            push @directories, "$recursive_dir/$entry" if ( -d "$recursive_dir/$entry" and $entry !~ /^\./ );
                $debug and warn "$recursive_dir/$entry";
                }
                closedir $dir;
            }
         
            foreach my $dir ( @directories ) {
                $results = handle_dirimage( $dir, $filesuffix, $tempfile );
                 $handled++ if $results == 1;
            }
          $total = scalar @directories;
        } 
        else {       #if ($filetype eq 'zip' )
           
            $results = handle_dirimage( $dirname, $filesuffix, $tempfile );
            $handled = 1;
            $total = 1;
        }

        if ( !$results ) {
          $nok=1;
        } else {
           my $filecount;
            map {$filecount += $_->{count}} @counts;
            $debug and warn "Total directories processed: $total";
            $debug and warn "Total files processed: $filecount";
            $template->param(
            TOTAL => $total,
            HANDLED => $handled,
            COUNTS => \@counts,
            TCOUNTS => ($filecount > 0 ? $filecount : undef),
            );
    #        $template->param( borrowernumber => $borrowernumber ) if $borrowernumber;
        }
    
    }
}
	
	if (!$nok){
		print scalar ($destination eq "circ") ? 
			$input->redirect("/cgi-bin/koha/circ/circulation.pl?borrowernumber=$borrowernumber") :
			$input->redirect("/cgi-bin/koha/members/moremember.pl?borrowernumber=$borrowernumber".($print_confirmation?'&print=confirmation':'')) ;
		exit;		# You can only send 1 redirect!  After that, content or other headers don't matter.
	}
	
	$template->param(
		print_confirmation => $print_confirmation,
	);
}
# END B014

if ($delete){
	print $input->redirect("/cgi-bin/koha/deletemem.pl?member=$borrowernumber");
	exit;		# same as above
}

if ($nok or !$nodouble){
    $op="add" if ($op eq "insert");
    $op="modify" if ($op eq "save");
    %data=%newdata; 
    $template->param( updtype => ($op eq 'add' ?'I':'M'));	# used to check for $op eq "insert"... but we just changed $op!
    unless ($step){
    	# Progilone B014
    	if ( $categorycode eq $PRE_REG_CATEGORY ) {
    		$template->param( "$categorycode" => $categorycode );
	    	$template->param( updtype => 'I', step_1 => 1,step_2 => 0,step_3 => 1, step_4 => 0, step_5 => 0, step_6 => 0);
	    } else {
		    $template->param( step_1 => 1,step_2 => 0,step_3 => 1, step_4 => 1, step_5 => 1, step_6 => 1);
	    }  
    }  
} 
# B014 : borrower pre-registrated can be modified by anyone
if ($data{categorycode} ne $PRE_REG_CATEGORY and C4::Context->preference("IndependantBranches")) {
# END B014
    my $userenv = C4::Context->userenv;
    if ($userenv->{flags} % 2 != 1 && $data{branchcode}){
        unless ($userenv->{branch} eq $data{'branchcode'}){
            print $input->redirect("/cgi-bin/koha/members/members-home.pl");
            exit;
        }
    }
}
if ($op eq 'add'){
	# Progilone B014
	if ( $categorycode eq $PRE_REG_CATEGORY ) {
    	$template->param( updtype => 'I', step_1 => 1,step_2 => 0,step_3 => 1, step_4 => 0, step_5 => 0, step_6 => 0);
    } else {
	    $template->param( updtype => 'I', step_1=>1, step_2=>0, step_3=>1, step_4=>1, step_5 => 1, step_6 => 1);
    }
}
if ($op eq "modify")  {
    $template->param( updtype => 'M',modify => 1 );
    $template->param( step_1=>1, step_2=>0, step_3=>1, step_4=>1, step_5 => 1, step_6 => 1) unless $step; # B014
}
# my $cardnumber=$data{'cardnumber'};
$data{'cardnumber'}=fixup_cardnumber($data{'cardnumber'}) if $op eq 'add';
if(!defined($data{'sex'})){
    $template->param( none => 1);
} elsif($data{'sex'} eq 'F'){
    $template->param( female => 1);
} elsif ($data{'sex'} eq 'M'){
    $template->param(  male => 1);
} else {
    $template->param(  none => 1);
}

##Now all the data to modify a member.
my ($categories,$labels)=ethnicitycategories();
  
my $ethnicitycategoriescount=$#{$categories};
my $ethcatpopup;
if ($ethnicitycategoriescount>=0) {
  $ethcatpopup = CGI::popup_menu(-name=>'ethnicity',
        -id => 'ethnicity',
        -tabindex=>'',
        -values=>$categories,
        -default=>$data{'ethnicity'},
        -labels=>$labels);
  $template->param(ethcatpopup => $ethcatpopup); # bad style, has to be fixed
}

my @typeloop;
foreach (qw(C A S P I X)) {
    my $action="WHERE category_type=?";
	($categories,$labels)=GetborCatFromCatType($_,$action);
	my @categoryloop;
	foreach my $cat (@$categories){
		push @categoryloop,{'categorycode' => $cat,
			  'categoryname' => $labels->{$cat},
			  'categorycodeselected' => ((defined($borrower_data->{'categorycode'}) && 
                                                     $cat eq $borrower_data->{'categorycode'}) 
                                                     || (defined($categorycode) && $cat eq $categorycode)),
		};
	}
	my %typehash;
	$typehash{'typename'}=$_;
	$typehash{'categoryloop'}=\@categoryloop;
	push @typeloop,{'typename' => $_,
	  'categoryloop' => \@categoryloop};
}  
$template->param('typeloop' => \@typeloop);

# test in city
$select_city=getidcity($data{'city'}) if defined $guarantorid and ($guarantorid ne '0');
($default_city=$select_city) if ($step eq 0);
if (!defined($select_city) or $select_city eq '' ){
	$default_city = &getidcity($data{'city'});
}

my $city_arrayref = GetCities();
if (@{$city_arrayref} ) {
    $template->param( city_cgipopup => 1);

    if ($default_city) { # flag the current or default val
        for my $city ( @{$city_arrayref} ) {
            if ($default_city == $city->{cityid}) {
                $city->{selected} = 1;
                last;
            }
        }
    }
}
  
my $default_roadtype;
$default_roadtype=$data{'streettype'} ;
my($roadtypeid,$road_type)=GetRoadTypes();
  $template->param( road_cgipopup => 1) if ($roadtypeid );
my $roadpopup = CGI::popup_menu(-name=>'streettype',
        -id => 'streettype',
        -values=>$roadtypeid,
        -labels=>$road_type,
        -override => 1,
        -default=>$default_roadtype
        );  

my $default_borrowertitle;
$default_borrowertitle=$data{'title'} ;
my($borrowertitle)=GetTitles();
$template->param( title_cgipopup => 1) if ($borrowertitle);
my $borrotitlepopup = CGI::popup_menu(-name=>'title',
        -id => 'btitle',
        -values=>$borrowertitle,
        -override => 1,
        -default=>$default_borrowertitle
        );    

my @relationships = split /,|\|/, C4::Context->preference('BorrowerRelationship');
my @relshipdata;
while (@relationships) {
  my $relship = shift @relationships || '';
  my %row = ('relationship' => $relship);
  if (defined($data{'relationship'}) and $data{'relationship'} eq $relship) {
    $row{'selected'}=' selected';
  } else {
    $row{'selected'}='';
  }
  push(@relshipdata, \%row);
}

# B015
my %flags = ( 'gonenoaddress' => ['gonenoaddress' ],
              'lost'          => ['lost' ],
	          'docs'          => ['docs' ],
	          'debarred'      => ['debarred' ],
              'debarred2'     => ['debarred2' ],);
# END B015

 
my @flagdata;
foreach (keys(%flags)) {
	my $key = $_;
	my %row =  ('key'   => $key,
		    'name'  => $flags{$key}[0]);
	if ($data{$key}) {
		$row{'yes'}=' checked';
		$row{'no'}='';
    }
	else {
		$row{'yes'}='';
		$row{'no'}=' checked';
	}
	push @flagdata,\%row;
}

# B015
if ($data{debarred}){
    $data{datedebarred} = $data{debarred} if ( $data{debarred} ne "9999-12-31" );
}
if ($data{debarred2}){
    $data{datedebarred2} = $data{debarred2} if ( $data{debarred2} ne "9999-12-31" );
}
# END B015

#get Branches
my @branches;
my @select_branch;
my %select_branches;

my $onlymine=(C4::Context->preference('IndependantBranches') && 
              C4::Context->userenv && 
              C4::Context->userenv->{flags} % 2 !=1  && 
              C4::Context->userenv->{branch}?1:0);
              
my $branches=GetBranches($onlymine);
my $default;

for my $branch (sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} } keys %$branches) {
    push @select_branch,$branch;
    $select_branches{$branch} = $branches->{$branch}->{'branchname'};
    $default = C4::Context->userenv->{'branch'} if (C4::Context->userenv && C4::Context->userenv->{'branch'});
}
# --------------------------------------------------------------------------------------------------------
  #in modify mod :default value from $CGIbranch comes from borrowers table
  #in add mod: default value come from branches table (ip correspendence)
$default=$data{'branchcode'}  if ($op eq 'modify' || ($op eq 'add' && $category_type eq 'C'));
my $CGIbranch = CGI::scrolling_list(-id    => 'branchcode',
            -name   => 'branchcode',
            -values => \@select_branch,
            -labels => \%select_branches,
            -size   => 1,
            -override => 1,  
            -multiple =>0,
            -default => $default,
        );
my $CGIorganisations;
my $member_of_institution;
if (C4::Context->preference("memberofinstitution")){
    my $organisations=get_institutions();
    my @orgs;
    my %org_labels;
    foreach my $organisation (keys %$organisations) {
        push @orgs,$organisation;
        $org_labels{$organisation}=$organisations->{$organisation}->{'surname'};
    }
    $member_of_institution=1;

    $CGIorganisations = CGI::scrolling_list( -id => 'organisations',
        -name     => 'organisations',
        -labels   => \%org_labels,
        -values   => \@orgs,
        -size     => 5,
        -multiple => 'true'

    );
}

# --------------------------------------------------------------------------------------------------------

my $CGIsort = buildCGIsort("Bsort1","sort1",$data{'sort1'});
if ($CGIsort) {
    $template->param(CGIsort1 => $CGIsort);
}
$template->param( sort1 => $data{'sort1'});		# shouldn't this be in an "else" statement like the 2nd one?

$CGIsort = buildCGIsort("Bsort2","sort2",$data{'sort2'});
if ($CGIsort) {
    $template->param(CGIsort2 => $CGIsort);
} else {
    $template->param( sort2 => $data{'sort2'});
}

# B014
$CGIsort = buildCGIsort("Bsort3","sort3",$data{'sort3'});
if ($CGIsort) {
    $template->param(CGIsort3 => $CGIsort);
} else {
    $template->param( sort3 => $data{'sort3'});
}
# END B014

if ($nok) {
    foreach my $error (@errors) {
        $template->param($error) || $template->param( $error => 1);
    }
    $template->param(nok => 1);
}
  
  #Formatting data for display    
  
if (!defined($data{'dateenrolled'}) or $data{'dateenrolled'} eq ''){
  $data{'dateenrolled'}=C4::Dates->today('iso');
}
if (C4::Context->preference('uppercasesurnames')) {
	$data{'surname'}    =uc($data{'surname'}    );
	$data{'contactname'}=uc($data{'contactname'});
}
foreach (qw(dateenrolled dateexpiry dateofbirth datedebarred datedebarred2)) { # B015
	# B014 - BUG 69
    if ( $_ eq 'dateexpiry' && $categorycode eq $PRE_REG_CATEGORY ){
    	$data{'dateexpiry'} = '';
    }
    else{
	    $data{$_} = format_date($data{$_}); # back to syspref for display
	    $template->param( $_ => $data{$_});
    }
    # END B014 - BUG 69
}

if (C4::Context->preference('ExtendedPatronAttributes')) {
    $template->param(ExtendedPatronAttributes => 1);
    patron_attributes_form($template, $borrowernumber);
}

if (C4::Context->preference('EnhancedMessagingPreferences')) {
    if ($op eq 'add') {
        C4::Form::MessagingPreferences::set_form_values({ categorycode => $categorycode }, $template);
    } else {
        C4::Form::MessagingPreferences::set_form_values({ borrowernumber => $borrowernumber }, $template);
    }
    $template->param(SMSSendDriver => C4::Context->preference("SMSSendDriver"));
    $template->param(SMSnumber     => defined $data{'smsalertnumber'} ? $data{'smsalertnumber'} : $data{'mobile'});
}

$template->param( "showguarantor"  => ($category_type=~/A|I|S|X/) ? 0 : 1); # associate with step to know where you are
$debug and warn "memberentry step: $step";
$template->param(%data);
$template->param( "step_$step"  => 1) if $step;	# associate with step to know where u are
$template->param(  step  => $step   ) if $step;	# associate with step to know where u are
$template->param( debug  => $debug  ) if $debug;

$template->param(
  BorrowerMandatoryField => C4::Context->preference("BorrowerMandatoryField"),#field to test with javascript
  category_type => $category_type,#to know the category type of the borrower
  DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
  select_city => $select_city,
  "$category_type"  => 1,# associate with step to know where u are
  destination   => $destination,#to know wher u come from and wher u must go in redirect
  check_member    => $check_member,#to know if the borrower already exist(=>1) or not (=>0) 
  "op$op"   => 1);
  
my $sca_enrolled_by = '';
my $sca_enrolled_by_empty = 1;
if (defined $borrower_data->{'sca_enrolled_by'} && $borrower_data->{'sca_enrolled_by'} ne '') {
    $sca_enrolled_by = $borrower_data->{'sca_enrolled_by'};
    $sca_enrolled_by_empty = 0;
}


$template->param(
  nodouble  => $nodouble,
  borrowernumber  => $borrowernumber, #register number
  guarantorid => (defined($borrower_data->{'guarantorid'})) ? $borrower_data->{'guarantorid'} : $guarantorid,
  ethcatpopup => $ethcatpopup,
  relshiploop => \@relshipdata,
 # city_loop => $city_arrayref, B014
  roadpopup => $roadpopup,  
  borrotitlepopup => $borrotitlepopup,
  guarantorinfo   => $guarantorinfo,
  flagloop  => \@flagdata,
  dateformat      => C4::Dates->new()->visual(),
  C4::Context->preference('dateformat') => 1,
  check_categorytype =>$check_categorytype,#to recover the category type with checkcategorytype function
  modify          => $modify,
  nok     => $nok,#flag to konw if an error 
  CGIbranch => $CGIbranch,
  memberofinstution => $member_of_institution,
  CGIorganisations => $CGIorganisations,
  NoUpdateLogin =>  $NoUpdateLogin,
  print_confirmation => $print_confirmation,
  old_category => $old_category,
  sca_enrolled_by => $sca_enrolled_by,
  sca_enrolled_by_empty => $sca_enrolled_by_empty,
  enrolled_by_bulac => $ENROLLED_BY_BULAC,
  enrolled_by_inalco => $ENROLLED_BY_INALCO,
);

if(defined($data{'flags'})){
  $template->param(flags=>$data{'flags'});
}
if(defined($data{'contacttitle'})){
  $template->param("contacttitle_" . $data{'contacttitle'} => "SELECTED");
}

  
output_html_with_http_headers $input, $cookie, $template->output;

sub  parse_extended_patron_attributes {
    my ($input) = @_;
    my @patron_attr = grep { /^patron_attr_\d+$/ } $input->param();

    my @attr = ();
    my %dups = ();
    foreach my $key (@patron_attr) {
        my $value = $input->param($key);
        next unless defined($value) and $value ne '';
        my $password = $input->param("${key}_password");
        my $code     = $input->param("${key}_code");
        next if exists $dups{$code}->{$value};
        $dups{$code}->{$value} = 1;
        push @attr, { code => $code, value => $value, password => $password };
    }
    return \@attr;
}

sub patron_attributes_form {
    my $template = shift;
    my $borrowernumber = shift;

    my @types = C4::Members::AttributeTypes::GetAttributeTypes();
    if (scalar(@types) == 0) {
        $template->param(no_patron_attribute_types => 1);
        return;
    }
    my $attributes = C4::Members::Attributes::GetBorrowerAttributes($borrowernumber);

    # map patron's attributes into a more convenient structure
    my %attr_hash = ();
    foreach my $attr (@$attributes) {
        push @{ $attr_hash{$attr->{code}} }, $attr;
    }

    my @attribute_loop = ();
    my $i = 0;
    foreach my $type_code (map { $_->{code} } @types) {
        my $attr_type = C4::Members::AttributeTypes->fetch($type_code);
        my $entry = {
            code              => $attr_type->code(),
            description       => $attr_type->description(),
            repeatable        => $attr_type->repeatable(),
            password_allowed  => $attr_type->password_allowed(),
            category          => $attr_type->authorised_value_category(),
            password          => '',
        };
        if (exists $attr_hash{$attr_type->code()}) {
            foreach my $attr (@{ $attr_hash{$attr_type->code()} }) {
                my $newentry = { map { $_ => $entry->{$_} } %$entry };
                $newentry->{value} = $attr->{value};
                $newentry->{password} = $attr->{password};
                $newentry->{use_dropdown} = 0;
                if ($attr_type->authorised_value_category()) {
                    $newentry->{use_dropdown} = 1;
                    $newentry->{auth_val_loop} = GetAuthorisedValues($attr_type->authorised_value_category(), $attr->{value});
                }
                $i++;
                $newentry->{form_id} = "patron_attr_$i";
                #use Data::Dumper; die Dumper($entry) if  $entry->{use_dropdown};
                push @attribute_loop, $newentry;
            }
        } else {
            $i++;
            my $newentry = { map { $_ => $entry->{$_} } %$entry };
            if ($attr_type->authorised_value_category()) {
                $newentry->{use_dropdown} = 1;
                $newentry->{auth_val_loop} = GetAuthorisedValues($attr_type->authorised_value_category());
            }
            $newentry->{form_id} = "patron_attr_$i";
            push @attribute_loop, $newentry;
        }
    }
    $template->param(patron_attributes => \@attribute_loop);

}

# B014
sub handle_dirimage {
    my ( $dir, $suffix ,$tempfile ) = @_;
    my $source;
	my %errorloc;
	my %countloc;
    $debug and warn "Entering sub handle_dir; passed \$dir=$dir, \$suffix=$suffix";
    if ($suffix =~ m/zip/i) {     # If we were sent a zip file, process any included data/idlink.txt files
        my ( $file, $filename, $cardnumber , $dirhandle);
        $debug and warn "Passed a zip file.";
        opendir $dirhandle, $dir;
        while ( my $filename = readdir $dirhandle ) {
            $file = "$dir/$filename" if ($filename =~ m/datalink\.txt/i || $filename =~ m/idlink\.txt/i);
        }
        unless (open (FILE, $file)) {
        warn "Opening $dir/$file failed!";
		push @errors, "IMGFILE";
		push @errors, "OPNLINK";
              
        return 0; # This error is fatal to the import of this directory contents, so bail and return the error to the caller
        };

        while (my $line = <FILE>) {
            $debug and warn "Reading contents of $file";
        chomp $line;
            $debug and warn "Examining line: $line";
        my $delim = ($line =~ /\t/) ? "\t" : ($line =~ /,/) ? "," : "";
            $debug and warn "Delimeter is \'$delim\'";
            unless ( $delim eq "," || $delim eq "\t" ) {
                warn "Unrecognized or missing field delimeter. Please verify that you are using either a ',' or a 'tab'";
                    # This error is fatal to the import of this directory contents, so bail and return the error to the caller
				push @errors, "IMGFILE";
				push @errors, "DELERR";
                return 0;
            }
        ($cardnumber, $filename) = split $delim, $line;
        $cardnumber =~ s/[\"\r\n]//g;  # remove offensive characters
        $filename   =~ s/[\"\r\n\s]//g;
            $debug and warn "Cardnumber: $cardnumber Filename: $filename";
            $source = "$dir/$filename";
            %countloc = handle_image($cardnumber, $source, %countloc);
        }
        close FILE;
        closedir ($dirhandle);
    } else {
        $source = $tempfile;
        %countloc = handle_image($cardnumber, $source, %countloc);
    }
push @counts, \%countloc;
return 1;
}

sub handle_image {
    my ($cardnumber, $source, %count) = @_;
    $debug and warn "Entering sub handle_file; passed \$cardnumber=$cardnumber, \$source=$source";
    $count{filenames} = () if !$count{filenames};
    $count{source} = $source if !$count{source};
	  my %filerrors;
        my $filename;
    if ($cardnumber && $source) {     # Now process any imagefiles
      
        if ($filetype eq 'image') {
            $filename = $uploadfilename;
        } else {
            $filename = $1 if ($source =~ /\/([^\/]+)$/);
        }
        $debug and warn "Source: $source";
        my $size = (stat($source))[7];
            if ($size > 550000) {    # This check is necessary even with image resizing to avoid possible security/performance issues...
                $filerrors{'OVRSIZ'} = 1;
                push my @filerrors, \%filerrors;
                push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
                $template->param( ERRORS => 1 );
                 $nok=1;
                return %count;    # this one is fatal so bail here...
            }
        my ($srcimage, $image, $imgfile);
        if (open (IMG, "$source")) {
            $srcimage = GD::Image->new(*IMG);
            close (IMG);
            if (defined $srcimage) {
                my $mimetype = 'image/png'; # GD autodetects three basic image formats: PNG, JPEG, XPM; we will convert all to PNG which is lossless...
                # Check the pixel size of the image we are about to import...
                my ($width, $height) = $srcimage->getBounds();
                $debug and warn "$filename is $width pix X $height pix.";
                if ($width > 200 || $height > 300) {    # MAX pixel dims are 200 X 300...
                    $debug and warn "$filename exceeds the maximum pixel dimensions of 200 X 300. Resizing...";
                    my $percent_reduce;    # Percent we will reduce the image dimensions by...
                    if ($width > 200) {
                        $percent_reduce = sprintf("%.5f",(140/$width));    # If the width is oversize, scale based on width overage...
                    } else {
                        $percent_reduce = sprintf("%.5f",(200/$height));    # otherwise scale based on height overage.
                    }
                    my $width_reduce = sprintf("%.0f", ($width * $percent_reduce));
                    my $height_reduce = sprintf("%.0f", ($height * $percent_reduce));
                    $debug and warn "Reducing $filename by " . ($percent_reduce * 100) . "\% or to $width_reduce pix X $height_reduce pix";
                    $image = GD::Image->new($width_reduce, $height_reduce, 1); #'1' creates true color image...
                    $image->copyResampled($srcimage,0,0,0,0,$width_reduce,$height_reduce,$width,$height);
                    $imgfile = $image->png();
                    $debug and warn "$filename is " . length($imgfile) . " bytes after resizing.";
                    undef $image;
                    undef $srcimage;    # This object can get big...
                } else {
                    $image = $srcimage;
                    $imgfile = $image->png();
                    $debug and warn "$filename is " . length($imgfile) . " bytes.";
                    undef $image;
                    undef $srcimage;    # This object can get big...
                }
                $debug and warn "Image is of mimetype $mimetype";
                my $dberror = PutPatronImage($cardnumber,$mimetype, $imgfile) if $mimetype;
                if ( !$dberror && $mimetype ) { # Errors from here on are fatal only to the import of a particular image, so don't bail, just note the error and keep going
                    $count{count}++;
                    push @{ $count{filenames} }, { source => $filename, cardnumber => $cardnumber };
                } elsif ( $dberror ) {
                        warn "Database returned error: $dberror";
                        ($dberror =~ /patronimage_fk1/) ? $filerrors{'IMGEXISTS'} = 1 : $filerrors{'DBERR'} = 1;
                        push my @filerrors, \%filerrors;
                        push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
                        $nok=1;
                        $template->param( ERRORS => 1 );
                } elsif ( !$mimetype ) {
                    warn "Unable to determine mime type of $filename. Please verify mimetype.";
                    $filerrors{'MIMERR'} = 1;
                    push my @filerrors, \%filerrors;
                    push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
                   $template->param( ERRORS => 1 );
                    $nok=1;
                   
                }
            } else {
                warn "Contents of $filename corrupted!";
            #   $count{count}--;
                $filerrors{'CORERR'} = 1;
                push my @filerrors, \%filerrors;
                push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
               $template->param( ERRORS => 1 );
               $nok=1;
            
            }
        } else {
          #  warn "Opening $dir/$filename failed!";
            $filerrors{'OPNERR'} = 1;
            push my @filerrors, \%filerrors;
            push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
           $template->param( ERRORS => 1 );
            $nok=1;
        
        }
    } else {    # The need for this seems a bit unlikely, however, to maximize error trapping it is included
        warn "Missing " . ($cardnumber ? "filename" : ($filename ? "cardnumber" : "cardnumber and filename"));
        $filerrors{'CRDFIL'} = ($cardnumber ? "filename" : ($filename ? "cardnumber" : "cardnumber and filename"));
        push my @filerrors, \%filerrors;
        push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
       $template->param( ERRORS => 1 );
        $nok=1;
    
    }
    return (%count);
}
# END B014

# Local Variables:
# tab-width: 8
# End:
