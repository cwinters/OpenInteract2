#!/usr/bin/perl

# Translate an OI 1.x handler using OI::CommonHandler into two files,
# the action initialization and the code.

# Usage:
#   translate_common_handler.pl OpenInteract::Handler::MyHandler
#
# Note that 'OpenInteract::Handler::MyHandler' must be in your @INC
# path; this is best run from the root of the old package.

use strict;
use OpenInteract2::Conversion::CommonHandler;

my $old_class = shift @ARGV;
eval "require $old_class";
if ( $@ ) {
    die "Cannot require '$old_class': $@\nBe sure it is in your @INC ",
        "by running this from the old package directory or by setting ",
        "the 'PERL5LIB' environment variable appropriately.\n";
}
my ( $new_ini, $new_class, $new_class_name ) =
    OpenInteract2::Conversion::CommonHandler
                          ->new( $old_class )
                          ->convert();
my $ini_file = 'action_new.ini';
open( INI, '>', $ini_file ) || die "Cannot write to '$ini_file': $!";
print INI $new_ini;
close( INI );

my ( $class_file ) = $new_class =~ /^.*::(\w+)$/;
$class_file .= '.pm';
open( CLASS, '>', $class_file ) || die "Cannot write to '$class_file': $!";
print CLASS $new_class;
close( CLASS );

