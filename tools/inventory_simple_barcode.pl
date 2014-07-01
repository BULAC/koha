#!/usr/bin/perl

#
# B12 : Inventory
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
use C4::Output;
use C4::Items;
use C4::Dates qw/format_date format_date_in_iso/;
use C4::Koha;
use C4::Circulation;

my $input = new CGI;

# les critères de sélection
my $itembarcode = $input->param('itembarcode');
my $op = $input->param('op');

my ($template, $borrowernumber, $cookie) = get_template_and_user({
    template_name   => "tools/inventory_simple_barcode.tmpl",
    query           => $input,
    type            => "intranet",
    authnotrequired => 0,
    flagsrequired   => {tools => 'inventory'},
    debug           => 1,
});
                
$template->param(today => C4::Dates->today(),
                 DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar());
                
my @brcditems;
if (!$itembarcode && $op){
    my @errorsaisie='1';
    $template->param(errorsaisie=>\@errorsaisie) if (@errorsaisie);
    
} else {
    
    my $dbh=C4::Context->dbh;
    my $date = format_date_in_iso(C4::Dates->today());
#   warn "$date";
    my $strsth='
        SELECT * FROM issues, items
        WHERE items.itemnumber=issues.itemnumber
        AND items.barcode =?
    ';
    my $qonloan = $dbh->prepare($strsth);
    $strsth='
        SELECT * FROM items
        WHERE items.barcode =?
        AND items.wthdrawn = 1
    ';
    my $qwthdrawn = $dbh->prepare($strsth);
    my @errorloop;
    my $count=0;
    
    if ($itembarcode && length($itembarcode)>0) {
        ($count,@errorloop) = _barcode_loop($date,$qonloan,$qwthdrawn,$count,$itembarcode,@errorloop);
    }
        
    $qonloan->finish;
    $qwthdrawn->finish;
    $template->param(date=>format_date($date),Number=>$count);
    #$template->param(errorfile=>$errorfile) if ($errorfile);
    $template->param(errorloop=>\@errorloop) if (@errorloop);
}

output_html_with_http_headers $input, $cookie, $template->output;

sub _barcode_loop {
    my ($date,$qonloan,$qwthdrawn,$count,$barcode,@errorloop) = @_;
    
    if ($qwthdrawn->execute($barcode) &&$qwthdrawn->rows){
        push @errorloop, {'barcode'=>$barcode,'ERR_WTHDRAWN'=>1};
    }else{
        my $item = GetItem('', $barcode);
        if (defined $item && $item->{'itemnumber'}){
            ModItem({ datelastseen => $date, datelast_stocktaking => $date}, undef, $item->{'itemnumber'});
            push @brcditems, $item;
            $count++;
            $qonloan->execute($barcode);
            if ($qonloan->rows){
                my $data = $qonloan->fetchrow_hashref;
                my ($doreturn, $messages, $iteminformation, $borrower) =AddReturn($barcode, $data->{homebranch});
                if ($doreturn){
                    push @errorloop, {'barcode'=>$barcode,'ERR_ONLOAN_RET'=>1}
                } else {
                    push @errorloop, {'barcode'=>$barcode,'ERR_ONLOAN_NOT_RET'=>1}
                }
            }
        } else {
            push @errorloop, {'barcode'=>$barcode,'ERR_BARCODE'=>1};
        }
    }
    return ($count,@errorloop);
}