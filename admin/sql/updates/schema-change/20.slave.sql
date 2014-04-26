-- Created by merging:
-- 20140310-dates.sql
-- 20140212-ordering-columns.sql
-- 20140208-drop-script_language.sql
-- 20140407-link-cardinality.sql
-- 20140311-remove-area-sortnames.sql
-- 20140313-remove-label-sortnames.sql
-- 20140214-add-instruments.sql
-- 20140215-add-instruments-documentation.sql (changing tables to fully specified with schema and removing search_path declaration)
-- 20140318-series.sql
-- 20140418-series-instrument-functions.sql

-- Plus the addition of descriptive SELECTs for each section.
\set ON_ERROR_STOP 1
BEGIN;

SELECT 'Adding has_dates flag to reltypes';
ALTER TABLE link_type ADD COLUMN has_dates BOOLEAN NOT NULL DEFAULT TRUE;

--------------------------------------------------------------------------------

SELECT 'Adding ordering columns';

ALTER TABLE area_alias_type ADD COLUMN parent INTEGER;
ALTER TABLE area_alias_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE area_alias_type ADD COLUMN description TEXT;

ALTER TABLE area_type ADD COLUMN parent INTEGER;
ALTER TABLE area_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE area_type ADD COLUMN description TEXT;

ALTER TABLE artist_type ADD COLUMN parent INTEGER;
ALTER TABLE artist_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE artist_type ADD COLUMN description TEXT;

ALTER TABLE artist_alias_type ADD COLUMN parent INTEGER;
ALTER TABLE artist_alias_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE artist_alias_type ADD COLUMN description TEXT;

ALTER TABLE gender ADD COLUMN parent INTEGER;
ALTER TABLE gender ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE gender ADD COLUMN description TEXT;

ALTER TABLE label_type ADD COLUMN parent INTEGER;
ALTER TABLE label_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE label_type ADD COLUMN description TEXT;

ALTER TABLE label_alias_type ADD COLUMN parent INTEGER;
ALTER TABLE label_alias_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE label_alias_type ADD COLUMN description TEXT;

ALTER TABLE medium_format ADD COLUMN description TEXT;

ALTER TABLE place_type ADD COLUMN parent INTEGER;
ALTER TABLE place_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE place_type ADD COLUMN description TEXT;

ALTER TABLE place_alias_type ADD COLUMN parent INTEGER;
ALTER TABLE place_alias_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE place_alias_type ADD COLUMN description TEXT;

ALTER TABLE release_group_primary_type ADD COLUMN parent INTEGER;
ALTER TABLE release_group_primary_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE release_group_primary_type ADD COLUMN description TEXT;

ALTER TABLE release_group_secondary_type ADD COLUMN parent INTEGER;
ALTER TABLE release_group_secondary_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE release_group_secondary_type ADD COLUMN description TEXT;

ALTER TABLE release_packaging ADD COLUMN parent INTEGER;
ALTER TABLE release_packaging ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE release_packaging ADD COLUMN description TEXT;

ALTER TABLE release_status ADD COLUMN parent INTEGER;
ALTER TABLE release_status ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE release_status ADD COLUMN description TEXT;

ALTER TABLE work_alias_type ADD COLUMN parent INTEGER;
ALTER TABLE work_alias_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE work_alias_type ADD COLUMN description TEXT;

ALTER TABLE work_attribute_type ADD COLUMN parent INTEGER;
ALTER TABLE work_attribute_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE work_attribute_type ADD COLUMN description TEXT;

ALTER TABLE work_attribute_type_allowed_value ADD COLUMN parent INTEGER;
ALTER TABLE work_attribute_type_allowed_value ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE work_attribute_type_allowed_value ADD COLUMN description TEXT;

ALTER TABLE work_type ADD COLUMN parent INTEGER;
ALTER TABLE work_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE work_type ADD COLUMN description TEXT;

ALTER TABLE cover_art_archive.art_type ADD COLUMN parent INTEGER;
ALTER TABLE cover_art_archive.art_type ADD COLUMN child_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE cover_art_archive.art_type ADD COLUMN description TEXT;


-- set Original Production, Bootleg Production and Reissue Production as children of Production, like pre-NGS (MBS-2410)
UPDATE label_type SET parent = 3 WHERE id IN (4, 5, 6);

-- put Other second to last and None last (MBS-6709)
UPDATE release_packaging SET child_order = 1 WHERE id = 5;
UPDATE release_packaging SET child_order = 2 WHERE id = 7;

-- put Other last
UPDATE cover_art_archive.art_type SET child_order = 1 WHERE id = 8;

--------------------------------------------------------------------------------

SELECT 'DROP TABLE script_language';

DROP TABLE script_language;

--------------------------------------------------------------------------------

SELECT 'Link type cardinality (MBS-7205)';

    ALTER TABLE link_type ADD COLUMN entity0_cardinality integer,
                          ADD COLUMN entity1_cardinality integer;

    -- Type pairs where the info is central to entity1, but many-valued to entity0
    -- e.g. artist-recording (performer, mastering, etc.)
    UPDATE link_type SET entity0_cardinality = 1, entity1_cardinality = 0
     WHERE (entity_type0 = 'artist' AND entity_type1 IN ('recording', 'release', 'release_group', 'work'))
        OR (entity_type0 = 'label'  AND entity_type1 IN ('recording', 'release', 'work'));

    -- Type pairs where the info is central to entity0, but many-valued to entity1
    -- e.g. recording-work (performance, medley, etc.)
    UPDATE link_type SET entity0_cardinality = 0, entity1_cardinality = 1
     WHERE (entity_type0 = 'artist' AND entity_type1 = 'label')
        OR (entity_type0 = 'recording' AND entity_type1 IN ('release', 'work'));

    -- Type pairs where the info is central to both entities. Default.
    UPDATE link_type SET entity0_cardinality = 0, entity1_cardinality = 0 WHERE entity0_cardinality IS NULL AND entity1_cardinality IS NULL;

    ALTER TABLE link_type ALTER COLUMN entity0_cardinality SET NOT NULL,
                          ALTER COLUMN entity0_cardinality SET DEFAULT 0,
                          ALTER COLUMN entity1_cardinality SET NOT NULL,
                          ALTER COLUMN entity1_cardinality SET DEFAULT 0;

--------------------------------------------------------------------------------

SELECT 'Remove area sortnames';

ALTER TABLE area DROP COLUMN sort_name;

--------------------------------------------------------------------------------

SELECT 'Remove label sortnames';

-- Migrate existing sortnames

-- If the name contains non-Latin scripts, we currently have a weird mixture of non-Latin name and Latin sortname.
-- The guidelines for alias sortnames say not to do that, so for those we'll reuse the sortname as the alias name.
INSERT INTO label_alias (label, name, sort_name)
SELECT l.id, l.sort_name, l.sort_name
FROM label l
WHERE l.name != l.sort_name
AND l.name ~ '[\u0370-\u1DFF\u2E80-\u9FFF\uAC00-\uD7FF]'
AND l.sort_name NOT IN (SELECT sort_name FROM label_alias WHERE label = l.id) -- If there's already an alias with this sortname, we're not losing anything by dropping it
ORDER BY l.name;

-- If the name doesn't contain non-Latin scripts, we can just create an alias with the current name and sortname.
INSERT INTO label_alias (label, name, sort_name)
SELECT l.id, l.name, l.sort_name
FROM label l
WHERE l.name != l.sort_name
AND l.name !~ '[\u0370-\u1DFF\u2E80-\u9FFF\uAC00-\uD7FF]'
AND l.id NOT IN (SELECT label FROM label_alias WHERE name = l.name AND sort_name = l.sort_name)
ORDER BY l.name;

