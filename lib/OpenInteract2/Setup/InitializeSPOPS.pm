package OpenInteract2::Setup::InitializeSPOPS;

# $Id: InitializeSPOPS.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Initialize;

$OpenInteract2::Setup::InitializeSPOPS::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'initialize spops';
}

sub get_dependencies {
    return ( 'read spops config' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $spops_config = $ctx->spops_config;
    my $classes = SPOPS::Initialize->process({
        config => $spops_config
    });
    my $num_classes = ( ref $classes ) ? scalar @{ $classes } : 0;
    if ( $num_classes > 0 ) {
        $log->info( "Initialized $num_classes SPOPS classes" );
        $log->debug( "Specific SPOPS classes initialized: ",
                     join( ", ", @{ $classes } ) );
        my @alias_classes = ();
        for ( values %{ $spops_config } ) {
            my $alias_class = $_->{alias_class};
            push @alias_classes, $alias_class if ( $alias_class );
        }
        my $req = OpenInteract2::Setup->new(
            'require classes',
            classes      => \@alias_classes,
            classes_type => 'SPOPS implementations'
        )->run();
        my $req_alias = $req->param( 'required_classes' );
        $log->info( "Brought in ", scalar( @{ $req_alias } ), " SPOPS ",
                    "implementation classes (aka, 'alias classes'): ",
                    join( ', ', @{ $req_alias } ) );
    }
    else {
        $log->error( "No SPOPS classes initialized!" );
    }
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::InitializeSPOPS - Initialize SPOPS classes

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'initialize spops' );
 $setup->run();

=head1 DESCRIPTION

This setup action passes the SPOPS configuration (returned by the
context method C<spops_config()> to C<process()> in
L<SPOPS::Initialize>. This generates the SPOPS classes into existence.

We also C<require()> any referenced C<alias_class> keys from the SPOPS
configuration. This is useful for when you want to add behavior to a
generated SPOPS class. So you'd declare it like this:

 [myobject]
 class       = OpenInteract2::MyObjectPersist
 alias_class = OpenInteract2::MyObject

And then implement it:

 package OpenInteract2::MyObject
 
 use strict;
 @OpenInteract::MyObject::ISA = qw( OpenInteract::MyObjectPersist );
 
 sub some_custom_method { ... }

The class 'OpenInteract2::MyObject' is what's returned when you call
C<lookup_object()> on the context:

 my $object_class = CTX->lookup_object( 'myobject' );
 # $object_class is now 'OpenInteract2::MyObject'
 $object_class->some_custom_method;

=head2 Setup Metadata

B<name> - 'initialize spops'

B<dependencies> - 'read spops config'

=head1 SEE ALSO

L<SPOPS::Initialize>

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
