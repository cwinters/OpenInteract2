package OpenInteract2::Manage::Website::ThemeDump;

# $Id: ThemeDump.pm,v 1.10 2005/03/17 14:58:04 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Data::Dumper;
use OpenInteract2::Context qw( CTX );


$OpenInteract2::Manage::Website::ThemeDump::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'dump_theme';
}

sub get_brief_description {
    return 'Dump a theme to a distributable format';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        theme_id => {
            description => 'ID of theme to export',
            is_required => 'yes',
        },
        theme_file => {
            description => 'Name of file to export the theme to',
            is_required => 'yes',
        },
    };
}

# We don't validate theme_id until run_task() since context isn't yet
# created

sub run_task {
    my ( $self ) = @_;
    my $action = 'dump theme';

    my $theme_id = $self->param( 'theme_id' );
    my $theme = eval {
        CTX->lookup_object( 'theme' )->fetch( $theme_id )
    };
    if ( $@ ) {
        $self->_fail( $action, "Error fetching theme '$theme_id': $@" );
        return;
    }

    my $properties = eval { $theme->themeprop };
    if ( $@ ) {
        $self->_fail( $action, "Error fetching theme properties: $@" );
        return;
    }

    my @structure = (
         { theme_fields      => [ qw( title description credit ) ],
           theme_prop_fields => [ qw( prop value description ) ] },
         [ $theme->title, $theme->description, $theme->credit ]
    );

    foreach my $prop ( @{ $properties } ) {
        push @structure, [ $prop->prop, $prop->value, $prop->description ];
    }

    my $filename = $self->param( 'theme_file' );
    eval { open( THEMEBALL, '>', $filename  ) || die $! };
    if ( $@ ) {
        $self->_fail( $action,
                      "Could not open themeball file '$filename': $@" );
        return;
    }
    print THEMEBALL Data::Dumper->Dump( [ \@structure ], [ 'themeball' ] );
    close THEMEBALL;
    $self->_ok( $action, "Themeball saved ok",
                filename => $filename );
    return;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ThemeDump - Dump a theme to a themeball

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'dump_theme', { website_dir => $website_dir,
                     theme_id    => 5,
                     theme_file  => 'my_themeball' } );
 my $status = $task->execute;
 print "Dumped?  $status->{is_ok}\n",
       "Filename $status->{filename}\n",
       "$status->{message}\n";
 }

=head1 DESCRIPTION

This task dumps a theme to a "themeball" which can be installed to
any other OpenInteract system.

=head1 REQUIRED OPTIONS

In addition to 'website_dir' you must define:

=over 4

=item B<theme_id>=$

ID of theme you want to dump

=item B<theme_file>=$

Filename for dumped theme (will be overwritten if it exists).

=back

=head1 STATUS MESSAGES

In addition to the normal entries, each status hashref includes:

=over 4

=item B<filename>

Set to the filename used for the dump; empty if the action failed.

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
