CREATE TABLE theme_prop (
 themeprop_id  %%INCREMENT%%,
 theme_id      %%INCREMENT_TYPE%% not null,
 prop          varchar(30) not null,
 value         text,
 description   text,
 primary key   ( themeprop_id ),
 unique        ( theme_id, prop )
)
