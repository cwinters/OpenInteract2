package OpenInteract2::Cache::File;

# $Id: File.pm,v 1.12 2005/03/18 04:09:49 lachoy Exp $

use strict;
use base qw( OpenInteract2::Cache );
use Cache::FileCache;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Cache::File::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my $DEFAULT_SIZE   = 2000000;  # 10 MB -- max size of cache
my $DEFAULT_EXPIRE = 86400;    # 1 day

sub initialize {
    my ( $self, $cache_conf ) = @_;
    $log ||= get_logger( LOG_CACHE );

    # Allow values that are passed in to override anything
    # set in the config object

    $cache_conf->{directory} ||= '';
    unless ( -d $cache_conf->{directory} ) {
        $log->error( "Cannot create a filesystem cache without a valid ",
                     "directory. (Given: $cache_conf->{directory})" );
        return undef;
    }

    my $cache_dir      = $cache_conf->{directory};
    my $max_size       = $cache_conf->{max_size};
    my $default_expire = $cache_conf->{default_expire};
    my $cache_depth    = $cache_conf->{directory_depth};

    # If a value isn't set, use the default from the class
    # configuration above.

    $max_size       ||= $DEFAULT_SIZE;
    $default_expire ||= $DEFAULT_EXPIRE;

    $log->is_info &&
        $log->info( "Using the following cache settings ",
                    "[Dir $cache_dir] [Size $max_size] ",
                    "[Expire $default_expire] [Depth $cache_depth]" );
    return Cache::FileCache->new({
        default_expires_in => $default_expire,
        max_size           => $max_size,
        cache_root         => $cache_dir,
        cache_depth        => $cache_depth,
    });
}

sub purge_all {
    # no-op for now...
}

sub get_data {
    my ( $self, $cache, $key ) = @_;
    $log->is_debug && $log->debug( "Retrieving from '$key'" );
    return $cache->get( $key );
}


sub set_data {
    my ( $self, $cache, $key, $data, $expires ) = @_;
    $log->is_debug && 
        $log->debug( "Assigning to '$key' to expire in '$expires'" );
    $cache->set( $key, $data, $expires );
    return 1;
}


sub clear_data {
    my ( $self, $cache, $key ) = @_;
    $log->is_debug && $log->debug( "Removing cache item '$key'" );
    $cache->remove( $key );
    return 1;
}

1;

__END__

=head1 NAME

OpenInteract2::Cache::File -- Implement caching in the filesystem

=head1 DESCRIPTION

Subclass of L<OpenInteract2::Cache|OpenInteract2::Cache> that uses the
filesystem to cache objects.

=head1 METHODS

B<initialize( \%config )>

Creates a new L<Cache::FileCache|Cache::FileCache> object for later
use, initializing it with the values from C<\%config> -- this
corresponds to the data under C<cache> in your server
configuration. Here's what you can set:

=over 4

=item *

B<directory> (required)

Root directory of cache. Must be writable by the user who owns the
server process.

=item *

B<max_size> (optional)

Max size of the cache, in bytes. (Default: 2000000 about 10MB)

=item *

B<default_expire> (optional)

Number of seconds the cached item should be valid. (Default: 86400, or
one day)

=item *

B<directory_depth> (optional)

If you cache a B<lot> of content set this to '2' or '3' so the cache
doesn't create too many files in a single directory, which can foul up
some filesystems.

=back

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
