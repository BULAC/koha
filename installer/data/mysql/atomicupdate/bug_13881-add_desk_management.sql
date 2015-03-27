DROP TABLE IF EXISTS desks;
CREATE TABLE desks (
  deskcode varchar(10) NOT NULL,         -- desk id
  branchcode varchar(10) NOT NULL,       -- branch id the desk is attached to
  deskname varchar(80) NOT NULL,         -- name used for OPAC or intranet printing
  deskdescription varchar(300) NOT NULL, -- longer description of the desk
  PRIMARY KEY (deskcode),
  FOREIGN KEY (branchcode)
    REFERENCES branches(branchcode)
      ON DELETE CASCADE
      ON UPDATE CASCADE
) ENGINE=InnoDB CHARSET=utf8 COLLATE=utf8_unicode_ci;