-- Drop the column

ALTER TABLE label DROP COLUMN sort_name;

--------------------------------------------------------------------------------

SELECT 'Add instrument entity tables';

CREATE TABLE instrument_type (
    id                  SERIAL, -- PK
    name                VARCHAR(255) NOT NULL,
    parent              INTEGER, -- references instrument_type.id
    child_order         INTEGER NOT NULL DEFAULT 0,
    description         TEXT
);

CREATE TABLE instrument (
    id                  SERIAL, -- PK
    gid                 uuid NOT NULL,
    name                VARCHAR NOT NULL,
    type                INTEGER, -- references instrument_type.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >=0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    comment             VARCHAR(255) NOT NULL DEFAULT '',
    description         TEXT NOT NULL DEFAULT ''
);

CREATE TABLE instrument_gid_redirect
(
    gid                 UUID NOT NULL, -- PK
    new_id              INTEGER NOT NULL, -- references instrument.id
    created             TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE instrument_alias_type (
    id SERIAL, -- PK,
    name TEXT NOT NULL,
    parent              INTEGER, -- references instrument_alias_type.id
    child_order         INTEGER NOT NULL DEFAULT 0,
    description         TEXT
);

CREATE TABLE instrument_alias (
    id                  SERIAL, --PK
    instrument          INTEGER NOT NULL, -- references instrument.id
    name                VARCHAR NOT NULL,
    locale              TEXT,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >=0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    type                INTEGER, -- references instrument_alias_type.id
    sort_name           VARCHAR NOT NULL,
    begin_date_year     SMALLINT,
    begin_date_month    SMALLINT,
    begin_date_day      SMALLINT,
    end_date_year       SMALLINT,
    end_date_month      SMALLINT,
    end_date_day        SMALLINT,
    primary_for_locale  BOOLEAN NOT NULL DEFAULT false,
    ended               BOOLEAN NOT NULL DEFAULT FALSE
      CHECK (
        (
          -- If any end date fields are not null, then ended must be true
          (end_date_year IS NOT NULL OR
           end_date_month IS NOT NULL OR
           end_date_day IS NOT NULL) AND
          ended = TRUE
        ) OR (
          -- Otherwise, all end date fields must be null
          (end_date_year IS NULL AND
           end_date_month IS NULL AND
           end_date_day IS NULL)
        )
      ),
    CONSTRAINT primary_check CHECK ((locale IS NULL AND primary_for_locale IS FALSE) OR (locale IS NOT NULL)),
    CONSTRAINT search_hints_are_empty
      CHECK (
        (type <> 2) OR (
          type = 2 AND sort_name = name AND
          begin_date_year IS NULL AND begin_date_month IS NULL AND begin_date_day IS NULL AND
          end_date_year IS NULL AND end_date_month IS NULL AND end_date_day IS NULL AND
          primary_for_locale IS FALSE AND locale IS NULL
        )
      )
);

CREATE TABLE instrument_annotation (
    instrument  INTEGER NOT NULL, -- PK, references instrument.id
    annotation  INTEGER NOT NULL -- PK, references annotation.id
);

CREATE TABLE edit_instrument
(
    edit                INTEGER NOT NULL, -- PK, references edit.id
    instrument          INTEGER NOT NULL  -- PK, references instrument.id CASCADE
);

CREATE TABLE l_area_instrument
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references area.id
    entity1             INTEGER NOT NULL, -- references instrument.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_artist_instrument
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references artist.id
    entity1             INTEGER NOT NULL, -- references instrument.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_label
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references instrument.id
    entity1             INTEGER NOT NULL, -- references label.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_instrument
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references instrument.id
    entity1             INTEGER NOT NULL, -- references instrument.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_place
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references instrument.id
    entity1             INTEGER NOT NULL, -- references recording.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_recording
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references instrument.id
    entity1             INTEGER NOT NULL, -- references recording.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_release
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references instrument.id
    entity1             INTEGER NOT NULL, -- references release.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_release_group
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references instrument.id
    entity1             INTEGER NOT NULL, -- references release_group.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_url
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references instrument.id
    entity1             INTEGER NOT NULL, -- references url.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_work
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references instrument.id
    entity1             INTEGER NOT NULL, -- references work.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

SELECT setval('link_id_seq', (SELECT MAX(id) FROM link));
SELECT setval('link_type_id_seq', (SELECT MAX(id) FROM link_type));
SELECT setval('url_id_seq', (SELECT MAX(id) FROM url));

INSERT INTO instrument_type (name) VALUES ('Wind instrument'), ('String instrument'), ('Percussion instrument'), ('Electronic instrument'), ('Other instrument');

INSERT INTO instrument_alias_type (name) VALUES ('Instrument name'), ('Search hint');

INSERT INTO instrument (gid, name, description) SELECT gid, name, COALESCE(description, '') FROM link_attribute_type WHERE parent IS NOT NULL AND root = 14 ORDER BY id;

INSERT INTO link_type (gid, entity_type0, entity_type1, name, description, link_phrase, reverse_link_phrase, long_link_phrase, priority) VALUES
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/url/wikipedia'), 'instrument', 'url', 'wikipedia', 'wikipedia', 'Wikipedia', 'Wikipedia', 'Wikipedia', 0),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/url/image'), 'instrument', 'url', 'image', 'image', 'image', 'image', 'image', 0),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/url/wikidata'), 'instrument', 'url', 'wikidata', 'wikidata', 'Wikidata', 'Wikidata', 'Wikidata', 0),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/url/information page'), 'instrument', 'url', 'information page', 'information page', 'information page', 'information page', 'information page', 0),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/instrument/child'), 'instrument', 'instrument', 'child', '', 'child of', 'children', 'is a child of', 0),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/instrument/type of'), 'instrument', 'instrument', 'type of', 'type of', 'type of', 'subtypes', 'is a type of', 0),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/instrument/derived from'), 'instrument', 'instrument', 'derived from', 'derived from', 'derived from', 'derivations', 'is derived from', 0),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/instrument/related to'), 'instrument', 'instrument', 'related to', 'related to', 'related to', 'related instruments', 'is related to', 0),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/instrument/instrument/parts'), 'instrument', 'instrument', 'parts', 'parts', 'consists of', 'part of', 'has parts', 0);

INSERT INTO link (link_type) SELECT id FROM link_type WHERE entity_type0 = 'instrument' ORDER BY id;


-- Remove descriptions which are just the same as the name
UPDATE instrument SET description = '' WHERE description = name;
UPDATE link_attribute_type SET description = '' WHERE description = name AND root = 14;


-- Migrate URLs from instrument descriptions to URL relationships

-- 1. Insert the URLs into the url table
WITH urls AS (
	SELECT DISTINCT regexp_replace(description, '.*\(<a href="(https?://[a-z]+.wikipedia.org/wiki/[^#"]+)">Wikipedia</a>\)$', E'\\1') as url
	FROM link_attribute_type
	WHERE root = 14
	AND description ~ '.*\(<a href="(https?://[a-z]+.wikipedia.org/wiki/[^#"]+)">Wikipedia</a>\)$'
)
INSERT INTO url (gid, url)
SELECT generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', url), url
FROM urls
WHERE url NOT IN (SELECT url FROM url WHERE url = urls.url)
ORDER BY url;


