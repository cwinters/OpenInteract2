CREATE TABLE whats_new (
 new_id        %%INCREMENT%%,
 class         varchar(75) null,
 object_id     varchar(150) null,
 listing_type  varchar(30) not null,
 title         varchar(200) not null,
 url           varchar(150) not null,
 posted_on     %%DATETIME%% not null,
 posted_by     int not null,
 active        char(3) null default 'yes',
 primary key   ( new_id )
)