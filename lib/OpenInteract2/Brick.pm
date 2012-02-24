package OpenInteract2::Brick;

# $Id: Brick.pm,v 1.7 2005/10/22 22:11:14 lachoy Exp $

use strict;
use base qw( Class::Factory );
use File::Basename           qw( basename dirname );
use File::Path               qw( mkpath );
use File::Spec::Functions    qw( catfile );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config::Readonly;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Util;
use Template;

$OpenInteract2::Brick::VERSION  = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

# Docs are up here because parsers get confused by the included class
# below...

=pod

=head1 NAME

OpenInteract2::Brick - Base class for inlined data packages

=head1 SYNOPSIS

 use OpenInteract2::Brick;
 
 my $loader = OpenInteract2::Brick->new( 'apache' );
 my @resources = $loader->list_resources;
 print "Resources available in 'Apache': ",
       join( ', ', @resources ), "\n";
 
 my $httpd_static_info = $loader->load_resource( 'httpd_static.conf' );
 print "File should be stored in: $httpd_static_info->{destination}\n";
 print "File contents:\n$httpd_static_info->{content}\n";

=head1 DESCRIPTION

Rather than including lots of sample files used to create packages and
websites, OI2 has a set of 'bricks'. Each one of these classes has one
or more inlined files you can ask for by file name. Each of these
files also has associated with it some metadata to determine where it
should go and whether it should be evaluated as a template before
being stored. (Of course, you're free to ignore these data and do
whatever you want with the contents, but other parts of the OI2
framework need them.)

=head1 CLASS METHODS

B<new( $type )>

Returns an instance of the bricks associated with C<$type>, which
should always be a lowercased value.

B<list_bricks()>

Returns a sorted list of all available brick names. With the name you
can instantiate a new brick:

 my @brick_names = OpenInteract2::Brick->list_bricks;
 foreach my $name ( @brick_names ) {
     my $brick = OpenInteract2::Brick->new( $name );
     print "Resources in brick '$name': ",
           join( ", ", $brick->list_resources ), "\n";
 }

=head1 OBJECT METHODS

B<list_resources()>

Returns an array of all resources defined. These are always simple
filenames with no paths, so with the 'apache2' type you would do
something like:

 my $loader = OpenInteract2::Brick->new( 'apache2' );
 print "Apache2 resources:\n  ",
       join( "\n  ", $loader->list_resources ), "\n";

And get:

 Apache2 resources:
   httpd_mp2_solo.conf
   startup_mp2.pl

These resource names are what you use in C<load_resource()>:

 my $startup_info = $loader->load_resource( 'startup_mp2.pl' );
 print "Startup script is:\n", $startup_info->{contents};

B<load_resource( $resource_name >

Loads the resource and metdata associated with C<$resource_name>. If
C<$resource_name> is empty or no resource is actually associated with
it we throw an exception.

If the resource is found we return a hashref with the following keys:

=over 4

=item *

B<content>: Contents of the resource.

=item *

B<destination>: Space-delimited string of directories where this
resource should be copied. Note that the string may have template
directives in it.

=item *

B<evaluate>: Whether you should evaluate the data in 'content' before
storing it.

=back

Regarding template directives. A number of resources have template
directives in them so they can be properly named -- for instance, the
perl 'package' declaration in the generated action whene you create a
new package looks like this:

 package OpenInteract2::Action::[% class_name %];

When we use this resource we first run it through a template processor
(Template Toolkit) so that when we create a package called
'baseball_stats' the above will get translated to:

 package OpenInteract2::Action::BaseballStats;

B<copy_all_resources_to( $destination_dir, [ \%token_replacements ] )>

Copies all resources from this brick to C<$destination_dir>. See
L<copy_resources_to()> for more.

Returns: hashref with keys 'copied', 'skipped', 'same' each of which
has as its value an arrayref of the relevant files.

B<copy_resources_to( $destination_dir, \%token_replacements, @resource_names )>

Copies the resources with C<@resource_names> to the given
C<$destination_dir>. For those resources that are evaluatable use the
C<\%token_replacements> when evaluating as Template Toolkit templates.

If the source and destination are the same -- checked by the content
size and MD5 digest -- we don't do a copy.

We also don't do a copy if the resource is specified in the
directory's has a '.no_overwrite' file. (See
L<OpenInteract2::Config::Readonly> for this file's format and how we
use it.)

