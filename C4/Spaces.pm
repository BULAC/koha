package C4::Spaces;

use Modern::Perl;
use C4::Context;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $DEBUG);

BEGIN {
    require Exporter;
    @ISA       = qw(Exporter);
    @EXPORT_OK = qw(
&GetBorrowerSpaces
&GetBorrowerInvitations
    );
    %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

    $DEBUG = 0;
}


sub GetBorrowerSpaces {
    my $borrower_number = shift;
    my $query = "SELECT id_borrower, space_type.name, space_type.name as type, space.name, start_date, end_date
                 FROM espacesprod.booking
                 JOIN espacesprod.space ON booking.id_space = space.id_space
                 JOIN espacesprod.space_type ON space.id_space_type = space_type.id_space_type
                 WHERE id_borrower = ?
                 ORDER BY start_date";
    my $dbh   = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute($borrower_number);
    my $retaref = [];
    while (my $row = $sth->fetchrow_hashref()) {
	push @$retaref, $row
    }
    return $retaref;
}

sub GetBorrowerInvitations {
    my $borrower_number = shift;
    my $query = "SELECT id_borrower, space_type.name, space_type.name as type, space.name, start_date, end_date
                 FROM espacesprod.booking
                 JOIN espacesprod.space ON booking.id_space = space.id_space
                 JOIN espacesprod.space_type ON space.id_space_type = space_type.id_space_type
                 JOIN espacesprod.invitation ON invitation.id_booking = booking.id_booking
                 WHERE invitation.id_borrower = ?
                 ORDER BY start_date";
    my $dbh   = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute($borrower_number);
    my $retaref = [];
    while (my $row = $sth->fetchrow_hashref()) {
	push @$retaref, $row
    }
    return $retaref;
}


1;
