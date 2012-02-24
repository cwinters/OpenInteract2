CREATE TABLE oi_comment_disable (
 disable_id         %%INCREMENT%%,
 disabled_on        %%DATETIME%% not null,
 class              varchar(75) not null,
 object_id          varchar(255) not null,
 object_url         varchar(75) not null,
 object_title       varchar(150) not null,
 primary key( disable_id ),
 unique( class, object_id )
)