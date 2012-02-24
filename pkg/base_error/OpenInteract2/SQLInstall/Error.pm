package OpenInteract2::SQLInstall::Error;

# $Id: Error.pm,v 1.4 2005/03/18 04:09:43 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::Error::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);


sub get_security_file {
    return 'install_security.dat';
}

1;
