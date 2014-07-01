#!/usr/bin/perl
# small script that builds the tag cloud

use strict;
#use warnings; FIXME - Bug 2505
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Koha;
use C4::Context;
use C4::Biblio;
use Date::Calc;
use Time::HiRes qw(gettimeofday);
use ZOOM;
use MARC::File::USMARC;
use Getopt::Long;
my ( $input_marc_file, $number) = ('',0);
my ($version, $confirm,$test_parameter,$field,$batch,$max_digits,$cloud_tag);
GetOptions(
	'c' => \$confirm,
	'h' => \$version,
	'f:s' => \$field,
	'b' =>\$batch,
	'm:s' => \$max_digits,
	't:s' => \$cloud_tag,
);

if ($version || (!$confirm)) {
    print <<EOF
    This script rebuilds the catalogue browser & the tag cloud
    run the script with -c to execute it.
    Parameters :
    -b to run in batch mode, without any output
    -f TTTs to define the MARC tag/subfield to use for building nav (676a in UNIMARC for dewey for example) If not defined, the browser table won't be modified.
    -c to confirm & run the script.
    -m to tell how many digits have to be used for browser (usually : 3, the 1st 3 dewey digits for example)
    -t TTT to define the MARC fields/subfield to use to fill the tag cloud. If not defined, the cloud table won't be filled.
     
     example :
     export PERL5LIB=/path/to/koha;export KOHA_CONF=/etc/koha/koha-conf.xml;./build_browser_and_cloud.pl -b -f 676a -t 606 -c
EOF
;
exit;
}

##################################
#
# MAIN PARAMETERS
#
###################################

$max_digits=3 unless $max_digits;
$field =~ /(\d\d\d)(.?)/;
my $browser_tag = $1;
my $browser_subfield = $2;
warn "browser : $browser_tag / $browser_subfield" unless $batch;
die "no cloud or browser field/subfield defined : nothing to do !" unless $browser_tag or $cloud_tag;

my $dbh = C4::Context->dbh;

my $i=0;
$|=1; # flushes output
my $starttime = gettimeofday;

##################################
#
# Parse all the database.
#
###################################
#FIXME : could be improved to get directly only biblios that have to be updated.

my $sth = $dbh->prepare("select biblionumber from biblioitems");
$sth->execute;
# the result hash for the browser table
my %browser_result;

# the result hash for the cloud table
my %cloud_result;

while ((my ($biblionumber)= $sth->fetchrow)) {
    $i++;
    print "." unless $batch;
    #now, parse the record, extract the item fields, and store them in somewhere else.
    my $Koharecord;
    eval{
	    $Koharecord = GetMarcBiblio($biblionumber);
    };
    if($@){
	    warn 'pb when getting biblio '.$i.' : '.$@;
	    next;
    }
    # deal with BROWSER part
    if ($browser_tag && $Koharecord) { 
        foreach my $browsed_field ($Koharecord->subfield($browser_tag,$browser_subfield)) {
            $browsed_field =~ s/\.//g;
            my $upto = length($browsed_field)<=$max_digits?length($browsed_field):$max_digits;
            for (my $i=1;$i <= $upto;$i++) {
                $browser_result{substr($browsed_field,0,$i)}->{value}++;
                $browser_result{substr($browsed_field,0,$i)}->{endnode}=1;
            }
        }
    }
    #deal with CLOUD part
    if ($cloud_tag && $Koharecord) {
        if($Koharecord->field($cloud_tag)){
            foreach ($Koharecord->field($cloud_tag)) {
                my $line;
                foreach ($_->subfields()) {
                    next if $_->[0]=~ /\d/;
                    $line .= $_->[1].' ';
                }
                $line =~ s/ $//;
                $line =~ s/;//g;
                $cloud_result{$line}++;
            }
        }else{
            print "!" unless $batch;
        }
    }

    my $timeneeded = gettimeofday - $starttime;
    print "$i in $timeneeded s\n" unless ($i % 50  or $batch);
}

# fills the browser table
if ($browser_tag) {
    print "inserting datas in browser table\n" unless $batch;
    # read existing classification table is possible
    my $classification;
    if (C4::Context->preference('opaclanguages') =~ m/fr/i && $browser_tag eq '686' & $browser_subfield eq 'a') {
        $classification = bulac_domaine();
    }

    foreach (keys %browser_result) {
        my $father = substr($_,0,-1);
        $browser_result{$father}->{notendnode}=1;
    }
    $dbh->do("truncate browser");
    my $sth = $dbh->prepare("insert into browser (level,classification,description,number,endnode) values (?,?,?,?,?)");
    foreach (keys %browser_result) {
        $sth->execute(length($_),$_,$classification->{$_}?$classification->{$_}:"classification $_",$browser_result{$_}->{value},$browser_result{$_}->{notendnode}?0:1) if $browser_result{$_}->{value};
    }
}

