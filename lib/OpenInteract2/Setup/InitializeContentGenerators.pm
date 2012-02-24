package OpenInteract2::Setup::InitializeContentGenerators;

# $Id: InitializeContentGenerators.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::ContentGenerator;
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::InitializeContentGenerators::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'initialize content generators';
}

sub get_dependencies {
    return ( 'read packages' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    $log->info( "Initializing all content generators" );
    my $all_generator_info = $ctx->lookup_content_generator_config;

BIG_GENERATOR:
    while ( my ( $name, $generator_data ) = each %{ $all_generator_info } ) {
        next if ( $name eq 'default' );
        my $generator_class = $generator_data->{class};
        unless ( $generator_class ) {
            $log->error( "Cannot use generator '$name': no class ",
                         "specified in the generator configuration ",
                         "key 'class'" );
            next BIG_GENERATOR;
        }
        my $full_name = "[Name: $name] [Class: $generator_class]";
        $log->info( "Trying to require and initialize $full_name" );
        eval "require $generator_class";
        if ( $@ ) {
           $log->error( "Failed to require generator $full_name: $@" );
           next BIG_GENERATOR;
        }
        my ( $generator );
        eval {
            $generator = $generator_class->new( $name, $generator_class );
            $generator->initialize( $generator_data );
        };
        if ( $@ ) {
            $log->error( "Require ok, but cannot initialize generator ",
                         "$full_name. Error: $@" );
        }
        else {
            $log->info( "Successfully required and initialized ",
                        "generator $full_name" );
            OpenInteract2::ContentGenerator->add_generator( $name, $generator );
        }
    }
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::InitializeContentGenerators - Initialize content generator objects

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'initialize content generators' );
 $setup->run();

=head1 DESCRIPTION

This cycles through the data in the server configuration key
C<content_generator> and performs the following for each subitem:

=over 4

=item *

Calls C<require()> on each class specified in that subitem's 'class'
key. If no class is declared there we skip over the subitem entirely
and log an error.

=item *

Instantiates an object of that class and calls C<initialize()>
on it, passing in the data (hashref) from the respective
'content_generator' configuration section as the only argument.

=item *

Passes that object to the C<add_generator()> method along with its associated name.

=back

=head2 Setup Metadata

B<name> - 'initialize content generators'

B<dependencies> - default

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
