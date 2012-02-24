package OpenInteract2::Manage::Website::ListObjects;

# $Id: ListObjects.pm,v 1.10 2005/03/17 14:58:04 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Setup;

$OpenInteract2::Manage::Website::ListObjects::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'list_objects';
}

sub get_brief_description {
    return 'List SPOPS objects available in a website';
}

# get_parameters() inherited from parent

sub run_task {
    my ( $self ) = @_;
    my $spops_config = CTX->spops_config;
OBJECT:
    foreach my $alias ( sort keys %{ $spops_config } ) {
        next OBJECT unless ( $alias and $alias !~ /^_/ );
        my $object_info = $spops_config->{ $alias };
        my @alias_list = ( $alias );
        if ( ref $object_info->{alias} eq 'ARRAY' ) {
            push @alias_list, @{ $object_info->{alias} };
        }
        $self->_ok(
            'OpenInteract2 SPOPS object',
            "SPOPS object $alias is a $object_info->{class}",
            name  => $alias,
            alias => \@alias_list,
            class => CTX->lookup_object( $alias ),
            isa   => $object_info->{isa},
            rule  => $object_info->{rules_from}
        );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ListObjects - Task to list all SPOPS objects in a website

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'list_objects', { website_dir => $website_dir });
 my @status = $task->execute;
 foreach my $s ( @status ) {
     print "Object [[$s->{name}]]\n",
           "Aliases:  ", join( ", ", $s->{alias} ), "\n",
           "Class:    $s->{class}\n",
           "ISA:      ", join( ", ", $s->{isa} ), "\n",
           "Rules:    ", join( ", ", $s->{rule} ), "\n";
 }

=head1 DESCRIPTION

Task to list all the objects currently known in a website.

=head1 STATUS MESSAGES

In addition to the default entries, each status hashref includes:

=over 4

=item B<name>

Name of the object (also the first alias)

=item B<alias> (\@)

All aliases by which this object is known

=item B<class>

Class used for object

=item B<isa> (\@)

Contents of the configuration 'isa'

=item B<rule> (\@)

Contents of the configuration 'rule_from'

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
