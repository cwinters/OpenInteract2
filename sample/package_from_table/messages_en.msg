# This OpenInteract2 file was generated
#   by:    [% invocation %]
#   on:    [% date %]
#   from:  [% source_template %]
#   using: OpenInteract2 version [% oi2_version %]

[% package_name %].title_update           = Update the Object
[% package_name %].title_create           = Create a New Object
[% package_name %].title_search_form      = Search for Objects
[% package_name %].title_search_results   = Search Results
[% package_name %].title_display          = Object Details
[% package_name %].no_results             = No results found. <a href="[_1]">Create a new object</a>?

[% FOREACH field = fields -%]
[% package_name %].[% field.name %]_title = [% field.display %]
[% END -%]
