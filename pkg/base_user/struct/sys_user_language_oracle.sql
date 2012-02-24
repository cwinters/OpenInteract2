CREATE TABLE sys_user_language (
  user_language_id  int not null,
  language          varchar2(12) not null,
  primary key( user_language_id ),
  unique( language )
)