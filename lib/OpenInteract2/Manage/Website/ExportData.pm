package OpenInteract2::Manage::Website::ExportData;

# $Id: ExportData.pm,v 1.3 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Export;

$OpenInteract2::Manage::Website::ExportData::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'export_data';
}

sub get_brief_description {
    return "Export data for one or more SPOPS objects into one of " .
           "multiple formats for easy data interchange.";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        spops => {
            description =>
                  "Tag for class you'd like to export -- for example " .
                  "use 'news' for 'OpenInteract2::News'",
            is_required => 'yes',
        },
        query => {
            description =>
                  "WHERE clause used to filter objects to export. " .
                  "This is passed directly to the database.",
            is_required => 'no',
            do_validate => 'no',
        },
        format => {
            description =>
                  "Format of export. May be 'object' (default), " .
                  "'xml', 'perl' (Data::Dumper-type output), " .
                  "'sql' (series of SQL statements) or 'dbdata' (like " .
                  "'object' but can be put directly into db table).",
            is_required => 'no',
            do_validate => 'yes',
            default     => 'object',
        },
        output_file => {
            description =>
                  'Name of file to which I will write output; will be ' .
                  'overwritten if it exists (default: STDOUT)',
            is_required => 'no',
            do_validate => 'no',
        },
    };
}

sub param_validate {
    my ( $self, $param, $value ) = @_;
    if ( $param eq 'format' ) {
        my @types = qw( object xml perl sql dbdata );
        my $type_pat = join( '|', @types );
        unless ( $param =~ /^($type_pat)$/ ) {
            return "Must be one of: ", join( ', ', @types );
        }
        return $self->SUPER::param_validate( $param, $value );
    }
}

# cannot define validate_param() for 'spops' since we need the context
# to be created... wait for run_task()

sub run_task {
    my ( $self ) = @_;
    my $log = get_logger( LOG_APP );

    my $action = 'export data';
    my $object_tag = $self->param( 'spops' );
    my $object_class = eval { $self->_check_spops_key( $object_tag ) };
    if ( $@ ) {
        return $self->_fail( $action, "$@" );
    }
    $log->info( "Using class '$object_class' for SPOPS name ",
                "'$object_tag'" );

    my $export_format = $self->param( 'format' );
    my $exporter = SPOPS::Export->new( $export_format,
                                       { object_class => $object_class });
    if ( my $query = $self->param( 'query' ) ) {
        $exporter->where( $query );
    };
    $exporter->skip_security(1);

    if ( $export_format eq 'xml' ) {
        $exporter->object_tag( $object_tag );
    }

    $log->info( "Created exporter object ok" );

    my $exporter_output = eval { $exporter->run() };
    if ( $@ ) {
        $log->error( "Error running exporter: $@" );
        $self->_fail( $action, "Export execution failed: $@" );
    }
    $log->info( "Ran exporter ok" );

    my $out_file = $self->param( 'output_file' );
    if ( $out_file ) {
        open( OUT, "> $out_file" )
            || oi_error "Cannot write to '$out_file': $!";
        print OUT $exporter_output;
        close( OUT );
        $log->info( "Wrote exporter output to '$out_file' ok" );
    }
    else {
        print $exporter_output;
        $log->info( "Wrote exporter output to STDOUT ok" );
    }
    my $msg = ( SPOPS->VERSION >= 0.88 )
                ? "Export succeeded (" . $exporter->number_exported . " records)"
                : "Export succeeded";
    $self->_ok( $action, $msg );
    return;
}


OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ExportData - Export SPOPS data for easy data interchange

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my %PARAMS = (
     spops       => 'news',
     query       => q{posted_on BETWEEN( '2004-04-01' AND '2004-04-30' )},
     output_file => 'news_export.sql',
     format      => 'sql',
 );
 my $task = OpenInteract2::Manage->new( 'export_data', \%PARAMS );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 OPTIONS

=head2 Required

=over 4

=item B<spops>=spops-name

Name of SPOPS object to export. The name is what you use in the
context C<lookup_object()> call:

 my $news_class = CTX->lookup_object( 'news' );

=back

=head2 Optional

=over 4

=item B<query>=where clause

If you want to restrict the objects to export just pass along the text
of a WHERE clause here (without the 'WHERE'). It will be passed to the
database verbatim as the 'where' parameter of the C<fetch_iterator()>
class method. (See L<SPOPS::DBI> or L<SPOPS::LDAP> for more
information about this method.)

=item B<output_file>=filename

Export will be written to this file. Any existing contents will be
destroyed.

If you do not specify a file the exporter output will be printed to
STDOUT.

=item B<format>=format

Valid formats are:

B<object> (default) -- See L<SPOPS::Export::Object>

B<sql> -- See L<SPOPS::Export::SQL>

B<perl> -- See L<SPOPS::Export::Perl>

B<xml> -- See L<SPOPS::Export::XML>

B<dbdata> -- See L<SPOPS::Export::DBI::Data>

=back

=head1 STATUS INFORMATION

This method reports no additional status information.

=head1 SEE ALSO

L<SPOPS::Export>

=head1 COPYRIGHT

Copyright (C) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters, E<lt>chris@cwinters.comE<gt>

