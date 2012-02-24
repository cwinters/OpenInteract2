CREATE TABLE news (
 news_id       int not null,
 posted_on     date not null, 
 posted_by     %%USERID_TYPE%% not null,
 title         varchar2(75) null,
 news_item     clob null,
 image_src     varchar2(255) null,
 image_url     varchar2(255) null,
 image_align   varchar2(5) null,
 section       varchar2(20) default 'Public',
 active        char(3) default 'yes',
 previous_id   int null,
 next_id       int null,
 expires_on    date null,
 active_on     date null,
 primary key   ( news_id )
)
