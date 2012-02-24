CREATE TABLE full_text_index (
 ft_id         %%INCREMENT_TYPE%% not null,
 term          varchar(30) not null,
 occur         int not null,
 primary key   ( ft_id, term )
)