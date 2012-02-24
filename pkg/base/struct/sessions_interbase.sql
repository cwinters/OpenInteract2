CREATE TABLE sessions (
 id            char(32) not null,
 a_session     blob,
 last_accessed timestamp,
 primary key   ( id )
)