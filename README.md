# README: OpenInteract2

## QUICK INSTALL

    1. perl Makefile.PL     or    perl Build.PL
    2. make                       perl Build
    3. make test                  perl Build test
    4. make install               perl Build install
    5. oi2_manage create_website --website_dir=/path/to/my/website
    6. ... edit /path/to/my/website/conf/server.ini ...
    7. oi2_daemon --website_dir=/path/to/my/website
    8. GET http://localhost:8080/

For more details read 'perldoc OpenInteract2::Manual::QuickStart'
and get OI2 up and running in just a few minutes.

## ABOUT

OpenInteract2 is an extensible application server that includes
everything you need to quickly build robust applications. It includes:

 * A robust system of components that can access your data just about
   any way that you can think up and present the data in reusable
   templates.
 * A very flexible separation of presentation and data access: you can
   use one template for accessing data from different sources using
   one template (e.g., a listing of users from the system, from an
   LDAP server, from an NT/SMB authentication controller, etc.) or you
   can use one set of data to fill multiple templates.
 * A convenient packaging system that makes it simple for developers
   to distribute code, data schemas, configuration, initial data and
   all other information necessary for an application. It also makes
   the installation and upgrading processes very straightforward and
   simple.
 * A consistent security mechanism allowing you to control security
   for users and groups not only at the task level, but also at the
   individual data object level.
 * A simple user and group-management system that allows users to
   create their own accounts and an administrator to assign them to
   one or more groups.
 * An integrated, database-independent method for distributing data
   necessary for a package. You should be able to install any package
   on any database that's been tested with OpenInteract.
 * The ability to deploy an OpenInteract2 application server as a
   standalone service, inside an Apache/mod_perl server, or even
   accessed as a CGI process. And it's easy to extend OI2 to use
   additional interfaces.

More? See:

 * Latest news: http://www.openinteract.org/
 * Issue tracking: http://jira.openinteract.org/
 * Dive in: 'perldoc OpenInteract2::Manual'

# AUTHORS

Chris Winters <chris@cwinters.com>

See OpenInteract2::Manual for more thorough credits.
