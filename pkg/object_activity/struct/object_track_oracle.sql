CREATE TABLE object_track (
 objtrack_id   int not null,
 class         varchar2(50) not null,
 object_id     varchar2(150) not null,
 action        varchar2(10) default 'create',
 action_by     %%USERID_TYPE%% not null,
 action_on     date not null,
 notes         varchar2(500) null,
 primary key   ( objtrack_id ),
 unique        ( class, object_id, action, action_by, action_on )
)