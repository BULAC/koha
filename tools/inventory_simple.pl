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
use C4::Biblio;
use C4::Items;
use C4::Inventory::InventoryItems;
use C4::Dates qw/format_date format_date_in_iso/;
use C4::Koha;
use C4::Branch; # GetBranches
use C4::Circulation;
use C4::Stack::Search;

my $input = new CGI;

# les critères de sélection
my $uploadbarcodes = $input->param('uploadbarcodes');

# validation, filtre, pagination
my $op = $input->param('op');
my $filter = $input->param('filter');
my $filteronly = $input->param('filteronly');

my $pagesize = $input->param('pagesize');
$pagesize=50 unless $pagesize;
my $offset = $input->param('offset');
$offset=0 unless $offset;
if ($filteronly) { # si on a filtré on repart du début de la liste
    $offset=0;
}

# les critères de comparaison
my $callnumber_type = $input->param( 'callnumber_type' ) || 'store_callnumber'; 
my $callnumber_prefix = $input->param( 'callnumber_prefix' ) || '';
my $callnumber_min = $input->param( 'callnumber_min' ) || '';
my $callnumber_max = $input->param( 'callnumber_max' ) || '';

my $locationcomparison = $input->param('locationcomparison');
my $branchcodecomparison = $input->param('branchcodecomparison');

# les critères de filtre
my $noproblem = $input->param('noproblem');
my $manquant = $input->param('manquant');
my $nonrecole = $input->param('nonrecole');
my $mauvaiselocalisation = $input->param('mauvaiselocalisation');
my $enpret = $input->param('enpret');
my $CBinexistant = $input->param('CBinexistant');

#contains the results loop
my $res;    
# warn "uploadbarcodes : ".$uploadbarcodes;
# use Data::Dumper; warn Dumper($input);

my ($template, $borrowernumber, $cookie) = get_template_and_user({
    template_name   => "tools/inventory_simple.tmpl",
    query           => $input,
    type            => "intranet",
    authnotrequired => 0,
    flagsrequired   => {tools => 'inventory'},
    debug           => 1,
});

# make branch selection options...
my $branch_loop = GetBranchesLoop($branchcodecomparison);

# make location selection options...
my @authorised_value_list;
my $authorisedvalue_categories;
my $data = GetAuthorisedValues("LOC");
foreach my $value (@$data){
    $value->{selected}=1 if ($value->{authorised_value} eq ($locationcomparison));
}      
push @authorised_value_list,@$data;

$template->param(branchloop => $branch_loop,
                authorised_values=>\@authorised_value_list,   
                DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
                dateformat => C4::Context->preference("dateformat"),
                today => C4::Dates->today(),
                callnumber_prefix => $callnumber_prefix,
                callnumber_min => $callnumber_min,
                callnumber_max => $callnumber_max,
                locationcomparison=>$locationcomparison,
                branchcodecomparison=>$branchcodecomparison,
                offset => $offset,
                pagesize => $pagesize,
                noproblem => $noproblem,
                manquant => $manquant,
                nonrecole => $nonrecole,
                mauvaiselocalisation => $mauvaiselocalisation,
                enpret => $enpret,
                CBinexistant => $CBinexistant,
                filter => $filter,
                op => $op
                );
my @brcditems;
my $qwthdrawn;
my $qonloan;
my $date;
my $count=0;

