ALTER TABLE reserves     ADD COLUMN deskcode VARCHAR(10) DEFAULT NULL AFTER branchcode,
                         ADD KEY deskcode (deskcode),
                         ADD FOREIGN KEY (deskcode) REFERENCES desks (deskcode)
                           ON DELETE SET NULL ON UPDATE SET NULL;
ALTER TABLE old_reserves ADD COLUMN deskcode VARCHAR(10) DEFAULT NULL AFTER branchcode,
                         ADD KEY deskcode (deskcode),
                         ADD FOREIGN KEY (deskcode) REFERENCES desks (deskcode)
                           ON DELETE SET NULL ON UPDATE SET NULL;
