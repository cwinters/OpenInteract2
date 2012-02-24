CREATE TABLE whats_new (
 new_id        int not null,
 class         varchar2(75) null,
 object_id     varchar2(150) null,
 listing_type  varchar2(30) not null,
 title         varchar2(200) not null,
 url           varchar2(150) not null,
 posted_on     datetime not null,
 posted_by     int not null,
 active        char(3) null default 'yes',
 primary key   ( new_id )
)