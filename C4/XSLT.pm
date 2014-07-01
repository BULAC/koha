package C4::XSLT;
# Copyright (C) 2006 LibLime
# <jmf at liblime dot com>
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

use C4::Context;
use C4::Branch;
use C4::Utils::Constants; # MAN340
use C4::Items;
use C4::Koha;
use C4::Biblio;
use C4::Circulation;
use C4::Reserves;
use C4::AuthoritiesMarc; # PROGILONE - sept 2010 - C2
use C4::Output qw//;
use Encode;
use XML::LibXML;
use XML::LibXSLT;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    require Exporter;
    $VERSION = 0.03;
    @ISA = qw(Exporter);
    @EXPORT = qw(
        &XSLTParse4Display
    );
}

=head1 NAME

C4::XSLT - Functions for displaying XSLT-generated content

=head1 FUNCTIONS

=head2 transformMARCXML4XSLT

Replaces codes with authorized values in a MARC::Record object

=cut

sub transformMARCXML4XSLT {
    my ($biblionumber, $record) = @_;
    my $frameworkcode = GetFrameworkCode($biblionumber);
    my $tagslib = &GetMarcStructure(1,$frameworkcode);
    my @fields;
    # FIXME: wish there was a better way to handle exceptions
    eval {
        @fields = $record->fields();
    };
    if ($@) { warn "PROBLEM WITH RECORD"; next; }
    my $av = getAuthorisedValues4MARCSubfields($frameworkcode);
    foreach my $tag ( keys %$av ) {
        foreach my $field ( $record->field( $tag ) ) {
            if ( $av->{ $tag } ) {
                my @new_subfields = ();
                for my $subfield ( $field->subfields() ) {
                    my ( $letter, $value ) = @$subfield;
                    $value = GetAuthorisedValueDesc( $tag, $letter, $value, '', $tagslib )
                        if $av->{ $tag }->{ $letter };
                    push( @new_subfields, $letter, $value );
                } 
                $field ->replace_with( MARC::Field->new(
                    $tag,
                    $field->indicator(1),
                    $field->indicator(2),
                    @new_subfields
                ) );
            }
        }
    }
    return $record;
}

=head2 getAuthorisedValues4MARCSubfields

Returns a ref of hash of ref of hash for tag -> letter controled by authorised values

=cut

# Cache for tagfield-tagsubfield to decode per framework.
# Should be preferably be placed in Koha-core...
my %authval_per_framework;

