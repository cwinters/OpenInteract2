package OpenInteract2::Conversion::SPOPSConfig;

# $Id: SPOPSConfig.pm,v 1.9 2005/03/17 14:58:01 sjn Exp $

use strict;
use base qw( OpenInteract2::Conversion::IniConfig );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Conversion::SPOPSConfig::VERSION  = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);
my @ORDER = qw( class code_class isa field field_discover id_field
                is_secure increment_field convert_date_field
                sequence_name no_insert skip_undef no_update
                base_table sql_defaults object_name name
                has_a links_to creation_security track display );

sub get_field_order {
    return \@ORDER;
}

sub init {
    my ( $self ) = @_;
    $self->transforms({ isa               => \&_modify_isa,
                        track             => \&_modify_track,
                        creation_security => \&_modify_creation_security,
                        increment_field   => \&_modify_true_to_yes,
                        class             => \&_modify_oi_to_oi2,
                        code_class        => \&_modify_oi_to_oi2 } );
    return $self;
}

sub pre_transform_check {
    my ( $self, $config ) = @_;
    unless ( ref $config->{isa} eq 'ARRAY' and scalar @{ $config->{isa} } ) {
        return $config;
    }
    if ( grep /^SPOPS::Secure$/, @{ $config->{isa} } ) {
        $config->{is_secure} = 'yes';
    }
    return $config;
}

my @ISA_REMOVE =  qw( ^OpenInteract::SPOPS
                      ^SPOPS::DBI
                      ^SPOPS::LDAP
                      ^SPOPS::Secure
                      ^SPOPS::Utility );

sub _modify_isa {
    my ( $name, $value ) = @_;
    unless ( ref $value eq 'ARRAY' and scalar @{ $value } ) {
        return ( $name, $value );
    }
    my @keep = ();
ISA:
    foreach my $isa ( @{ $value } ) {
        foreach my $check_pat ( @ISA_REMOVE ) {
             next ISA if ( $isa =~ /$check_pat/ );
        }
        $isa =~ s/^OpenInteract/OpenInteract2/;
        push @keep, $isa;
    }
    return ( $name, \@keep );
}


sub _modify_track {
    my ( $name, $value ) = @_;
    foreach my $key ( keys %{ $value } ) {
        if ( $value->{ $key } == 1 ) {
            $value->{ $key } = 'yes';
        }
    }
    return ( $name, $value );
}

sub _modify_creation_security {
    my ( $name, $value ) = @_;
    $value->{user} = $value->{u};
    delete $value->{u};
    $value->{world} = $value->{w};
    delete $value->{w};
    if ( ref $value->{g} eq 'HASH' ) {
        my @group_spec = ();
        foreach my $group_id ( keys %{ $value->{g} } ) {
            if ( $group_id == 2 ) {
                push @group_spec, "public_group:$value->{g}{ $group_id }";
            }
            elsif ( $group_id == 3 ) {
                push @group_spec, "site_admin_group:$value->{g}{ $group_id }";
            }
            else {
                push @group_spec, "$group_id:$value->{g}{ $group_id }";
            }
        }
        $value->{g} = \@group_spec;
    }
    $value->{group} = $value->{g};
    delete $value->{g};
    return ( $name, $value );
}

sub _modify_true_to_yes {
    my ( $name, $value ) = @_;
    return ( $name, 'yes' ) if ( $value );
    return ( $name, 'no'  );
}

sub _modify_oi_to_oi2 {
    my ( $name, $value ) = @_;
    if ( ref $value eq 'ARRAY' ) {
        s/^OpenInteract/OpenInteract2/ for @{ $value };
    }
    else {
        $value =~ s/^OpenInteract/OpenInteract2/;
    }
    return ( $name, $value );
}

1;

__END__

=head1 NAME

OpenInteract2::Conversion::SPOPSConfig - Convert old spops.perl files into INI configurations

=head1 SYNOPSIS

 use OpenInteract2::Conversion::SPOPSConfig;
 
 my $old_config_text = join( '', <STDIN> );
 print OpenInteract2::Conversion::SPOPSConfig
                          ->new( $old_config_text )
                          ->convert();

=head1 DESCRIPTION

Utility for translating an SPOPS object configuration, either in a
serialized Perl format or in an actual Perl hashref, into an INI
format. It also does a few transformations along the way to make
fieldnames/values consistent and ensure there are no deeply nested
datastructures.

See
L<OpenInteract2::Conversion::IniConfig|OpenInteract2::Conversion::IniConfig>
for more information about the process.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Conversion::IniConfig|OpenInteract2::Conversion::IniConfig>

L<SPOPS::Manual::Configuration|SPOPS::Manual::Configuration>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
