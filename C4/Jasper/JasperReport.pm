package C4::Jasper::JasperReport;

##
# B011 : Jasper Report
##

use strict;
use vars qw($VERSION @ISA @EXPORT);
use C4::Context;
use C4::Letters;

use SOAP::Lite;
use POSIX qw(strftime);
use Time::HiRes;
use Archive::Zip;

##
# Declarations
##
BEGIN {
    # TODO set the version for version checking
    $VERSION = 0.01;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &exportReport_Old
        &GeneratePDF_Old
        
        &GenerateZip
        &DownloadZip
        &SendEmail
        &GetExportTypes
    );
}

# export Reports
# param : reportname
# param : parameters
sub exportReport_Old {
    my $reportname = shift;
    my $parameters = shift;
    my $ask_parameter = shift;
    
    my $filetype;
    
    my $address = C4::Context->preference("JasperServerUrl").'/jasperserver/flow.html?_flowId=viewReportFlow';
    my $report = 'reportUnit=/reports/'.$reportname.'&standAlone=true&ParentFolderUri=/reports';
    my $connection = 'j_username='.C4::Context->preference("JasperServerUserConnection").'&j_password='.C4::Context->preference("JasperServerPasswordConnection");
    
    my $parameter = '';
    for (keys %$parameters) {
        $parameter = $parameter.'&'.$_.'='.$parameters->{$_};
    }
    unless ($ask_parameter) {
        $filetype = 'output=pdf';
    } else {
        $filetype = '';
    }
    return "$address&$report&$connection$parameter&$filetype";
}

##
# Generate PDF file into file at path
#
# param : path
# param : filename
# param : reportname
# param : parameters
##
sub GeneratePDF_Old($$$$) {
    # input args
    my ($path, $filename, $reportname, $parameters) = @_;
    
    eval {
        # local vars
        my $URL = exportReport_Old($reportname, $parameters, 0);
    
        # save report
        my $file = get($URL);
        
        if ( $file ){
            open( FILE, '>', $path . $filename );
            binmode FILE;
            print FILE $file;
            close( FILE );
            
            return 1;
        }
    };
    return 0;
}

sub _generateInputXml {
	my ( $report_directory, $report_name, $parameters, $format ) = @_;
	
	my $parameter_xml = '';
    for my $param_name (keys %$parameters) {
        my $param_value = $parameters->{$param_name};
        # do not use if ($param_value) to authorize 0 and '0'
        if ( defined $param_value && $param_value ne '' ) {
            $parameter_xml = $parameter_xml."<parameter name='$param_name'>$param_value</parameter>\n";
        }
    }
	
	my $input_xml = "
<request operationName='runReport'>
    <argument name='RUN_OUTPUT_FORMAT'>$format</argument>
    <resourceDescriptor name='' wsType='reportUnit' uriString='/reports/$report_directory/$report_name' isNew='false'>
        <label>null</label>
        $parameter_xml
    </resourceDescriptor>
</request>
";
	
	return $input_xml;
}

