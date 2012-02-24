package OpenInteract2::ContentGenerator::TT2Process;

# $Id: TT2Process.pm,v 1.23 2007/03/09 03:52:41 a_v Exp $

use strict;
use base qw( OpenInteract2::ContentGenerator );

use Data::Dumper             qw( Dumper );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::ContentGenerator::TemplateSource;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::TT2::Context;
use OpenInteract2::TT2::Plugin;
use OpenInteract2::TT2::Provider;
use Template;

$OpenInteract2::ContentGenerator::TT2Process::VERSION  = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant DEFAULT_COMPILE_EXT => '.ttc';
use constant DEFAULT_CACHE_SIZE  => 75;

sub template { return $_[0]->{_template} }

########################################
# GENERATE CONTENT

sub generate {
    my ( $self, $template_config, $template_vars, $template_source ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );

    my ( $source_type, $source ) =
        OpenInteract2::ContentGenerator::TemplateSource->identify( $template_source );

    my ( $template_name );

    # TODO: We're losing information (name) if an object is passed in,
    # but that might be ok because (a) it's not done often (ever?) and
    # (b) it's only necessary for the custom_variable_class

    if ( $source_type eq 'NAME' ) {
        $template_name = $source;
        my ( $text, $filename, $modtime ) =
            OpenInteract2::ContentGenerator::TemplateSource->load_source( $template_name );
        $source = \$text;
    }
    else {
        $template_name = '_anonymous_';
    }

    $log->is_debug &&
        $log->debug( "Processing template '$template_name'" );

    my $template = $self->template;

    # Make all declared plugins available to every template

    foreach my $plugin_name ( keys %{ $self->{_plugin_class} } ) {
        unless ( $self->{_plugin}{ $plugin_name } ) {
            $self->{_plugin}{ $plugin_name } =
                $template->context->plugin( $plugin_name );
        }
        $template_vars->{ $plugin_name } = $self->{_plugin}{ $plugin_name };
        $log->is_debug &&
            $log->debug( "Adding plugin '$plugin_name' to template vars" );
    }

    # Create a 'MSG' method and add the Locale::Maketext object
    # available:

    if ( CTX->request ) {
        my $lh = CTX->request->language_handle;
        $template_vars->{MSG} = sub {
            return ( $lh ) ? $lh->maketext( @_ ) : "$_[0]: no language handle";
        };
        $template_vars->{LH}  = $lh;
    }
    else {
        $template_vars->{MSG} = sub { return "$_[0]: no language handle" };
    }

    $self->_customize_template_variables( $template_name, $template_vars );

    my ( $html );
    eval {
        $template->process( $source, $template_vars, \$html )
            || die "Cannot process template '$template_name': ",
                   $template->error(), "\n";
    };
    if ( $@ ) {
        $log->error( "Failed to process template '$template_name': $@" );
        return $@;
    }
    $log->is_info &&
        $log->info( "Processed template '$template_name' ok" );
    return $html;
}

sub _customize_template_variables {
    my ( $self, $template_name, $template_vars ) = @_;
    return unless ( $self->{_customize_variables} );
    $log ||= get_logger( LOG_TEMPLATE );

    $log->is_debug &&
        $log->debug( "Running custom template variable handler" );
    my $class = $self->{_customize_variables};
    eval {
        $class->customize_template_vars( $template_name, $template_vars )
    };
    if ( $@ ) {
        $log->error( "Custom template handler '$class' died; I'm going ",
                     "to keep processing but clear out the handler for ",
                     "later calls. Error: $@" );
        $self->{_customize_variables} = undef;
    }
    else {
        $log->is_debug &&
            $log->debug( "Ran custom template variable handler ok" );
    }
}

########################################
# INITIALIZATION

# Since each website gets its own template object, when we call
# initialize() all the website's information has been read in and
# setup so we should be able to ask the config object what plugin
# objects are defined, etc.

