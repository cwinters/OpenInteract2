package OpenInteract2::Cache;

# $Id: Cache.pm,v 1.15 2005/07/04 03:05:54 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Scalar::Util             qw( blessed );

$OpenInteract2::Cache::VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

# Returns: caching object (implementation-neutral)

my ( $log );

sub new {
    my ( $pkg, $conf ) = @_;
    my $class = ref $pkg || $pkg;
    $conf ||= {};
    $log ||= get_logger( LOG_CACHE );
    if ( $log->is_info ) {
        $log->info( "Instantiating new cache of class '$class'" );
        foreach my $key ( keys %{ $conf } ) {
            $log->info( "...with key '$key' => '$conf->{ $key }'" );
        }
    }
    my $self = bless( {}, $class );
    $self->{_cache_object} = $self->initialize( $conf );
    return $self;
}


# Returns: data from the cache

sub get {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_CACHE );

    # if the cache hasn't been initialized, bail

    unless ( $self->{_cache_object} ) {
        $log->is_info &&
            $log->info( "Object from cache requested, cache object not created" );
        return undef;
    }

    # allow for get( $key ) and get({ key => $key }) calling methods
    my ( $key );
    if ( ref $p ) {
        $key = $p->{key};
    }
    else {
        $key = $p;
        $p   = {}; 
    }

    my $is_object = 0;
    my $obj_class = undef;
    if ( ! $key and $p->{class} and $p->{object_id} ) {
        $key = _make_spops_idx( $p->{class}, $p->{object_id} );
        $log->is_debug &&
            $log->debug( "Created class+id key [$key]" );
        $obj_class = $p->{class};
        $is_object++;
        return undef  unless ( $obj_class->pre_cache_get( $p->{object_id} ) );
    }
    unless ( $key ) {
        $log->is_debug && $log->debug( "Cache MISS (no key)" );
        return undef;
    }

    my $data = $self->get_data( $self->{_cache_object}, $key );
    unless ( $data ) {
        $log->is_debug && $log->debug( "Cache MISS [$key]" );
        return undef;
    }

    $log->is_debug && $log->debug( "Cache HIT [$key]" );
    if ( $is_object ) {
        return undef unless ( $obj_class->post_cache_get( $data ) );
    }
    return $data;
}

sub set {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_CACHE );

    # if the cache hasn't been initialized, bail

    unless ( $self->{_cache_object} ) {
        $log->is_info &&
            $log->info( "Request to cache object, cache object not created" );
        return undef;
    }


    my $is_object = 0;
    my $key  = $p->{key};
    my $data = $p->{data};
    my ( $obj );
    if ( _is_spops_object( $data ) ) {
        $obj = $data;
        $key = _make_spops_idx( ref $obj, $obj->id );
        $log->is_debug &&
            $log->debug( "Created class+id key [$key]" );
        $is_object++;
        return undef  unless ( $obj->pre_cache_save );
        $data = $obj->as_data_only;
    }
    $self->set_data( $self->{_cache_object}, $key, $data, $p->{expire} );
    if ( $obj and $obj->can( 'post_cache_save' ) ) {
        return undef  if ( $obj->post_cache_save );
    }
    return 1;
}

sub clear {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_CACHE );

    # if the cache hasn't been initialized, bail
    return undef unless ( $self->{_cache_object} );

    my $key = $p->{key};
    if ( ! $key and _is_spops_object( $p->{data} ) ) {
        $key = _make_spops_idx( ref $p->{data}, $p->{data}->id );
    }
    elsif ( ! $key and $p->{class} and $p->{object_id} ) {
        $key = _make_spops_idx( $p->{class}, $p->{object_id} );
    }
    $log->is_debug &&
        $log->debug( "Trying to clear cache of [$key]" );
    return $self->clear_data( $self->{_cache_object}, $key );
}


sub purge {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_CACHE );

    # if the cache hasn't been initialized, bail

    unless ( $self->{_cache_object} ) {
        $log->is_info &&
            $log->info( "Purge of cache requested, cache object not created" );
        return undef;
    }

    $log->is_info &&
        $log->info( "Trying to purge cache of all objects" );
    return $self->purge_all( $self->{_cache_object} );
}


