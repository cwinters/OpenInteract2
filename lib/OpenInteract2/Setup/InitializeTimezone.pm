package OpenInteract2::Setup::InitializeTimezone;

# $Id: InitializeTimezone.pm,v 1.2 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use DateTime::TimeZone;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_INIT );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::InitializeTimezone::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'initialize timezone';
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $server_config = $ctx->server_config;
    my $timezone = $server_config->{timezone};
    unless ( $timezone ) {
        $timezone = 'America/New_York';
        $log->warn(
            "No timezone set in server configuration! Please set the ",
            "configuration key 'Global.timezone' to a valid ",
            "DateTime::TimeZone value. (I'm going to be a cultural ",
            "imperialist and assume '$timezone'.)"
        );
    }
    my $timezone_object = DateTime::TimeZone->new( name => $timezone );
    $ctx->timezone( $timezone );
    $ctx->timezone_object( $timezone_object );
    $log->info( "Assigned timezone '$timezone' to context ok" );
 }

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::InitializeTimezone - Create the global timezone object

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'initialize timezone' );
 $setup->run();
 
 my $dt = CTX->create_date;
 my $dt = CTX->create_date({ epoch => 15 });
 my $dt = CTX->create_date({ year => 2005, month => 1, day => 23 });

=head1 DESCRIPTION

This setup action finds the timezone from the server configuration key
'Global.timezone' and creates a L<DateTime::TimeZone> object from
it. If that key is empty we assume 'America/New_York' since that's the
center of the world.

After we create the L<DateTime::TimeZone> object we store it in the
context via the C<timezone_object> property and the string used as the
timezone source in the 'timezone' property.

=head2 Setup Metadata

B<name> - 'initialize timezone'

B<dependencies> - default

=head1 SEE ALSO

L<DateTime::TimeZone>

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
