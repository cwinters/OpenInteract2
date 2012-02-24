CREATE TABLE full_text_index (
 ft_id         int not null,
 term          varchar2(30) not null,
 occur         int not null,
 primary key   ( ft_id, term )
)