Returns: hashref with keys 'copied', 'skipped', 'same' each of which
has as its value an arrayref of the relevant files.

=head1 SUBCLASSING

Since you typically don't create subclasses by hand this is mostly
unnecessary. If you're interested in creating a C<::Brick> subclass by
hand first look in the C<build_bricks> script found at the root of the
OI2 source tree -- it builds the class dynamically based on
specifications and files found in the filesystem.

That said, subclasses must implement the following methods:

B<get_name()>

Return the name by which people instantiate this loader. Should be
lower-cased.

B<get_resources()>

Return a hash of data regarding the resources specified by this
class. Keys are resource names (generally filenames) and values are
arrayrefs with two elements:

=over 4

=item 0.

String with destination information. This tells the caller where the
contents should be stored. Should be space-delimited and may have
template directives in it.

=item 1.

Whether the content can be evaluated by a template processor as 'yes'
or 'no'. Generally you should leave this as 'yes' unless the specified
resource is actually a TT2 template.

=back

B<load( $resource_name )>

Return the content associated with C<$resource_name>. The caller
(L<OpenInteract2::Brick> checks that C<$resource_name> is valid before
invoking this method.

=head1 SEE ALSO

L<Class::Factory>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut


my $TEMPLATE = Template->new();

my ( $log );

sub list_bricks {
    my ( $class ) = @_;
    return $class->get_registered_types;
}

sub list_resources {
    my ( $self ) = @_;
    my %all_resources = $self->get_resources;
    return sort keys %all_resources;
}

sub load_resource {
    my ( $self, $name ) = @_;
    unless ( $name ) {
        oi_error "You must specify a resource name to load.";
    }
    my %all_resources = $self->get_resources;
    my $info = $all_resources{ $name };
    unless ( $info ) {
        oi_error "Resource '$name' is invalid. Valid resources are: ",
                 join( ', ', sort keys %all_resources );
    }
    $info->[1] ||= 'yes';
    return {
        content     => $self->load( $name ),
        destination => $info->[0],
        evaluate    => $info->[1],
    };
}

sub copy_all_resources_to {
    my ( $self, $dest_dir, $template_vars ) = @_;
    return $self->copy_resources_to(
        $dest_dir, $template_vars, $self->list_resources
    );
}

sub copy_resources_to {
    my ( $self, $dest_dir, $template_vars, @resource_names ) = @_;
    $log ||= get_logger( LOG_INIT );

    $template_vars ||= {};

    my @copied  = ();
    my @skipped = ();
    my @same    = ();

NAME:
    foreach my $name ( @resource_names ) {
        my $info = $self->load_resource( $name );
        # First process any template keys in the destination...
        my ( $final_dest_spec );
        $TEMPLATE->process( \$info->{destination}, $template_vars, \$final_dest_spec )
            || oi_error "Cannot process destination '$info->{destination}': ",
                        $TEMPLATE->error();
        $log->is_info && $log->info( "Translated '$info->{destination}' ",
                                     "-> $final_dest_spec" );
        my @dest_spec      = split( /\s+/, $final_dest_spec );
        my $relative_dest  = join( '/', @dest_spec );
        my $full_dest_file = catfile( $dest_dir, @dest_spec );

        if ( $self->_is_readonly( $full_dest_file ) ) {
            $log->is_info &&
                $log->info( "Skipping '$full_dest_file', marked ",
                            "as readonly in the destination directory" );
            push @skipped, $full_dest_file;
            next NAME;
        }

        # ...next, evaluate the content if we're supposed to
        my $content = $info->{content};
        unless ( 'no' eq lc $info->{evaluate} ) {
            my ( $new_content );
            $template_vars->{source_template} = $name;
            $TEMPLATE->process( \$content, $template_vars, \$new_content )
                || oi_error "Cannot copy and replace tokens from resource '$name': ",
                            $TEMPLATE->error();
            $log->is_info && $log->info( "Processed template ok" );
            $content = $new_content;
        }

        if ( $self->_is_same( $full_dest_file, $content ) ) {
            $log->is_info &&
                $log->info( "Skipping '$full_dest_file', content and ",
                            "destination file are the same" );
            push @same, $full_dest_file;
            next NAME;
        }

        my $dest_dir = dirname( $full_dest_file );
        unless ( -d $dest_dir ) {
            mkpath( $dest_dir );
        }
        open( OUT, '>', $full_dest_file )
            || oi_error "Cannot write resource '$name' to '$full_dest_file': $!";
        print OUT $content;
        close( OUT );
        $log->is_info &&
            $log->info( "Copied resource '$name' to '$full_dest_file' ok" );
        push @copied, $full_dest_file;
    }
    return {
        copied  => \@copied,
        skipped => \@skipped,
        same    => \@same,
    };
}

sub _is_readonly {
    my ( $self, $dest_file ) = @_;
    return 0 unless ( -f $dest_file );
    my $base_dest_file = basename( $dest_file );
    my $full_dest_dir  = dirname( $dest_file );
    my $ro_check = OpenInteract2::Config::Readonly->new( $full_dest_dir );
    return ( ! $ro_check->is_writeable( $base_dest_file ) );
}

sub _is_same {
    my ( $self, $dest_file, $content ) = @_;
    return 0 unless ( -f $dest_file );
    my $source_size = length $content;
    my $dest_file_size   = (stat $dest_file)[7];
    return 0 unless ( $source_size == $dest_file_size );
    my $source_digest =
        OpenInteract2::Util->digest_content( $content );
    my $dest_digest   =
        OpenInteract2::Util->digest_file( $dest_file );
    return ( $source_digest eq $dest_digest );
}

########################################
# SUBCLASSES

sub get_name      { _must_implement( 'get_name', @_ ) }
sub get_resources { _must_implement( 'get_resources', @_ ) }
sub load          { _must_implement( 'load', @_ ) }

sub _must_implement {
    my ( $method, $item ) = @_;
    my $class = ref( $item ) || $item;
    oi_error "Class '$class' must implement method '$method'";
}

OpenInteract2::Util->find_factory_subclasses(
    'OpenInteract2::Brick', @INC
);

########################################
# GENERATING NEW BRICKS

sub get_brick_class_template {
    return <<'TEMPLATE';
# This OpenInteract2 file was generated
#   by:    [% invocation %]
#   on:    [% date %]
#   from:  OpenInteract2::Brick->get_brick_class_template()
#   using: OpenInteract2 version [% oi2_version %]

package OpenInteract2::Brick::[% brick_name %];

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
[% FOREACH file_info = all_files -%]
    '[% file_info.name %]' => '[% file_info.inline_name %]',
[% END -%]
);

sub get_name {
    return '[% lc_brick_name %]';
}

sub get_resources {
    return (
[% FOREACH file_info = all_files -%]
        '[% file_info.name %]' => [ '[% file_info.destination %]', '[% file_info.evaluate %]' ],
[% END -%]
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

OpenInteract2::Brick::[% brick_name %] - [% brick_summary %]

=head1 SYNOPSIS

[% brick_example | indent(2) %]

=head1 DESCRIPTION

[% brick_description %]

=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4

[% FOREACH file_info = all_files %]
=item B<[% file_info.name %]>
[% END %]

=back

=head1 COPYRIGHT

Copyright (c) 2005 [% author_names.join( ', ' ) %]. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

[% FOREACH author_info = authors %]
[% author_info.name %] E<lt>[% author_info.email %]E<gt>
[% END %]

=cut

[% FOREACH file_info = all_files %]
sub [% file_info.inline_name %] {
    return <<'SOMELONGSTRING';
[% file_info.contents %]
SOMELONGSTRING
}
[% END %]
TEMPLATE
}

1;
