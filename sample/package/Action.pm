# This OpenInteract2 file was generated
#   by:    [% invocation %]
#   on:    [% date %]
#   from:  [% source_template %]
#   using: OpenInteract2 version [% oi2_version %]

package OpenInteract2::Action::[% class_name %];

# This is a sample action. It exists only to provide a template for
# you and some notes on what these configuration variables mean.

use strict;

# All actions subclass OI2::Action or one of its subclasses

use base qw( OpenInteract2::Action );

# You almost always use these next three lines -- the first imports
# the logger, the second logging constants, the third the context

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

# Use whatever standard you like here -- it's always nice to let CVS
# deal with it :-)

$OpenInteract2::Action::[% class_name %]::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

# Here's an example of the simplest response...

sub hello {
    my ( $self ) = @_;
    return 'Hello world!';
}


# Here's a more complicated example -- this will just display all the
# content types in the system.

sub list {
    my ( $self ) = @_;

 # This will hold the data you're passing to your template

    my %params = ();

 # Retrieve the class corresponding to the 'content_type' SPOPS
 # object...

    my $type_class = CTX->lookup_object( 'content_type' );
    $params{content_types} = eval { $type_class->fetch_group() };

 # If we've encountered an error in the action, add the error message
 # to it. The template has a component to find the errors encountered
 # and display them

    if ( $@ ) {
        $self->param_add( error_msg => "Failed to fetch content types: $@" );
    }

 # The template also has a component to display a status
 # message. (This is a silly status message, but it's just an
 # example...)

    else {
        my $num_types = scalar @{ $params{content_types} };
        $self->param_add( status_msg => "Fetched $num_types types successfully" );
    }

 # Every action should return content. It can do this by generating
 # content itself or calling another action to do so. Here we're doing
 # it ourselves.

    return $self->generate_content(
                    \%params, { name => '[% package_name %]::sample' } );
}

1;