# fills the cloud (tags) table
my $sthver = $dbh->prepare("SELECT weight FROM tags WHERE entry = ? ");
my $sthins = $dbh->prepare("insert into tags (entry,weight) values (?,?)");
my $sthup  = $dbh->prepare("UPDATE tags SET weight = ? WHERE entry = ?");
if ($cloud_tag) {
    $dbh->do("truncate tags");
    foreach my $key (keys %cloud_result) {
        $sthver->execute($key);
        if(my $row = $sthver->fetchrow_hashref){
            my $count = $row->{weight} + $cloud_result{$key};
            $sthup->execute($count, $key);
        }else{
            $sthins->execute($key,$cloud_result{$key});
        }
    }
}
# $dbh->do("unlock tables");
my $timeneeded = time() - $starttime;
print "$i records done in $timeneeded seconds\n" unless $batch;


sub bulac_domaine {
return {
   "0" => "DOMAINE TRANSVERSE",
   "1" => "AFRIQUE",
   "2" => "MOYEN-ORIENT, MAGHREB et ASIE CENTRALE",
   "3" => "HAUTE ASIE et ASIE DU SUD",
   "4" => "ASIE DU SUD-EST, PACIFIQUE et OCEANIE", 
   "5" => "ASIE ORIENTALE", 
   "6" => "CEI, CAUCASE",  
   "7" => "EUROPE CENTRALE",   
   "8" => "EUROPE BALKANIQUE",
   "9" => "AMERIQUE",  
   "00" => "DOMAINE TRANSVERSE",
   "01" => "ASIE",
   "02" => "EUROPE",
   "10" => "AFRIQUE : généralités",
   "11" => "AFRIQUE nord-orientale",
   "12" => "AFRIQUE de l'Océan Indien",
   "13" => "AFRIQUE occidentale",
   "14" => "AFRIQUE centrale et centre-orientale",
   "15" => "AFRIQUE australe",
   "20" => "MOYEN-ORIENT, MAGHREB et ASIE CENTRALE : généralités",
   "21" => "ARABE",
   "22" => "HEBREU et langues hébraïques (yiddish, judéo-arabe, araméen)",
   "23" => "PERSAN",
   "24" => "KURDE",
   "25" => "AFGHANISTAN",
   "26" => "TURQUIE",
   "27" => "ASIE CENTRALE",
   "28" => "EGYPTOLOGIE",
   "29" => "BERBERE",
   "30" => "HAUTE ASIE et ASIE DU SUD  : généralités",
   "31" => "SRI LANKA",
   "32" => "BENGLADESH",
   "33" => "INDE",
   "35" => "MALDIVES",
   "36" => "TZIGANES",
   "37" => "PAKISTAN",
   "38" => "NEPAL",
   "39" => "TIBET, BHOUTAN, LADDAKH",
   "40" => "ASIE DU SUD-EST , PACIFIQUE et OCEANIE : généralités",
   "41" => "BIRMANIE",
   "42" => "CAMBODGE",
   "43" => "INDONESIE",
   "44" => "LAOS",
   "45" => "MALAISIE",
   "46" => "THAILANDE",
   "47" => "PHILIPPINES",
   "48" => "VIETNAM",
   "49" => "PACIFIQUE et OCEANIE",
   "50" => "ASIE ORIENTALE : généralités",
   "51" => "CHINE",
   "52" => "COREE",
   "53" => "JAPON",
   "59" => "MONGOLIE",
   "60" => "CEI, CAUCASE : généralités",
   "61" => "RUSSE",
   "63" => "BIELORUSSIE",
   "64" => "UKRAINE",
   "65" => "GEORGIE",
   "66" => "ARMENIE",
   "69" => "SIBERIE",
   "70" => "EUROPE CENTRALE : généralités",
   "71" => "POLOGNE",
   "72" => "TCHEQUE (REP), SLOVAQUIE",
   "73" => "SORABE",
   "74" => "HONGRIE",
   "75" => "ROUMANIE",
   "76" => "LETTONIE, LITHUANIE",
   "77" => "FINLANDE, ESTONIE",
   "80" => "EUROPE BALKANIQUE  : généralités",
   "81" => "ALBANIE",
   "82" => "BULGARIE",
   "83" => "GRECE (moderne)",
   "84" => "YOUGOSLAVE",
   "91" => "AMERIQUE DU NORD, CENTRALE ET DU SUD : généralités",
   "94" => "Civilisations améridiennes, Inuit",
}
;
}
