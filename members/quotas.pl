#!/usr/bin/perl

##
# B012 : View quotas
##

use strict;
use warnings;

use CGI;

use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Biblio;
use C4::Output;
use C4::Members;

my $query = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'members/quotas.tmpl',
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
        debug           => 1,
    }
);

my $borrowernumber = $query->param('borrowernumber');

#For menu
my $borrower = GetMember( 'borrowernumber' => $borrowernumber );
$template->param( $borrower );

$borrower = GetMemberDetails( $borrowernumber );

#Get category's rules
my $dbh = C4::Context->dbh;
    
my $sth =  $dbh->prepare( '
    SELECT * FROM issuingrules
        WHERE categorycode=?
        AND branchcode=?
' );
    
$sth->execute(
    $borrower->{'categorycode'},
    $borrower->{'branchcode'}
);
my $quotas = $sth->fetchall_arrayref({});

# Table of quotas
foreach my $rule ( @$quotas ){
    if (defined $rule->{'itemtype'} && $rule->{'itemtype'} eq '*' ){
        $rule->{'itemtype_default'} = '1';
    } else {
        my $itemtype = getitemtypeinfo($rule->{'itemtype'});
        $rule->{'itemtype_ui'} = $itemtype->{'description'};        
    }
}

#output data
$template->param(
    BORROWER_INFO   => [ $borrower ],
    QUOTAS          => $quotas,
    quotasview      => 1
);

output_html_with_http_headers $query, $cookie, $template->output;
