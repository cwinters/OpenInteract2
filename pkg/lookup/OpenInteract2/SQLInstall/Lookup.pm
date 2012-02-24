package OpenInteract2::SQLInstall::Lookup;

# $Id: Lookup.pm,v 1.2 2005/03/18 04:09:47 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::Lookup::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub get_security_file {
    return 'install_security.dat';
}

1;
