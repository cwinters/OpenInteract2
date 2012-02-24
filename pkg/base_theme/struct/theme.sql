CREATE TABLE theme (
 theme_id      %%INCREMENT%%,
 title         varchar(50) not null,
 description   text,
 parent        %%INCREMENT_TYPE%% not null,
 credit        varchar(200),
 primary key   ( theme_id )
)
