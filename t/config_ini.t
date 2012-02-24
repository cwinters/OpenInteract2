# -*-perl-*-

# $Id: config_ini.t,v 1.17 2004/11/27 20:33:54 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 54;

require_ok( 'OpenInteract2::Config::Ini' );

my $test_config = <<'TEST';
[Global]
sub1 = val1

@INCLUDE = included_config.ini

[head1]
sub1 = val1
sub1 = val2
@,sub2 = val1, val2

[head2]
sub1 = val1
sub2 = this is a longer value with a \
line continuation

[head3 child]
sub1 = val1
sub1 = val2
@,sub1 = val3, val4
@,sub1 = val5, val6
sub2 = val3
TEST

my $config_file = get_use_file( 'test_config.ini', 'name' );

{
    my $conf = eval {
        OpenInteract2::Config::Ini->new({
            directory => get_use_dir(),
            content   => $test_config,
        })
    };
    ok( ! $@, "Object created (content)" ) || diag "Error: $@";
    is( ref( $conf ), 'OpenInteract2::Config::Ini',
        'Correct object type created (from content)' );
    is( $conf->{sub1}, 'val1',
        'Global value read in correctly (from content)' );
    is( $conf->{head2}{sub1}, 'val1',
        'Sub value scalar read in correctly (from content)' );
    is( $conf->{head2}{sub2}, 'this is a longer value with a line continuation',
        'Sub value scalar with line continuations read in correctly (from content)' );
    is( $conf->{head1}{sub1}[0], 'val1',
        'Sub value array read in correctly (from content)' );
    is( $conf->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar read in correctly (from content)' );
    is_deeply( $conf->{head1}{sub2}, [ 'val1', 'val2' ],
               'Sub value array with leading @, read in correctly (from content)' );
    is_deeply( $conf->{head3}{child}{sub1},
               [ qw( val1 val2 val3 val4 val5 val6 ) ],
               'Nested sub value array declared with mixed @, and line has ' .
               'correct members (from content)' );
    is( $conf->{include}{position}, 'Center',
        'Included scalar read in correctly (from content)' );
    is_deeply( $conf->{include}{name}, [ 'Mario', 'Lemieux' ],
               'Included array read in correctly (from content)' );
    is_deeply( $conf->{include}{location}, [ 'Pittsburgh', 'Pennsylvania', 'USA' ],
               'Included array with leading @, read in correctly (from content)' );


    my $conf_data = $conf->as_data;
    is( ref( $conf_data ), 'HASH',
        'Correct data type returned from as_data()' );
    is( $conf_data->{sub1}, 'val1',
        'Global value in as_data() correctly (from content)' );
    is( $conf_data->{head2}{sub1}, 'val1',
        'Sub value scalar in as_data() correctly (from content)' );
    is( $conf_data->{head2}{sub2}, 'this is a longer value with a line continuation',
        'Sub value scalar with line continuations in as_data() correctly (from content)' );
    is( $conf_data->{head1}{sub1}[0], 'val1',
        'Sub value array in as_data() correctly (from content)' );
    is( $conf_data->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar in as_data() correctly (from content)' );
    is( $conf_data->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array in as_data() correctly (from content)' );
    is_deeply( $conf_data->{head1}{sub2}, [ 'val1', 'val2' ],
               'Sub value array with leading @, read in correctly in ' .
               'as_data() (from content)' );
    is_deeply( $conf_data->{head3}{child}{sub1},
               [ qw( val1 val2 val3 val4 val5 val6) ],
               'Nested sub value array declared with mixed @, and line has ' .
               'correct members in as_data() (from content)' );
    is( $conf_data->{include}{position}, 'Center',
        'Included scalar read in correctly in as_data() (from content)' );
    is_deeply( $conf_data->{include}{name}, [ 'Mario', 'Lemieux' ],
               'Included array read in correctly in as_data() (from content)' );
    is_deeply( $conf_data->{include}{location}, [ 'Pittsburgh', 'Pennsylvania', 'USA' ],
               'Included array with leading @, read in correctly in as_data() (from content)' );
}

{
    my $conf = eval {
        OpenInteract2::Config::Ini->new({ filename => $config_file } )
    };
    ok( ! $@, "Object created (from file)" ) || diag "Error: $@";
    is( ref( $conf ), 'OpenInteract2::Config::Ini',
        'Correct object type created (from file)' );
    is( $conf->{sub1}, 'val1',
        'Global value read in correctly (from file)' );
    is( $conf->{head2}{sub1}, 'val1',
        'Sub value scalar read in correctly (from file)' );
    is( $conf->{head2}{sub2}, 'this is a longer value with a line continuation',
        'Sub value scalar with line continuations read in correctly (from file)' );
    is( $conf->{head1}{sub1}[0], 'val1',
        'Sub value array read in correctly (from file)' );
    is( $conf->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar read in correctly (from file)' );
    is( $conf->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array read in correctly (from file)' );
    is_deeply( $conf->{head1}{sub2}, [ 'val1', 'val2' ],
               'Sub value array with leading @, read in correctly (from file)' );
    is_deeply( $conf->{head3}{child}{sub1},
               [ qw( val1 val2 val3 val4 val5 val6 ) ],
               'Nested sub value array declared with mixed @, and line has ' .
               'correct members (from file)' );
    is( $conf->{include}{position}, 'Center',
        'Included scalar read in correctly (from file)' );
    is_deeply( $conf->{include}{name}, [ 'Mario', 'Lemieux' ],
               'Included array read in correctly (from file)' );
    is_deeply( $conf->{include}{location}, [ 'Pittsburgh', 'Pennsylvania', 'USA' ],
               'Included array with leading @, read in correctly (from file)' );

    my $conf_data = $conf->as_data;
    is( ref( $conf_data ), 'HASH',
        'Correct data type returned from as_data() (from file)' );
    is( $conf_data->{sub1}, 'val1',
        'Global value in as_data() correctly (from file)' );
    is( $conf_data->{head2}{sub1}, 'val1',
        'Sub value scalar in as_data() correctly (from file)' );
    is( $conf->{head2}{sub2}, 'this is a longer value with a line continuation',
        'Sub value scalar with line continuations in as_data() correctly (from file)' );
    is( $conf_data->{head1}{sub1}[0], 'val1',
        'Sub value array in as_data() correctly (from file)' );
    is( $conf_data->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar in as_data() correctly (from file)' );
    is( $conf_data->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array in as_data() correctly (from file)' );
    is_deeply( $conf_data->{head1}{sub2}, [ 'val1', 'val2' ],
               'Sub value array with leading @, read in correctly in ' .
               'as_data() (from file)' );
    is_deeply( $conf_data->{head3}{child}{sub1},
               [ qw( val1 val2 val3 val4 val5 val6) ],
               'Nested sub value array declared with mixed @, and line has ' .
               'correct members in as_data() (from file)' );
    is( $conf_data->{include}{position}, 'Center',
        'Included scalar read in correctly in as_data() (from file)' );
    is_deeply( $conf_data->{include}{name}, [ 'Mario', 'Lemieux' ],
               'Included array read in correctly in as_data() (from file)' );
    is_deeply( $conf_data->{include}{location}, [ 'Pittsburgh', 'Pennsylvania', 'USA' ],
               'Included array with leading @, read in correctly in as_data() (from file)' );
}

# ensure @INCLUDE not found throws exception

{
    my $conf = eval {
        OpenInteract2::Config::Ini->new({ content => $test_config })
    };
    ok( $@, 'Exception correctly thrown if we cannot find @INCLUDE specified in content' );
    my $error = "$@";
    like( $error, qr/Config file '\..+included_config.ini' does not exist/,
          'Expected exception thrown with @INCLUDE not found' );
}

{
    my $conf = eval {
        OpenInteract2::Config::Ini->new({
            filename  => $config_file,
            directory => 'somepath',
        })
    };
    ok( $@, 'Exception correctly thrown if we feed bad directory to @INCLUDE specified in file' );
    my $error = "$@";
    like( $error, qr/Config file 'somepath.+included_config.ini' does not exist/,
          'Expected exception thrown with @INCLUDE not found' );
}
