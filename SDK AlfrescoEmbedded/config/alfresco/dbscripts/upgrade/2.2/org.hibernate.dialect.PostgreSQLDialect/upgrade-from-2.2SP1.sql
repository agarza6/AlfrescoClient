--
-- Title:      Upgrade V2.2 SP1 or SP2 
-- Database:   PostgreSQL
-- Since:      V2.2 Schema 91
-- Author:     Derek Hulley
--
-- MLText values must be pulled back from attributes into localizable properties.
-- NodeStatus has been moved to alf_node.
-- Auditable properties have been moved to alf_node.
-- alf_node contains the old alf_node_status information.
--
-- Please contact support@alfresco.com if you need assistance with the upgrade.
--

-- -------------------
-- Build new Store --
-- -------------------

CREATE TABLE t_alf_store
(
   id INT8 NOT NULL,
   version INT8 NOT NULL,
   protocol VARCHAR(50) NOT NULL,
   identifier VARCHAR(100) NOT NULL,
   root_node_id INT8,
   PRIMARY KEY (id),
   CONSTRAINT alf_store_protocol_key UNIQUE (protocol, identifier)
);

-- --------------------------
-- Populate the ADM nodes --
-- --------------------------

CREATE TABLE t_alf_node (
   id INT8 NOT NULL,
   version INT8 NOT NULL,
   store_id INT8 NOT NULL,
   uuid VARCHAR(36) NOT NULL,
   transaction_id INT8 NOT NULL,
   node_deleted BOOL NOT NULL,
   type_qname_id INT8 NOT NULL,
   acl_id INT8,
   audit_creator VARCHAR(255),
   audit_created VARCHAR(30),
   audit_modifier VARCHAR(255),
   audit_modified VARCHAR(30),
   audit_accessed VARCHAR(30),
   CONSTRAINT fk_alf_node_acl FOREIGN KEY (acl_id) REFERENCES alf_access_control_list (id), 
   CONSTRAINT fk_alf_node_tqn FOREIGN KEY (type_qname_id) REFERENCES alf_qname (id), 
   CONSTRAINT fk_alf_node_txn FOREIGN KEY (transaction_id) REFERENCES alf_transaction (id), 
   CONSTRAINT fk_alf_node_store FOREIGN KEY (store_id) REFERENCES t_alf_store (id), 
   PRIMARY KEY (id),
   CONSTRAINT alf_node_store_id_key UNIQUE (store_id, uuid)
);
CREATE INDEX idx_alf_node_del ON t_alf_node (node_deleted);
CREATE INDEX fk_alf_node_acl ON t_alf_node (acl_id);
CREATE INDEX fk_alf_node_tqn ON t_alf_node (type_qname_id);
CREATE INDEX fk_alf_node_txn ON t_alf_node (transaction_id);
CREATE INDEX fk_alf_node_store ON t_alf_node (store_id);

-- Fill the store table
INSERT INTO t_alf_store (id, version, protocol, identifier, root_node_id)
   SELECT NEXTVAL ('hibernate_sequence'), 1, protocol, identifier, root_node_id FROM alf_store
;

-- Summarize the alf_node_status table
CREATE TABLE t_summary_nstat
(
   node_id INT8 NOT NULL,
   transaction_id INT8 DEFAULT NULL,
   PRIMARY KEY (node_id)
);
INSERT INTO t_summary_nstat (node_id, transaction_id) 
  SELECT node_id, transaction_id FROM alf_node_status WHERE node_id IS NOT NULL;

-- Copy data over
INSERT INTO t_alf_node
   (
      id, version, store_id, uuid, transaction_id, node_deleted, type_qname_id, acl_id,
      audit_creator, audit_created, audit_modifier, audit_modified, audit_accessed
   )
   SELECT
      n.id, 1, s.id, n.uuid, nstat.transaction_id, false, n.type_qname_id, n.acl_id,
      null, null, null, null, null
   FROM
      alf_node n
      JOIN t_summary_nstat nstat ON (nstat.node_id = n.id)
      JOIN t_alf_store s ON (s.protocol = n.protocol AND s.identifier = n.identifier)
;
DROP TABLE t_summary_nstat;