-- 2. Insert relationships into l_instrument_url
INSERT INTO l_instrument_url (link, entity0, entity1)
SELECT link.id, i.id, url.id
FROM (
	SELECT l.id
	FROM link_type lt
	JOIN link l ON l.link_type = lt.id
	WHERE lt.name = 'wikipedia'
	AND lt.entity_type0 = 'instrument'
) AS link, instrument i
JOIN url ON regexp_replace(description, '.*\(<a href="(https?://[a-z]+.wikipedia.org/wiki/[^#"]+)">Wikipedia</a>\)$', E'\\1') = url
WHERE i.description ~ '.*\(<a href="(https?://[a-z]+.wikipedia.org/wiki/[^#"]+)">Wikipedia</a>\)$'
ORDER BY link.id, i.id, url.id;


-- 3. Remove the URLs from the instrument descriptions
UPDATE instrument
SET description = regexp_replace(description, ' *\(<a href="(https?://[a-z]+.wikipedia.org/wiki/[^#"]+)">Wikipedia</a>\)$', '')
WHERE description ~ '.*\(<a href="(https?://[a-z]+.wikipedia.org/wiki/[^#"]+)">Wikipedia</a>\)$';

UPDATE link_attribute_type
SET description = regexp_replace(description, ' *\(<a href="(https?://[a-z]+.wikipedia.org/wiki/[^#"]+)">Wikipedia</a>\)$', '')
WHERE description ~ '.*\(<a href="(https?://[a-z]+.wikipedia.org/wiki/[^#"]+)">Wikipedia</a>\)$'
AND root = 14;


-- Migrate aliases from instrument descriptions to instrument aliases

-- 1. Insert the aliases into instrument_alias
WITH rows AS (
	SELECT id, unnest(regexp_split_to_array(regexp_replace(description, '.*Other names(?: include)?:? (.*?)\.? *$', E'\\1'), ', +| +and +')) AS name
	FROM instrument
	WHERE description ~ 'Other name'
)
INSERT INTO instrument_alias (instrument, name, sort_name) SELECT id, name, name FROM rows ORDER BY id, name;

-- 2. Remove the aliases from the instrument descriptions
UPDATE instrument
SET description = regexp_replace(description, ' ?Other names(?: include)?:? (.*?)\.? *$', '')
WHERE description ~ '.*Other names(?: include)?:? (.*?)\.? *$';

UPDATE link_attribute_type
SET description = regexp_replace(description, ' ?Other names(?: include)?:? (.*?)\.? *$', '')
WHERE description ~ '.*Other names(?: include)?:? (.*?)\.? *$'
AND root = 14;


-- Turn instrument tree into relationships
INSERT INTO l_instrument_instrument (link, entity0, entity1)
SELECT link.id, i_parent.id, i_child.id
FROM (
    SELECT l.id
    FROM link_type lt
    JOIN link l ON l.link_type = lt.id
    WHERE lt.name = 'child'
    AND lt.entity_type0 = 'instrument'
) AS link,
link_attribute_type a_child
JOIN link_attribute_type a_parent ON a_parent.id = a_child.parent
JOIN instrument i_parent ON i_parent.gid = a_parent.gid
JOIN instrument i_child ON i_child.gid = a_child.gid
WHERE a_child.root = 14
AND a_child.parent != 14
ORDER BY link.id, i_parent.id, i_child.id;


-- Flatten the instrument tree
UPDATE link_attribute_type SET child_order = 0, parent = 14 WHERE root = 14 AND id != 14;


SELECT setval('instrument_type_id_seq', (SELECT MAX(id) FROM instrument_type));
SELECT setval('instrument_id_seq', (SELECT MAX(id) FROM instrument));
SELECT setval('instrument_alias_type_id_seq', (SELECT MAX(id) FROM instrument_alias_type));
SELECT setval('instrument_alias_id_seq', (SELECT MAX(id) FROM instrument_alias));
SELECT setval('l_instrument_instrument_id_seq', (SELECT MAX(id) FROM l_instrument_instrument));
SELECT setval('l_instrument_url_id_seq', (SELECT MAX(id) FROM l_instrument_url));
SELECT setval('link_id_seq', (SELECT MAX(id) FROM link));
SELECT setval('link_type_id_seq', (SELECT MAX(id) FROM link_type));
SELECT setval('url_id_seq', (SELECT MAX(id) FROM url));

ALTER TABLE edit_instrument ADD CONSTRAINT edit_instrument_pkey PRIMARY KEY (edit, instrument);
ALTER TABLE instrument ADD CONSTRAINT instrument_pkey PRIMARY KEY (id);
ALTER TABLE instrument_alias ADD CONSTRAINT instrument_alias_pkey PRIMARY KEY (id);
ALTER TABLE instrument_alias_type ADD CONSTRAINT instrument_alias_type_pkey PRIMARY KEY (id);
ALTER TABLE instrument_annotation ADD CONSTRAINT instrument_annotation_pkey PRIMARY KEY (instrument, annotation);
ALTER TABLE instrument_gid_redirect ADD CONSTRAINT instrument_gid_redirect_pkey PRIMARY KEY (gid);
ALTER TABLE instrument_type ADD CONSTRAINT instrument_type_pkey PRIMARY KEY (id);
ALTER TABLE l_area_instrument ADD CONSTRAINT l_area_instrument_pkey PRIMARY KEY (id);
ALTER TABLE l_artist_instrument ADD CONSTRAINT l_artist_instrument_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_instrument ADD CONSTRAINT l_instrument_instrument_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_label ADD CONSTRAINT l_instrument_label_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_place ADD CONSTRAINT l_instrument_place_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_recording ADD CONSTRAINT l_instrument_recording_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_release ADD CONSTRAINT l_instrument_release_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_release_group ADD CONSTRAINT l_instrument_release_group_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_url ADD CONSTRAINT l_instrument_url_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_work ADD CONSTRAINT l_instrument_work_pkey PRIMARY KEY (id);

CREATE INDEX edit_instrument_idx ON edit_label (label);
CREATE UNIQUE INDEX instrument_idx_gid ON instrument (gid);
CREATE INDEX instrument_idx_name ON instrument (name);

CREATE INDEX instrument_alias_idx_instrument ON instrument_alias (instrument);
CREATE UNIQUE INDEX instrument_alias_idx_primary ON instrument_alias (instrument, locale) WHERE primary_for_locale = TRUE AND locale IS NOT NULL;
CREATE UNIQUE INDEX l_area_instrument_idx_uniq ON l_area_label (entity0, entity1, link);
CREATE UNIQUE INDEX l_artist_instrument_idx_uniq ON l_artist_label (entity0, entity1, link);
CREATE UNIQUE INDEX l_instrument_instrument_idx_uniq ON l_instrument_instrument (entity0, entity1, link);
CREATE UNIQUE INDEX l_instrument_label_idx_uniq ON l_instrument_label (entity0, entity1, link);
CREATE UNIQUE INDEX l_instrument_place_idx_uniq ON l_instrument_place (entity0, entity1, link);
CREATE UNIQUE INDEX l_instrument_recording_idx_uniq ON l_instrument_recording (entity0, entity1, link);
CREATE UNIQUE INDEX l_instrument_release_idx_uniq ON l_instrument_release (entity0, entity1, link);
CREATE UNIQUE INDEX l_instrument_release_group_idx_uniq ON l_instrument_release_group (entity0, entity1, link);
CREATE UNIQUE INDEX l_instrument_url_idx_uniq ON l_instrument_url (entity0, entity1, link);
CREATE UNIQUE INDEX l_instrument_work_idx_uniq ON l_instrument_work (entity0, entity1, link);
CREATE INDEX l_area_instrument_idx_entity1 ON l_area_label (entity1);
CREATE INDEX l_artist_instrument_idx_entity1 ON l_artist_label (entity1);
CREATE INDEX l_instrument_instrument_idx_entity1 ON l_instrument_instrument (entity1);
CREATE INDEX l_instrument_label_idx_entity1 ON l_instrument_label (entity1);
CREATE INDEX l_instrument_place_idx_entity1 ON l_instrument_place (entity1);
CREATE INDEX l_instrument_recording_idx_entity1 ON l_instrument_recording (entity1);
CREATE INDEX l_instrument_release_idx_entity1 ON l_instrument_release (entity1);
CREATE INDEX l_instrument_release_group_idx_entity1 ON l_instrument_release_group (entity1);
CREATE INDEX l_instrument_url_idx_entity1 ON l_instrument_url (entity1);
CREATE INDEX l_instrument_work_idx_entity1 ON l_instrument_work (entity1);

