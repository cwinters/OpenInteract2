package OpenInteract2::TT2::Provider;

# $Id: Provider.pm,v 1.6 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( Template::Provider );
use Digest::MD5;
use File::Spec;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::TT2::Provider::VERSION  = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant DEFAULT_MAX_CACHE_TIME       => 60 * 30;
use constant DEFAULT_TEMPLATE_EXTENSION   => 'template';
use constant DEFAULT_PACKAGE_TEMPLATE_DIR => 'template/';
use constant DEFAULT_TEMPLATE_TYPE        => 'filesystem';

# Copied from Template::Provider since they're not exported

use constant PREV   => 0;
use constant NAME   => 1;
use constant DATA   => 2;
use constant LOAD   => 3;
use constant NEXT   => 4;
use constant STAT   => 5;

# This should return a two-item list: the first is the template to be
# processed, the second is an error (if any). $name is a simple name
# of a template, which in our case is often of the form
# 'package::template_name'.

sub fetch {
	my ( $self, $text ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
	my ( $name );

	# if scalar or glob reference, then get a unique name to cache by

	if ( ref( $text ) eq 'SCALAR' ) {
		$log->is_debug &&
            $log->debug( "anonymous template passed in" );
		$name = $self->_get_anon_name( $text );
	}
    elsif ( ref( $text ) eq 'GLOB' ) {
		$log->is_debug &&
            $log->debug( "GLOB passed in to fetch" );
        $name = $self->_get_anon_name( $text );
    }

    # Otherwise, it's a 'package::template' name or a unique filename
    # found in '$WEBSITE_DIR/template', both of which are handled in
    # _load() below. Also check that the template name doesn't have
    # any invalid characters (e.g., '../../../etc/passwd')

    else {
        $log->is_debug &&
            $log->debug( "info passed in [$text] is site filename or ",
                         "package::template; will check file system" );
        $name = $text;
        undef $text;
        eval { $self->_validate_template_name( $name ) };
        if ( $@ ) {
            return ( $@, Template::Constants::STATUS_ERROR );
        }
	}

    # If we have a directory to compile the templates to, create a
    # unique filename for this template

    # Just keep the compile name the same as the name passed
    # in, replacing '::' with '-'

    my ( $compile_file );

	if ( $self->{COMPILE_DIR} ) {
		my $ext = $self->{COMPILE_EXT} || '.ttc';
        my $compile_name = $name;
        $compile_name =~ s/::/-/g;
		$compile_file = File::Spec->catfile( $self->{COMPILE_DIR},
                                             $compile_name . $ext );
        $log->is_debug &&
            $log->debug( "compiled output filename [$compile_file]" );
	}

    my ( $data, $error );

	# caching disabled (cache size is 0) so load and compile but don't cache

	if ( $self->{SIZE} == 0 ) {
		$log->is_debug &&
            $log->debug( "fetch template [$name] [caching disabled]" );
		( $data, $error ) = $self->_load( $name, $text );
        ( $data, $error ) = $self->_compile( $data, $compile_file ) unless ( $error );
        $data = $data->{data}                                       unless ( $error );
	}

	# cached entry exists, so refresh slot and extract data

    elsif ( $name and ( my $cache_slot = $self->{LOOKUP}{ $name } ) ) {
		$log->is_debug &&
            $log->debug( "fetch template [$name] ",
                         "[cached (limit: $self->{SIZE})]" );
		( $data, $error ) = $self->_refresh( $cache_slot );
		$data = $cache_slot->[ DATA ] unless ( $error );
	}

	# nothing in cache so try to load, compile and cache

    else {
		$log->is_debug &&
            $log->debug( "fetch template ( $name ) ",
                         "[uncached (limit: $self->{SIZE})]" );
		( $data, $error ) = $self->_load( $name, $text );
		( $data, $error ) = $self->_compile( $data, $compile_file ) unless ( $error );
		$data = $self->_store( $name, $data )                       unless ( $error );
	}

	return( $data, $error );
}


# NOTE: You should NEVER even check to see if $name exists anywhere
# else on the filesystem besides under the $WEBSITE_DIR. The
# SiteTemplate object takes care of this, but it's just another
# warning...
#
# From Template::Provider -- here's what the hashref includes:
#
#   name    filename or $content, if provided, or 'input text', etc.
#   text    template text
#   time    modification time of file, or current time for handles/strings
#           (we also use this for the 'last_update' field of an SPOPS object)
#   load    time file/object was loaded (now!)

sub _load {
    my ( $self, $name, $content ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
	$log->is_debug &&
        $log->debug( "_load(@_[1 .. $#_])" );

    # If no name, $self->{TOLERANT} being true means we can decline
    # safely. Otherwise return an error. We might modify this in the
    # future to not even check TOLERANT -- if it's not defined we
    # don't want anything to do with it, and nobody else should either
    # (NYAH!). Note that $name should be defined even if we're doing a
    # scalar ref or glob template

    unless ( defined $name ) {
        if ( $self->{TOLERANT} ) {
            $log->is_debug &&
                $log->debug( "No name passed in and TOLERANT set, ",
                             "so decline" );
            return ( undef, Template::Constants::STATUS_DECLINED );
        }
        $log->is_debug &&
            $log->debug( "No name passed in and TOLERANT not set ",
                         "so return error" );
        return ( "No template", Template::Constants::STATUS_ERROR );
    }

    # is this an anonymous template? if so, return it

    # Note: it would be cool if we could figure out where 'name' is
    # passed to and have it deal with references properly, and then
    # propogate that reference through to processing, etc.

    if ( ref( $content ) eq 'SCALAR' ) {
        $log->is_debug &&
            $log->debug( "Nothing to load: template is scalar ref." );
        return ({ name => $name,
                  text => $$content,
                  time => time,
                  load => 0 }, undef );
    }

    if ( ref( $content ) eq 'GLOB' ) {
        $log->is_debug &&
            $log->debug( "Load template from glob (file) ref" );
        local $/ = undef;
        return ({ name => 'file handle',
                  text => <$content>,
                  time => time,
                  load => 0 }, undef );
    }

    my ( $content_template, $data );
    eval {
        $content_template =
            CTX->lookup_class( 'template' )->fetch( $name );
        unless ( $content_template ) {
            die "Template with name [$name] not found.\n";
        }
        $data = { 'name' => $content_template->full_filename,
                  'text' => $content_template->contents,
                  'time' => $content_template->modified_on->epoch,
                  'load' => time };

    };
    if ( $@ ) {
        return ( $@, Template::Constants::STATUS_ERROR );
    }
    return ( $data, undef );
}


# Override so we can use OI-configured value for seeing whether we
# need to refresh

sub _refresh {
	my ( $self, $slot ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );

    $log->is_debug && $log->debug( "_refresh([ @$slot ])" );

    # If the cache time has expired reload the entry

    my $do_reload = 0;
    my $tt_config = CTX->lookup_content_generator_config( 'TT' );
    my $max_cache_time = $tt_config->{cache_expire}
                         || DEFAULT_MAX_CACHE_TIME;
	my ( $data, $error );
    my $elapsed_time = $slot->[ DATA ]->{time} - time;
	if ( $elapsed_time > $max_cache_time ) {
        $log->is_debug &&
            $log->debug( "Doing refresh for ", $slot->[ NAME ], " ",
                         "because $elapsed_time > $max_cache_time" );
        ( $data, $error ) = $self->_load( $slot->[ NAME ] );
        unless ( $error ) {
            ( $data, $error ) = $self->_compile( $data );
            unless ( $error ) {
                $slot->[ DATA ] = $data->{data};
                $slot->[ LOAD ] = $data->{time};
            }
        }
	}

	# remove existing slot from usage chain...

    unless( $self->{ HEAD } == $slot ) {
        if ( $slot->[ PREV ] ) {
            $slot->[ PREV ][ NEXT ] = $slot->[ NEXT ];
        }
        else {
            $self->{HEAD} = $slot->[ NEXT ];
        }
        if ( $slot->[ NEXT ] ) {
            $slot->[ NEXT ][ PREV ] = $slot->[ PREV ];
        }
        else {
            $self->{TAIL} = $slot->[ PREV ];
        }

        # ... and add to start of list
        my $head = $self->{HEAD};
        $head->[ PREV ] = $slot if ( $head );
        $slot->[ PREV ] = undef;
        $slot->[ NEXT ] = $head;
        $self->{HEAD} = $slot;
    }

	return ( $data, $error );
}


# Ensure there aren't any funny characters

sub _validate_template_name {
    my ( $self, $name ) = @_;
    if ( $name =~ m|\.\.| ) {
        die "Template name must not have any directory tree symbols (e.g., '..')";
    }
    if ( $name =~ m|^/| ) {
        die "Template name must not begin with an absolute path symbol";
    }
    return 1;
}

########################################
# ANONYMOUS TEMPLATE NAME

# store names for non-named templates by using a unique fingerprint of
# the template text as a hash key

my $ANON_NUM      = 0;
my %ANON_TEMPLATE = ();

sub _get_anon_name {
	my ( $self, $text ) = @_;
    my $key = Digest::MD5::md5_hex( ref( $text ) ? $$text : $text );
	return $ANON_TEMPLATE{ $key } if ( exists $ANON_TEMPLATE{ $key } );
	return $ANON_TEMPLATE{ $key } = 'anon_' . ++$ANON_NUM;
}


1;

__END__

=head1 NAME

OpenInteract2::TT2::Provider - Retrieve templates for the Template Toolkit

=head1 SYNOPSIS

 $Template::Config::CONTEXT = 'OpenInteract2::TT2::Context';
 my $template = Template->new(
                       COMPILE_DIR    => '/tmp/ttc',
                       COMPILE_EXT    => '.ttc',
                       LOAD_TEMPLATES => [ OpenInteract2::TT2::Provider->new ] );
 my ( $output );
 $template->process( 'package::template', \%params, \$output );

=head1 DESCRIPTION

B<NOTE>: As shown above, you need to use
L<OpenInteract2::TT2::Context|OpenInteract2::TT2::Context> as a
context for your templates since our naming scheme ('package::name')
collides with the TT naming scheme for specifying a prefix before a
template.

This package is a provider for the Template Toolkit while running
under OpenInteract. Being a provider means that TT hands off any
requests for templates to this class, which has OpenInteract-specific
naming conventions (e.g., 'package::template') and knows how to find
templates in the sitewide package template directory or the normal
package template directory

=head1 METHODS

All of the following are object methods and have as the first argument
the object itself.

B<fetch( $text )>

Overrides L<Template::Provider|Template::Provider>.

Uses C<$text> to somehow retrieve a template. The actual work to
retrieve a template is done in C<_load()>, although this method
ensures that the template name is 'safe' and creates a name we use to
save the compiled template.

Returns a two-element list: the first is a compiled template, the
second is an error message. (Of course, if there is no error the
second item will be undefined.)

B<_load( $name, $content )>

Loads the template content, returning a two-element list. The first
item in the list is the TT hashref, the second is an error message.

We try three ways to retrieve a template, in this order:

=over 4

=item 1.

B<scalar reference>: If the template is a scalar reference it does not
need to be retrieved, so we just put C<$content> in the TT hashref
structure as the data to process and return it.

=item 2.

B<glob reference>: If the template is a glob reference we treat it as
a filehandle and read all data from C<$content> in the TT hashref
structure as the data to process as return it.

=item 3.

B<filesystem template>: Templates can be stored in the filesystem. If
a template does not use C<$package> it can be found under
C<$WEBSITE_DIR/template>; if it does, it can be found under
C<$WEBSITE_DIR/template/$package> or
C<$WEBSITE_DIR/pkg/$package-version/template>, in that order.

=back

B<_refresh( $cache_slot )>

Called when we use C<$cache_slot> for a template. This refreshes the
time of the slot and brings it to the head of the LRU cache.

You can tune the expiration time of the cache by setting the key:

 {cache}{template}{expire}

in your server configuration file to the amount of time (in seconds)
to keep an entry in the cache.

B<_validate_template_name( $full_template_name )>

Ensures that C<$full_template_name> does not have any tricky
filesystem characters (e.g., '..') in it.

B<_get_anon_name( $text )>

If we get an anonymous template to provide, we need to create a unique
name for it so we can compile and cache it properly. This method
returns a unique name based on C<$text>.

=head1 BUGS

None known.

=head1 TO DO

B<Testing>

Needs more testing in varied environments.

=head1 SEE ALSO

L<Template|Template>

L<Template::Provider|Template::Provider>

Slashcode L<http://www.slashcode.com/|http://www.slashcode.com/>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

Robert McArthur E<lt>mcarthur@dstc.edu.auE<gt>

Authors of Slashcode L<http://www.slashcode.com/|http://www.slashcode.com/>