if (!$uploadbarcodes && $op){
    my $errorsaisie='1';
    $template->param(errorsaisie=>$errorsaisie) if ($errorsaisie);
    
} elsif ( !$callnumber_prefix && $op ) {
    my $errorcomparison='1';
    $template->param(errorcomparison=>$errorcomparison) if ($errorcomparison);
    
} else {
    
    my $dbh=C4::Context->dbh;
    $date = format_date_in_iso(C4::Dates->today());
#   warn "$date";
    my $strsth='
        SELECT * FROM issues, items
        WHERE items.itemnumber=issues.itemnumber
        AND items.barcode =?
    ';
    $qonloan = $dbh->prepare($strsth);
    
    $strsth='
        SELECT * FROM items 
        WHERE items.barcode =?
        AND items.wthdrawn = 1
    ';
    $qwthdrawn = $dbh->prepare($strsth);
    
    my @barcodeloop;
    # premier passage 
    if ($uploadbarcodes && length($uploadbarcodes)>0) {
        while (my $temp=<$uploadbarcodes>){
            $temp =~ s/\r?\n$//;
            my $barcodeupload->{barcodeitem} = $temp;
            push @barcodeloop,$barcodeupload;
        }
        
    # deuxième passage (application du filtre ou pagination)
    } else {
        my @barcodelooptemp = $input->param('barcodeitem');
        foreach my $temp(@barcodelooptemp){
            my $barcodeupload->{barcodeitem} = $temp;
            push @barcodeloop,$barcodeupload;
        }
    }
    
    # récupération des données
    my $restemp;
    my @barcoderecole;
    foreach my $barcode (@barcodeloop){
        ($restemp) = _barcode_loop($barcode->{barcodeitem},$restemp);
        push @barcoderecole,$barcode->{barcodeitem};
    }
    
    # cas des exemplaires non présents dans le fichier 
    my $resrecole = GetItemsByCriteriaLocation($branchcodecomparison, $locationcomparison, $callnumber_prefix, $callnumber_min, $callnumber_max, $callnumber_type);
    my $barcodecomp;
    foreach (@$resrecole){
        $barcodecomp = $_->{barcode};
        unless ($barcodecomp ~~ @barcoderecole) {
            if (!$filter || $nonrecole){
               $_->{ERR_STOCKTAKING} = '1';
               push @$restemp, $_;
            }
        }
    }
    
    # export csv
    _export_csv($input,$restemp);
        
    # pagination
    my $size = $pagesize;
    my $offsettemp = $offset;
    foreach my $re (@$restemp){
        if ( ( !$offsettemp && $size )) {
            push @$res, $re;
            $size--;
        }
        $offsettemp-- if ($offsettemp);
    }

    $qonloan->finish;
    $qwthdrawn->finish;
    
    my $result = $op || $filter;
    
    $template->param(barcodeloop=>\@barcodeloop,
                     nextoffset => ((($offset+$pagesize) < scalar @$restemp)?$offset+$pagesize:0),
                     prevoffset => ($offset?$offset-$pagesize:0),
                     result => $result,
                     loop =>$res,
                     date=>format_date($date),
                     Number=>$count);
}

output_html_with_http_headers $input, $cookie, $template->output;

sub _export_csv {
    my ($input,$resexport) = @_;
    
    if ($input->param('CSVexport') eq 'on'){
        
        #eval {use Text::CSV};
        eval {use Text::CSV::Encoded};
        my $csv = Text::CSV::Encoded->new() or die Text::CSV::Encoded->error_diag ();
        print $input->header(
            -type       => 'text/csv',
            -attachment => 'inventory.csv',
        );

        # caracters 
        my $csvseparator = $input->param('csv_separator');
        if ($csvseparator eq '\t') { $csvseparator = "\t" }
        
        my $endline = $input->param('end_line');
        if ($endline eq '\n') { $endline = "\n" }        
        if ($endline eq '\t') { $endline = "\t" }
        
        my $dataprotection = $input->param('data_protection');

        $csv->sep_char($csvseparator);
        $csv->eol($endline);
        $csv->quote_char($dataprotection);
        $csv = $csv->encoding_out( 'utf8' );

        # header        
        my @header = ( 'barcode','itemcallnumber','title','author','publicationyear','datelastseen','holdingbranch','location','problems' );
        $csv->combine(@header);
        my $string = $csv->string;
        print $string;
        
        # lines
        for my $re (@$resexport){
            my @line;
            push @line, $re->{'barcode'};
            push @line, $re->{'itemcallnumber'};
            push @line, $re->{'title'};
            push @line, $re->{'author'};
            push @line, $re->{'publicationyear'};
            push @line, $re->{'datelastseen'};
            push @line, $re->{'holdingbranch'};
            push @line, $re->{'location'};
            if ($re->{'ERR_WTHDRAWN'}) {
               push @line, 'Retiré de la circulation';
            }
            if ($re->{'ERR_ONLOAN'}) {
               push @line, 'En prêt';
            }
            if ($re->{'ERR_COMM'}) {
               push @line, 'En demande de communication';
            }
            if ($re->{'ERR_BARCODE'}) {
               push @line, 'Barre code inexistant';
            }
            if ($re->{'ERR_BRANCH'}) {
               push @line, 'Mauvaise localisation (Branch)';
            }
            if ($re->{'ERR_LOCATION'}) {
               push @line, 'Mauvaix niveau de localisation';
            }
            if ($re->{'ERR_CALLNUMBER'}) {
               push @line, 'Mauvaise localisation (cote)';
            }
            if ($re->{'ERR_STOCKTAKING'}) {
               push @line, 'Non recolé';
            }
            $csv->combine(@line);
            print $csv->string;
        }
        exit;
    }
}

