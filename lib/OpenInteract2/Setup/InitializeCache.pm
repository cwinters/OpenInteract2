package OpenInteract2::Setup::InitializeCache;

# $Id: InitializeCache.pm,v 1.2 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::InitializeCache::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'initialize cache';
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $cache_config = $ctx->lookup_cache_config || {};
    unless ( 'yes' eq lc $cache_config->{use}  ) {
        $log->info( "Cache not configured for usage" );
        return;
    }

    my $cache_class = $cache_config->{class};
    $log->info( "Creating cache with class '$cache_class'" );
    OpenInteract2::Setup->new(
        'require classes',
        classes      => $cache_class,
        classes_type => 'Cache class',
    )->run();
    my $cache = $cache_class->new( $cache_config );
    $log->info( "Cache setup with '$cache_class' ok" );

    if ( 'yes' eq lc $cache_config->{cleanup} ) {
        $log->info( "Cache configured for cleanup at startup, purging..." );
        $cache->purge;
    }
    $self->param( cache => $cache );
    $ctx->cache( $cache );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::InitializeCache - Initialize the cache

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'initialize cache' );
 $setup->run();
 
 my $cache = CTX->cache;
 $cache->set({ key => 'foo', data => { bar => 'baz' } });

=head1 DESCRIPTION

This setup action first checks the 'cache.use' server configuration
key. If set to anything but 'yes' the action does nothing, since you
don't want to use a cache.

Otherwise it:

=over 4

=item *

Brings in the class referenced in 'cache.class'.

=item *

Instantiates a new cache object by passing in the 'cache'
configuration to C<new()> on that class.

=item *

If the key 'cache.cleanup' is set to 'yes' it calls C<purge()> on the
just-created cache object.

=item *

Finally, it assigns the cache object to the context with the
C<cache()> method.

=back

=head2 Setup Metadata

B<name> - 'initialize cache'

B<dependencies> - default

=head1 SEE ALSO

L<OpenInteract2::Setup>

L<OpenInteract2::Cache>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
