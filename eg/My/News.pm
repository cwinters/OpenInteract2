package My::News;

use strict;
use base qw( OpenInteract2::Action );

sub show { return "This is the show task!" }
sub list { return "This is the list task!" }

1;
