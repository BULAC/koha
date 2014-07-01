package C4::Spaces::Space;

use strict;
use C4::Spaces::Connector;

use vars qw($VERSION @ISA @EXPORT);

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
      &GetSpaceTypesLoop
    );
}

##
# Get space types for templates loop tag (for HTML select)
# optionnal argument is selected space type
##
sub GetSpaceTypesLoop(;$) {
    my $selcode = shift;

    my @spacetype_loop;

    my $spacetypes = GetSpaceTypes();
    foreach (@$spacetypes) {
        push @spacetype_loop, {
            spacetype_id   => $_->{'spacetype_id'},
            spacetype_name => $_->{'spacetype_name'},
            selected       => ( defined $selcode && $selcode eq $_->{'spacetype_id'} ) ? 1 : undef,
        };
    }
    
    return \@spacetype_loop;
}

1;
__END__
