package OpenInteract2::Setup::RequireSystemClasses;

use strict;
use base qw( OpenInteract2::Setup::RequireClasses );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

$OpenInteract2::Setup::RequireSystemClasses::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'require system classes';
}

sub get_dependencies {
    return ( 'create templib' );
}

sub setup {
    my ( $self, $ctx ) = @_;
    my $conf_system_classes = $ctx->lookup_class;
    $self->param( classes => values %{ $conf_system_classes } );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::RequireSystemClasses - Bring in declared 'system_classes'

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'require system classes' );
 $setup->run();

=head1 DESCRIPTION

This setup action brings in all classes from the context method
L<lookup_class> (sourced by the server configuration key
'system_class').

 [system_class]
 repository       = OpenInteract2::Repository
 package          = OpenInteract2::Package
 template         = OpenInteract2::SiteTemplate
 setup            = OpenInteract2::Setup
 ini_reader       = OpenInteract2::Config::Ini

All classes are stored in the 'classes' parameter to be processed by
its parent, L<OpenInteract2::Setup::RequireClasses>.

=head2 Setup Metadata

B<name> - 'require system classes'

B<dependencies> - 'create templib'

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
