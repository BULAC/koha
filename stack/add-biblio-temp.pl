#! /usr/bin/perl

##
# B06 - Temporary items
##

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
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Stack::Manager;
use C4::Stack::Search;
use C4::Stack::StackItemsTemp;
use C4::Utils::Constants;

#
# Build output
#
my $query = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "stack/add-biblio-temp.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
        debug           => 1,
    }
);

#
# input params
#
my $op = $query->param('op');

# The stack request
my $request_number = $query->param('request_number');
my $stack = GetStackById($request_number);
unless ($stack) {
    die 'Stack request not found : '.$request_number;
}

# Set up the item stack ....
my %retrievalitems;
my @inputloop;

foreach ( $query->param ) {
    my $counter;
    if (/retrieval-(\d*)/) {
        $counter = $1;
        if ($counter > 20) {
            next;
        }
    } else {
        next;
    }

    my %input;
    my $stack = $query->param("retrieval-$counter");
    push @inputloop, {counter => $counter, request_number => $stack};
}

# create itemtype Listbox
my $dbh = C4::Context->dbh;
my @itype;
my %labels;
my $itype_sth = $dbh->prepare('SELECT itemtype, description FROM itemtypes ORDER BY itemtype');
$itype_sth->execute();

while ( my ($itemtype, $description) = $itype_sth->fetchrow_array) {
    push(@itype,$itemtype);
    $labels{$itemtype} = $description;
}

my $title = $query->param('title') || '';
my $author = $query->param('author') || '';
my $pubyear = $query->param('publicationyear') || '';

my $unite = $query->param('unite') || '';
my $materials = $query->param('checkboxmaterials') || '';
my $materialsinfo = $query->param('materials') || '';
my $year = $query->param('year') || '';
my $volume = $query->param('volume') || '';
my $number = $query->param('number') || '';
my $itemcallnumber = $query->param('itemcallnumber') || '';
my $address = $query->param('physicaladress') || '';
my $barcode = $query->param('barcode') || '';
my $itemtype = $query->param('selectItype') || '';
my $temporary = $query->param('temporary') || '';

# Listbox of itype
my $CGIitype = CGI::scrolling_list(-name=>'selectItype',
        -id=>'selectItype',
        -values=> \@itype,
        -default=>$itemtype,
        -labels=> \%labels,
        -size=>1,
        -multiple=>0,
);
    
$template->param(
    inputloop => \@inputloop,
    itype     => $CGIitype,
);