sub _barcode_loop {
    my ($barcode, $res) = @_;

    my $item = GetItemInfoForInventory($barcode);
    $item->{barcode} = $barcode;
    
    $callnumber_prefix =~ s/[\s\.-]//g;
    $callnumber_min = int( $callnumber_min || 0 );
	$callnumber_max = int( $callnumber_max || 999999 );
	
    if (defined $item && $item->{'itemnumber'}){
        
        if ($qwthdrawn->execute($barcode) && $qwthdrawn->rows) {
            if (!$filter || $manquant){
                $item->{ERR_WTHDRAWN} = '1';
                push @$res, $item;
            }
            
        } elsif ($qonloan->execute($barcode) && $qonloan->rows){
            if (!$filter || $enpret){
                $item->{ERR_ONLOAN} = '1';
                push @$res, $item;
            }
            
        } elsif (GetCurrentStackByItemnumber($item->{'itemnumber'})){
            if (!$filter || $enpret){
                $item->{ERR_COMM} = '1';
                push @$res, $item;
            }
            
        } elsif (!($item->{holdingbranch} eq $branchcodecomparison)){
            if (!$filter || $mauvaiselocalisation){
                $item->{ERR_BRANCH} = '1';
                push @$res, $item;
            }
            
        } elsif (!($item->{location} eq $locationcomparison)){
            if (!$filter || $mauvaiselocalisation){
                $item->{ERR_LOCATION} = '1';
                push @$res, $item;
            }
            
        } elsif ( $callnumber_type eq 'store_callnumber' ) {
        	my ( $base, $sequence, $rest ) =  C4::Callnumber::StoreCallnumber::GetBaseAndSequenceFromStoreCallnumber( $item->{itemcallnumber}, 0 );
        	if ( $base =~ m/^$callnumber_prefix/ && $sequence >= $callnumber_min && $sequence <= $callnumber_max ) {
			    if (!$filter || $mauvaiselocalisation) {
	                $item->{ERR_CALLNUMBER} = '1';
	                push @$res, $item;
	            }
        	}
		} elsif ( $callnumber_type ne 'store_callnumber' ) { 
			my ( $base, $sequence ) =  C4::Callnumber::FreeAccessCallnumber::GetBaseAndSequenceFromFreeAccessCallnumber( $item->{itemcallnumber} );
			if ( $base eq $callnumber_prefix && C4::Callnumber::FreeAccessCallnumber::IsSequenceBetweenMinMax( $sequence, $callnumber_min, $callnumber_max ) ) {
	            if (!$filter || $mauvaiselocalisation){
	                $item->{ERR_CALLNUMBER} = '1';
	                push @$res, $item;
	            }				
			}
        } else {
            if (!$filter || $noproblem){
                ModItem({ datelastseen => $date, datelast_stocktaking => $date}, undef, $item->{'itemnumber'});
                $item->{datelastseen}=format_date($date);
                $count++;
                push @$res, $item;
            }
        }
        
    } else {
        if (!$filter || $CBinexistant){
           $item->{ERR_BARCODE} = '1';
           push @$res, $item;
        }
    }
    
    return ($res);
}