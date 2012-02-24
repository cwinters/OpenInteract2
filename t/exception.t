# -*-perl-*-

# $Id: exception.t,v 1.9 2005/02/28 01:02:07 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 82;

BEGIN {
    use_ok( 'OpenInteract2::Exception',
            qw( oi_error oi_app_error oi_datasource_error
                oi_param_error oi_security_error  )
    );
}

# Test normal base exception

{
    my $e_message = 'Error fetching object';
    eval { OpenInteract2::Exception->throw( $e_message ) };
    my $e = $@;
    is( ref $e, 'OpenInteract2::Exception',
        'Base object creation' );
    is( $e->message(), $e_message,
        'Base message creation' );
    ok( $e->line(),
        'Base line number set' );

    is( ref( $e->trace() ), 'Devel::StackTrace',
        'Base trace set' );
    is( "$e", $e_message,
        'Base $@ stringified' );
}

# Test the imported method
{
    my $e_message = "Error fetching object";
    eval { oi_error $e_message  };
    my $e = $@;
    is( ref $e, 'OpenInteract2::Exception',
        'Shortcut object creation' );
    is( $e->message(), $e_message,
        'Shortcut message creation' );
    ok( $e->package(),
        'Shortcut package set' );
    ok( $e->line(),
        'Shortcut line number set' );

    is( ref( $e->trace() ),
        'Devel::StackTrace',
        'Shortcut trace set' );
    is( "$e", $e_message,
        'Shortcut $@ stringified' );
}

# Test the security exception

{
    require_ok( 'OpenInteract2::Exception::Security' );
    my $s_message = 'Security restrictions violated';
    eval {
        OpenInteract2::Exception::Security->throw(
                         $s_message,
                         { security_required => 4,
                           security_found    => 1 } )
    };
    my $s = $@;

    is( ref $s, 'OpenInteract2::Exception::Security',
        'Security object creation' );
    is( $s->message(), $s_message,
        'Security message creation' );
    ok( $s->package(),
        'Security package set' );
    ok( $s->line(),
        'Security line number set' );

    is( $s->security_required(), 4,
        'Security required returned'  );
    is( $s->security_found(), 1,
        'Security found returned'  );

    is( ref( $s->trace() ), 'Devel::StackTrace',
        'Trace set' );
    my $stringified = "Security violation. Object requires 'READ' but got 'NONE'";
    is( "$s", $stringified,
        'Security $@ stringified' );
}

# shortcut
{
    my $s_message = 'Security restrictions violated';
    eval {
        oi_security_error $s_message,
                          { security_required => 4,
                            security_found    => 1 }
    };
    my $s = $@;

    is( ref $s, 'OpenInteract2::Exception::Security',
        'Security object creation' );
    is( $s->message(), $s_message,
        'Security message creation' );

    is( $s->security_required(), 4,
        'Security required returned'  );
    is( $s->security_found(), 1,
        'Security found returned'  );

    my $stringified = "Security violation. Object requires 'READ' but got 'NONE'";
    is( "$s", $stringified,
        'Security $@ stringified' );
}

# Test the datasource exception

{
    my $d_message = 'Connect failed: invalid password for oiuser';
    my $d_name    = 'main';
    my $d_type    = 'DBI';
    my $d_connect = 'DBI:Pg:dbname=test;oiuser;oipass';

    my %d_params = (
     datasource_name => $d_name,
     datasource_type => $d_type,
     connect_params  => $d_connect,
    );

    eval {
        OpenInteract2::Exception::Datasource->throw(
                         $d_message, \%d_params )
    };
    my $d = $@;
    is( ref $d, 'OpenInteract2::Exception::Datasource',
        'Datasource object creation' );
    is( $d->message(), $d_message,
        'Datasource message creation' );
    ok( $d->package(),
        'Datasource package set' );
    ok( $d->line(),
        'Datasource line number set' );

    is( $d->datasource_name, $d_name,
        'Datasource name returned'  );
    is( $d->datasource_type(), $d_type,
        'Datasource type returned'  );
    is( $d->connect_params(), $d_connect,
        'Datasource connection params returned' );

    is( ref( $d->trace() ), 'Devel::StackTrace',
        'Trace set' );
    is( "$d", $d_message,
        'Datasource $@ stringified' );
}

# shortcut
{
    my $d_message = 'Connect failed: invalid password for oiuser';
    my $d_name    = 'main';
    my $d_type    = 'DBI';
    my $d_connect = 'DBI:Pg:dbname=test;oiuser;oipass';

    my %d_params = (
     datasource_name => $d_name,
     datasource_type => $d_type,
     connect_params  => $d_connect,
    );

    eval {
        oi_datasource_error $d_message, \%d_params
    };
    my $d = $@;
    is( ref $d, 'OpenInteract2::Exception::Datasource',
        'Datasource object creation' );
    is( $d->message(), $d_message,
        'Datasource message creation' );

    is( $d->datasource_name, $d_name,
        'Datasource name returned'  );
    is( $d->datasource_type(), $d_type,
        'Datasource type returned'  );
    is( $d->connect_params(), $d_connect,
        'Datasource connection params returned' );

    is( "$d", $d_message,
        'Datasource $@ stringified' );
}

# Test the application exception

