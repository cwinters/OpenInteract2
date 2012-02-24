# -*-perl-*-

# $Id: pod.t,v 1.1 2005/02/13 19:49:14 lachoy Exp $

use strict;
use Test::More;
eval "use Test::Pod 1.00";
if ( $@ ) {
    plan skip_all => "Test::Pod 1.00 required for testing POD" ;
}
my @pod_dirs = qw( script blib );
all_pod_files_ok( all_pod_files( @pod_dirs ) );