CREATE INDEX instrument_idx_txt ON instrument USING gin(to_tsvector('mb_simple', name));

--------------------------------------------------------------------------------

SELECT 'Add instrument entity documentation tables';

CREATE TABLE documentation.l_area_instrument_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_area_instrument.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_artist_instrument_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_artist_instrument.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_instrument_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_instrument.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_label_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_label.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_place_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_place.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_recording_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_recording.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_release_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_release.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_release_group_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_release_group.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_url_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_url.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_work_example (
  id INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_work.id
  published BOOLEAN NOT NULL,
  name TEXT NOT NULL
);

ALTER TABLE documentation.l_area_instrument_example ADD CONSTRAINT l_area_instrument_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_artist_instrument_example ADD CONSTRAINT l_artist_instrument_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_instrument_example ADD CONSTRAINT l_instrument_instrument_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_label_example ADD CONSTRAINT l_instrument_label_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_place_example ADD CONSTRAINT l_instrument_place_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_recording_example ADD CONSTRAINT l_instrument_recording_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_release_example ADD CONSTRAINT l_instrument_release_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_release_group_example ADD CONSTRAINT l_instrument_release_group_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_url_example ADD CONSTRAINT l_instrument_url_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_work_example ADD CONSTRAINT l_instrument_work_example_pkey PRIMARY KEY (id);

--------------------------------------------------------------------------------

SELECT 'Adding series';

-----------------------
-- CREATE NEW TABLES --
-----------------------

