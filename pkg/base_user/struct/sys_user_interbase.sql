CREATE TABLE sys_user (
 user_id       %%INCREMENT%%,
 login_name    varchar(25) not null,
 email         varchar(100) not null,
 password      varchar(30) not null,
 last_login    timestamp null,
 num_logins    int,
 theme_id      %%INCREMENT_TYPE%% default 1,
 first_name    varchar(50),
 last_name     varchar(50),
 title         varchar(50),
 language      varchar(6) default 'en',
 notes         blob,
 removal_date  timestamp null,
 primary key   ( user_id ),
 unique        ( login_name ),
 unique        ( email )
)