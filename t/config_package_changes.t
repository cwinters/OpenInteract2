# -*-perl-*-

# $Id: config_package_changes.t,v 1.7 2004/09/27 04:16:07 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 60;

my $use_dir = get_use_dir();

# TODO: When we get test packages setup we'll read a changes file
# using a package parameter.

require_ok( 'OpenInteract2::Config::PackageChanges' );

{
    my $pwd = get_current_dir();
    chdir( $use_dir );
    my $changes = eval {
        OpenInteract2::Config::PackageChanges->new({ file => 'Changes' });
    };
    ok( ! $@, "Config read by 'file' parameter" ) || diag "Error: $@";

    my @all_entries = $changes->entries;
    is( scalar @all_entries, 19, "All entries fetched" );

    is( $all_entries[0]->{version}, '2.03', 'First entry version (file)' );
    is( $all_entries[0]->{date}, 'Sun Apr  6 22:45:18 EDT 2003', 'First entry date (file)' );
    is( $all_entries[-1]->{version}, '1.50', 'Last entry version (file)' );
    is( $all_entries[-1]->{date}, 'Tue Apr  2 00:36:48 EST 2002', 'Last entry date (file)' );
    is( $all_entries[4]->{version}, '1.64', 'Middle entry version (file)' );
    is( $all_entries[4]->{date}, 'Wed Mar 4 17:12:29 EST 2003', 'Middle entry date (file)' );

    my ( $new_entry ) = $changes->latest(1);
    is( $new_entry->{version}, '2.03', "Latest version read (file)" );
    is( $new_entry->{date}, 'Sun Apr  6 22:45:18 EDT 2003', "Latest date read (file)" );
    ok( $new_entry->{message} =~ /Force scalar context on \->id call/, 'Latest message read (file)' );

    my @new_entries = $changes->latest(5);
    is( scalar @new_entries, 5, "Correct number of new entries (file)" );

    my ( $old_entry ) = $changes->first(1);
    is( $old_entry->{version}, '1.50', "First version read (file)" );
    is( $old_entry->{date}, 'Tue Apr  2 00:36:48 EST 2002', "First date read (file)" );
    ok( $old_entry->{message} =~ /Add Oracle-specific table/, 'First message read (file)' );

    my @old_entries = $changes->first(3);
    is( scalar @old_entries, 3, "Correct number of old entries (file)" );

    my @since_entries = $changes->since( '2.00' );
    is( scalar @since_entries, 4, "Entries since version (file)" );
    is( $since_entries[0]->{version}, '2.03', "Entries since version, first (file)" );
    is( $since_entries[1]->{version}, '2.02', "Entries since version, first (file)" );
    is( $since_entries[2]->{version}, '2.01', "Entries since version, third (file)" );
    is( $since_entries[3]->{version}, '2.00', "Entries since version, last (file)" );

    my @before_entries = $changes->before( '1.60' );
    is( scalar @before_entries, 11, "Entries before version (file)" );
    is( $before_entries[0]->{version}, '1.60', "Entries before version, first (file)" );
    is( $before_entries[1]->{version}, '1.59', "Entries before version, first (file)" );
    is( $before_entries[2]->{version}, '1.58', "Entries before version, third (file)" );
    is( $before_entries[3]->{version}, '1.57', "Entries before version, last (file)" );

    $changes->write_config( 'foo' );

    chdir( $pwd );
}