-- Hook the store up to the root node
ALTER TABLE t_alf_store 
   ADD CONSTRAINT fk_alf_store_root FOREIGN KEY (root_node_id) REFERENCES t_alf_node (id)
;
CREATE INDEX fk_alf_store_root ON t_alf_store (root_node_id); 

-- -----------------------------
-- Populate Version Counter  --
-- -----------------------------

CREATE TABLE t_alf_version_count
(
   id INT8 NOT NULL,
   version INT8 NOT NULL,
   store_id INT8 NOT NULL,
   version_count INT4 NOT NULL,
   CONSTRAINT alf_version_count_store_id_key UNIQUE (store_id),
   CONSTRAINT fk_alf_vc_store FOREIGN KEY (store_id) REFERENCES t_alf_store (id),
   PRIMARY KEY (id)
);

INSERT INTO t_alf_version_count
   (
      id, version, store_id, version_count
   )
   SELECT
      NEXTVAL ('hibernate_sequence'), 1, s.id, vc.version_count
   FROM
      alf_version_count vc
      JOIN t_alf_store s ON (s.protocol = vc.protocol AND s.identifier = vc.identifier)
;

DROP TABLE alf_version_count;
ALTER TABLE t_alf_version_count RENAME TO alf_version_count;

-- -----------------------------
-- Populate the Child Assocs --
-- -----------------------------

CREATE TABLE t_alf_child_assoc
(
   id INT8 NOT NULL,
   version INT8 NOT NULL,
   parent_node_id INT8 NOT NULL,
   type_qname_id INT8 NOT NULL,
   child_node_name_crc INT8 NOT NULL,
   child_node_name VARCHAR(50) NOT NULL,
   child_node_id INT8 NOT NULL,
   qname_ns_id INT8 NOT NULL,
   qname_localname VARCHAR(255) NOT NULL,
   is_primary BOOL,
   assoc_index INT4,
   CONSTRAINT fk_alf_cass_pnode foreign key (parent_node_id) REFERENCES t_alf_node (id),
   CONSTRAINT fk_alf_cass_cnode foreign key (child_node_id) REFERENCES t_alf_node (id),
   CONSTRAINT fk_alf_cass_tqn foreign key (type_qname_id) REFERENCES alf_qname (id),
   CONSTRAINT fk_alf_cass_qnns foreign key (qname_ns_id) REFERENCES alf_namespace (id),
   PRIMARY KEY (id)
);
CREATE INDEX idx_alf_cass_qnln ON t_alf_child_assoc (qname_localname);
CREATE INDEX fk_alf_cass_pnode ON t_alf_child_assoc (parent_node_id);
CREATE INDEX fk_alf_cass_cnode ON t_alf_child_assoc (child_node_id);
CREATE INDEX fk_alf_cass_tqn ON t_alf_child_assoc (type_qname_id);
CREATE INDEX fk_alf_cass_qnns ON t_alf_child_assoc (qname_ns_id);
CREATE INDEX idx_alf_cass_pri ON t_alf_child_assoc (parent_node_id, is_primary, child_node_id);

INSERT INTO t_alf_child_assoc
   (
      id, version,
      parent_node_id,
      type_qname_id,
      child_node_name_crc, child_node_name,
      child_node_id,
      qname_ns_id, qname_localname,
      is_primary, assoc_index
   )
   SELECT
      ca.id, 1,
      ca.parent_node_id,
      ca.type_qname_id,
      ca.child_node_name_crc, ca.child_node_name,
      ca.child_node_id,
      ca.qname_ns_id, ca.qname_localname,
      ca.is_primary, ca.assoc_index
   FROM
      alf_child_assoc ca
;

-- Clean up
DROP TABLE alf_child_assoc;
ALTER TABLE t_alf_child_assoc RENAME TO alf_child_assoc;
ALTER TABLE alf_child_assoc
   ADD CONSTRAINT alf_child_assoc_parent_node_id_key UNIQUE (parent_node_id, type_qname_id, child_node_name_crc, child_node_name);

-- ----------------------------
-- Populate the Node Assocs --
-- ----------------------------