CREATE TABLE series
(
    id                  SERIAL,
    gid                 UUID NOT NULL,
    name                VARCHAR NOT NULL,
    comment             VARCHAR(255) NOT NULL DEFAULT '',
    type                INTEGER NOT NULL, -- references series_type.id
    ordering_attribute  INTEGER NOT NULL, -- references link_text_attribute_type.attribute_type
    ordering_type       INTEGER NOT NULL, -- references series_ordering_type.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE series_type
(
    id                  SERIAL,
    name                VARCHAR(255) NOT NULL,
    entity_type         VARCHAR(50) NOT NULL,
    parent              INTEGER, -- references series_type.id
    child_order         INTEGER NOT NULL DEFAULT 0,
    description         TEXT
);

CREATE TABLE series_ordering_type
(
    id                  SERIAL,
    name                VARCHAR(255) NOT NULL,
    parent              INTEGER, -- references series_ordering_type.id
    child_order         INTEGER NOT NULL DEFAULT 0,
    description         TEXT
);

CREATE TABLE series_deletion
(
    gid                 UUID NOT NULL, -- PK
    last_known_name     VARCHAR NOT NULL,
    last_known_comment  TEXT NOT NULL,
    deleted_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE series_gid_redirect
(
    gid                 UUID NOT NULL, -- PK
    new_id              INTEGER NOT NULL,
    created             TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE series_alias_type
(
    id                  SERIAL, -- PK
    name                TEXT NOT NULL,
    parent              INTEGER, -- references series_alias_type.id
    child_order         INTEGER NOT NULL DEFAULT 0,
    description         TEXT
);

CREATE TABLE series_alias
(
    id                  SERIAL,
    series              INTEGER NOT NULL, -- references series.id
    name                VARCHAR NOT NULL,
    locale              TEXT,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    type                INTEGER, -- references series_alias_type.id
    sort_name           VARCHAR NOT NULL,
    begin_date_year     SMALLINT,
    begin_date_month    SMALLINT,
    begin_date_day      SMALLINT,
    end_date_year       SMALLINT,
    end_date_month      SMALLINT,
    end_date_day        SMALLINT,
    primary_for_locale  BOOLEAN NOT NULL DEFAULT FALSE,
    ended               BOOLEAN NOT NULL DEFAULT FALSE
      CHECK (
        (
          -- If any end date fields are not null, then ended must be true
          (end_date_year IS NOT NULL OR
           end_date_month IS NOT NULL OR
           end_date_day IS NOT NULL) AND
          ended = TRUE
        ) OR (
          -- Otherwise, all end date fields must be null
          (end_date_year IS NULL AND
           end_date_month IS NULL AND
           end_date_day IS NULL)
        )
      ),
    CONSTRAINT primary_check CHECK ((locale IS NULL AND primary_for_locale IS FALSE) OR (locale IS NOT NULL)),
    CONSTRAINT search_hints_are_empty
      CHECK (
        (type <> 2) OR (
          type = 2 AND sort_name = name AND
          begin_date_year IS NULL AND begin_date_month IS NULL AND begin_date_day IS NULL AND
          end_date_year IS NULL AND end_date_month IS NULL AND end_date_day IS NULL AND
          primary_for_locale IS FALSE AND locale IS NULL
        )
      )
);

CREATE TABLE series_annotation (
    series              INTEGER NOT NULL, -- PK, references series.id
    annotation          INTEGER NOT NULL -- PK, references annotation.id
);

CREATE TABLE documentation.l_area_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_area_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_artist_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_artist_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_instrument_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_instrument_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_label_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_label_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_place_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_place_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_recording_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_recording_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_release_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_release_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_release_group_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_release_group_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_series_series_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_series_series.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_series_url_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_series_url.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE documentation.l_series_work_example
(
    id                  INTEGER NOT NULL, -- PK, references musicbrainz.l_series_work.id
    published           BOOLEAN NOT NULL,
    name                TEXT NOT NULL
);

CREATE TABLE edit_series
(
    edit                INTEGER NOT NULL, -- PK, references edit.id
    series              INTEGER NOT NULL  -- PK, references series.id CASCADE
);

CREATE TABLE editor_subscribe_series
(
    id                  SERIAL,
    editor              INTEGER NOT NULL, -- references editor.id
    series              INTEGER NOT NULL, -- references series.id
    last_edit_sent      INTEGER NOT NULL -- references edit.id
);

CREATE TABLE editor_subscribe_series_deleted
(
    editor              INTEGER NOT NULL, -- PK, references editor.id
    gid                 UUID NOT NULL, -- PK, references series_deletion.gid
    deleted_by          INTEGER NOT NULL -- references edit.id
);

CREATE TABLE l_area_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_artist_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_instrument_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_label_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_place_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_recording_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_release_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_release_group_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_series_series
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_series_url
(
    id                  SERIAL,
    link                INTEGER NOT NULL,
    entity0             INTEGER NOT NULL,
    entity1             INTEGER NOT NULL,
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE l_series_work
(
    id                  SERIAL,
    link                INTEGER NOT NULL, -- references link.id
    entity0             INTEGER NOT NULL, -- references series.id
    entity1             INTEGER NOT NULL, -- references work.id
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    link_order          INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0)
);

CREATE TABLE link_text_attribute_type (
    attribute_type      INT NOT NULL -- PK, references link_attribute_type.id CASCADE
);

CREATE TABLE link_attribute_text_value (
    link                INT NOT NULL, -- PK, references link.id
    attribute_type      INT NOT NULL, -- PK, references link_text_attribute_type.attribute_type
    text_value          TEXT NOT NULL
);

CREATE TABLE orderable_link_type (
    link_type           INTEGER NOT NULL, -- PK
    direction           SMALLINT NOT NULL DEFAULT 1 CHECK (direction = 1 OR direction = 2)
);

-----------------------
-- CREATE NEW VIEWS  --
-----------------------

CREATE OR REPLACE VIEW recording_series AS
    SELECT entity0 AS recording, entity1 AS series, link_order, text_value
    FROM l_recording_series lrs
    JOIN series s ON s.id = lrs.entity1
    JOIN link l ON l.id = lrs.link
    JOIN link_type lt ON (lt.id = l.link_type AND lt.gid = 'ea6f0698-6782-30d6-b16d-293081b66774')
    JOIN link_attribute_text_value latv ON (latv.attribute_type = s.ordering_attribute AND latv.link = l.id)
    ORDER BY series, link_order;

CREATE OR REPLACE VIEW release_series AS
    SELECT entity0 AS release, entity1 AS series, link_order, text_value
    FROM l_release_series lrs
    JOIN series s ON s.id = lrs.entity1
    JOIN link l ON l.id = lrs.link
    JOIN link_type lt ON (lt.id = l.link_type AND lt.gid = '3fa29f01-8e13-3e49-9b0a-ad212aa2f81d')
    JOIN link_attribute_text_value latv ON (latv.attribute_type = s.ordering_attribute AND latv.link = l.id)
    ORDER BY series, link_order;

CREATE OR REPLACE VIEW release_group_series AS
    SELECT entity0 AS release_group, entity1 AS series, link_order, text_value
    FROM l_release_group_series lrgs
    JOIN series s ON s.id = lrgs.entity1
    JOIN link l ON l.id = lrgs.link
    JOIN link_type lt ON (lt.id = l.link_type AND lt.gid = '01018437-91d8-36b9-bf89-3f885d53b5bd')
    JOIN link_attribute_text_value latv ON (latv.attribute_type = s.ordering_attribute AND latv.link = l.id)
    ORDER BY series, link_order;

CREATE OR REPLACE VIEW work_series AS
    SELECT entity1 AS work, entity0 AS series, link_order, text_value
    FROM l_series_work lsw
    JOIN series s ON s.id = lsw.entity0
    JOIN link l ON l.id = lsw.link
    JOIN link_type lt ON (lt.id = l.link_type AND lt.gid = 'b0d44366-cdf0-3acb-bee6-0f65a77a6ef0')
    JOIN link_attribute_text_value latv ON (latv.attribute_type = s.ordering_attribute AND latv.link = l.id)
    ORDER BY series, link_order;

-------------------------
-- INSERT INITIAL DATA --
-------------------------

-- new relationship types
SELECT setval('link_type_id_seq', (SELECT MAX(id) FROM link_type));

INSERT INTO link_type (gid, entity_type0, entity_type1, name, description, link_phrase, reverse_link_phrase, long_link_phrase) VALUES
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/recording/series/part_of'), 'recording', 'series', 'part of', 'Indicates that the recording is part of a series.', 'parts', 'part of', 'has part'),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/release/series/part_of'), 'release', 'series', 'part of', 'Indicates that the release is part of a series.', 'part of', 'parts', 'has part'),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/release_group/series/part_of'), 'release_group', 'series', 'part of', 'Indicates that the release group is part of a series.', 'part of', 'parts', 'has part'),
    (generate_uuid_v3('6ba7b8119dad11d180b400c04fd430c8', 'http://musicbrainz.org/linktype/series/work/part_of'), 'series', 'work', 'part of', 'Indicates that the work is part of a series.', 'parts', 'part of', 'has part')
    RETURNING id, gid, entity_type0, entity_type1, name, long_link_phrase;

INSERT INTO orderable_link_type (link_type, direction) VALUES
    ((SELECT id FROM link_type WHERE gid = 'ea6f0698-6782-30d6-b16d-293081b66774'), 2),
    ((SELECT id FROM link_type WHERE gid = '3fa29f01-8e13-3e49-9b0a-ad212aa2f81d'), 2),
    ((SELECT id FROM link_type WHERE gid = '01018437-91d8-36b9-bf89-3f885d53b5bd'), 2),
    ((SELECT id FROM link_type WHERE gid = 'b0d44366-cdf0-3acb-bee6-0f65a77a6ef0'), 1);

INSERT INTO series_type (name, entity_type, parent, child_order, description) VALUES
    ('Recording', 'recording', NULL, 0, 'Indicates that the series is of recordings.'),
    ('Release', 'release', NULL, 1, 'Indicates that the series is of releases.'),
    ('Release group', 'release_group', NULL, 2, 'Indicates that the series is of release groups.'),
    ('Work', 'work', NULL, 3, 'Indicates that the series is of works.'),
    ('Catalog', 'work', 4, 0, 'Indicates that the series is a works catalog.');

INSERT INTO series_ordering_type (name, parent, child_order, description) VALUES
    ('Automatic', NULL, 0, 'Sorts the items in the series automatically by their ordering attribute, using a natural sort order.'),
    ('Manual', NULL, 1, 'Allows for manually setting the position of each item in the series.');

INSERT INTO series_alias_type (name) VALUES ('Series name'), ('Search hint');

-----------------------------
-- MIGRATE EXISTING TABLES --
-----------------------------

ALTER TABLE l_area_area ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_area_artist ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_area_label ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_area_place ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_area_recording ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_area_release ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_area_release_group ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_area_url ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_area_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_artist_artist ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_artist_label ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_artist_place ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_artist_recording ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_artist_release ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_artist_release_group ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_artist_url ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_artist_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_label_label ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_label_place ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_label_recording ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_label_release ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_label_release_group ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_label_url ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_label_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_place_place ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_place_recording ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_place_release ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_place_release_group ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_place_url ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_place_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_recording_recording ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_recording_release ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_recording_release_group ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_recording_url ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_recording_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_release_release ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_release_release_group ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_release_url ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_release_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_release_group_release_group ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_release_group_url ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_release_group_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_url_url ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_url_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);
ALTER TABLE l_work_work ADD COLUMN link_order INTEGER NOT NULL DEFAULT 0 CHECK (link_order >= 0);

--------------------
-- CREATE INDEXES --
--------------------

ALTER TABLE documentation.l_area_series_example ADD CONSTRAINT l_area_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_artist_series_example ADD CONSTRAINT l_artist_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_instrument_series_example ADD CONSTRAINT l_instrument_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_label_series_example ADD CONSTRAINT l_label_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_place_series_example ADD CONSTRAINT l_place_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_recording_series_example ADD CONSTRAINT l_recording_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_release_group_series_example ADD CONSTRAINT l_release_group_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_release_series_example ADD CONSTRAINT l_release_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_series_series_example ADD CONSTRAINT l_series_series_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_series_url_example ADD CONSTRAINT l_series_url_example_pkey PRIMARY KEY (id);
ALTER TABLE documentation.l_series_work_example ADD CONSTRAINT l_series_work_example_pkey PRIMARY KEY (id);
ALTER TABLE editor_subscribe_series ADD CONSTRAINT editor_subscribe_series_pkey PRIMARY KEY (id);
ALTER TABLE editor_subscribe_series_deleted ADD CONSTRAINT editor_subscribe_series_deleted_pkey PRIMARY KEY (editor, gid);

