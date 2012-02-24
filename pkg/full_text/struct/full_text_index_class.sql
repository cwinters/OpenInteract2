CREATE TABLE full_text_index_class (
  ft_id        %%INCREMENT%%,
  class        varchar(75) not null,
  object_id    varchar(255) not null,
  primary key( ft_id ),
  unique( class, object_id )  
)