CREATE TABLE t_alf_node_assoc
(
   id INT8 NOT NULL,
   version INT8 NOT NULL, 
   source_node_id INT8 NOT NULL,
   target_node_id INT8 NOT NULL,
   type_qname_id INT8 NOT NULL,
   CONSTRAINT fk_alf_nass_snode FOREIGN KEY (source_node_id) REFERENCES t_alf_node (id),
   CONSTRAINT fk_alf_nass_tnode FOREIGN KEY (target_node_id) REFERENCES t_alf_node (id),
   CONSTRAINT fk_alf_nass_tqn FOREIGN KEY (type_qname_id) REFERENCES alf_qname (id),
   PRIMARY KEY (id)
);
CREATE INDEX fk_alf_nass_snode ON t_alf_node_assoc (source_node_id);
CREATE INDEX fk_alf_nass_tnode ON t_alf_node_assoc (target_node_id);
CREATE INDEX fk_alf_nass_tqn ON t_alf_node_assoc (type_qname_id);

INSERT INTO t_alf_node_assoc
   (
      id, version,
      source_node_id, target_node_id,
      type_qname_id
   )
   SELECT
      na.id, 1,
      na.source_node_id, na.target_node_id,
      na.type_qname_id
   FROM
      alf_node_assoc na
;

-- Clean up
DROP TABLE alf_node_assoc;
ALTER TABLE t_alf_node_assoc RENAME TO alf_node_assoc;
ALTER TABLE alf_node_assoc
   ADD CONSTRAINT alf_node_assoc_source_node_id_key UNIQUE (source_node_id, target_node_id, type_qname_id);

-- -----------------------------
-- Populate the Node Aspects --
-- -----------------------------

CREATE TABLE t_alf_node_aspects
(
   node_id INT8 NOT NULL,
   qname_id INT8 NOT NULL,
   CONSTRAINT fk_alf_nasp_n FOREIGN KEY (node_id) REFERENCES t_alf_node (id),
   CONSTRAINT fk_alf_nasp_qn FOREIGN KEY (qname_id) REFERENCES alf_qname (id),
   PRIMARY KEY (node_id, qname_id)
);
CREATE INDEX fk_alf_nasp_n ON t_alf_node_aspects (node_id);
CREATE INDEX fk_alf_nasp_qn ON t_alf_node_aspects (qname_id);

-- Note the omission of sys:referencable.  This is implicit.
INSERT INTO t_alf_node_aspects
   (
      node_id, qname_id
   )
   SELECT
      na.node_id,
      qname_id
   FROM
      alf_node_aspects na
      JOIN alf_qname qn ON (na.qname_id = qn.id)
      JOIN alf_namespace ns ON (qn.ns_id = ns.id)
   WHERE
      ns.uri != 'http://www.alfresco.org/model/system/1.0' OR
      qn.local_name != 'referenceable'
;

-- Clean up
DROP TABLE alf_node_aspects;
ALTER TABLE t_alf_node_aspects RENAME TO alf_node_aspects;

-- ---------------------------------
-- Populate the AVM Node Aspects --
-- ---------------------------------

CREATE TABLE t_avm_aspects
(
   node_id INT8 NOT NULL,
   qname_id INT8 NOT NULL,
   CONSTRAINT fk_avm_nasp_n FOREIGN KEY (node_id) REFERENCES avm_nodes (id),
   CONSTRAINT fk_avm_nasp_qn FOREIGN KEY (qname_id) REFERENCES alf_qname (id),
   PRIMARY KEY (node_id, qname_id)
);
CREATE INDEX fk_avm_nasp_n ON t_avm_aspects (node_id);
CREATE INDEX fk_avm_nasp_qn ON t_avm_aspects (qname_id);

INSERT INTO t_avm_aspects
   (
      node_id, qname_id
   )
   SELECT
      anew.id,
      anew.qname_id
   FROM
      avm_aspects_new anew
;

-- Clean up
DROP TABLE avm_aspects;
DROP TABLE avm_aspects_new;
ALTER TABLE t_avm_aspects RENAME TO avm_aspects;

-- ----------------------------------
-- Migrate Sundry Property Tables --
-- ----------------------------------

