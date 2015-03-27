#!/usr/bin/perl
#
# Copyright (C) 2015 BULAC
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 17;

BEGIN {
    use_ok('C4::Branch');
    use_ok('C4::Desks');
}

my $deskcode = 'MON BUREAU';
my $deskname = 'mon bureau';
my $deskdescription = "Le beau bureau ici.";
my $branchcode = shift [keys GetBranches];

my $hrdesk = {
	      'deskcode'        => $deskcode,
	      'deskname'        => $deskname,
	      'deskdescription' => $deskdescription,
	      'branchcode'      => $branchcode
	     };

ok(AddDesk($hrdesk) == 1, 'AddDesk creates desk.');
ok(! defined AddDesk($hrdesk)
   , 'AddDesk returns undef when desk already exists');

my $desk = GetDesk($deskcode);
ok (ref($desk) eq 'HASH', 'GetDesk returns hashref.');
ok($desk->{'deskcode'} eq $deskcode, 'GetDesk returns desk code');
ok($desk->{'deskname'} eq $deskname, 'GetDesk returns desk name');
ok($desk->{'deskdescription'} eq $deskdescription, 'GetDesk returns desk description');
ok($desk->{'branchcode'} eq $branchcode, 'GetDesk returns branchcode');
ok(! defined GetDesk('this desk surely not exists'),
   "GetDesk returns undef when desk doesn't exist");

my $modifieddesk = {
		    'deskcode'        => $deskcode,
		    'deskname'        => 'mon joli bureau',
		    'deskdescription' => "Celui dans l'entrée",
		    'branchcode'      => $branchcode
		   };
ok(ModDesk($modifieddesk) == 1, 'ModDesk modifies Desk');
$modifieddesk->{'deskcode'} = 'this desk surely not exists';
ok(ModDesk($modifieddesk) == 0, 'ModDesk returns 0 when deskcode is wrong');

my $desks = GetDesks();
ok(ref($desks) eq 'ARRAY', 'GetDesks returns an array');
ok($desks->[$#{ $desks }] eq $deskcode, 'GetDesks returns desk codes');
ok(! defined GetDesks("this branch sureley doesn't exist"), 'GetDesks returns undef when no desks are found');

ok(DelDesk($deskcode) == 1, 'DelDesk returns 1 when successfuly deleting desk');
ok(DelDesk('this desk surely not exists'),
   "DelDesk returns 0 when no desk were deleted");
