CREATE TABLE comment_notify (
 comment_notify_id  %%INCREMENT%%,
 class              varchar(75) not null,
 object_id          varchar(255) not null,
 email              varchar(50) not null,
 name               varchar(50) null,
 primary key( comment_notify_id ),
 unique( class, object_id, email )
)