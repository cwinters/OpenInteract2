CREATE TABLE theme_prop (
 themeprop_id  %%INCREMENT%%,
 theme_id      %%INCREMENT_TYPE%% not null,
 prop          varchar(30) not null,
 value         blob,
 description   varchar(255),
 primary key   ( themeprop_id ),
 unique        ( theme_id, prop )
)