sub _generateReport {
	my ( $report_directory, $report_name, $parameters, $format, $filename ) = @_;
	my $result = 0;
	
	eval {
        my $input = _generateInputXml( $report_directory, $report_name, $parameters, $format );
        
        my $jasperURL = C4::Context->preference("JasperServerUrl");
        $jasperURL =~ s{http://}{}i;
        $jasperURL =~ s{/}{}g;
        
        my $jasperUser = C4::Context->preference("JasperServerUserConnection");
        my $jasperPassword = C4::Context->preference("JasperServerPasswordConnection");
        
        my $soap = SOAP::Lite
                    ->readable(1)
                    ->uri('http://'.$jasperURL.'/jasperserver/services/repository')
                    ->proxy('http://'.$jasperUser.':'.$jasperPassword.'@'.$jasperURL.'/jasperserver/services/repository?wsdl');
        my $som = $soap->runReport($input);
        
        foreach my $part (@{$som->parts}) {
        	open(FILE, ">>".$filename);        
        	if (my $io = $part->open("r")) {
        		while (defined($_ = $io->getline)) { print FILE $_ }
        		$io->close;
        	}
        	close(FILE);
        }
        $result = 1;
	};
	warn $@ if $@;
	return $result;
}

sub _generatePDF {
	my ( $report_directory, $report_name, $parameters ) = @_;
	
	my $save_directory = "/tmp/";
	my $filename = _generateReportName( $report_name ).'.pdf';
	
	my $result = _generateReport( $report_directory, $report_name, $parameters, 'PDF', $save_directory.$filename );
	
	return ( $result, $save_directory.$filename );
}

sub GenerateZip {
	my ( $report_directory, $report_name, $action, $parameters_list, $format ) = @_;
	
	my $save_directory = "/tmp/";
	my $base_filename = _generateReportName( $report_name );
	unless ( $format ) {
		$format = 'pdf';
	}
	
	my @results = ();
	
	my $zipname = $base_filename;
	if ( $action eq 'visualization' ) {
		$zipname = $zipname.'-KohaVisualization';
	} elsif ( $action eq 'print' ) {
		$zipname = $zipname.'-KohaPrint';
	}
	$zipname = $zipname.'.zip';
	
	eval {
    	my $zip = Archive::Zip->new();
    	my $file_number = 1;
    	
    	foreach my $parameters ( @$parameters_list ) {
    		my $file_nb = '';
    		if ( $file_number > 1 ) {
    			$file_nb = '-'.$file_number;
    		}
    		my $filename = $base_filename.$file_nb.'.'.$format;
    		my $result = _generateReport( $report_directory, $report_name, $parameters, $format, $save_directory.$filename );
    		if ( $result ) {
    			$zip->addFile( $save_directory.$filename, $filename);
    		}
			
			push @results, $result;
    		$file_number = $file_number + 1;
    	}
    	
    	my $result = $zip->writeToFileNamed($save_directory.$zipname);
	};
	
	return ( $save_directory, $zipname, @results );
}

sub DownloadZip {
    my ( $report_directory, $report_name, $action, $parameters_list, $format ) = @_;
    
    eval {
        my ( $save_directory, $zipname, @results ) = GenerateZip( $report_directory, $report_name, $action, $parameters_list, $format );
        
        my $zipBuffer = open(ZIP, "<$save_directory/$zipname");
        binmode(ZIP);
        my $report_content = do { local $/; <ZIP> };
        close(ZIP);
        	
        print "Content-Type: application/zip\n";
        print "Content-Disposition: attachment; filename=\"$zipname\"\n";
        print "Content-Length: ".length($report_content)."\n";
        print "\n";
        
        print $report_content;
    }
}

sub SendEmail {
	my ( $report_directory, $report_name, $parameters, $letter, $sendtoborrower, $from_address, $to_address ) = @_;
	
	unless ( $from_address ) {
		my $from_address = C4::Context->preference('KohaAdminEmailAddress');
	}
	
	my ( $result, $filename ) = _generatePDF( $report_directory, $report_name, $parameters );
	
	if ( $result ) {
		open FILE, '<'.$filename;
		my $filecontent = do { local $/; <FILE> };
		
		my $attachment = {
			filename => $report_name.'.pdf',
			content => $filecontent,
			type => 'application/pdf',
		};
		
		C4::Letters::EnqueueLetter(
			{
				letter                 => $letter,
				borrowernumber         => $sendtoborrower,
				message_transport_type => 'email',
				from_address           => $from_address,
				to_address             => $to_address,
				attachments            => [$attachment],
			}
		);
	}
	
	return $result;
}

sub _generateReportName {
	my ( $report_name ) = @_;
	
	my ( $seconds, $microseconds ) = Time::HiRes::gettimeofday();
	my $format_seconds = strftime( '%Y.%m.%d-%H.%M.%S', localtime( $seconds ) );
	
	my $filename = $report_name."-".$format_seconds."-".$microseconds;
	return $filename;
}

sub GetExportTypes {
	my ( $selected ) = @_;
	
	my @exporttype_values = ('pdf', 'csv');
	my @exporttype_hash = ();
	foreach my $exporttype ( @exporttype_values ) {
		my %data;
		
		$data{"value"} = $exporttype;
		$data{"label"} = $exporttype;
		
		if ($selected && $selected eq $exporttype ) {
            $data{"selected"} = 1;
        }

		push ( @exporttype_hash, \%data );
	}
	
	return @exporttype_hash;
}

1;
__END__