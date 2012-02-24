#!/usr/bin/perl

# Translate a package.conf --> package.ini
# Usage:
#   translate_package_to_ini.pl < package.conf > package.ini

use strict;

my @SERIAL_FIELDS = qw( name version author url
                        spops_file action_file message_file module
                        sql_installer config_watcher description
                        template_plugin observer );
my %LIST_FIELDS = map { $_ => 1 } qw( author module spops_file action_file
                                      message_file config_watcher );
my %HASH_FIELDS = map { $_ => 1 } qw( template_plugin observer );

my %config = ();

my $is_description = 0;

while ( <STDIN> ) {
    next if ( /^\s*\#/ );
    next if ( /^\s*$/ );
    chomp;
    s/\r//g;
    s/^\s+//;
    s/\s+$//;

    if ( $is_description ) {
        $config{description} .= $_ . ' ';
        next;
    }

    my ( $field, $value ) = split /\s+/, $_, 2;
    if ( $field eq 'description' ) {
        $is_description++;
        next;
    }

    # If there are multiple values possible, make a list
    if ( $LIST_FIELDS{ $field } and $value ) {
        push @{ $config{ $field } }, $value;
    }

    # Otherwise, if it's a key -> key -> value set; add to list
    elsif ( $HASH_FIELDS{ $field } and $value ) {
        my ( $sub_key, $sub_value ) = split /\s+/, $value, 2;
        $config{ $field }->{ $sub_key } = $sub_value;
    }

    # If not all that, then simple key -> value
    else {
        $config{ $field } = $value;
    }
}

# Translate to INI, manually so we can control order and format

my $fmt = "%-15s = %s\n";

print "[package]\n";
foreach my $field ( @SERIAL_FIELDS ) {
    if ( $LIST_FIELDS{ $field } ) {
        my $values = $config{ $field } || [];
        foreach my $value ( @{ $values } ) {
            printf( $fmt, $field, $value );
        }
    }
    elsif ( $HASH_FIELDS{ $field } ) {
        if ( $config{ $field } ) {
            print "[package $field]\n";
            for ( keys %{ $config{ $field } } ) {
                printf( $fmt, $_, $config{ $field }->{$_} );
            }
        }
    }
    else {
        printf( $fmt, $field, $config{ $field } );
    }
}