{
    my $changes = eval {
        OpenInteract2::Config::PackageChanges->new({ dir => $use_dir });
    };
    ok( ! $@, "Config read by 'dir' parameter" ) || diag "Error: $@";

    my @all_entries = $changes->entries;
    is( scalar @all_entries, 19, "All entries fetched" );

    is( $all_entries[0]->{version}, '2.03', "First entry version (dir)" );
    is( $all_entries[-1]->{version}, '1.50', "Last entry version (dir)" );
    is( $all_entries[4]->{version}, '1.64', "Middle entry version (dir)" );

    my ( $new_entry ) = $changes->latest(1);
    is( $new_entry->{version}, '2.03', "Latest version read (dir)" );

    my @new_entries = $changes->latest(8);
    is( scalar @new_entries, 8, "Correct number of new entries (dir)" );

    my @old_entries = $changes->first(2);
    is( $old_entries[0]->{version}, '1.51', "First version read (dir)" );
    is( $old_entries[1]->{version}, '1.50', "First version read (dir)" );

    my @since_entries = $changes->since( '1.51' );
    is( scalar @since_entries, 18, "Entries since version (dir)" );
    is( $since_entries[0]->{version}, '2.03', 'Entries since version, first (dir)' );
    is( $since_entries[-1]->{version}, '1.51', 'Entries since version, last (dir)' );

    my @before_entries = $changes->before( '2.00' );
    is( scalar @before_entries, 16, "Entries before version (dir)" );
    is( $before_entries[0]->{version}, '2.00', "Entries before version, first (dir)" );
    is( $before_entries[1]->{version}, '1.64', "Entries before version, first (dir)" );
    is( $before_entries[2]->{version}, '1.63', "Entries before version, third (dir)" );
    is( $before_entries[3]->{version}, '1.62', "Entries before version, last (dir)" );
}


{
    my $content = q{
1.56  Mon May 13 08:51:18 EDT 2002

      Modified OpenInteract::Handler::NewUser to use either
      Email::Valid or Mail::RFC822::Address to validate the email
      address. (Email::Valid is not available via PPM for Win32
      systems.) Responding to SF Bug #554665.

1.55  Sun May  5 11:13:39 EDT 2002

      Fix other 'datetime' -> 'date' in struct/sys_user_oracle.sql

1.54  Thu May  2 09:00:03 EDT 2002

      Add Interbase-specific table and generator.

1.53  Tue Apr 16 15:04:37 EDT 2002

      Change datatype from 'datetime' to 'date' in
      struct/sys_user_oracle.sql

1.52  Sat Apr 13 12:46:42 EDT 2002

      In OI/Handler/NewUser.pm - use
      SPOPS::Utility->generate_random_code() directly.

1.51  Sat Apr 13 12:20:19 EDT 2002

      Use SPOPS::Utility->crypt_it rather than have it in our ISA.

1.50

1.49  Thu Apr 10 23:56:35 EDT 2002

1.48
};
    my $changes = eval {
        OpenInteract2::Config::PackageChanges->new({ content => $content });
    };
    ok( ! $@, "Config read by 'content' parameter" ) || diag "Error: $@";

    my @all_entries = $changes->entries;
    is( scalar @all_entries, 9, "All entries fetched" );

    is( $all_entries[0]->{version}, '1.56', "First entry version (content)" );
    is( $all_entries[-1]->{version}, '1.48', "Last entry version (content)" );
    is( $all_entries[4]->{version}, '1.52', "Middle entry version (content)" );

    my ( $new_entry ) = $changes->latest(1);
    is( $new_entry->{version}, '1.56', "Latest version read (content)" );

    my @new_entries = $changes->latest(3);
    is( scalar @new_entries, 3, "Correct number of new entries (content)" );

    my @old_entries = $changes->first(2);
    is( $old_entries[0]->{version}, '1.49', "First version read (content)" );
    is( $old_entries[1]->{version}, '1.48', "First version read (content)" );

    my @since_entries = $changes->since( '1.54' );
    is( scalar @since_entries, 3, "Entries since version (content)" );
    is( $since_entries[0]->{version}, '1.56', 'Entries since version, first (content)' );
    is( $since_entries[-1]->{version}, '1.54', 'Entries since version, last (content)' );

    my @before_entries = $changes->before( '1.53' );
    is( scalar @before_entries, 6, "Entries before version (content)" );
    is( $before_entries[0]->{version}, '1.53', "Entries before version, first (content)" );
    is( $before_entries[1]->{version}, '1.52', "Entries before version, first (content)" );
    is( $before_entries[-1]->{version}, '1.48', "Entries before version, third (content)" );
}
