CREATE TABLE object_tags (
  tag_id            %%INCREMENT%% NOT NULL,
  tag               VARCHAR(35) NOT NULL,
  object_type       VARCHAR(20) NOT NULL,
  object_id         %%INCREMENT_TYPE%% NOT NULL,
  name              VARCHAR(100) NULL,
  url               VARCHAR(150) NULL,
  created_on        %%DATETIME%% NULL,
  PRIMARY KEY( tag_id ),
  UNIQUE( tag, object_type, object_id )
);