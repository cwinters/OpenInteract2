CREATE TABLE sys_user_language (
  user_language_id  %%INCREMENT%%,
  language          varchar(12) not null,
  primary key( user_language_id ),
  unique( language )
)