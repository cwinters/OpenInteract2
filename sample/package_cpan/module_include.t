# -*-perl-*-

# This OpenInteract2 file was generated
#   by:    [% invocation %]
#   on:    [% date %]
#   from:  [% source_template %]
#   using: OpenInteract2 version [% oi2_version %]

use strict;
use Test::More tests => [% package_modules.size + 2 %];

require_ok( '[% full_app_class %]' );
require_ok( '[% full_brick_class %]' );
[% FOREACH module = package_modules.sort -%]
require_ok( '[% module %]' );
[% END -%]

