CREATE TABLE content_type (
  content_type_id   %%INCREMENT%%,
  mime_type         varchar(50) not null,
  extensions        varchar(40) not null,
  description       varchar(100),
  image_source      varchar(50),
  PRIMARY KEY       ( content_type_id ),
  UNIQUE            ( mime_type )
)