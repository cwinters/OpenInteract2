CREATE TABLE sessions (
 id            char(32) not null,
 a_session     long,
 last_accessed date default sysdate,
 primary key   ( id )
)