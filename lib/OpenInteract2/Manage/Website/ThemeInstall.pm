package OpenInteract2::Manage::Website::ThemeInstall;

# $Id: ThemeInstall.pm,v 1.12 2005/03/17 14:58:04 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Data::Dumper;
use OpenInteract2::Context qw( CTX );

$OpenInteract2::Manage::Website::ThemeInstall::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'install_theme';
}

sub get_brief_description {
    return 'Install a theme dumped from a website to your website';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        theme_file => {
            description => 'Name of file to import the theme from',
            is_required => 'yes',
        },
    };
}

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'theme_file' ) {
        unless ( $value and -f $value ) {
            return "Must be a valid filename";
        }
        my $data = eval { _open_file( $value ) };
        if ( $@ ) {
            return "Error parsing file: $@";
        }
        $self->param( theme_data => $data );
    }
    return $self->SUPER::validate_param( $name, $value );
}


sub run_task {
    my ( $self ) = @_;
    my $action = 'install theme';

    my $themeball = $self->param( 'theme_data' );
    my $theme_meta = shift @{ $themeball };
    my $theme_data = $self->_map_fields(
        $theme_meta->{theme_fields}, shift @{ $themeball }
    );

    my $default_parent = CTX->lookup_default_object_id( 'theme' );
    $theme_data->{parent} = $default_parent;

    my ( $theme );
    eval {
        $theme = CTX->lookup_object( 'theme' )->new( $theme_data );
        $theme->save;
    };
    if ( $@ ) {
        $self->_fail( $action, "Cannot save theme: $@" );
        return;
    }

    my $theme_id = $theme->id;
    my $themeprop_class = CTX->lookup_object( 'themeprop' );
    my $props = 0;
    foreach my $prop_raw ( @{ $themeball } ) {
        my $prop_data = $self->_map_fields(
            $theme_meta->{theme_prop_fields}, $prop_raw
        );
        my $prop = $themeprop_class->new( $prop_data );
        $prop->{theme_id} = $theme_id;
        eval { $prop->save };
        $props++;
    }
    $self->_ok( $action,
                "New theme (ID: $theme_id) and $props properties saved ok" );
    return;
}


sub _map_fields {
    my ( $self, $fields, $data ) = @_;
    my %map = ();
    for ( my $i = 0; $i < scalar @{ $fields }; $i++ ) {
        $map{ $fields->[ $i ] } = $data->[ $i ];
    }
    return \%map;
}


sub _open_file {
    my ( $theme_file ) = @_;
    eval { open( THEMEBALL, "< $theme_file" ) || die $! };
    die "cannot open - $@" if ( $@ );

    local $/ = undef;
    my $contents = <THEMEBALL>;
    my ( $data );
    {
        no strict 'vars';
        $data = eval $contents;
        die "invalid data - $@" if ( $@ );
    }
    close( THEMEBALL );
    return $data;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ThemeInstall - Install a theme from a themeball

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'install_theme', { website_dir => $website_dir,
                        theme_file  => 'my_themeball' });
 my $status = $task->execute;
 print "Installed?  $status->{is_ok}\n",
       "$status->{message}\n";
 }

=head1 DESCRIPTION

This task installs a theme from a "themeball", dumped using the
'dump_theme' task.

=head1 REQUIRED OPTIONS

In addition to 'website_dir' you must define:

=over 4

=item B<theme_file>=$

Filename of dumped theme to install.

=back

=head1 STATUS MESSAGES

No additional entries in the status messages.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
