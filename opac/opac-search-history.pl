#!/usr/bin/perl

# Copyright 2009 BibLibre SARL
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

use C4::Auth qw(:DEFAULT get_session);
use CGI;
use Storable qw(freeze thaw);
use C4::Context;
use C4::Output;
use C4::Log;
use C4::Items;
use C4::Debug;
use C4::Dates;
use URI::Escape;
use POSIX qw(strftime);


my $cgi = new CGI;

# PROGILONE - may 2010 - F14
# Get Session
my $session = get_session($cgi->cookie("CGISESSID"));

# Getting the template and auth
my ($template, $loggedinuser, $cookie)
= get_template_and_user({template_name => "opac-search-history.tmpl",
                                query => $cgi,
                                type => "opac",
                                authnotrequired => 1,
                                flagsrequired => {borrowers => 1},
                                debug => 1,
                                });

$template->param(dateformat => C4::Context->preference("dateformat"));

# If the user is not logged in, we deal with the cookie
if (!$loggedinuser) {

    # Deleting search history
    if ($cgi->param('action') && $cgi->param('action') eq 'delete') {
	# Deleting cookie's content 
	my $recentSearchesCookie = $cgi->cookie(
	    -name => 'KohaOpacRecentSearches',
	    -value => freeze([]),
	    -expires => ''
	    );

	# Redirecting to this same url with the cookie in the headers so it's deleted immediately
	my $uri = $cgi->url();
	print $cgi->redirect(-uri => $uri,
			     -cookie => $recentSearchesCookie);
			     
	# PROGILONE - may 2010 - F14
	# Manage Search History by session
	$session->param('historySession', undef);
    # Showing search history
    } else {

	# Getting the cookie
	my $searchcookie = $cgi->cookie('KohaOpacRecentSearches');
	    if ( $session->param('historySession') ) {			
        my @recentSearches = @{$session->param('historySession')}; 
		# PROGILONE - may 2010 - F14
		# Manage Search History by session
		# -- if (@recentSearches) {

		# As the dates are stored as unix timestamps, let's do some formatting
		foreach my $asearch (@recentSearches) {
		# PROGILONE - may 2010 - F14
		my @output;
			# PROGILONE - may 2010 - F14
            # Change display of query in opac search history
			my $num_op = () = split /&op/, $asearch->{'query_cgi'}, -1;
			my @idx = split(/&op/, $asearch->{'query_cgi'} );
			
			# Identify operands
			for (my $i=0;$i<$num_op;$i++) {
				my %row;
				#Test index with operands
				if ($i > 0){
					my $operand = substr($idx[$i], index($idx[$i],"op=")+2, 2);
						if ($operand eq "an"){
						$row{OPERAND_AND} = 1;
						}				
						elsif ($operand eq "or"){
						$row{OPERAND_OR} = 1;
						}
						elsif ($operand eq "no"){
						$row{OPERAND_NOT} = 1;
						}
				}
			
				my $idx_query = substr($idx[$i], index($idx[$i],"idx=")+4, 2);
				my $phrase_idx = substr($idx[$i], index($idx[$i],",")+1, 3);
			
				# Identify indexes
				$row{get_index($idx_query,$phrase_idx)} = 1;
		    
		    	# Identify keywords 
		    	$row{KEYWORD} = substr($idx[$i], index($idx[$i],"q=")+2);
		    
				push(@output, \%row);
	    	}
			$asearch->{'searchhistodetail'} = \@output;
		}
  		# PROGILONE - may 2010 - F14
		
		$template->param(recentSearches => \@recentSearches);
		}
	    	
    }
} else {
# And if the user is logged in, we deal with the database
   
    my $dbh = C4::Context->dbh;

    # Deleting search history
    if ($cgi->param('action') && $cgi->param('action') eq 'delete') {
	my $query = "DELETE FROM search_history WHERE userid = ?";
	my $sth   = $dbh->prepare($query);
	$sth->execute($loggedinuser);

	# Redirecting to this same url so the user won't see the search history link in the header
	my $uri = $cgi->url();
	print $cgi->redirect($uri);


    # Showing search history
    } else {

	my $date = C4::Dates->new();
	my $dateformat = $date->DHTMLcalendar() . " %H:%i:%S"; # Current syspref date format + standard time format

	# Getting the data with date format work done by mysql
	my $query = "SELECT userid, sessionid, query_desc, query_cgi, total, DATE_FORMAT(time, \"$dateformat\") as time FROM search_history WHERE userid = ? AND sessionid = ?";
	my $sth   = $dbh->prepare($query);
	$sth->execute($loggedinuser, $cgi->cookie("CGISESSID"));
	my $searches = $sth->fetchall_arrayref({});
	
	# PROGILONE - may 2010 - F14
	# Search History

	foreach my $row_search ( @{$searches} ) {
			my @output;
 			my $tmp_query= $row_search->{'query_cgi'};
			my $num_op = () = split /&op/, $tmp_query, -1;
			my @idx = split(/&op/, $tmp_query);
	
			for (my $i=0;$i<$num_op;$i++) {
				my %row;
				#Test index witout operand
				if ($i > 0){
				my $operand = substr($idx[$i], index($idx[$i],"op=")+2, 2);
					if ($operand eq "an"){
					$row{OPERAND_AND} = 1;
					}
					elsif ($operand eq "or"){
					$row{OPERAND_OR} = 1;
					}
					elsif ($operand eq "no"){
					$row{OPERAND_NOT} = 1;
					}
				}
			
				my $idx_query = substr($idx[$i], index($idx[$i],"idx=")+4, 2);
				my $phrase_idx = substr($idx[$i], index($idx[$i],",")+1, 3);
			
				# Identify indexes
				$row{get_index($idx_query,$phrase_idx)} = 1;
		    
		    	# Identify keywords 
		    	$row{KEYWORD} = substr($idx[$i], index($idx[$i],"q=")+2);
		    
				push(@output, \%row);
					
	        } #end for

		$row_search->{'searchhistodetail'} = \@output;
    }
    # PROGILONE - may 2010 - F14
    	   
    $template->param(recentSearches => $searches);
	
	# Getting searches from previous sessions
	$query = "SELECT COUNT(*) FROM search_history WHERE userid = ? AND sessionid != ?";
	$sth   = $dbh->prepare($query);
	$sth->execute($loggedinuser, $cgi->cookie("CGISESSID"));

	# If at least one search from previous sessions has been performed
        if ($sth->fetchrow_array > 0) {
	    $query = "SELECT userid, sessionid, query_desc, query_cgi, total, DATE_FORMAT(time, \"$dateformat\") as time FROM search_history WHERE userid = ? AND sessionid != ?";
	    $sth   = $dbh->prepare($query);
	    $sth->execute($loggedinuser, $cgi->cookie("CGISESSID"));
    	my $previoussearches = $sth->fetchall_arrayref({});
	
		# PROGILONE - may 2010 - F14
		# Search History
    	foreach my $row_search ( @{$previoussearches} ) {
    		my @output;
			my $tmp_query= $row_search->{'query_cgi'};
			my $num_op = () = split /&op/, $tmp_query, -1;
			my @idx = split(/&op/, $tmp_query);
	
			for (my $i=0;$i<$num_op;$i++) {
				my %row;
				#Test index witout operand
				if ($i > 0){
				my $operand = substr($idx[$i], index($idx[$i],"op=")+2, 2);
					if ($operand eq "an"){
					$row{OPERAND_AND} = 1;
					}
					elsif ($operand eq "or"){
					$row{OPERAND_OR} = 1;
					}
					elsif ($operand eq "no"){
					$row{OPERAND_NOT} = 1;
					}
				}
			
				my $idx_query = substr($idx[$i], index($idx[$i],"idx=")+4, 2);
				my $phrase_idx = substr($idx[$i], index($idx[$i],",")+1, 3);
			
				# Identify indexes
				$row{get_index($idx_query,$phrase_idx)} = 1;
		    
		    	# Identify keywords 
		    	$row{KEYWORD} = substr($idx[$i], index($idx[$i],"q=")+2);
		    
				push(@output, \%row);
					
	        } #end for

		$row_search->{'searchprevioushistodetail'} = \@output;
    }
    # PROGILONE - may 2010 - F14

    $template->param(previousSearches => $previoussearches);
	
	}

	$sth->finish;


    }

}

