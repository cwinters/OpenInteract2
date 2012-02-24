CREATE TABLE content_type (
  content_type_id   int not null,
  mime_type         varchar2(50) not null,
  extensions        varchar2(40) not null,
  description       varchar2(100) null,
  image_source      varchar2(50) null,
  PRIMARY KEY       ( content_type_id ),
  UNIQUE            ( mime_type )
)