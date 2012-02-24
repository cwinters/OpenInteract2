#!/usr/bin/perl

# Translate an spops.perl file into an spops_foo.ini file
# Usage:
#   translate_spops_to_ini.pl < my/spops.perl > my/spops.ini

use strict;
use OpenInteract2::Conversion::SPOPSConfig;

my $old_config_text = join( '', <STDIN> );
print OpenInteract2::Conversion::SPOPSConfig
                          ->new( $old_config_text )
                          ->convert();