$template->param(searchhistoryview => 1);

output_html_with_http_headers $cgi, $cookie, $template->output;

# PROGILONE - may 2010 - F14
sub get_index{
	
	my ($idx_query, $phrase_idx) = @_;
	my $idx;
	
			if ( $idx_query =~ /kw/){
		    	$idx = "INDEX_KEYWORD";
		    }
			elsif ( $idx_query =~ /au/){	
		    	if ($phrase_idx eq "phr"){
		    		$idx = "INDEX_AUTHOR_PHRASE";
		    	}
		    	else{
		    		$idx = "INDEX_AUTHOR";	
		    	}
		    }
		    elsif ( $idx_query =~ /cp/){
		    	$idx = "INDEX_COPRPORATE_NAME";
		    }
		    elsif ( $idx_query =~ /cf/){	
		    	if ($phrase_idx eq "phr"){
		    			$idx = "INDEX_CONFERENCE_NAME_PHRASE";
		    	}
		    	else{
		    		$idx = "INDEX_CONFERENCE_NAME";	
		    	}
		    }
		    elsif ( $idx_query =~ /pn/){	
		    	if ($phrase_idx eq "phr"){
		    		$idx = "INDEX_PERSONAL_NAME_PHRASE";
		    	}
		    	else{
		    		$idx = "INDEX_PERSONAL_NAME";	
		    	}
		    }
		    elsif ( $idx_query =~ /nt/){
		    		$idx = "INDEX_NOTES_NAME";
		    }
		    elsif ( $idx_query =~ /pb/){
		    		$idx = "INDEX_PUBLISHER";
		    }
		    elsif ( $idx_query =~ /pl/){
		    		$idx = "INDEX_PUBLISHER_LOCATION";
		    }
		    elsif ( $idx_query =~ /sn/){
		    		$idx = "INDEX_STANDARD_NUMBER";
		    }
		    elsif ( $idx_query =~ /nb/){
		    	$idx = "INDEX_ISBN";
		    }
		    elsif ( $idx_query =~ /ns/){
		    	$idx = "INDEX_ISSN";
		    }
		    # Warning Simple Search : /callnum/
		    elsif ( $idx_query =~ /lcn/){
		    		$idx = "INDEX_CALL_NUMBER";
		    }
		    elsif ( $idx_query =~ /su/){	
		    	if ($phrase_idx eq "phr"){
		    		$idx = "INDEX_SUBJECT_PHRASE";
		    	}
		    	else{
		    		$idx = "INDEX_SUBJECT";	
		    	}
		    }
		    elsif ( $idx_query =~ /ti/){	
		    	if ($phrase_idx eq "phr"){
		    		$idx = "INDEX_TITLE_PHRASE";
		    	}
		    	else{
		    		$idx = "INDEX_TITLE";	
		    	}
		   	}
		    elsif ( $idx_query =~ /se/){
		    	$idx = "INDEX_SERIES";
		    }
			else{
				$idx = undef;
			}
		return $idx;
}
# PROGILONE - may 2010 - F14