-- Modify the avm_store_properties table
CREATE TABLE t_avm_store_properties
(
   id INT8 NOT NULL,
   avm_store_id INT8,
   qname_id INT8 NOT NULL,
   actual_type_n INT4 NOT NULL,
   persisted_type_n INT4 NOT NULL,
   multi_valued BOOL NOT NULL,
   boolean_value BOOL,
   long_value INT8,
   float_value FLOAT4,
   double_value FLOAT8,
   string_value VARCHAR(1024),
   serializable_value BYTEA,
   CONSTRAINT fk_avm_sprop_store FOREIGN KEY (avm_store_id) REFERENCES avm_stores (id),
   CONSTRAINT fk_avm_sprop_qname FOREIGN KEY (qname_id) REFERENCES alf_qname (id),
   PRIMARY KEY (id)
);
CREATE INDEX fk_avm_sprop_store ON t_avm_store_properties (avm_store_id);
CREATE INDEX fk_avm_sprop_qname ON t_avm_store_properties (qname_id);

INSERT INTO t_avm_store_properties
   (
      id,
      avm_store_id,
      qname_id,
      actual_type_n, persisted_type_n,
      multi_valued, boolean_value, long_value, float_value, double_value, string_value, serializable_value
   )
   SELECT
      NEXTVAL ('hibernate_sequence'),
      p.avm_store_id,
      p.qname_id,
      p.actual_type_n, p.persisted_type_n,
      p.multi_valued, p.boolean_value, p.long_value, p.float_value, p.double_value, p.string_value, p.serializable_value
   FROM
      avm_store_properties p
;
DROP TABLE avm_store_properties;
ALTER TABLE t_avm_store_properties RENAME TO avm_store_properties;

-- Modify the avm_node_properties_new table
CREATE TABLE t_avm_node_properties
(
   node_id INT8 NOT NULL,
   qname_id INT8 NOT NULL,
   actual_type_n INT4 NOT NULL,
   persisted_type_n INT4 NOT NULL,
   multi_valued BOOL NOT NULL,
   boolean_value BOOL,
   long_value INT8,
   float_value FLOAT4,
   double_value FLOAT8,
   string_value VARCHAR(1024),
   serializable_value BYTEA,
   CONSTRAINT fk_avm_nprop_n FOREIGN KEY (node_id) REFERENCES avm_nodes (id),
   CONSTRAINT fk_avm_nprop_qn FOREIGN KEY (qname_id) REFERENCES alf_qname (id),
   PRIMARY KEY (node_id, qname_id)
);
CREATE INDEX fk_avm_nprop_n ON t_avm_node_properties (node_id);
CREATE INDEX fk_avm_nprop_qn ON t_avm_node_properties (qname_id);

INSERT INTO t_avm_node_properties
   (
      node_id,
      qname_id,
      actual_type_n, persisted_type_n,
      multi_valued, boolean_value, long_value, float_value, double_value, string_value, serializable_value
   )
   SELECT
      p.node_id,
      p.qname_id,
      p.actual_type_n, p.persisted_type_n,
      p.multi_valued, p.boolean_value, p.long_value, p.float_value, p.double_value, p.string_value, p.serializable_value
   FROM
      avm_node_properties_new p
;

DROP TABLE avm_node_properties_new;
DROP TABLE avm_node_properties;
ALTER TABLE t_avm_node_properties RENAME TO avm_node_properties;


-- -----------------
-- Build Locales --
-- -----------------

CREATE TABLE alf_locale
(
   id INT8 NOT NULL,
   version INT8 NOT NULL DEFAULT 1,
   locale_str VARCHAR(20) NOT NULL,
   PRIMARY KEY (id),
   UNIQUE (locale_str)
);

INSERT INTO alf_locale (id, locale_str) VALUES (1, '.default');

-- Locales come from the attribute table which was used to support MLText persistence
INSERT INTO alf_locale (id, locale_str)
   SELECT NEXTVAL ('hibernate_sequence'), mkey
      FROM
      (SELECT DISTINCT(ma.mkey)
         FROM alf_node_properties np
         JOIN alf_attributes a1 ON (np.attribute_value = a1.id)
         JOIN alf_map_attribute_entries ma ON (ma.map_id = a1.id)
      ) X
;

-- -------------------------------
-- Migrate ADM Property Tables --
-- -------------------------------

