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

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'opac-userquotas.tmpl',
        query           => $query,
        type            => 'opac',
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);


# Get borrower
my $borrower = GetMemberDetails( $borrowernumber );

#Get category's rules
my $dbh = C4::Context->dbh;
    
my $sth =  $dbh->prepare( '
    SELECT * FROM issuingrules
        WHERE categorycode=?
        AND branchcode=?
        ORDER BY itemtype
' );
    
$sth->execute(
    $borrower->{'categorycode'},
    $borrower->{'branchcode'}
);
my $quotas = $sth->fetchall_arrayref({});

my @quotas_loop;

# Table of quotas
foreach my $rule ( @$quotas ){
    if (defined $rule->{'itemtype'} && $rule->{'itemtype'} eq '*' ){
                
        $template->param(
            maxissueqty_all         => $rule->{'maxissueqty'},
            reservesallowed_all     => $rule->{'reservesallowed'},
            maxinstantstackqty_all  => $rule->{'maxinstantstackqty'},
            maxdelayedstackqty_all  => $rule->{'maxdelayedstackqty'},
            maxstackqty_all         => $rule->{'maxstackqty'},
        );
        
    } else {
        
        my $itemtype = getitemtypeinfo($rule->{'itemtype'});
        $rule->{'itemtype_ui'} = $itemtype->{'description'};
        push @quotas_loop, $rule;
    }
}

#output data    
$template->param( BORROWER_INFO => [ $borrower ],
                  QUOTAS        => \@quotas_loop,
                  userquotas    => 1
            );

output_html_with_http_headers $query, $cookie, $template->output;
