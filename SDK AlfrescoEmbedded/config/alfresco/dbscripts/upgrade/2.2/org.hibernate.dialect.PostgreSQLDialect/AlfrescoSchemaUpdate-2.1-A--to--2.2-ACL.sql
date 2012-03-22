--
-- Title:      Update for permissions schema changes
-- Database:   PostgreSQL
-- Since:      V2.2 Schema 85
-- Author:     
--
-- Please contact support@alfresco.com if you need assistance with the upgrade.
--

CREATE TABLE alf_acl_change_set
(
   id INT8 NOT NULL,
   version INT8 NOT NULL,
   PRIMARY KEY (id)
);


-- Add to ACL
ALTER TABLE alf_access_control_list
   ADD COLUMN type INT4 NOT NULL DEFAULT 0,    
   ADD COLUMN latest BOOL NOT NULL DEFAULT TRUE,
   ADD COLUMN acl_id VARCHAR(36) NOT NULL DEFAULT 'UNSET',
   ADD COLUMN acl_version INT8 NOT NULL DEFAULT 1,
   ADD COLUMN inherited_acl INT8,
   ADD COLUMN is_versioned BOOL NOT NULL DEFAULT FALSE,
   ADD COLUMN requires_version BOOL NOT NULL DEFAULT FALSE,
   ADD COLUMN acl_change_set INT8,
   ADD COLUMN inherits_from INT8,
   ADD CONSTRAINT fk_alf_acl_acs FOREIGN KEY (acl_change_set) REFERENCES alf_acl_change_set (id);
CREATE INDEX idx_alf_acl_inh ON alf_access_control_list (inherits, inherits_from);
CREATE INDEX fk_alf_acl_acs ON alf_access_control_list (acl_change_set);

UPDATE alf_access_control_list acl
   SET acl_id = (acl.id);

ALTER TABLE alf_access_control_list
   ADD UNIQUE (acl_id, latest, acl_version);

-- Create ACL member list
CREATE TABLE alf_acl_member
(
   id INT8 NOT NULL,
   version INT8 NOT NULL,
   acl_id INT8 NOT NULL,
   ace_id INT8 NOT NULL,
   pos INT4 NOT NULL,
   CONSTRAINT fk_alf_aclm_acl FOREIGN KEY (acl_id) REFERENCES alf_access_control_list (id),
   CONSTRAINT fk_alf_aclm_ace FOREIGN KEY (ace_id) REFERENCES alf_access_control_entry (id),
   PRIMARY KEY (id),
   UNIQUE(acl_id, ace_id, pos)
);
CREATE INDEX fk_alf_aclm_acl ON alf_acl_member (acl_id);
CREATE INDEX fk_alf_aclm_ace ON alf_acl_member (ace_id);

ALTER TABLE alf_access_control_entry DROP CONSTRAINT alf_access_control_entry_acl_id_key; -- (optional)

-- Extend ACE
ALTER TABLE alf_access_control_entry
   ADD COLUMN applies INT4 NOT NULL DEFAULT 0,
   ADD COLUMN context_id INT8;

-- remove unused
DROP TABLE alf_auth_ext_keys;

-- remove authority constraint
DROP INDEX FKFFF41F99B25A50BF; -- (optional)
ALTER TABLE alf_access_control_entry DROP CONSTRAINT FKFFF41F99B25A50BF; -- (optional)

-- not required from 2.1-A
-- restructure authority
--ALTER TABLE alf_authority RENAME recipient TO authority;
--ALTER TABLE alf_authority
--   DROP CONSTRAINT alf_authority_pkey,
--   ALTER COLUMN authority DROP NOT NULL,
--   ADD COLUMN id INT8 NOT NULL DEFAULT NEXTVAL ('hibernate_sequence'),
--   ADD COLUMN crc INT8,
--   ADD primary key (id),
--   ADD UNIQUE (authority, crc);
--ALTER TABLE alf_authority ALTER id DROP DEFAULT;
--CREATE INDEX idx_alf_auth_aut ON alf_authority (authority);

-- migrate data - fix up FK refs to authority
--UPDATE alf_access_control_entry ace
--   set auth_id = (select id from alf_authority a where a.authority = ace.authority_id);


-- migrate data - build equivalent ACL entries
INSERT INTO alf_acl_member (id, version, acl_id, ace_id, pos)
    SELECT 
        NEXTVAL ('hibernate_sequence'), 1, ace.acl_id, ace.id, 0 
    FROM 
        alf_access_control_entry ace 
    JOIN 
        alf_access_control_list acl ON acl.id = ace.acl_id;

