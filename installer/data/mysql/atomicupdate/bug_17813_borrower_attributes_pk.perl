$DBversion = "16.12.00.XXX";
if ( CheckVersion($DBversion) ) {
    unless (     column_exists( 'borrower_attributes', 'id' )
             and index_exists( 'borrower_attributes', 'PRIMARY' ) )
    {
        $dbh->do(q{
            ALTER TABLE `borrower_attributes`
                ADD `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST
        });
    }

    print "Upgrade to $DBversion done (Bug 17813: Table borrower_attributes needs a primary key\n";
    SetVersion($DBversion);
}