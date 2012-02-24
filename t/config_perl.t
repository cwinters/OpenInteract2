# -*-perl-*-

# $Id: config_perl.t,v 1.5 2004/05/25 00:13:30 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 7;

require_ok( 'OpenInteract2::Config' );

# First try the content

{
    my $test_config = <<'TEST';
$data = {
   head1 => { sub1 => [ 'val1', 'val2' ] },
   head2 => { sub1 => 'val1',
              sub2 => 'this is a longer value' },
   head3 => { child => { sub1 => [ 'val1', 'val2' ] } },
};
TEST

    my $conf = eval { OpenInteract2::Config->new( 'perl',
                                                 { content => $test_config } ) };
    ok( ! $@,
        "Object created" ) || diag "Error: $@";
    is( ref( $conf ), 'OpenInteract2::Config::PerlFile',
        'Correct object type created' );
    is( $conf->{head1}{sub1}[0], 'val1',
        'Values read in correctly' );
}

# Now try a file

{
    my $write_file = get_use_file( 'test_config.perl', 'name' );
    my $conf = eval { OpenInteract2::Config->new( 'perl',
                                                 { filename => $write_file } ) };
    ok( ! $@, "File object created" ) || diag "Error: $@";
    is( ref( $conf ), 'OpenInteract2::Config::PerlFile',
        'File correct object type created' );
    is( $conf->{head1}{sub1}[0], 'val1',
        'File values read in correctly' );
}



