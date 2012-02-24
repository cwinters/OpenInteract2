# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

use Module::Build;

Module::Build->new(
    dist_name         => 'OpenInteract',
    dist_abstract     => 'Pure-perl extensible application server',
    license           => 'perl',
    dist_version_from => 'VERSION',
    scripts           => [ qw( script/oi2_manage script/oi2_daemon ) ],
    requires => {
      # TODO: update this to include 'without()' functionality
      # when Adam publishes it.
      'Algorithm::Dependency'      => 1.03,
      'Apache::Session'            => 1.50,
      'Archive::Zip'               => 0,
      'CGI::Cookie'                => 0,
      'Cache::FileCache'           => 0,
      'Carp::Assert'               => 0,
      'Class::Accessor'            => 0,
      'Class::Factory'             => 1.00,
      'Class::Fields'              => 0,
      'Class::Observable'          => 1.00,
      'Class::Singleton'           => 1.03,
      'DateTime'                   => 0.13,
      'DateTime::Format::Strptime' => 1.00,
      'Devel::StackTrace'          => 0,
      'Digest::MD5'                => 0,
      'Email::Valid'               => 0.12,
      'Exception::Class'           => 1.10,
      'File::MMagic'               => 0,
      'Getopt::Long'               => 2.32,
      'HTML::Entities'             => 1.13,
      'HTML::TagCloud'             => 0,
      'Lingua::Stem'               => 0.50,
      'Locale::Maketext'           => 1.06,
      'Log::Dispatch'              => 2.00,
      'Log::Log4perl'              => 0.34,
      'LWP::Simple'                => 0,
      'MIME::Lite'                 => 2.00,
      'Mail::RFC822::Address'      => 0.3,
      'Mail::Sendmail'             => 0.77,
      'Pod::POM'                   => 0,
      'Scalar::Util'               => 0,
      'SPOPS'                      => 0.87,
      'Template'                   => 2.04,
      'Test::MockObject'           => 0.12,
      'Test::More'                 => 0.41,
      'Text::Sentence'             => 0,
      'URI'                        => 1,

# remove these for final release?
      'DBD::SQLite'                => 0.25,
    },
)->create_build_script();
