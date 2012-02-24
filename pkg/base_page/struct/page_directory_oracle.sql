CREATE TABLE page_directory (
  directory         varchar2(150) not null,
  action            varchar2(50) not null,
  subdirs_inherit   char(3) default 'no',
  primary key( directory )
)