-- Create ACE context
CREATE TABLE alf_ace_context
(
   id INT8 NOT NULL,
   version INT8 NOT NULL,
   class_context VARCHAR(1024),
   property_context VARCHAR(1024),
   kvp_context VARCHAR(1024),
   PRIMARY KEY (id)
 );


-- Create auth aliases table
CREATE TABLE alf_authority_alias
(
   id INT8 NOT NULL,
   version INT8 NOT NULL,
   auth_id INT8 NOT NULL,
   alias_id INT8 NOT NULL,
   CONSTRAINT fk_alf_autha_ali FOREIGN KEY (alias_id) REFERENCES alf_authority (id),
   CONSTRAINT fk_alf_autha_aut FOREIGN KEY (auth_id) REFERENCES alf_authority (id),
   PRIMARY KEY (id),
   UNIQUE (auth_id, alias_id)
);
CREATE INDEX fk_alf_autha_ali ON alf_authority_alias (alias_id);
CREATE INDEX fk_alf_autha_aut ON alf_authority_alias (auth_id);


-- Tidy up unused cols on ace tabl    e and add the FK contstraint back
-- finish take out of ACL_ID
ALTER TABLE alf_access_control_entry
   DROP CONSTRAINT FKFFF41F99B9553F6C,
   DROP CONSTRAINT FKFFF41F9960601995,
   DROP COLUMN acl_id
;
ALTER TABLE alf_access_control_entry
   ADD CONSTRAINT fk_alf_ace_auth FOREIGN KEY (authority_id) REFERENCES alf_authority (id),
   ADD CONSTRAINT fk_alf_ace_perm FOREIGN KEY (permission_id) REFERENCES alf_permission (id),
   ADD CONSTRAINT fk_alf_ace_ctx FOREIGN KEY (context_id) REFERENCES alf_ace_context (id)
;
DROP INDEX FKFFF41F99B9553F6C; -- (optional)   
DROP INDEX FKFFF41F9960601995;
CREATE INDEX fk_alf_ace_auth ON alf_access_control_entry (authority_id);
CREATE INDEX fk_alf_ace_perm ON alf_access_control_entry (permission_id);
CREATE INDEX fk_alf_ace_ctx ON alf_access_control_entry (context_id);

CREATE TABLE alf_tmp_min_ace (
  min INT8 NOT NULL,
  permission_id INT8 NOT NULL,
  authority_id INT8 NOT NULL,
  allowed BOOL NOT NULL,
  applies INT4 NOT NULL,
  UNIQUE (permission_id, authority_id, allowed, applies)
);

INSERT INTO alf_tmp_min_ace (min, permission_id, authority_id, allowed, applies)
    SELECT
       MIN(ace1.id),
       ace1.permission_id,
       ace1.authority_id,
       ace1.allowed,
       ace1.applies
    FROM
       alf_access_control_entry ace1
    GROUP BY
       ace1.permission_id, ace1.authority_id, ace1.allowed, ace1.applies
;
   

-- Update members to point to the first use of an access control entry
UPDATE alf_acl_member mem
   SET ace_id = (SELECT help.min FROM alf_access_control_entry ace 
                     JOIN alf_tmp_min_ace help
                     ON        help.permission_id = ace.permission_id AND
                                help.authority_id = ace.authority_id AND 
                                help.allowed = ace.allowed AND 
                                help.applies = ace.applies 
                     WHERE ace.id = mem.ace_id  );

DROP TABLE alf_tmp_min_ace;

-- Remove duplicate aces the mysql way (as you can not use the deleted table in the where clause ...)

CREATE TABLE tmp_to_delete AS 
    SELECT 
        ace.id 
    FROM 
        alf_acl_member mem 
    RIGHT OUTER JOIN alf_access_control_entry ace ON mem.ace_id = ace.id 
    WHERE 
        mem.ace_id IS NULL;
DELETE FROM alf_access_control_entry ace USING tmp_to_delete t WHERE ace.id = t.id;
DROP TABLE tmp_to_delete;

-- Add constraint for duplicate acls

ALTER TABLE alf_access_control_entry
   ADD UNIQUE (permission_id, authority_id, allowed, applies, context_id);

--
-- Record script finish
--
DELETE FROM alf_applied_patch WHERE id = 'patch.db-V2.2-ACL-From-2.1-A';
INSERT INTO alf_applied_patch
  (id, description, fixes_from_schema, fixes_to_schema, applied_to_schema, target_schema, applied_on_date, applied_to_server, was_executed, succeeded, report)
  VALUES
  (
    'patch.db-V2.2-ACL-From-2.1-A', 'Manually executed script upgrade V2.2: Update acl schema',
    0, 82, -1, 120, null, 'UNKOWN', TRUE, TRUE, 'Script completed'
  );
