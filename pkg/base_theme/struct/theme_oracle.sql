CREATE TABLE theme (
 theme_id      int not null,
 title         varchar2(50) not null,
 description   varchar2(500) null,
 parent        int not null,
 credit        varchar2(200) null,
 primary key   ( theme_id )
)