{
    my $a_message = 'Please ensure you fill in the "title" field';
    my $a_package = 'custom';
    eval {
        OpenInteract2::Exception::Application->throw(
                         $a_message, { oi_package => $a_package } )
    };
    my $a = $@;

    is( ref $a, 'OpenInteract2::Exception::Application',
        'Application object creation' );
    is( $a->message(), $a_message,
        'Application message creation' );
    ok( $a->package(),
        'Application package set' );
    ok( $a->line(),
        'Application line number set' );

    is( $a->oi_package(), $a_package,
        'Application OI package returned' );

    is( ref( $a->trace() ), 'Devel::StackTrace',
        'Trace set' );
    is( "$a", $a_message,
        '$@ stringified' );
}

# shortcut
{
    my $a_message = 'Please ensure you fill in the "title" field';
    my $a_package = 'custom';
    eval {
        oi_app_error $a_message, { oi_package => $a_package }
    };
    my $a = $@;

    is( ref $a, 'OpenInteract2::Exception::Application',
        'Application object creation' );
    is( $a->message(), $a_message,
        'Application message creation' );

    is( $a->oi_package(), $a_package,
        'Application OI package returned' );

    is( "$a", $a_message,
        '$@ stringified' );
}

# Test the parameter exception

{
    my $p_message = 'Parameters failed to validate';
    my $p_user_fail = 'Must be at least 5 characters';
    my %p_fail    = ( username => $p_user_fail );
    eval {
        OpenInteract2::Exception::Parameter->throw(
                         $p_message, { parameter_fail => \%p_fail } )
    };
    my $p = $@;

    is( ref $p, 'OpenInteract2::Exception::Parameter',
        'Parameter object creation' );
    is( $p->message(), $p_message,
        'Parameter message creation' );
    ok( $p->package(),
        'Parameter package set' );
    ok( $p->line(),
        'Parameter line number set' );

    my $failures = $p->parameter_fail;
    is( ref $failures, 'HASH',
        'Failed parameters is hash' );
    is( $failures->{username}, $p_user_fail,
        'Failure for parameter username set' );

    is( ref( $p->trace() ), 'Devel::StackTrace',
        'Trace set' );
    is( "$p", "One or more parameters were not valid: username: $p_user_fail",
        '$@ stringified' );
}

# Test the parameter exception with multiple failures for one field

{
    my $p_message = 'Parameters failed to validate';
    my $p_length_fail = 'Must be at least 5 characters';
    my $p_chars_fail  = 'Must not have any unseemly characters';
    my $all_errors = [ $p_length_fail, $p_chars_fail ];
    my %p_fail    = ( username => $all_errors );
    eval {
        OpenInteract2::Exception::Parameter->throw(
                         $p_message, { parameter_fail => \%p_fail } )
    };
    my $p = $@;

    is( ref $p, 'OpenInteract2::Exception::Parameter',
        'Parameter object creation' );
    is( $p->message(), $p_message,
        'Parameter message creation' );
    ok( $p->package(),
        'Parameter package set' );
    ok( $p->line(),
        'Parameter line number set' );

    my $failures = $p->parameter_fail;
    is( ref $failures, 'HASH',
        'Failed parameters is hash' );
    is_deeply( $failures->{username}, $all_errors,
        'Both failures for parameter username set' );

    is( ref( $p->trace() ), 'Devel::StackTrace',
        'Trace set' );
    is( "$p", "One or more parameters were not valid: username: $p_length_fail; $p_chars_fail",
        '$@ stringified' );
}

# Test the parameter exception with multiple fields failing

{
    my $p_message = 'Parameters failed to validate';
    my $p_length_fail = 'Must be at least 5 characters';
    my $p_chars_fail  = 'Must not have any unseemly characters';
    my %p_fail    = ( username => $p_length_fail, password => $p_chars_fail );
    eval {
        OpenInteract2::Exception::Parameter->throw(
                         $p_message, { parameter_fail => \%p_fail } )
    };
    my $p = $@;

    is( ref $p, 'OpenInteract2::Exception::Parameter',
        'Parameter object creation' );
    is( $p->message(), $p_message,
        'Parameter message creation' );
    ok( $p->package(),
        'Parameter package set' );
    ok( $p->line(),
        'Parameter line number set' );

    my $failures = $p->parameter_fail;
    is( ref $failures, 'HASH',
        'Failed parameters is hash' );
    is( $failures->{username}, $p_length_fail,
        'Failure for parameter username set' );
    is( $failures->{password}, $p_chars_fail,
        'Failure for parameter password set' );

    is( ref( $p->trace() ), 'Devel::StackTrace',
        'Trace set' );
    is( "$p", "One or more parameters were not valid: password: $p_chars_fail ;; username: $p_length_fail",
        '$@ stringified' );
}

# shortcut

{
    my $p_message = 'Parameters failed to validate';
    my $p_user_fail = 'Must be at least 5 characters';
    my %p_fail    = ( username => $p_user_fail );
    eval {
        oi_param_error $p_message, { parameter_fail => \%p_fail }
    };
    my $p = $@;

    is( ref $p, 'OpenInteract2::Exception::Parameter',
        'Parameter object creation' );
    is( $p->message(), $p_message,
        'Parameter message creation' );

    my $failures = $p->parameter_fail;
    is( ref $failures, 'HASH',
        'Failed parameters is hash' );
    is( $failures->{username}, $p_user_fail,
        'Failure for parameter username set' );

    is( "$p", "One or more parameters were not valid: username: $p_user_fail",
        '$@ stringified' );
}