ALTER TABLE l_area_series ADD CONSTRAINT l_area_series_pkey PRIMARY KEY (id);
ALTER TABLE l_artist_series ADD CONSTRAINT l_artist_series_pkey PRIMARY KEY (id);
ALTER TABLE l_instrument_series ADD CONSTRAINT l_instrument_series_pkey PRIMARY KEY (id);
ALTER TABLE l_label_series ADD CONSTRAINT l_label_series_pkey PRIMARY KEY (id);
ALTER TABLE l_place_series ADD CONSTRAINT l_place_series_pkey PRIMARY KEY (id);
ALTER TABLE l_recording_series ADD CONSTRAINT l_recording_series_pkey PRIMARY KEY (id);
ALTER TABLE l_release_group_series ADD CONSTRAINT l_release_group_series_pkey PRIMARY KEY (id);
ALTER TABLE l_release_series ADD CONSTRAINT l_release_series_pkey PRIMARY KEY (id);
ALTER TABLE l_series_series ADD CONSTRAINT l_series_series_pkey PRIMARY KEY (id);
ALTER TABLE l_series_url ADD CONSTRAINT l_series_url_pkey PRIMARY KEY (id);
ALTER TABLE l_series_work ADD CONSTRAINT l_series_work_pkey PRIMARY KEY (id);

ALTER TABLE link_attribute_text_value ADD CONSTRAINT link_attribute_text_value_pkey PRIMARY KEY (link, attribute_type);
ALTER TABLE link_text_attribute_type ADD CONSTRAINT link_text_attribute_type_pkey PRIMARY KEY (attribute_type);
ALTER TABLE series ADD CONSTRAINT series_pkey PRIMARY KEY (id);
ALTER TABLE series_alias ADD CONSTRAINT series_alias_pkey PRIMARY KEY (id);
ALTER TABLE series_alias_type ADD CONSTRAINT series_alias_type_pkey PRIMARY KEY (id);
ALTER TABLE series_annotation ADD CONSTRAINT series_annotation_pkey PRIMARY KEY (series, annotation);
ALTER TABLE series_deletion ADD CONSTRAINT series_deletion_pkey PRIMARY KEY (gid);
ALTER TABLE series_gid_redirect ADD CONSTRAINT series_gid_redirect_pkey PRIMARY KEY (gid);
ALTER TABLE series_ordering_type ADD CONSTRAINT series_ordering_type_pkey PRIMARY KEY (id);
ALTER TABLE series_type ADD CONSTRAINT series_type_pkey PRIMARY KEY (id);

DROP INDEX IF EXISTS l_area_area_idx_uniq;
DROP INDEX IF EXISTS l_area_artist_idx_uniq;
DROP INDEX IF EXISTS l_area_instrument_idx_uniq;
DROP INDEX IF EXISTS l_area_label_idx_uniq;
DROP INDEX IF EXISTS l_area_place_idx_uniq;
DROP INDEX IF EXISTS l_area_recording_idx_uniq;
DROP INDEX IF EXISTS l_area_release_idx_uniq;
DROP INDEX IF EXISTS l_area_release_group_idx_uniq;
DROP INDEX IF EXISTS l_area_series_idx_uniq;
DROP INDEX IF EXISTS l_area_url_idx_uniq;
DROP INDEX IF EXISTS l_area_work_idx_uniq;

DROP INDEX IF EXISTS l_artist_artist_idx_uniq;
DROP INDEX IF EXISTS l_artist_instrument_idx_uniq;
DROP INDEX IF EXISTS l_artist_label_idx_uniq;
DROP INDEX IF EXISTS l_artist_place_idx_uniq;
DROP INDEX IF EXISTS l_artist_recording_idx_uniq;
DROP INDEX IF EXISTS l_artist_release_idx_uniq;
DROP INDEX IF EXISTS l_artist_release_group_idx_uniq;
DROP INDEX IF EXISTS l_artist_series_idx_uniq;
DROP INDEX IF EXISTS l_artist_url_idx_uniq;
DROP INDEX IF EXISTS l_artist_work_idx_uniq;

DROP INDEX IF EXISTS l_instrument_instrument_idx_uniq;
DROP INDEX IF EXISTS l_instrument_label_idx_uniq;
DROP INDEX IF EXISTS l_instrument_place_idx_uniq;
DROP INDEX IF EXISTS l_instrument_recording_idx_uniq;
DROP INDEX IF EXISTS l_instrument_release_idx_uniq;
DROP INDEX IF EXISTS l_instrument_release_group_idx_uniq;
DROP INDEX IF EXISTS l_instrument_series_idx_uniq;
DROP INDEX IF EXISTS l_instrument_url_idx_uniq;
DROP INDEX IF EXISTS l_instrument_work_idx_uniq;

DROP INDEX IF EXISTS l_label_label_idx_uniq;
DROP INDEX IF EXISTS l_label_place_idx_uniq;
DROP INDEX IF EXISTS l_label_recording_idx_uniq;
DROP INDEX IF EXISTS l_label_release_idx_uniq;
DROP INDEX IF EXISTS l_label_release_group_idx_uniq;
DROP INDEX IF EXISTS l_label_series_idx_uniq;
DROP INDEX IF EXISTS l_label_url_idx_uniq;
DROP INDEX IF EXISTS l_label_work_idx_uniq;

DROP INDEX IF EXISTS l_place_place_idx_uniq;
DROP INDEX IF EXISTS l_place_recording_idx_uniq;
DROP INDEX IF EXISTS l_place_release_idx_uniq;
DROP INDEX IF EXISTS l_place_release_group_idx_uniq;
DROP INDEX IF EXISTS l_place_series_idx_uniq;
DROP INDEX IF EXISTS l_place_url_idx_uniq;
DROP INDEX IF EXISTS l_place_work_idx_uniq;

DROP INDEX IF EXISTS l_recording_recording_idx_uniq;
DROP INDEX IF EXISTS l_recording_release_idx_uniq;
DROP INDEX IF EXISTS l_recording_release_group_idx_uniq;
DROP INDEX IF EXISTS l_recording_series_idx_uniq;
DROP INDEX IF EXISTS l_recording_url_idx_uniq;
DROP INDEX IF EXISTS l_recording_work_idx_uniq;

DROP INDEX IF EXISTS l_release_release_idx_uniq;
DROP INDEX IF EXISTS l_release_release_group_idx_uniq;
DROP INDEX IF EXISTS l_release_series_idx_uniq;
DROP INDEX IF EXISTS l_release_url_idx_uniq;
DROP INDEX IF EXISTS l_release_work_idx_uniq;

DROP INDEX IF EXISTS l_release_group_release_group_idx_uniq;
DROP INDEX IF EXISTS l_release_group_series_idx_uniq;
DROP INDEX IF EXISTS l_release_group_url_idx_uniq;
DROP INDEX IF EXISTS l_release_group_work_idx_uniq;

DROP INDEX IF EXISTS l_series_series_idx_uniq;
DROP INDEX IF EXISTS l_series_url_idx_uniq;
DROP INDEX IF EXISTS l_series_work_idx_uniq;

DROP INDEX IF EXISTS l_url_url_idx_uniq;
DROP INDEX IF EXISTS l_url_work_idx_uniq;

DROP INDEX IF EXISTS l_work_work_idx_uniq;

