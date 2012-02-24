CREATE TABLE comment_summary (
 comment_summary_id int not null,
 class              varchar2(75) not null,
 object_id          varchar2(255) not null,
 object_url         varchar2(75) not null,
 object_title       varchar2(150) not null,
 num_comments       int,
 last_posted_on     %%DATETIME%% null,
 primary key( comment_summary_id )
)