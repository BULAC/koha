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
                window.open(\"/cgi-bin/koha/cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_995g.pl&index=\"+i+\"&result=\"+defaultvalue,\"unimarc_field_995g\",'width=1000,height=600,toolbar=false,scrollbars=yes');
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
            template_name   => "cataloguing/value_builder/unimarc_field_995g.tmpl",
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

    $template->param(
        index     => $index,
        "sf1$sf1" => 1,
        "sf2$sf2" => 1,        
    );
    
    output_html_with_http_headers $input, $cookie, $template->output;
}

1;
