#!/usr/bin/perl

#
# Progilone B10: FreeAccessCallnumber
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

use C4::Callnumber::FreeAccessCallnumber;
use C4::Callnumber::Callnumber;
use C4::Utils::String qw/TrimStr/;

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
                window.open(\"/cgi-bin/koha/cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_995B.pl&index=\"+i+\"&result=\"+defaultvalue,\"unimarc_field_995B\",'width=1000,height=600,toolbar=false,scrollbars=yes');
            }
        </script>
";

    return ( $field_number, $res );
}

sub plugin {
    my ( $input ) = @_;

    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name   => "cataloguing/value_builder/unimarc_field_995B.tmpl",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { editcatalogue => '*' },
            debug           => 1,
        }
    );
    
    my $index   = $input->param( 'index' );
    my $result  = $input->param( 'result' ) || '                             '; #a generated FreeAccessCallnumber is 29 characters long
    my $op = $input->param( 'op' ) || '';
    
    my ( $geo_index, $classification, $complement, $volume) = ( '', '', '', '' );
    my $serial = 0;
    my $number = 0;
    
    my $freeInput = 0;
	my $freeCallnumber = ( TrimStr( $result ) eq '' ) ? '' : $result;
	
	if ( IsFreeInputCallnumber( $result ) ) {
		$freeInput = 1;
	} else {
		( $geo_index, $classification, $complement, $volume) = FreeAccessCallnumberCut( $result );
	}
	
	my $subscription = $input->param( 'subscription' ) || 0;
	if ( $subscription ) {
		my $trim_classification = TrimStr( $classification );
		unless ( $trim_classification eq '' ) {
			#The callnumber is not a free access callnumber
			( $geo_index, $classification, $complement, $volume ) = ( '', '', '', '', '' );
		}
		$result = GenerateFreeAccessCallnumber( $geo_index, $classification, $complement, $volume);
	}
	
	if ( IsSerialCallnumber( $result ) || $subscription ) {
		$serial = 1;
		( $complement, $number ) = CutSerialComplement( $complement );
	}
    
    if ( $op eq 'compute' ) {
	    my $callnumber = '';
	    $serial         = $input->param( 'serial' );
	    $number         = $input->param( 'number' );
	    $freeInput      = $input->param( 'freeInput' );
	    $freeCallnumber = $input->param( 'freeCallnumber' );
		my $base_complement = '';
		
		if ( $freeInput ) {
			$callnumber = $freeCallnumber;
		} else {
		    if ( $serial ) {
			    $geo_index       = $input->param( 'serial_geo_index' );
			    $base_complement = $input->param( 'serial_complement' );
		    	$classification  = '';
		    	$volume          = '';
		    	
		    	$number     = FindNextSerialNumber( $geo_index, $base_complement );
		    	$complement = ComputeSerialComplement( $base_complement, $number );
		    } else {
			    $geo_index      = $input->param( 'geo_index' );
			    $classification = $input->param( 'classification' );
			    $complement     = $input->param( 'complement' );
			    $volume         = $input->param( 'volume' );
		    }
		    
			$callnumber = GenerateFreeAccessCallnumber( $geo_index, $classification, $complement, $volume );
		}
    	
    	$template->param(
	        "index"          => $index,
	        "result"         => $result,
	        "op"             => $op,
	        "serial"         => $serial,
	        "subscription"   => $subscription,
	        "number"         => $number,
	        "geo_index"      => TrimStr($geo_index),
	        "classification" => TrimStr($classification),
	        "complement"     => TrimStr($complement),
	        "volume"         => TrimStr($volume),
	        "callnumber"     => $callnumber,
	        "freeInput"      => $freeInput,
	        "freeCallnumber" => $freeCallnumber,
		);
    }
    
    if ($op eq 'cancel') {
	    $geo_index      = $input->param( 'geo_index' );
	    $classification = $input->param( 'classification' );
	    $complement     = $input->param( 'complement' );
	    $volume         = $input->param( 'volume' );
	    $serial         = $input->param( 'serial' );
	    $number         = $input->param( 'number' );
	    $freeInput      = $input->param( 'freeInput' );
		$freeCallnumber = $input->param( 'freeCallnumber' );
	    
	    if ( $serial ) {
	    	( $complement, $number ) = CutSerialComplement( $complement );
	    }
	    
	    $op = '';
    }
    
    if ( $op eq '' ) {
    	
    	my @geo_index_auth_values_hash = GetGeoIndexAuthValues( $geo_index );
    	
	    $template->param(
	        "index"                      => $index,
	        "result"                     => $result,
	        "op"                         => $op,
	        "serial"                     => $serial,
	        "subscription"               => $subscription,
			"classification"             => TrimStr($classification),
			"complement"                 => TrimStr($complement),
			"volume"                     => TrimStr($volume),
			"geo_index_auth_values_hash" => \@geo_index_auth_values_hash,
			"freeInput"                  => $freeInput,
			"freeCallnumber"             => $freeCallnumber,
		);
	}
    
    output_html_with_http_headers $input, $cookie, $template->output;
}

1;
