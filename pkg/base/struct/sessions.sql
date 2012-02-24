CREATE TABLE sessions (
 id            char(32) not null,
 a_session     text,
 last_accessed timestamp,
 primary key   ( id )
)