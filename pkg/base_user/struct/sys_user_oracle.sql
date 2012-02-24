CREATE TABLE sys_user (
 user_id       int not null,
 login_name    varchar2(25) not null,
 email         varchar2(100) not null,
 password      varchar2(30) not null,
 last_login    date null,
 num_logins    int null,
 theme_id      int default 1,
 first_name    varchar2(50) null,
 last_name     varchar2(50) null,
 title         varchar2(50) null,
 language      varchar2(6) default 'en',
 notes         varchar2(500) null,
 removal_date  date null,
 primary key   ( user_id ),
 unique        ( login_name ),
 unique        ( email )
)