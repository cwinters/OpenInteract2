CREATE TABLE oi_comment (
 comment_id         int not null,
 class              varchar2(75) not null,
 object_id          varchar2(255) not null,
 posted_on          %%DATETIME%% not null, 
 poster_name        varchar2(30) not null,
 poster_email       varchar2(50) null,
 poster_url         varchar2(75) null,
 subject            varchar2(75) not null,
 content            clob null,
 primary key( comment_id )
)