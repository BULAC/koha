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


use strict;
use warnings;
use CGI;
use C4::Auth;    # get_template_and_user
use C4::Output;
use C4::VirtualShelves;
use C4::Branch;          # GetBranches
use C4::Members;         # GetMember
use C4::NewsChannels;    # get_opac_news
use C4::Acquisition;     # GetRecentAcqui
use C4::Languages qw(getTranslatedLanguages accept_language);

my $input = new CGI;
my $dbh   = C4::Context->dbh;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-main.tmpl",
        type            => "opac",
        query           => $input,
        authnotrequired => 1,
        flagsrequired   => { borrow => 1 },
    }
);

my $casAuthentication = C4::Context->preference('casAuthentication');
$template->param(
    casAuthentication   => $casAuthentication,
);


my $borrower = GetMember( borrowernumber=>$borrowernumber );
$template->param(
    textmessaging        => $borrower->{textmessaging},
) if (ref($borrower) eq "HASH");

# display news
# use cookie setting for language, bug default to syspref if it's not set
(my $theme) = themelanguage(C4::Context->config('opachtdocs'),'opac-main.tmpl','opac',$input);

my $translations = getTranslatedLanguages('opac',$theme);
my @languages = ();
foreach my $trans (@$translations)
{
    push(@languages, $trans->{rfc4646_subtag});
}

my $news_lang = getlanguagecookie($input); # PROGILONE - MAN321
unless ($news_lang) {
    if ($ENV{HTTP_ACCEPT_LANGUAGE}) {
        while( !$news_lang && ( $ENV{HTTP_ACCEPT_LANGUAGE} =~ m/([a-zA-Z]{2,}-?[a-zA-Z]*)(;|,)?/g ) ){
            if( my @lang = grep { /^$1$/i } @languages ) {
                $news_lang = $lang[0];
            }
        }
    }
    if (not $news_lang) {
        my @languages = split ",", C4::Context->preference("opaclanguages");
        $news_lang = $languages[0];
    }
}

$news_lang = $news_lang ? $news_lang : 'en' ;

my $all_koha_news   = &GetNewsToDisplay($news_lang);
my $koha_news_count = scalar @$all_koha_news;

$template->param(
    koha_news       => $all_koha_news,
    koha_news_count => $koha_news_count
);

# If GoogleIndicTransliteration system preference is On Set paramter to load Google's javascript in OPAC search screens
if (C4::Context->preference('GoogleIndicTransliteration')) {
        $template->param('GoogleIndicTransliteration' => 1);
}

# PROGILONE - may 2010 - F10
# Fetch the paramater list as a hash in scalar context:
#  * returns paramater list as tied hash ref
#  * we can edit the values by changing the key
#  * multivalued CGI paramaters are returned as a packaged string separated by "\0" (null)
my $params = $input->Vars;

# indexes are query qualifiers, like 'title', 'author', etc. They
# can be single or multiple parameters separated by comma: kw,right-Truncation 
my @indexes;
@indexes = split("\0",$params->{'idx'}) if $params->{'idx'};

# if a simple index (only one)  display the index used in the top search box
if ($indexes[0] && !$indexes[1]) {
    $template->param("ms_".$indexes[0] => 1);
}
# an operand can be a single term, a phrase, or a complete ccl query
my @operands;
@operands = split("\0",$params->{'q'}) if $params->{'q'};

# if a simple search, display the value in the search box
if ($operands[0] && !$operands[1]) {
    $template->param(ms_value => $operands[0]);
}
# End PROGILONE

output_html_with_http_headers $input, $cookie, $template->output;
