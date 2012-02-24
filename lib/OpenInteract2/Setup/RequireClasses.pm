package OpenInteract2::Setup::RequireClasses;

# $Id: RequireClasses.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_INIT );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Util;

$OpenInteract2::Setup::RequireClasses::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'require classes';
}

sub execute {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $type = $self->param( 'classes_type' ) || 'Class';
    my @to_require = $self->_find_classes_to_require;
    $log->is_debug &&
        $log->debug( "$type to require: ", join( ', ', @to_require ) );
    foreach my $require_class ( @to_require ) {
        next unless ( $require_class );
        eval "require $require_class";
        if ( $@ ) {
            oi_error "$type: failed to require class '$require_class': $@";
        }
        $log->is_debug && $log->debug( "$type: $require_class: require ok" );
    }
    $self->param( required_classes => \@to_require );
}

sub _find_classes_to_require {
    my ( $self ) = @_;

    if ( my $class_file = $self->param( 'classes_file' ) ) {
        $self->param(
            classes => OpenInteract2::Util->read_file_lines( $class_file ) );
    }

    # Value in 'classes' can be single class or arrayref of classes
    my $tmp_to_require = $self->param( 'classes' );
    return () unless ( $tmp_to_require );
    my $typeof = ref $tmp_to_require;
    return () if ( $typeof and $typeof ne 'ARRAY' );
    return ( ref $tmp_to_require eq 'ARRAY' )
             ? @{ $tmp_to_require }
             : ( $tmp_to_require );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::RequireClasses - Bring in one or a set of classes

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'require classes' );
 # declare one at a time...
 $setup->param( classes => 'Foo::Bar' );
 
 # an arrayref...
 $setup->param( classes => [ 'Foo::Bar', 'Foo::Baz' ] );
 
 # or from a file... (one class per line)
 $setup->param( classes_file => 'my_foo_classes.txt' );
 $setup->run();

 # Typical inlined usage from other setup classes
 my $req = OpenInteract2::Setup->new(
      'require classes',
      classes      => [ keys %uniq_classes ],
      classes_type => 'Action classes',
 )->run();
 
 # Report on what was done
 print "I brought in the following classes: ",
       join( ', ', @{ $req->param( 'required_classes' ) } );

=head1 DESCRIPTION

This setup action simply brings in a set of classes. The classes to
bring in are found in one of two parameters:

=over 4

=item *

B<classes>: May be a single class or an arrayref of multiple classes.

=item *

B<classes_file>: File listing classes to bring in, one class per line.

=back

You can also specify the parameter C<classes_type> to be used in any
error message, which will look like this:

 $CLASSES_TYPE: failed to require class '$SOME_CLASS': $ERROR

=head2 Subclassing

A useful strategy for a setup task whose only job is to bring in
classes is to subclass this class and only implement B<setup()> to set
the B<classes> parameter. See L<OpenInteract2::Setup::RequireIndexers>
as an example.

=head2 Setup Metadata

B<name> - 'require classes'

B<dependencies> - default

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
