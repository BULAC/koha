package C4::Stack::StackItemsTemp;

##
# B06
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use C4::Context;
use C4::Items;
use C4::Biblio;

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &AddStackItemsTemp
        &DelStackItemsTempAndItem
        &DelStackItemsTempOnly
        
        &GetStackItemsTemp
        &IsStackItemsTempTemporary
        &CanDelStackItemsTemp
    );
}

# B06 #
=head2 AddStackItemsTemp

  my ($error) = AddStackItemsTemp( $stack_items_temp );

Perform the actual insert into the C<stack_items_temp> table.

=cut

sub AddStackItemsTemp {
    my ( $stack_items_temp ) = @_;
    my $dbh=C4::Context->dbh;  
    my $error;
    my $query =
           'INSERT INTO stack_items_temp SET
            itemnumber      = ?,
            biblionumber    = ?,
            temporary       = ?
          ';
    my $sth = $dbh->prepare($query);
   $sth->execute(
            $stack_items_temp->{'itemnumber'},
            $stack_items_temp->{'biblionumber'},
            $stack_items_temp->{'temporary'},
    );
    
    if ( defined $sth->errstr ) {
        $error .= "ERROR in AddStackItemsTemp $query".$sth->errstr;
    }
    return ( $error );
}



=head2 DelStackItemsTempAndItem

Delete temporary item information and item itself
DelStackItemsTempAndItem($itemnumber);

This function deletes the item, the biblio (if exists in stack_items_temp) and the stack_items_temp

=cut

sub DelStackItemsTempAndItem {
    my $itemnumber = shift;
    
    my $dbh = C4::Context->dbh;
    my $error;
    
    # get the stack_items_temp
    my $sth = $dbh->prepare('SELECT * FROM stack_items_temp WHERE itemnumber = ?');
    $sth->execute($itemnumber);
    my $stack_items_temp = $sth->fetchrow_hashref();
    
    if ($stack_items_temp->{'itemnumber'}) {
        # delete stack_items_temp
        DelStackItemsTempOnly($stack_items_temp->{'itemnumber'});
        
        # delete item
        my $item = GetItem($stack_items_temp->{'itemnumber'});
        $error = DelItemCheck($dbh, $item->{'biblionumber'}, $item->{'itemnumber'});
        
        # delete biblio
        if ($stack_items_temp->{'biblionumber'}) {
        	$error = DelBiblio($stack_items_temp->{'biblionumber'});
        }
    }
    
    return $error;
}

=head2 DelStackItemsTempOnly

Delete temporary item information
DelStackItemsTempOnly($itemnumber);

This function deletes the stack_items_temp only after cataloging

=cut

sub DelStackItemsTempOnly {
    my $itemnumber = shift;
    my $dbh = C4::Context->dbh;
    
    # delete stack_items_temp
    my $del_sth = $dbh->prepare('DELETE FROM stack_items_temp WHERE itemnumber = ?');
    $del_sth->execute($itemnumber);
    $del_sth->finish;
}

=head2 GetStackItemsTemp

Return temporary item information
The return value is a hashref mapping item column names to values.

=cut

sub GetStackItemsTemp {
    my $dbh     = C4::Context->dbh;
    my $query   = '
        SELECT
            title,
            author,
            barcode,
            itemcallnumber,
            publicationyear,
            temporary,
            items.itemnumber,
            items.biblionumber
        FROM stack_items_temp
            LEFT JOIN items ON (stack_items_temp.itemnumber = items.itemnumber)
            LEFT JOIN biblio ON (items.biblionumber = biblio.biblionumber)
            LEFT JOIN biblioitems ON (items.biblionumber = biblioitems.biblionumber)
        ORDER BY 
            title,author,barcode
    ';
    
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my @results;
    while ( my $row = $sth->fetchrow_hashref ) {
        # use to avoid deletion
        $row->{'allow_delete'} = CanDelStackItemsTemp($row->{'itemnumber'});
        push @results, $row;
    }
    return \@results;
}

=head2 IsStackItemsTempTemporary

Return temporary item nature : temporary or not.
IsStackItemsTempTemporary($itemnumber);

=cut

sub IsStackItemsTempTemporary {
    my $itemnumber = shift;
    my $dbh = C4::Context->dbh;
    
    my $sth = $dbh->prepare('SELECT * FROM stack_items_temp WHERE itemnumber = ?');
    $sth->execute($itemnumber);
    my $row = $sth->fetchrow_hashref;
    if ($row) {
        return $row->{'temporary'};
    }
    return undef;
}

=head2 CanDelStackItemsTemp

Return if temporary item can be deleted
CanDelStackItemsTemp($itemnumber);

=cut

sub CanDelStackItemsTemp {
    my $itemnumber = shift;
    my $dbh = C4::Context->dbh;
    
    # cant delete if linked to a stack request
    my $sth = $dbh->prepare('SELECT COUNT(*) AS nb FROM stack_requests WHERE itemnumber = ?');
    $sth->execute($itemnumber);
    my $row = $sth->fetchrow_hashref;
    if ($row && $row->{'nb'}) {
        return undef;
    }
    return 1;
}

1;
__END__