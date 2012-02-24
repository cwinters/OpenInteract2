CREATE TABLE news (
 news_id       %%INCREMENT%%,
 posted_on     timestamp not null, 
 posted_by     %%USERID_TYPE%% not null,
 title         varchar(75),
 news_item     blob,
 image_src     varchar(255) null,
 image_url     varchar(255) null,
 image_align   varchar(5) null,
 section       varchar(20) default 'Public',
 active        char(3) default 'yes',
 previous_id   %%INCREMENT_TYPE%% null,
 next_id       %%INCREMENT_TYPE%% null,
 expires_on    timestamp,
 active_on     timestamp,
 primary key   ( news_id )
)