CREATE TABLE t_alf_node_properties
(
   node_id INT8 NOT NULL,
   qname_id INT8 NOT NULL,
   locale_id INT8 NOT NULL,
   list_index INT4 NOT NULL,
   actual_type_n INT4 NOT NULL,
   persisted_type_n INT4 NOT NULL,
   boolean_value BOOL,
   long_value INT8,
   float_value FLOAT4,
   double_value FLOAT8,
   string_value VARCHAR(1024),
   serializable_value BYTEA,
   CONSTRAINT fk_alf_nprop_n FOREIGN KEY (node_id) REFERENCES t_alf_node (id),
   CONSTRAINT fk_alf_nprop_qn FOREIGN KEY (qname_id) REFERENCES alf_qname (id),
   CONSTRAINT fk_alf_nprop_loc FOREIGN KEY (locale_id) REFERENCES alf_locale (id),
   PRIMARY KEY (node_id, qname_id, list_index, locale_id)
);
CREATE INDEX fk_alf_nprop_n ON t_alf_node_properties (node_id);
CREATE INDEX fk_alf_nprop_qn ON t_alf_node_properties (qname_id);
CREATE INDEX fk_alf_nprop_loc ON t_alf_node_properties (locale_id);

-- Copy values over
INSERT INTO t_alf_node_properties
   (
      node_id, qname_id, locale_id, list_index,
      actual_type_n, persisted_type_n,
      boolean_value, long_value, float_value, double_value,
      string_value,
      serializable_value
   )
   SELECT
      np.node_id, np.qname_id, 1, -1,
      np.actual_type_n, np.persisted_type_n,
      np.boolean_value, np.long_value, np.float_value, np.double_value,
      np.string_value,
      np.serializable_value
   FROM
      alf_node_properties np
   WHERE
      np.attribute_value IS NULL
;

UPDATE t_alf_node n SET audit_creator =
(
   SELECT
      string_value
   FROM
      t_alf_node_properties np
      JOIN alf_qname qn ON (np.qname_id = qn.id)
      JOIN alf_namespace ns ON (qn.ns_id = ns.id)
   WHERE
      np.node_id = n.id AND
      ns.uri = 'http://www.alfresco.org/model/content/1.0' AND
      qn.local_name = 'creator'
);
UPDATE t_alf_node n SET audit_created =
(
   SELECT
      string_value
   FROM
      t_alf_node_properties np
      JOIN alf_qname qn ON (np.qname_id = qn.id)
      JOIN alf_namespace ns ON (qn.ns_id = ns.id)
   WHERE
      np.node_id = n.id AND
      ns.uri = 'http://www.alfresco.org/model/content/1.0' AND
      qn.local_name = 'created'
);
UPDATE t_alf_node n SET audit_modifier =
(
   SELECT
      string_value
   FROM
      t_alf_node_properties np
      JOIN alf_qname qn ON (np.qname_id = qn.id)
      JOIN alf_namespace ns ON (qn.ns_id = ns.id)
   WHERE
      np.node_id = n.id AND
      ns.uri = 'http://www.alfresco.org/model/content/1.0' AND
      qn.local_name = 'modifier'
);
UPDATE t_alf_node n SET audit_modified =
(
   SELECT
      string_value
   FROM
      t_alf_node_properties np
      JOIN alf_qname qn ON (np.qname_id = qn.id)
      JOIN alf_namespace ns ON (qn.ns_id = ns.id)
   WHERE
      np.node_id = n.id AND
      ns.uri = 'http://www.alfresco.org/model/content/1.0' AND
      qn.local_name = 'modified'
);
-- Remove the unused cm:auditable properties
DELETE
   FROM t_alf_node_properties
   WHERE EXISTS
   (
      SELECT 1 FROM alf_qname, alf_namespace
      WHERE
         t_alf_node_properties.qname_id = alf_qname.id AND
         alf_qname.ns_id = alf_namespace.id AND
         alf_namespace.uri = 'http://www.alfresco.org/model/content/1.0' AND
         alf_qname.local_name IN ('creator', 'created', 'modifier', 'modified')
   );

