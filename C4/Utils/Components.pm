package C4::Utils::Components;

##
# B03X : Components
##

use strict;

use vars qw($VERSION @ISA @EXPORT);
use C4::Context;
use C4::Utils::Constants;

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &buildCGIcancelStack
    );
}

#
# Build a HTML select with AV_SR_CANCEL authorised values
# without values >= 90, with a first blank value
#
sub buildCGIcancelStack {
    my ($input_name, $input_id, $with_blank, $data, $size) = @_;
    
    my $dbh = C4::Context->dbh;
    my $query = 'SELECT * FROM authorised_values WHERE category=? ORDER BY lib';
    my $sth=$dbh->prepare($query);
    $sth->execute($AV_SR_CANCEL);
    
    my $CGISort;
    if ($sth->rows > 0){
        my @values;
        push @values, '' if ($with_blank);
        my %labels;

        for (my $i = 0 ; $i < $sth->rows ; $i++){
            my $results = $sth->fetchrow_hashref;
            if ( scalar $results->{'authorised_value'} < 90 ){
                push @values, $results->{'authorised_value'};
            }
            $labels{ $results->{'authorised_value'} } = $results->{'lib'};
        }
        $CGISort= CGI::scrolling_list(
                    -name => $input_name,
                    -id =>   $input_id,
                    -values => \@values,
                    -labels => \%labels,
                    -default=> $data,
                    -size => ($size ? $size : 1),
                    -multiple => ($size ? 1 : 0));
    }
    $sth->finish;
    return $CGISort;
}

1;
__END__