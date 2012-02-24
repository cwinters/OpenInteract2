package My::Foo;

use strict;
use base qw( OpenInteract2::Action );

sub show { return "Why would you want to see a foo?" }
sub list { return "Egads, why would you want to see multiple foos?" }

1;
