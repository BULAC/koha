#!/usr/bin/perl

#
# B122 : Inventory
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

use C4::Auth;
use CGI;
use C4::Context;
use C4::Koha;
use C4::Output;

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
                window.open(\"/cgi-bin/koha/cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_995z.pl&index=\"+i+\"&result=\"+defaultvalue,\"unimarc_field_995z\",'width=1000,height=600,toolbar=false,scrollbars=yes');
            }
        </script>
";

    return ( $field_number, $res );
}

sub plugin {
    my ($input) = @_;
    my $index   = $input->param('index');
    my $result  = $input->param('result');
    my $dbh     = C4::Context->dbh;

    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name   => "cataloguing/value_builder/unimarc_field_995z.tmpl",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { editcatalogue => '*' },
            debug           => 1,
        }
    );
    $result = "  00 " unless $result;
    my $sf1  = substr( $result, 0,  1 );
    my $sf2  = substr( $result, 1,  1 );
    my $sf3  = substr( $result, 2,  1 );
    my $sf4  = substr( $result, 3,  1 );
    my $sf5  = substr( $result, 4,  1 );

    # etat papier
    my $sf1_auth_values = GetAuthorisedValues("PAPIER", $sf1);
    my @sf1_auth_values_hash = ();
    foreach my $value ( @$sf1_auth_values ) {
        my %data;
        $data{"valeur"} = $value->{'authorised_value'};
        $data{"libelle"} = $value->{'lib'};
        $data{"selected"} = 'selected = "selected"' if $value->{'selected'};
        push (@sf1_auth_values_hash, \%data);
    }
    
    # etat faconnage
    my $sf2_auth_values = GetAuthorisedValues("FACONNAGE", $sf2);
    my @sf2_auth_values_hash = ();
    foreach my $value ( @$sf2_auth_values ) {
        my %data;
        $data{"valeur"} = $value->{'authorised_value'};
        $data{"libelle"} = $value->{'lib'};
        $data{"selected"} = 'selected = "selected"' if $value->{'selected'};
        push (@sf2_auth_values_hash, \%data);
    }
    
    # intervention
    my $sf5_auth_values = GetAuthorisedValues("NIV_INTERV", $sf5);
    my @sf5_auth_values_hash = ();
    foreach my $value ( @$sf5_auth_values ) {
        my %data;
        $data{"valeur"} = $value->{'authorised_value'};
        $data{"libelle"} = $value->{'lib'};
        $data{"selected"} = 'selected = "selected"' if $value->{'selected'};
        push (@sf5_auth_values_hash, \%data);
    }
    
    $template->param(
        index     => $index,
        sf1       => $sf1,
        "sf1_auth_values_hash" => \@sf1_auth_values_hash,
        sf2       => $sf2,
        "sf2_auth_values_hash" => \@sf2_auth_values_hash,
        "sf3$sf3" => 1,
        "sf4$sf4" => 1,        
        sf5       => $sf5,
        "sf5_auth_values_hash" => \@sf5_auth_values_hash,
    );
    
    output_html_with_http_headers $input, $cookie, $template->output;
}

1;
