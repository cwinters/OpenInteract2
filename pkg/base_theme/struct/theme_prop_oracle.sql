CREATE TABLE theme_prop (
 themeprop_id  int not null,
 theme_id      int not null,
 prop          varchar2(30) not null,
 value         varchar2(500) null,
 description   varchar2(500) null,
 primary key   ( themeprop_id ),
 unique        ( theme_id, prop )
)
