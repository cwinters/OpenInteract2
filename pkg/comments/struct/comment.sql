CREATE TABLE oi_comment (
 comment_id         %%INCREMENT%%,
 class              varchar(75) not null,
 object_id          varchar(255) not null,
 posted_on          %%DATETIME%% not null, 
 poster_name        varchar(30) not null,
 poster_email       varchar(50) null,
 poster_url         varchar(75) null,
 poster_host        varchar(50) null,
 subject            varchar(75) not null,
 content            text null,
 primary key( comment_id )
)