sub _is_spops_object {
    my ( $item ) = @_;
    my $typeof = ref $item;
    return undef unless ( blessed( $item ) );
    return undef unless ( $item->isa( 'SPOPS' ) );
    return 1;
}

sub _make_spops_idx {
    return join '--', $_[0], $_[1];
}

########################################
# SUBCLASS TO OVERRIDE

sub initialize  { die "Subclass must define initialize()\n" }
sub get_data    { die "Subclass must define get_data()\n" }
sub set_data    { die "Subclass must define set_data()\n" }
sub clear_data  { die "Subclass must define clear_data()\n" }
sub purge_all   { die "Subclass must define purge_all()\n" }

1;

__END__

=head1 NAME

OpenInteract2::Cache -- Caches objects to avoid database hits and content to avoid template processing

=head1 SYNOPSIS

 # In $WEBSITE_DIR/conf/server.ini
 
 [cache]
 default_expire = 600
 use            = 0
 use_spops      = 0
 class          = OpenInteract2::Cache::File
 directory      = /path/to/cache
 max_size       = 2000000
 
 # Use implicitly with built-in content caching
 
 sub listing {
     my ( $self ) = @_;
     return $self->generate_content(
                         \%params, { name => 'mypkg::listing' } );
 }
 
 # Explicitly expire a cached item
 
 sub edit {
     my ( $self ) = @_;
     ...
     eval { $object->save };
     if ( $@ ) {
         # set error message
     }
     else {
         CTX->cache->clear({ key => 'mypkg::myhandler::listing' });
     }
 }

=head1 DESCRIPTION

This class is the base class for different caching implementations,
which are themselves just wrappers around various CPAN modules which
do the actual work. As a result, the module is pretty simple.

The only tricky aspect is that we use this for caching content and for
caching SPOPS objects. So there is some additional data checking not
normally in such a module.

=head1 METHODS

These are the methods for the cache. The following parameters are
passed to every method that operates on an individual cached
item. Either 'key' or 'class' and 'object_id' are required for these
methods.

=over 4

=item *

B<key>: Name under which we store data

=item *

B<class>: Class of SPOPS object

=item *

B<object_id>: ID of SPOPS object

=back

B<get( $key || \%params )>

Returns the data in the cache associated with a key; undef if data
corresponding to the key is not found.

Note that the common case (where you just want to retrieve a cached
item by key) allows you to skip creating a hashref to pass in a single
argument.

B<set( \%params )>

Saves the data found in the C<data> parameter into the cache,
referenced by the key C<key>. If C<data> is an SPOPS object we create
a key from its class and ID.

Parameters:

=over 4

=item *

B<data>: The data to save in the cache. This can be an object, HTML
content or any other cacheable Perl data structure. (Don't try to
store database handles, filehandles, or any other object with 'live'
connections to real-world resources.)

=item *

B<expire> (optional): Time the item should sit in the cache before being
refreshed. This can be in seconds (the default) or in the "[number]
[unit]" format outlined by L<Cache::Cache|Cache::Cache>. For example,
'10 minutes'.

=back

Returns a true value if successful.

B<clear( \%params )>

Invalidates the cache for the specified item.

B<purge()>

Clears the cache of all items.

=head1 SUBCLASS METHODS

These are the methods that must be overridden by a subclass to
implement caching.

B<initialize( \%OpenInteract2::Config )>

This method is called object is first created. Use it to define and
return the object that actually does the caching. It will be passed to
all successive methods (C<get_data()>, C<set_data()>, etc.).

Relevant keys in the L<OpenInteract2::Config|OpenInteract2::Config>
object passed in:

 cache_info.default_expire - Default expiration time for items
 cache_info.max_size       - Maximum size (in bytes) of cache

B<get_data( $cache_object, $key )>

Returns an object if it is cached and 'fresh', however that
implementation defines fresh.

B<set_data( $cache_object, $data, $key, [ $expires ] )>

Returns 1 if successful, undef on failure. If C<$expires> is undefined
or is not set to a valid L<Cache::Cache|Cache::Cache> value, then the
configuration key 'cache_info.default_expire'.

B<clear_data( $cache_object, $key )>

Removes the specified data from the cache. Returns 1 if successful,
undef on failure (or inability to do so).

B<purge_all( $cache_object )>

Clears the cache of all items.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