if ($op){
	
    if ( GetItemnumberFromBarcode( $barcode ) ) {
        
        $template->param(
            stackrequestnumber => $request_number,
            
		    stacktitre => $title,
		    stackauthor => $author,
		    stackeditionyear => $pubyear,
		    unite => $unite,
		    checkboxmaterials => $materials,
		    materials => $materialsinfo,
		    stackyears => $year,
		    stacknumbers => $volume,
		    number => $number,
		    stackcallnumber => $itemcallnumber,
		    physicaladress => $address,
		    barcode => $barcode,
		    
		    error => 1,
		    BARCODE_ERROR => 1
		);
    } else {
	    #
	    # Add item
	    # and biblio
	    #
	    
	    my $biblioitemnumber;
	    my $itemnumber;
	    my $biblionumber;
	    
	    # create the biblio in catalogue, with framework ''
	    my $biblio;
	    $biblio->{'author'} = $author;
	    $biblio->{'title'} = $title;
	    my $biblioitems;
	    $biblioitems->{'publicationyear'} = $pubyear;
	        
	    my $marcrecord = MARC::Record->new();
	    my ( $tag, $subfield );
	    my $newField;
	    
	    # title
	    ( $tag, $subfield ) = GetMarcFromKohaField( 'biblio.title', '' );
	    $newField = MARC::Field->new( "$tag", '', '', "$subfield" => $biblio->{'title'} );
	    $marcrecord->insert_fields_ordered($newField);
	    
	    # author
	    ( $tag, $subfield ) = GetMarcFromKohaField( 'biblio.author', '' );
	    $newField = MARC::Field->new( "$tag", '', '', "$subfield" => $biblio->{'author'} );
	    $marcrecord->insert_fields_ordered($newField);
	    
	    # publicationyear
	    ( $tag, $subfield ) = GetMarcFromKohaField( 'biblioitems.publicationyear', '' );
	    $newField = MARC::Field->new( "$tag", '', '', "$subfield" => $biblioitems->{'publicationyear'} );
	    $marcrecord->insert_fields_ordered($newField);
	    
	    ($biblionumber, $biblioitemnumber) = AddBiblio($marcrecord, '');
	    
	    # create the item in catalogue
	    my $item;
	    $item->{'biblionumber'}     = $biblionumber;
	    $item->{'biblioitemnumber'} = $biblioitemnumber;
	    $item->{'barcode'}          = $query->param('barcode');
	    $item->{'materials'}        = $materialsinfo;
	    $item->{'itemcallnumber'}   = $itemcallnumber;
	    $item->{'itype'}            = $itemtype;
	    
	    # unite + volume + number
	    my $volumeandnumber = 'Volume'.$volume.'Num'.$number;
	    $item->{'enumchron'} = $unite.$volumeandnumber;
	    
	    # get the branch
	    my $branch = C4::Context->userenv->{'branch'};
	    if ($branch && $branch ne 'NO_LIBRARY_SET') {
	        $item->{'holdingbranch'} = $branch;
	    }
	    
	    # Unlinked subfields
	    my $subfields = [];
	    if ($year) {
	        push @$subfields, 'o' => $year; # year
	    }
	    if ($address) {
	        push @$subfields, 'd' => $address; # physicaladress
	    }
	    
	    # item status enables stack circulation
	    $item->{'notforloan'} = $AV_ETAT_STACK; # MAN116
	    
	    # add an item
	    ($biblionumber, $biblioitemnumber, $itemnumber) = AddItem($item, $biblionumber, C4::Context->dbh, GetFrameworkCode( $biblionumber ), $subfields);
	    
	    # retrieval has been made so set item state
	    my $desk_code = C4::Context->userenv->{'desk'};
	    setItemWaitStack($itemnumber, $desk_code);
	    
	    # link with stack_request
	    SetItemNumber($stack->{'request_number'}, $itemnumber);
	    
	    # add a record in stack_items_temp
	    my $stack_items_temp;
	    $stack_items_temp->{'biblionumber'} = $biblionumber;
	    $stack_items_temp->{'itemnumber'} = $itemnumber;
	    $stack_items_temp->{'temporary'} = $temporary;
	    
	    my $error = AddStackItemsTemp($stack_items_temp);
	    
	    unless ( $error ){
	        my $input_redirect = '';
	        foreach ( @inputloop ) {
	            $input_redirect = $input_redirect . '&retrieval-' . $_->{counter} . '=' . $_->{request_number};
	        }
	        
	        # redirect to perform retrieval
	        print $query->redirect('/cgi-bin/koha/stack/stack-retrieval.pl?item_temp=1&op=1&stack_barcode='.$request_number.$input_redirect);
	        exit;
	    }
    }
    
} else {
    

    #
    # Set params to template
    #
    $template->param(
        stacktitre          => $stack->{'nc_title'},
        stackauthor         => $stack->{'nc_author'},
        stackeditionyear    => $stack->{'nc_pubyear'},
        stackcallnumber     => $stack->{'nc_callnumber'},
        
        stackrequestnumber  => $stack->{'request_number'},
        stackyears          => $stack->{'nc_years'},
        stacknumbers        => $stack->{'nc_numbers'},
        stacknotes          => $stack->{'notes'},
        
        
    );
    
}

#
# Print the page
#
output_html_with_http_headers $query, $cookie, $template->output;