CREATE TABLE sys_group_user (
 group_id      %%GROUPID_TYPE%% not null,
 user_id       %%USERID_TYPE%% not null,
 primary key   ( group_id, user_id )
)
