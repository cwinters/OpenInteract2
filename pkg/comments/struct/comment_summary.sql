CREATE TABLE comment_summary (
 comment_summary_id %%INCREMENT%%,
 class              varchar(75) not null,
 object_id          varchar(255) not null,
 object_url         varchar(75) not null,
 object_title       varchar(150) not null,
 num_comments       int,
 last_posted_on     %%DATETIME%% null,
 primary key( comment_summary_id )
)