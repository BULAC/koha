#!/usr/bin/perl

#
# Progilone B10: StoreCallnumber
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
use C4::Koha;

use C4::Callnumber::StoreCallnumber;
use C4::Callnumber::Callnumber;
use C4::Utils::String qw/TrimStr NormalizeStr/;
use C4::Callnumber::OlimpWS;

=head1

plugin_parameters : other parameters added when the plugin is called by the dopop function

=cut

sub plugin_parameters {
    my ( $dbh, $record, $tagslib, $i, $tabloop ) = @_;
    return "";
}

sub plugin_javascript {
    my ( $dbh, $record, $tagslib, $field_number, $tabloop ) = @_;
    my $res           = "
        <script type='text/javascript'>
            function Focus$field_number() {
                return 1;
            }

            function Blur$field_number() {
                return 1;
            }

            function Clic$field_number(i) {
                var defaultvalue;
                try {
                    defaultvalue = document.getElementById(i).value;
                } catch(e) {
                    alert('error when getting '+i);
                    return;
                }
                window.open(\"/cgi-bin/koha/cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_995K.pl&index=\"+i+\"&result=\"+defaultvalue,\"unimarc_field_995K\",'width=1000,height=600,toolbar=false,scrollbars=yes');
            }
        </script>
";

    return ( $field_number, $res );
}

sub plugin {
    my ( $input ) = @_;

    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name   => "cataloguing/value_builder/unimarc_field_995K.tmpl",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { editcatalogue => '*' },
            debug           => 1,
        }
    );
    
    my $index   = $input->param( 'index' );
    my $result  = $input->param( 'result' ) || '                       '; #a generated StoreCallnumber is 23 characters long
    my $op = $input->param( 'op' ) || '';

	my ( $branch, $mention, $type, $format, $number ) = ( '', '', '', '', '' ); #BULAC is the default branch value
	my $measures = '';
	my $retro = 0;
	my $retroCallnumber = (TrimStr( $result ) eq '') ? '' : $result;
	
	my $sequenceNumber = '';
	
	if ( IsRetroCallnumber( $result ) ) {
		$retro = 1;
	} else {
		( $branch, $mention, $type, $format, $number ) = StoreCallnumberCut( $result );
	}
    
    if ($op eq 'compute') {
    	$branch          = $input->param( 'branch' );
	    $mention         = uc NormalizeStr( $input->param( 'mention' ) );
	    $type            = $input->param( 'type' );
		$measures        = $input->param( 'measures' );
	    $format          = $input->param( 'format' );
	    $number          = $input->param( 'number' );
	    $retro           = $input->param( 'retro' );
	    $retroCallnumber = $input->param( 'retroCallnumber' );
	    $sequenceNumber  = $input->param( 'sequenceNumber' );
	    
	    my $callnumber = '';
	    my $computedNumber = 0;
	    my $ruleError = 0;
	    my $alreadyUsed = 0;
	    
    	if ( $retro ) {
    		$callnumber = $retroCallnumber;
    		$computedNumber = -1;
    	} elsif ( C4::Context->preference('UseAdvancedCallNumberManagement') ) {
    		( $computedNumber, $ruleError ) = FindNextNumber( $branch, $mention, $type, $format );
    		if ( $computedNumber >= 0 ) {
				$callnumber = GenerateStoreCallnumber( $branch, $mention, $type, $format, ($computedNumber==0)?'':$computedNumber );
    		}
    	} else {
    		$number = $sequenceNumber;
    		$callnumber = GenerateStoreCallnumber( $branch, $mention, $type, $format, $sequenceNumber );;
    		$computedNumber = -1;
    	}
    	
    	my $ruleNotActive = 0;
    	my $ruleNotExist  = 0;
    	
    	if ( $ruleError == 1) {
    		$ruleNotActive = 1;
    	} elsif ( $ruleError == 2) {
    		$ruleNotExist = 1;
    	}
    	
    	$template->param(
	        "index"           => $index,
	        "result"          => $result,
	        "op"              => $op,
	        "branch"          => TrimStr($branch),
	        "mention"         => TrimStr($mention),
	        "type"            => TrimStr($type),
	        "measures"        => TrimStr($measures),
	        "format"          => TrimStr($format),
	        "number"          => TrimStr($number),
	        "callnumber"      => $callnumber,
	        "retro"           => $retro,
	        "retroCallnumber" => $retroCallnumber,
	        "computedNumber"  => $computedNumber,
	        "ruleError"       => $ruleError,
	        "ruleNotActive"   => $ruleNotActive,
	        "ruleNotExist"    => $ruleNotExist
		);
    }
    
    if ( $op eq 'cancelOrCheck' ) {
	    my $cancel = $input->param( 'cancel' );
	    my $check  = $input->param( 'check' );
	    	
	    if ( $cancel ) {
	    	$branch          = $input->param( 'branch' );
		    $mention         = $input->param( 'mention' );
		    $type            = $input->param( 'type' );
		    $measures        = $input->param( 'measures' );
		    $format          = $input->param( 'format' );
		    $number          = $input->param( 'number' );
		    $retro           = $input->param( 'retro' );
		    $retroCallnumber = $input->param( 'retroCallnumber' );
		    $sequenceNumber  = $input->param( 'number' );
		    
		    $op = '';
    	} elsif ( $check ) {
    		$branch          = $input->param( 'branch' );
		    $mention         = $input->param( 'mention' );
		    $type            = $input->param( 'type' );
		    $measures        = $input->param( 'measures' );
		    $format          = $input->param( 'format' );
		    $number          = $input->param( 'choosenNumber' );
		    $retro           = $input->param( 'retro' );
		    $retroCallnumber = $input->param( 'retroCallnumber' );
		    
		    my $callnumber = $input->param( 'callnumber' );
		    my ( $computedNumber, $alreadyUsed ) = CanChooseNumber( $branch, $mention, $type, $format, $number );
		    if ( $computedNumber ) {
		    	$callnumber = GenerateStoreCallnumber( $branch, $mention, $type, $format, $number );
		    }
		    
		    $op = 'compute';
		    
		    $template->param(
		        "index"           => $index,
		        "result"          => $result,
		        "op"              => $op,
		        "branch"          => TrimStr($branch),
		        "mention"         => TrimStr($mention),
		        "type"            => TrimStr($type),
		        "measures"        => TrimStr($measures),
		        "format"          => TrimStr($format),
		        "number"          => TrimStr($number),
		        "callnumber"      => $callnumber,
		        "retro"           => $retro,
		        "retroCallnumber" => $retroCallnumber,
		        "computedNumber"  => $computedNumber,
		        "alreadyUsed"     => $alreadyUsed,
			);
    	}
    }
    
    if ( $op eq '' ) {
    	my @branch_data             = GetBranchValues( $branch, 1 );
		my @type_auth_values_hash   = GetTypeAuthValues( $type, 1 );
		my @format_auth_values_hash = GetFormatAuthValues( $format, 1 );
		
	    $template->param(
	        "index"                   => $index,
	        "result"                  => $result,
	        "op"                      => $op,
			"branch_values_hash"      => \@branch_data,
			"mention"                 => TrimStr($mention),
			"measures"                => TrimStr($measures),
			"number"                  => TrimStr($number),
			"type_auth_values_hash"   => \@type_auth_values_hash,
			"format_auth_values_hash" => \@format_auth_values_hash,
			"retro"                   => $retro,
			"retroCallnumber"         => $retroCallnumber,
			"sequenceNumber"          => $number,
		);
	}
	
	output_html_with_http_headers $input, $cookie, $template->output;
}

#sub normalize {
#    my ( $input ) = @_;
#    
#    for ( $input ) {  # the variable we work on
#		##  convert to Unicode first
#		##  if your data comes in Latin-1, then uncomment:
#		#$_ = Encode::decode( 'iso-8859-1', $_ );  
#		$_ = NFD( $_ );   ##  decompose
#		s/\pM//g;         ##  strip combining characters
#		s/[^\0-\x80]//g;  ##  clear everything else
#	}
#	
#	return $input; 
#}

1;