sub getAuthorisedValues4MARCSubfields {
    my ($frameworkcode) = @_;
    unless ( $authval_per_framework{ $frameworkcode } ) {
        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare("SELECT DISTINCT tagfield, tagsubfield
                                 FROM marc_subfield_structure
                                 WHERE authorised_value IS NOT NULL
                                   AND authorised_value!=''
                                   AND frameworkcode=?");
        $sth->execute( $frameworkcode );
        my $av = { };
        while ( my ( $tag, $letter ) = $sth->fetchrow() ) {
            $av->{ $tag }->{ $letter } = 1;
        }
        $authval_per_framework{ $frameworkcode } = $av;
    }
    return $authval_per_framework{ $frameworkcode };
}

my $stylesheet;

sub XSLTParse4Display {
    my ( $biblionumber, $orig_record, $xsl_suffix, $interface ) = @_;
    $interface = 'opac' unless $interface;
    # grab the XML, run it through our stylesheet, push it out to the browser
    my $record = transformMARCXML4XSLT($biblionumber, $orig_record);
    #return $record->as_formatted();
    my $itemsxml  = buildKohaItemsNamespace($biblionumber);
    my $xmlrecord = $record->as_xml(C4::Context->preference('marcflavour'));
    my $sysxml = "<sysprefs>\n";
    # PROGILONE - may 2010 - F21    
    foreach my $syspref ( qw/OPACURLOpenInNewWindow DisplayOPACiconsXSLT URLLinkText OPACBranchTooltipDisplay viewISBD OPACBaseURL/ ) {
        $sysxml .= "<syspref name=\"$syspref\">" .
                   C4::Context->preference( $syspref ) .
                   "</syspref>\n";
    }
    $sysxml .= "</sysprefs>\n";

    # PROGILONE - sept 2010 - C2
    # add authorities
    my $authxml = "<authorities>\n";
    
    foreach my $authfield ( $record->field("6.."), $record->field("7..") ) {
        foreach my $authid ( $authfield->subfield('9') ) {
            my $authrecord = GetAuthority($authid);
            if ($authrecord) {
                my $authtypecode = GetAuthTypeCode($authid);
                my $auth = BuildSummary($authrecord, $authid, $authtypecode);
                
                # delete existing html
                $auth =~ s/\<[^\>]*\>/ /g;
                
                #replace non authorized characters                
                $auth =~ s/\&/\&amp\;/g;
                $auth =~ s/\</\&lt\;/g;
                $auth =~ s/\>/\&gt\;/g;
                $auth =~ s/\'/\&apos\;/g;
                $auth =~ s/\"/\&quot\;/g;
        
                $authxml .= "<authority an=\"$authid\">$auth</authority>\n";
            }
        }
    }
    $authxml .= "</authorities>\n";
    # End PROGILONE

    $xmlrecord =~ s/\<\/record\>/$itemsxml$sysxml$authxml\<\/record\>/;
    $xmlrecord =~ s/\& /\&amp\; /;
    $xmlrecord =~ s/\&amp\;amp\; /\&amp\; /;

    my $parser = XML::LibXML->new();
    # don't die when you find &, >, etc
    $parser->recover_silently(0);
    my $source = $parser->parse_string($xmlrecord);
    unless ( $stylesheet ) {
        my $xslt = XML::LibXSLT->new();
        my $xslfile;
        if ($interface eq 'intranet') {
            $xslfile = C4::Context->config('intrahtdocs') . 
                      '/' . C4::Context->preference("template") . 
                      '/' . C4::Output::_current_language() .
                      '/xslt/' .
                      C4::Context->preference('marcflavour') .
                      "slim2intranet$xsl_suffix.xsl";
        } else {
            $xslfile = C4::Context->config('opachtdocs') . 
                      '/' . C4::Context->preference("opacthemes") . 
                      '/' . C4::Output::_current_language() .
                      '/xslt/' .
                      C4::Context->preference('marcflavour') .
                      "slim2OPAC$xsl_suffix.xsl";
        }
        my $style_doc = $parser->parse_file($xslfile);
        $stylesheet = $xslt->parse_stylesheet($style_doc);
    }
    my $results = $stylesheet->transform($source);
    my $newxmlrecord = $stylesheet->output_string($results);
    return $newxmlrecord;
}

sub buildKohaItemsNamespace {
    my ($biblionumber) = @_;
    my @items = C4::Items::GetItemsInfo($biblionumber);
    my $branches = GetBranches();
    my $xml = '';
    for my $item (@items) {
        
        my $status;
        my ( $transfertwhen, $transfertfrom, $transfertto ) = C4::Circulation::GetTransfers($item->{itemnumber});
	    my ( $reservestatus, $reserveitem ) = C4::Reserves::CheckReserves($item->{itemnumber});
        
        # MAN340
        if ( ($item->{notforloan_per_itemtype} && $item->{itemnotforloan} eq $AV_ETAT_LOAN) || 
             ( $item->{itemnotforloan} ne $AV_ETAT_LOAN && 
               $item->{itemnotforloan} ne $AV_ETAT_GENERIC && 
               $item->{itemnotforloan} ne $AV_ETAT_STACK) || 
             $item->{istate} || 
             $item->{wthdrawn} || $item->{itemlost} || $item->{damaged} || 
             (defined $transfertwhen && $transfertwhen ne '') ||  
             (defined $reservestatus && $reservestatus eq "Waiting") ){ 
            
            if ( $item->{wthdrawn}) {
                $status = "Withdrawn";
            }
            elsif ($item->{itemlost}) {
                $status = "Lost";
            }
            elsif ($item->{damaged}) {
                $status = "Damaged"; 
            }
            elsif (defined $transfertwhen && $transfertwhen ne '') {
                $status = 'In transit';
            }
            elsif (defined $reservestatus && $reservestatus eq "Waiting") {
                $status = 'Waiting';
            }
            elsif ( $item->{notforloan} < 0) {
                $status = "On order";
            } 
            elsif (( $item->{notforloan_per_itemtype} && $item->{itemnotforloan} eq $AV_ETAT_LOAN ) || 
                   ( $item->{itemnotforloan} ne $AV_ETAT_LOAN && 
                     $item->{itemnotforloan} ne $AV_ETAT_GENERIC && 
                     $item->{itemnotforloan} ne $AV_ETAT_STACK ) || 
                   $item->{istate}) {
                $status = "unavailable";
            }
        } else {
            $status = "available";
        }
        # END MAN 340

        # PROGILONE - avril 2010 - F21
        $xml .= "<item>";

        my $branch_infos = $branches->{$item->{holdingbranch}}; # like biblio details normal view
        $xml .= "<homebranch>".$branch_infos->{'branchname'}."</homebranch>";

        foreach my $branch_info ( qw/branchaddress1 branchaddress2 branchaddress3 branchzip branchcity branchcountry branchphone branchnotes/ ) {
                $xml .= '<'.$branch_info.'>'.$branch_infos->{$branch_info}.'</'.$branch_info.'>';
        }
        # End PROGILONE

		$xml .= "<status>".$status."</status>";

        my $itemcallnumber = $item->{itemcallnumber} || '';
        $itemcallnumber =~ s/\&/\&amp\;/g;
        $itemcallnumber =~ s/\</\&lt\;/g;
        $itemcallnumber =~ s/\>/\&gt\;/g;
        $itemcallnumber =~ s/\'/\&apos\;/g;
        $itemcallnumber =~ s/\"/\&quot\;/g;
		
		$xml .= "<itemcallnumber>".$itemcallnumber."</itemcallnumber>";
        $xml .=  "</item>";

    }
    $xml = "<items xmlns=\"http://www.koha.org/items\">".$xml."</items>";
    return $xml;
}



1;
__END__

=head1 NOTES

=cut

=head1 AUTHOR

Joshua Ferraro <jmf@liblime.com>

=cut
