CREATE TABLE page_directory (
  directory         varchar(150) not null,
  action            varchar(50) not null,
  subdirs_inherit   char(3) default 'no',
  primary key( directory )
)