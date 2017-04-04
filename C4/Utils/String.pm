package C4::Utils::String;

##
# B10X : callnumber utils
##

use strict;

use vars qw($VERSION @ISA @EXPORT);

#
# Declarations
#
BEGIN {

	# TODO set the version for version checking
	$VERSION = 0.01;
	require Exporter;
	@ISA    = qw(Exporter);
	@EXPORT = qw(
	  &TrimStr
	  &NormalizeStr
	  &ToLowercase
	  &ToUppercase
	);
}

sub TrimStr {
	my ($string) = @_;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub NormalizeStr {
	my ($string) = @_;

	$string =~ s/à|ä|â/a/g;
	$string =~ s/À|Ä|Â/A/g;

	$string =~ s/é|è|ë|ê/e/g;
	$string =~ s/É|È|Ë|Ê/E/g;

	$string =~ s/ï|î/i/g;
	$string =~ s/Ï|Î/I/g;

	$string =~ s/ö|ô/o/g;
	$string =~ s/Ö|Ô/o/g;

	$string =~ s/ü|û|ù/u/g;
	$string =~ s/Ü|Û|Ù/U/g;

	$string =~ s/ç/c/g;
	$string =~ s/Ç/C/g;

	return $string;
}

sub ToLowercase {
    my ($string) = @_;

    $string = uc( $string );
    $string =~ tr/ÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ/àâäéèêëîïôöùûüç/;
    
    return $string;
}

sub ToUppercase {
    my ($string) = @_;

    $string = uc( $string );
    $string =~ tr/àâäéèêëîïôöùûüç/ÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ/;

    return $string;
}

1;
__END__
