package OpenInteract2::Setup::ReadLocalizedMessages;

# $Id: ReadLocalizedMessages.pm,v 1.4 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use File::Spec::Functions    qw( catfile );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config::Initializer;
use OpenInteract2::I18N::Initializer;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::ReadLocalizedMessages::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'read localized messages';
}

sub get_dependencies {
    return ( 'read packages' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $i18n_init = OpenInteract2::I18N::Initializer->new;
    $i18n_init->locate_global_message_files();

    my $packages = $ctx->packages;
    foreach my $package ( @{ $packages } ) {
        my $package_id = join( '-', $package->name, $package->version );
        my $package_dir = $package->directory;
        my $filenames = $package->get_message_files;
        $log->debug( "Got message files from package $package_id: ",
                     join( ', ', @{ $filenames } ) );
        $i18n_init->add_message_files( @{ $filenames } );
    }
    my $classes = $i18n_init->run;
    $log->debug( "Created the following message classes: ",
                 join( ', ', @{ $classes } ) );

    my $initializer = OpenInteract2::Config::Initializer->new;
    foreach my $msg_class ( @{ $classes } ) {
        $initializer->notify_observers( 'localization', $msg_class );
        $log->info( "Notified observers of config for localization ",
                    "class '$msg_class' " );
    }
    $self->param( classes => $classes );

    # Don't do this until the I18N initializer has been run, otherwise
    # your default language will be excluded forever...

    my $default_language = $ctx->server_config->{language}{default_language};
    $ctx->assign_default_language_handle(
        OpenInteract2::I18N->get_handle( $default_language )
    );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::ReadLocalizedMessages - Find and read all localization data and create lookup tables

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'read localized messages' );
 $setup->run();

=head1 DESCRIPTION

This setup action asks each package for its localization message files
(via C<get_message_files()> and passes the files to
L<OpenInteract2::I18N::Initializer>, which does the actual work.

Once they're all read in we pass each class created to the
configuration initializers (L<OpenInteract2::Config::Initializer>)
with the type 'localization'.

=head2 Setup Metadata

B<name> - 'read localized messages'

B<dependencies> - 'read packages'

=head1 SEE ALSO

L<OpenInteract2::I18N::Initializer>

L<OpenInteract2::Config::Initializer>

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
