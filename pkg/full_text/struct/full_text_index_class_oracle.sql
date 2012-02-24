CREATE TABLE full_text_index_class (
  ft_id        int not null,
  class        varchar2(75) not null,
  object_id    varchar2(255) not null,
  primary key( ft_id ),
  unique( class, object_id )  
)