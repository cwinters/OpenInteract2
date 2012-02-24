# This OpenInteract2 file was generated
#   by:    [% invocation %]
#   on:    [% date %]
#   from:  [% source_template %]
#   using: OpenInteract2 version [% oi2_version %]

use ExtUtils::MakeMaker;

my %opts = (
    'NAME'	       => '[% full_app_class %]',
    'VERSION'      => '[% package_version %]',
    'PL_FILES'     => {},
    'NO_META'      => 1,
    'PREREQ_PM'    => {
        'OpenInteract2::Action' => 1.66,   # proxy for OI2
[% FOREACH req_module = required_modules -%]
        [% IF req_module %][% req_module %] => 0,[% END %]
[% END -%]
    },
);

if ( $ExtUtils::MakeMaker::VERSION >= 5.43 ) {
    $opts{AUTHOR}   = '[% author_names.join( ', ' ) %]',
    $opts{ABSTRACT} = q{[% abstract %]},
}

WriteMakefile( %opts );
