package OpenInteract2::ContentGenerator;

# $Id: ContentGenerator.pm,v 1.16 2005/03/18 04:09:48 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::ContentGenerator::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

# Each value in %GENERATOR is a singleton for a particular content
# generator, retrieved via instance()

my %GENERATOR = ();

my ( $log );

########################################
# FACTORY

sub add_generator {
    my ( $class, $name, $generator ) = @_;
    $GENERATOR{ $name } = $generator;
}

sub instance {
    my ( $class, $name ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    unless ( exists $GENERATOR{ $name } ) {
        my $msg = "Content generator '$name' was never initialized";
        $log->error( $msg );
        oi_error $msg;
    }
    return $GENERATOR{ $name };

}

########################################
# CONSTRUCTOR (internal)

sub new {
    my ( $pkg, $name, $gen_class ) = @_;
    my ( $package, @etc ) = caller;
    unless ( $package eq __PACKAGE__ ||
             $package eq 'OpenInteract2::Setup::InitializeContentGenerators' ) {
        oi_error "Cannot call 'new()' from anywhere except " . __PACKAGE__ . " " .
                 "or the relevant ::Setup action.";
    }
    return bless( { name  => $name,
                    class => $gen_class }, $pkg );
}


########################################
# READ-ONLY ACCESSORS

sub name  { return $_[0]->{name} }
sub class { return $_[0]->{class} }


########################################
# SUBCLASSES OVERRIDE

sub initialize { return }

sub generate {
    my ( $self ) = @_;
    oi_error "Class ", ref( $self ), " must implement 'generate()'";
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator - Coordinator for classes generating content

=head1 SYNOPSIS

 # In server startup
 
 OpenInteract2::ContentGenerator->initialize_all_generators;

 # Whenever you want a generator use either of these. (This is handled
 # behind the scenes in OI2::Action->generate_content for most uses.)
 
 my $generator = OpenInteract2::ContentGenerator->instance( 'TT' );
 my $generator = CTX->content_generator( 'TT' );
 
 # Every content generator implements 'generate()' which marries the
 # parameters with the template source and returns content
 
 $content = $generator->generate( \%template_params,
                                  \%content_params,
                                  \%template_source );

=head1 DESCRIPTION

This is a simple coordinating front end for the classes that actually
generate the content -- template processors, SOAP response generators,
etc. (You could probably put some sort of image generation in here
too, but that would be mad.)

=head1 METHODS

=head2 Class Methods

B<instance( $generator_name )>

Return an object representing the given content generator. If
C<$generator_name> is not found an exception is thrown.

Returns: an object with 
L<OpenInteract2::ContentGenerator|OpenInteract2::ContentGenerator>
as a parent.

=head2 Subclass Implementation Methods

B<initialize( \%configuration_params )>

Object method that gets called only once. Since this is normally at
server startup you can execute processes that are fairly intensive if
required.

This may seem like it should be a class method but since each
generator is a singleton it's an object method. As a result you can
save state that may be used by your generator many times throughout
its lifecycle. Note that it is not cleared out per-request, so the
data it stores should not be specific to a particular user or session.

The C<\%configuration_params> are pulled from the respective
'content_generator' section of the server configuration. So if you
had:

 [content_generator Foo]
 class     = OpenInteract2::ContentGenerator::Foo
 max_size  = 2000
 cache_dir = /tmp/foo

You would get the following hashref passed into
C<OpenInteract2::ContentGenerator::Foo>-E<gt>C<initialize>:

 {
   class     => 'OpenInteract2::ContentGenerator::Foo',
   max_size  => '2000',
   cache_dir => '/tmp/foo',
 }

You may also store whatever data in the object hashref required. The
parent class only uses 'name' and 'class', so as long as you keep away
from them you have free rein.

B<generate( \%template_params, \%content_params, \%template_source )>

Actually generates the content. This is the fun part!

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
