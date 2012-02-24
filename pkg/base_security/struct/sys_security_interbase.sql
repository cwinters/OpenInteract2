CREATE TABLE sys_security (
 sid            %%INCREMENT%%,
 class          varchar(60) not null,
 object_id      varchar(150) default '0',
 scope          char(1) not null,
 scope_id       varchar(150) default 'world',
 security_level char(1) not null,
 primary key    ( sid ),
)
