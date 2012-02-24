CREATE TABLE comment_notify (
 comment_notify_id  int not null,
 class              varchar2(75) not null,
 object_id          varchar2(255) not null,
 email              varchar2(50) not null,
 name               varchar2(50) null,
 primary key( comment_notify_id ),
 unique( class, object_id, email )
)