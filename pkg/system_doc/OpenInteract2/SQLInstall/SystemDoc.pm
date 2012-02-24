package OpenInteract2::SQLInstall::SystemDoc;

# $Id: SystemDoc.pm,v 1.3 2005/03/18 04:09:47 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::SystemDoc::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub get_security_file {
    return 'install_security.dat';
}

1;