CREATE UNIQUE INDEX l_area_area_idx_uniq ON l_area_area (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_artist_idx_uniq ON l_area_artist (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_instrument_idx_uniq ON l_area_label (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_label_idx_uniq ON l_area_label (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_place_idx_uniq ON l_area_place (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_recording_idx_uniq ON l_area_recording (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_release_idx_uniq ON l_area_release (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_release_group_idx_uniq ON l_area_release_group (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_series_idx_uniq ON l_area_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_url_idx_uniq ON l_area_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_area_work_idx_uniq ON l_area_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_artist_artist_idx_uniq ON l_artist_artist (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_instrument_idx_uniq ON l_artist_label (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_label_idx_uniq ON l_artist_label (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_place_idx_uniq ON l_artist_place (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_recording_idx_uniq ON l_artist_recording (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_release_idx_uniq ON l_artist_release (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_release_group_idx_uniq ON l_artist_release_group (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_series_idx_uniq ON l_artist_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_url_idx_uniq ON l_artist_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_artist_work_idx_uniq ON l_artist_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_instrument_instrument_idx_uniq ON l_instrument_instrument (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_instrument_label_idx_uniq ON l_instrument_label (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_instrument_place_idx_uniq ON l_instrument_place (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_instrument_recording_idx_uniq ON l_instrument_recording (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_instrument_release_idx_uniq ON l_instrument_release (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_instrument_release_group_idx_uniq ON l_instrument_release_group (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_instrument_series_idx_uniq ON l_instrument_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_instrument_url_idx_uniq ON l_instrument_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_instrument_work_idx_uniq ON l_instrument_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_label_label_idx_uniq ON l_label_label (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_label_place_idx_uniq ON l_label_place (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_label_recording_idx_uniq ON l_label_recording (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_label_release_idx_uniq ON l_label_release (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_label_release_group_idx_uniq ON l_label_release_group (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_label_series_idx_uniq ON l_label_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_label_url_idx_uniq ON l_label_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_label_work_idx_uniq ON l_label_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_place_place_idx_uniq ON l_place_place (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_place_recording_idx_uniq ON l_place_recording (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_place_release_idx_uniq ON l_place_release (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_place_release_group_idx_uniq ON l_place_release_group (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_place_series_idx_uniq ON l_place_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_place_url_idx_uniq ON l_place_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_place_work_idx_uniq ON l_place_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_recording_recording_idx_uniq ON l_recording_recording (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_recording_release_idx_uniq ON l_recording_release (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_recording_release_group_idx_uniq ON l_recording_release_group (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_recording_series_idx_uniq ON l_recording_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_recording_url_idx_uniq ON l_recording_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_recording_work_idx_uniq ON l_recording_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_release_release_idx_uniq ON l_release_release (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_release_release_group_idx_uniq ON l_release_release_group (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_release_series_idx_uniq ON l_release_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_release_url_idx_uniq ON l_release_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_release_work_idx_uniq ON l_release_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_release_group_release_group_idx_uniq ON l_release_group_release_group (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_release_group_series_idx_uniq ON l_release_group_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_release_group_url_idx_uniq ON l_release_group_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_release_group_work_idx_uniq ON l_release_group_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_series_series_idx_uniq ON l_series_series (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_series_url_idx_uniq ON l_series_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_series_work_idx_uniq ON l_series_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_url_url_idx_uniq ON l_url_url (entity0, entity1, link, link_order);
CREATE UNIQUE INDEX l_url_work_idx_uniq ON l_url_work (entity0, entity1, link, link_order);

CREATE UNIQUE INDEX l_work_work_idx_uniq ON l_work_work (entity0, entity1, link, link_order);

CREATE INDEX l_area_series_idx_entity1 ON l_area_series (entity1);
CREATE INDEX l_artist_series_idx_entity1 ON l_artist_series (entity1);
CREATE INDEX l_label_series_idx_entity1 ON l_label_series (entity1);
CREATE INDEX l_place_series_idx_entity1 ON l_place_series (entity1);
CREATE INDEX l_recording_series_idx_entity1 ON l_recording_series (entity1);
CREATE INDEX l_release_series_idx_entity1 ON l_release_series (entity1);
CREATE INDEX l_release_group_series_idx_entity1 ON l_release_group_series (entity1);
CREATE INDEX l_series_series_idx_entity1 ON l_series_series (entity1);
CREATE INDEX l_series_url_idx_entity1 ON l_series_url (entity1);
CREATE INDEX l_series_work_idx_entity1 ON l_series_work (entity1);

CREATE UNIQUE INDEX series_idx_gid ON series (gid);
CREATE INDEX series_idx_name ON series (name);

CREATE INDEX series_alias_idx_series ON series_alias (series);
CREATE UNIQUE INDEX series_alias_idx_primary ON series_alias (series, locale) WHERE primary_for_locale = TRUE AND locale IS NOT NULL;

CREATE INDEX series_idx_txt ON series USING gin(to_tsvector('mb_simple', name));

CREATE INDEX series_alias_idx_txt ON series_alias USING gin(to_tsvector('mb_simple', name));
CREATE INDEX series_alias_idx_txt_sort ON series_alias USING gin(to_tsvector('mb_simple', sort_name));

--------------------------------------------------------------------------------

SELECT 'Updating functions affected by series and instruments';

CREATE OR REPLACE FUNCTION empty_artists() RETURNS SETOF int AS
$BODY$
  SELECT id FROM artist
  WHERE
    id > 2 AND
    edits_pending = 0 AND
    (
      last_updated < now() - '1 day'::interval OR last_updated is NULL
    )
  EXCEPT
  SELECT artist FROM edit_artist WHERE edit_artist.status = 1
  EXCEPT
  SELECT artist FROM artist_credit_name
  EXCEPT
  SELECT entity1 FROM l_area_artist
  EXCEPT
  SELECT entity0 FROM l_artist_artist
  EXCEPT
  SELECT entity1 FROM l_artist_artist
  EXCEPT
  SELECT entity0 FROM l_artist_instrument
  EXCEPT
  SELECT entity0 FROM l_artist_label
  EXCEPT
  SELECT entity0 FROM l_artist_place
  EXCEPT
  SELECT entity0 FROM l_artist_recording
  EXCEPT
  SELECT entity0 FROM l_artist_release
  EXCEPT
  SELECT entity0 FROM l_artist_release_group
  EXCEPT
  SELECT entity0 FROM l_artist_series
  EXCEPT
  SELECT entity0 FROM l_artist_url
  EXCEPT
  SELECT entity0 FROM l_artist_work;
$BODY$
LANGUAGE 'sql';

CREATE OR REPLACE FUNCTION empty_labels() RETURNS SETOF int AS
$BODY$
  SELECT id FROM label
  WHERE
    id > 1 AND
    edits_pending = 0 AND
    (
      last_updated < now() - '1 day'::interval OR last_updated is NULL
    )
  EXCEPT
  SELECT label FROM edit_label WHERE edit_label.status = 1
  EXCEPT
  SELECT label FROM release_label
  EXCEPT
  SELECT entity1 FROM l_area_label
  EXCEPT
  SELECT entity1 FROM l_artist_label
  EXCEPT
  SELECT entity1 FROM l_instrument_label
  EXCEPT
  SELECT entity1 FROM l_label_label
  EXCEPT
  SELECT entity0 FROM l_label_label
  EXCEPT
  SELECT entity0 FROM l_label_place
  EXCEPT
  SELECT entity0 FROM l_label_recording
  EXCEPT
  SELECT entity0 FROM l_label_release
  EXCEPT
  SELECT entity0 FROM l_label_release_group
  EXCEPT
  SELECT entity0 FROM l_label_series
  EXCEPT
  SELECT entity0 FROM l_label_url
  EXCEPT
  SELECT entity0 FROM l_label_work;
$BODY$
LANGUAGE 'sql';

CREATE OR REPLACE FUNCTION empty_release_groups() RETURNS SETOF int AS
$BODY$
  SELECT id FROM release_group
  WHERE
    edits_pending = 0 AND
    (
      last_updated < now() - '1 day'::interval OR last_updated is NULL
    )
  EXCEPT
  SELECT release_group
  FROM edit_release_group
  JOIN edit ON (edit.id = edit_release_group.edit)
  WHERE edit.status = 1
  EXCEPT
  SELECT release_group FROM release
  EXCEPT
  SELECT entity1 FROM l_area_release_group
  EXCEPT
  SELECT entity1 FROM l_artist_release_group
  EXCEPT
  SELECT entity1 FROM l_instrument_release_group
  EXCEPT
  SELECT entity1 FROM l_label_release_group
  EXCEPT
  SELECT entity1 FROM l_place_release_group
  EXCEPT
  SELECT entity1 FROM l_recording_release_group
  EXCEPT
  SELECT entity1 FROM l_release_release_group
  EXCEPT
  SELECT entity1 FROM l_release_group_release_group
  EXCEPT
  SELECT entity0 FROM l_release_group_release_group
  EXCEPT
  SELECT entity0 FROM l_release_group_series
  EXCEPT
  SELECT entity0 FROM l_release_group_url
  EXCEPT
  SELECT entity0 FROM l_release_group_work;
$BODY$
LANGUAGE 'sql';

CREATE OR REPLACE FUNCTION empty_works() RETURNS SETOF int AS
$BODY$
  SELECT id FROM work
  WHERE
    edits_pending = 0 AND
    (
      last_updated < now() - '1 day'::interval OR last_updated is NULL
    )
  EXCEPT
  SELECT work
  FROM edit_work
  JOIN edit ON (edit.id = edit_work.edit)
  WHERE edit.status = 1
  EXCEPT
  SELECT entity1 FROM l_area_work
  EXCEPT
  SELECT entity1 FROM l_artist_work
  EXCEPT
  SELECT entity1 FROM l_instrument_work
  EXCEPT
  SELECT entity1 FROM l_label_work
  EXCEPT
  SELECT entity1 FROM l_place_work
  EXCEPT
  SELECT entity1 FROM l_recording_work
  EXCEPT
  SELECT entity1 FROM l_release_work
  EXCEPT
  SELECT entity1 FROM l_release_group_work
  EXCEPT
  SELECT entity1 FROM l_series_work
  EXCEPT
  SELECT entity1 FROM l_url_work
  EXCEPT
  SELECT entity1 FROM l_work_work
  EXCEPT
  SELECT entity0 FROM l_work_work;
$BODY$
LANGUAGE 'sql';

CREATE OR REPLACE FUNCTION empty_places() RETURNS SETOF int AS
$BODY$
  SELECT id FROM place
  WHERE
    edits_pending = 0 AND
    (
      last_updated < now() - '1 day'::interval OR last_updated is NULL
    )
  EXCEPT
  SELECT place
  FROM edit_place
  JOIN edit ON (edit.id = edit_place.edit)
  WHERE edit.status = 1
  EXCEPT
  SELECT entity1 FROM l_area_place
  EXCEPT
  SELECT entity1 FROM l_artist_place
  EXCEPT
  SELECT entity1 FROM l_instrument_place
  EXCEPT
  SELECT entity1 FROM l_label_place
  EXCEPT
  SELECT entity1 FROM l_place_place
  EXCEPT
  SELECT entity0 FROM l_place_place
  EXCEPT
  SELECT entity0 FROM l_place_recording
  EXCEPT
  SELECT entity0 FROM l_place_release
  EXCEPT
  SELECT entity0 FROM l_place_release_group
  EXCEPT
  SELECT entity0 FROM l_place_series
  EXCEPT
  SELECT entity0 FROM l_place_url
  EXCEPT
  SELECT entity0 FROM l_place_work;
$BODY$
LANGUAGE 'sql';

CREATE OR REPLACE FUNCTION empty_series() RETURNS SETOF int AS
$BODY$
  SELECT id FROM series
  WHERE
    edits_pending = 0 AND
    (
      last_updated < now() - '1 day'::interval OR last_updated is NULL
    )
  EXCEPT
  SELECT series
  FROM edit_series
  JOIN edit ON (edit.id = edit_series.edit)
  WHERE edit.status = 1
  EXCEPT
  SELECT entity1 FROM l_area_series
  EXCEPT
  SELECT entity1 FROM l_artist_series
  EXCEPT
  SELECT entity1 FROM l_instrument_series
  EXCEPT
  SELECT entity1 FROM l_label_series
  EXCEPT
  SELECT entity1 FROM l_place_series
  EXCEPT
  SELECT entity1 FROM l_recording_series
  EXCEPT
  SELECT entity1 FROM l_release_series
  EXCEPT
  SELECT entity1 FROM l_release_group_series
  EXCEPT
  SELECT entity0 FROM l_series_series
  EXCEPT
  SELECT entity1 FROM l_series_series
  EXCEPT
  SELECT entity0 FROM l_series_url
  EXCEPT
  SELECT entity0 FROM l_series_work;
$BODY$
LANGUAGE 'sql';

CREATE OR REPLACE FUNCTION delete_unused_url(ids INTEGER[])
RETURNS VOID AS $$
DECLARE
  clear_up INTEGER[];
BEGIN
  SELECT ARRAY(
    SELECT id FROM url url_row WHERE id = any(ids)
    AND NOT (
      EXISTS (
        SELECT TRUE FROM l_area_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_artist_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_instrument_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_label_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_place_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_recording_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_release_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_release_group_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_series_url
        WHERE entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_url_url
        WHERE entity0 = url_row.id OR entity1 = url_row.id
        LIMIT 1
      ) OR
      EXISTS (
        SELECT TRUE FROM l_url_work
        WHERE entity0 = url_row.id
        LIMIT 1
      )
    )
  ) INTO clear_up;

  DELETE FROM url_gid_redirect WHERE new_id = any(clear_up);
  DELETE FROM url WHERE id = any(clear_up);
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION delete_orphaned_recordings()
RETURNS TRIGGER
AS $$
  BEGIN
    PERFORM TRUE
    FROM recording outer_r
    WHERE id = OLD.recording
      AND edits_pending = 0
      AND NOT EXISTS (
        SELECT TRUE
        FROM edit JOIN edit_recording er ON edit.id = er.edit
        WHERE er.recording = outer_r.id
          AND type IN (71, 207, 218)
          LIMIT 1
      ) AND NOT EXISTS (
        SELECT TRUE FROM track WHERE track.recording = outer_r.id LIMIT 1
      ) AND NOT EXISTS (
        SELECT TRUE FROM l_area_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_artist_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_instrument_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_label_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_place_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_recording WHERE entity1 = outer_r.id OR entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_release WHERE entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_release_group WHERE entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_series WHERE entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_work WHERE entity0 = outer_r.id
          UNION ALL
         SELECT TRUE FROM l_recording_url WHERE entity0 = outer_r.id
      );

    IF FOUND THEN
      -- Remove references from tables that don't change whether or not this recording
      -- is orphaned.
      DELETE FROM isrc WHERE recording = OLD.recording;
      DELETE FROM recording_annotation WHERE recording = OLD.recording;
      DELETE FROM recording_gid_redirect WHERE new_id = OLD.recording;
      DELETE FROM recording_rating_raw WHERE recording = OLD.recording;
      DELETE FROM recording_tag WHERE recording = OLD.recording;
      DELETE FROM recording_tag_raw WHERE recording = OLD.recording;

      DELETE FROM recording WHERE id = OLD.recording;
    END IF;

    RETURN NULL;
  END;
$$ LANGUAGE 'plpgsql';

COMMIT;