-- Copy all MLText values over
INSERT INTO t_alf_node_properties
   (
      node_id, qname_id, list_index, locale_id,
      actual_type_n, persisted_type_n,
      boolean_value, long_value, float_value, double_value,
      string_value,
      serializable_value
   )
   SELECT
      np.node_id, np.qname_id, -1, loc.id,
      -1, 0,
      FALSE, 0, 0, 0,
      a2.string_value,
      a2.serializable_value
   FROM
      alf_node_properties np
      JOIN alf_attributes a1 ON (np.attribute_value = a1.id)
      JOIN alf_map_attribute_entries ma ON (ma.map_id = a1.id)
      JOIN alf_locale loc ON (ma.mkey = loc.locale_str)
      JOIN alf_attributes a2 ON (ma.attribute_id = a2.id)
;  -- (OPTIONAL)
UPDATE t_alf_node_properties
   SET actual_type_n = 6, persisted_type_n = 6, serializable_value = NULL
   WHERE actual_type_n = -1 AND string_value IS NOT NULL
;
UPDATE t_alf_node_properties
   SET actual_type_n = 9, persisted_type_n = 9
   WHERE actual_type_n = -1 AND serializable_value IS NOT NULL
;
DELETE FROM t_alf_node_properties WHERE actual_type_n = -1;

-- Delete the node properties and move the fixed values over
DROP TABLE alf_node_properties;
ALTER TABLE t_alf_node_properties RENAME TO alf_node_properties;

CREATE TABLE t_del_attributes
(
   id INT8 NOT NULL,
   PRIMARY KEY (id)
);
INSERT INTO t_del_attributes
   SELECT id FROM alf_attributes WHERE type = 'M'
;
DELETE FROM t_del_attributes
   WHERE EXISTS
   (
      SELECT 1
      FROM alf_map_attribute_entries ma
      WHERE ma.attribute_id = t_del_attributes.id
   );   
DELETE FROM t_del_attributes
   WHERE EXISTS
   (
      SELECT 1
      FROM alf_list_attribute_entries la
      WHERE la.attribute_id = t_del_attributes.id
   );   
DELETE FROM t_del_attributes
   WHERE EXISTS
   (
      SELECT 1
      FROM alf_global_attributes ga
      WHERE ga.attribute = t_del_attributes.id
   );   
INSERT INTO t_del_attributes
   SELECT a.id FROM t_del_attributes t
   JOIN alf_map_attribute_entries ma ON (ma.map_id = t.id)
   JOIN alf_attributes a ON (ma.attribute_id = a.id)
;
DELETE FROM alf_map_attribute_entries
   WHERE EXISTS
   (
      SELECT 1
      FROM t_del_attributes t
      WHERE alf_map_attribute_entries.map_id = t.id
   );
DELETE FROM alf_list_attribute_entries
   WHERE EXISTS
   (
      SELECT 1
      FROM t_del_attributes t
      WHERE alf_list_attribute_entries.list_id = t.id
   );
DELETE FROM alf_attributes
   WHERE EXISTS
   (
      SELECT 1
      FROM t_del_attributes t
      WHERE alf_attributes.id = t.id
   );
DROP TABLE t_del_attributes;

-- ------------------
-- Final clean up --
-- ------------------
DROP TABLE alf_node_status;
ALTER TABLE alf_store DROP CONSTRAINT fk_alf_store_rn;
DROP TABLE alf_node;
ALTER TABLE t_alf_node RENAME TO alf_node;
DROP TABLE alf_store;
ALTER TABLE t_alf_store RENAME TO alf_store;
CREATE INDEX idx_alf_auth_aut ON alf_authority (authority);  -- (optional)

-- ----------------
-- JBPM Differences
-- ----------------
ALTER TABLE jbpm_processinstance DROP CONSTRAINT jbpm_processinstance_key__key;  -- (optional)
CREATE INDEX idx_procin_key ON jbpm_processinstance (key_);  -- (optional)

--
-- Record script finish
--
DELETE FROM alf_applied_patch WHERE id = 'patch.db-V2.2-Upgrade-From-2.2SP1';
INSERT INTO alf_applied_patch
  (id, description, fixes_from_schema, fixes_to_schema, applied_to_schema, target_schema, applied_on_date, applied_to_server, was_executed, succeeded, report)
  VALUES
  (
    'patch.db-V2.2-Upgrade-From-2.2SP1', 'Manually executed script upgrade V2.2: Upgraded V2.2 SP1 or SP2',
    86, 90, -1, 91, null, 'UNKOWN', TRUE, TRUE, 'Script completed'
  );
