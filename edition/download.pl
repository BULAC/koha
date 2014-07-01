#!/usr/bin/perl
#
# B11
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
use CGI;
use C4::Auth;
use C4::Context;
use C4::Output;

my $input = new CGI;

my $directory = $input->param( 'directory' ) || '';
my $file = $input->param( 'file' ) || '';

if ( $directory && $file ) {
	my $zipBuffer = open(FH, "<$directory$file");
	binmode(FH);
	my $fileContent = do { local $/; <FH> };
	close(FH);

	print "Content-Type: application/x-zip-compressed\n";
	print "Content-Disposition: attachment; filename=\"$file\"\n";
	print "Content-Length: ".length($fileContent)."\n";
	print "\n";
	
	print $fileContent;
}
