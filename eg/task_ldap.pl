#!/usr/bin/perl

use strict;
use OpenInteract::Manage;

my $website_dir = '/home/cwinters/work/sourceforge/OpenInteract2/t/test_site';
my $manage = OpenInteract::Manage->new(
                         'test_ldap', { website_dir => $website_dir } );
my @status = $manage->execute;
foreach my $s ( @status ) {
    my $ok_label      = ( $s->{is_ok} eq 'yes' )
                              ? 'OK' : 'NOT OK';
    my $default_label = ( $s->{is_default} eq 'yes' )
                              ? ' (default) ' : '';
    print "Connection: $s->{name} $default_label\n",
          "Status:     $ok_label\n",
          "$s->{message}\n";
}
