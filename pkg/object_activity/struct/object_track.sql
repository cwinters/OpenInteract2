CREATE TABLE object_track (
 objtrack_id   %%INCREMENT%%,
 class         varchar(50) not null,
 object_id     varchar(150) not null,
 action        varchar(10) default 'create',
 action_by     %%USERID_TYPE%% not null,
 action_on     %%DATETIME%% not null,
 notes         text,
 primary key   ( objtrack_id ),
 unique        ( class, object_id, action, action_by, action_on )
)