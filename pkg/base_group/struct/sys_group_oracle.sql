CREATE TABLE sys_group (
 group_id      int not null,
 name          varchar2(30) not null,
 notes         varchar2(255) null,
 primary key   ( group_id )
)