sub initialize {
    my ( $self, $init_params ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    $log->is_debug &&
        $log->debug( "Starting TT2 template object init" );

    # Set the TT2 Context to an amenable value -- this just allows us
    # to use the 'pkg::template' INCLUDE syntax

    $Template::Config::CONTEXT = 'OpenInteract2::TT2::Context';

    # This will be the configuration passed to the TT2 object; later
    # actions modify it in-place

    my $tt_config = $self->_init_tt_config( $init_params );

    # Install various template configuration items (currently plugins)
    # as specified by packages

    $self->_package_template_config( $tt_config );

    # Allow initial configuration customizations

    $self->_custom_init_tt_config( $init_params, $tt_config );

    # Initialize per-template-process code for changing template
    # variables

    $self->_setup_variable_customizer( $init_params );

    # Put the configured OI provider in the mix. Note that we do this
    # AFTER the customization process so the user can fool around with
    # cache size, compile directory, etc.

    my $oi_provider = OpenInteract2::TT2::Provider->new(
                              CACHE_SIZE  => $tt_config->{CACHE_SIZE},
                              COMPILE_DIR => $tt_config->{COMPILE_DIR},
                              COMPILE_EXT => $tt_config->{COMPILE_EXT}, );
    unshift @{ $tt_config->{LOAD_TEMPLATES} }, $oi_provider;

    $log->is_debug &&
        $log->debug( "Passing the following to the TT2 new() call: ",
                     Dumper( $tt_config ) );
    my $template = Template->new( %{ $tt_config } );
    unless ( $template ) {
        oi_error "Template object not created: ", Template->error();
    }

    $self->{_template} = $template;
    $log->is_info &&
        $log->info( "Template Toolkit object created properly" );
}


sub _init_tt_config {
    my ( $self, $init_params ) = @_;

    # Default configuration -- this can be modified by each site

    my $cache_size  = ( defined $init_params->{cache_size} )
                        ? $init_params->{cache_size}
                        : DEFAULT_CACHE_SIZE;
    my $compile_ext = $init_params->{compile_ext} || DEFAULT_COMPILE_EXT;

    # Since we've moved the cache configuration give a default

    my $base_compile_dir = $init_params->{compile_dir} || 'cache/tt';
    my $compile_dir = File::Spec->catdir(
        CTX->lookup_directory( 'website' ), $base_compile_dir
    );

    # If the compile_dir isn't specified, be sure to set it **and**
    # the extension to undef, otherwise TT will try to compile/save
    # the templates into the directory we find them (maybe: the custom
    # provider might override, but whatever)

    unless ( defined $compile_dir ) {
        $compile_ext = undef;
        $compile_dir = undef;
    }

    $self->{_plugin_class}{OI} = 'OpenInteract2::TT2::Plugin';
    return {
        PLUGINS     => { OI => 'OpenInteract2::TT2::Plugin' },
        CACHE_SIZE  => $cache_size,
        COMPILE_DIR => $compile_dir,
        COMPILE_EXT => $compile_ext
    };
}


sub _package_template_config {
    my ( $self, $tt_config ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );

    $log->is_debug &&
        $log->debug( "Scanning all installed packages for template plugins" );

    my $pkg_list = CTX->packages;

    # For each package in the site...

    foreach my $package ( @{ $pkg_list } ) {
        my $pkg_name   = $package->name;
        my $plugins = $package->config->template_plugin;
        unless ( ref( $plugins ) eq 'HASH' ) {
            $log->is_debug &&
                $log->debug( "Package $pkg_name has no template ",
                             "plugins; skipping" );
            next;
        }

        # ... read in the template plugins and if found assign to the
        # \%tt_config that eventually gets passed to Template->new()

        while ( my ( $plugin_tag, $plugin_class ) = each %{ $plugins } ) {
            my $full_name = "$plugin_tag > $plugin_class";
            $log->is_debug &&
                $log->debug( "Evaluating template plugin '$full_name' ",
                             "from package '$pkg_name'" );
            eval "require $plugin_class";
            if ( $@ ) {
                $log->error( "Plugin '$full_name' from package ",
                             "'$pkg_name' failed: $@" );
            }
            else {
                $tt_config->{PLUGINS}{ $plugin_tag } = $plugin_class;
                $self->{_plugin_class}{ $plugin_tag } = $plugin_class;
            }
        }
    }
}


sub _custom_init_tt_config {
    my ( $self, $init_params, $tt_config ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );

    my $init_class = $init_params->{custom_init_class};
    return unless ( $init_class );

    eval "require $init_class";
    if ( $@ ) {
        $log->error( "Custom init class '$init_class' not available; ",
                     "continuing... Error: $@" );
    }
    else {
        $log->is_debug &&
            $log->debug( "Running custom template init for '$init_class'" );
        eval {
            $init_class->custom_template_initialize( $tt_config, $init_params )
        };
        if ( $@ ) {
            $log->error( "Failed custom template init '$init_class'; ",
                         "continuing... Error: $@" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Custom template init ok" );
        }
    }
}

# Allow websites to modify the template variables passed to every page
# -- initialize the class here

sub _setup_variable_customizer {
    my ( $self, $init_params ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    my $custom_variable_class = $init_params->{custom_variable_class};
    return unless ( $custom_variable_class );
    $log->is_debug &&
        $log->debug( "Reading TT2 variable customizer: '$custom_variable_class'" );
    eval "require $custom_variable_class";
    if ( $@ ) {
        $log->error( "Custom variable class '$custom_variable_class' ",
                     "not available. Error: $@" );
    }
    else {
        $self->{_customize_variables} = $custom_variable_class;
    }
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator::TT2Process - Process Template Toolkit templates in OpenInteract

=head1 SYNOPSIS

 # NOTE: You will probably never deal with this class. It's don'e
 # behind the scenes for you in the '$action->generate_content' method
 
 # Get a content generator by name from the context; name is
 # configured in server configuration under 'content_generator'
 
 my $generator = CTX->content_generator( 'TT' );
 
 # Specify an object by fully-qualified name (preferrred)
 
 my $html = $generator->generate( {}, { key => 'value' },
                                  { name => 'my_pkg::this_template' } );
 
 # Directly pass text to be parsed (fairly rare)
 
 my $little_template = 'Text to replace -- here is my login name: ' .
                       '[% login.login_name %]';
 my $html = $generator->generate( {}, { key => 'value' },
                                  { text => $little_template } );
 
 # Pass the already-created object for parsing (rare)
 
 my $site_template_obj = CTX->lookup_class( 'template' )->fetch( 'base_main' );
 my $html = $generator->generate( {}, { key => 'value' },
                                  { object => $site_template_obj } );

=head1 DESCRIPTION

This class processes templates within OpenInteract. The main method is
C<process()> -- just feed it a template name and a whole bunch of keys
and it will take care of finding the template (from a database,
filesystem, or wherever) and generating the finished content for you.

Shorthand used below: TT == Template Toolkit.

=head1 INITIALIZATION

=head2 Base Initialization

B<initialize( \%config )>

Performs all initialization, including reading plugins from all
packages. It then creates a TT processing object with necessary
parameters and stores it for later use. We call C<initialize()> from
L<OpenInteract2::ContentGenerator|OpenInteract2::ContentGenerator>
when the OI2 context is first initialized and never again so we can
perform expensive operations here.

=head2 Initializing Template Plugins

To declare a plugin exported by a package, specify it in the
C<package.conf> file for that package. The value is in two parts: the
first part is the name by which the plugin is known, the second is the
plugin class:

 template_plugin   MyPlugin   OpenInteract2::TT2Plugin::MyPlugin

See
L<OpenInteract2::Manual::Templates|OpenInteract2::Manual::Templates>
for information about creating your own template plugins.

=head2 Custom Initialization

You can define information in the server configuration of your website
that enables you to modify the configuration passed to the C<new()>
method of L<Template|Template>.

In your server configuration, define
C<template_info.custom_init_class> as the class that contains a method
'custom_template_initialize()'. The method gets passed the template
configuration hashref, which you can modify in-place as you see
fit. It also gets a copy of the server configuration for the TT
content generator as the second argument.

There are many variables that you can change; learn about them at
L<Template::Manual::Config|Template::Manual::Config>. For example,
assume that TT can use the configuration variable 'SUNSET' to do
something. To set the variable:

 # In conf/server.ini
 
 [content_generator TT]
 ...
 custom_init_class  = MyCustom::Template
 
 # In MyCustom/Template.pm:
 
 package MyCustom::Template;
 
 use strict;
 
 sub custom_template_initialize {
     my ( $class, $template_config, $init_params ) = @_;
     $template_config->{SUNSET} = '7:13 AM';
 }

Easy! Since this is a normal Perl method, you can perform any actions
you like here. For instance, you can retrieve templates from a website
via LWP, save them to your package template directory and process them
via PROCESS/INCLUDE as you normally would. Or set template
caching/compiling options on a SOAP server for your 100-machine
cluster and read them from a single source.

Note that C<initialize()> should only get executed once at context
initialization. (Standalone server: once; preforking server, probably
once per child.) Most of the time this is fairly infrequent, so you
can execute code here that takes a little more time than if it were
being executed with every request.

=head1 PROCESSING

=head2 Base Processing

B<generate( \%template_params, \%template_variables, \%template_source )>

Generate template content, given keys and values in
C<\%template_variables> and a template identifier in
C<\%template_source>.

Parameters:

=over 4

=item *

B<template_params> (\%)

Configuration options for the template. Note that you can set defaults
for these at configuration time as well.

=item *

B<template_variables> (\%)

The key/value pairs that will get plugged into the template. These can
be arbitrarily complex, since the Template Toolkit can do anything :-)

=item *

B<template_source>

Tell the method how to find the source for the template you want to
process. There are a number of ways to do this:

Method 1: Use a combined name (preferred method)

 name    => 'package_name::template_name'

Method 2: Specify the text yourself

 text    => $scalar_with_text
 or
 text    => \$scalar_ref_with_text

Method 3: Specify an object of type
L<OpenInteract2::SiteTemplate|OpenInteract2::SiteTemplate>

 object => $site_template_obj

=back

=head2 Customized Variables

You have the opportunity to step in during the executing of
C<generate()> with every request and create/modify/remove template
variables. To do so, you need to define a handler and tell OI where it
is.

To define the handler, just define a normal Perl class method
'customize_template_vars()' that gets two arguments: the name of the
current template (in 'package::name' format) and the template variable
hashref:

 sub customize_template_vars {
     my ( $class, $template_name, $template_vars ) = @_;
     $template_vars->{MOTD} = 'No matter where you go, there you are';
 }

To tell OI where your handler is, in your server configuration file
specify:

 [content_generator TT]
 ...
 custom_variable_class  = MyCustom::Template

You can set (or, conceivably, remove) information bound for every
template. Variables set via this method are available to the template
just as if they had been passed in via the C<generate()> call.

=head1 SEE ALSO

L<Template|Template>

L<OpenInteract2::ContentGenerator|OpenInteract2::ContentGenerator>

L<OpenInteract2::TT2::Context|OpenInteract2::TT2::Context>

L<OpenInteract2::TT2::Plugin|OpenInteract2::TT2::Plugin>

L<OpenInteract2::TT2::Provider|OpenInteract2::TT2::Provider>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
