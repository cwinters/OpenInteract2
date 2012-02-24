CREATE TABLE sys_security (
 sid            int not null,
 class          varchar2(60) not null,
 object_id      varchar2(150) default '0',
 scope          char(1) not null,
 scope_id       varchar2(150) default 'world',
 security_level char(1) not null,
 primary key    ( sid ),
 unique         ( object_id, class, scope, scope_id )
)
