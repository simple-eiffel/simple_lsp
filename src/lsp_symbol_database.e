note
	description: "SQLite database for storing Eiffel symbols - classes, features, inheritance"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_SYMBOL_DATABASE

create
	make

feature {NONE} -- Initialization

	make (a_db_path: STRING)
			-- Create or open symbol database
		require
			path_not_empty: a_db_path /= Void and then not a_db_path.is_empty
		do
			db_path := a_db_path
			create db.make (a_db_path)
			ensure_schema
		ensure
			path_set: db_path = a_db_path
		end

feature -- Access

	db_path: STRING
			-- Path to database file

feature -- Class Operations

	add_class (a_name, a_file_path: STRING; a_line, a_column: INTEGER; a_mtime: INTEGER_64)
			-- Add or update a class in the database
		require
			name_not_empty: a_name /= Void and then not a_name.is_empty
			path_not_empty: a_file_path /= Void and then not a_file_path.is_empty
		do
			db.run_sql_with (
				"INSERT OR REPLACE INTO classes (name, file_path, line, column, file_mtime) VALUES (?, ?, ?, ?, ?)",
				<<a_name, a_file_path, a_line, a_column, a_mtime>>)
		end

	add_class_full (a_name, a_file_path: STRING; a_line, a_column: INTEGER;
	                a_is_deferred, a_is_expanded, a_is_frozen: BOOLEAN;
	                a_header_comment: STRING; a_mtime: INTEGER_64)
			-- Add class with all attributes
		require
			name_not_empty: a_name /= Void and then not a_name.is_empty
			path_not_empty: a_file_path /= Void and then not a_file_path.is_empty
		do
			db.run_sql_with (
				"INSERT OR REPLACE INTO classes (name, file_path, line, column, is_deferred, is_expanded, is_frozen, header_comment, file_mtime) " +
				"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
				<<a_name, a_file_path, a_line, a_column,
				  bool_to_int (a_is_deferred), bool_to_int (a_is_expanded), bool_to_int (a_is_frozen),
				  a_header_comment, a_mtime>>)
		end

	find_class (a_name: STRING): detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			-- Find class by name
		require
			name_not_empty: a_name /= Void and then not a_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := db.fetch_with ("SELECT id, file_path, line, column FROM classes WHERE name = ? COLLATE NOCASE", <<a_name>>)
			if not l_result.is_empty then
				Result := [l_result.first.integer_value ("id"),
				           l_result.first.string_value ("file_path").to_string_8,
				           l_result.first.integer_value ("line"),
				           l_result.first.integer_value ("column")]
			end
		end

	class_id (a_name: STRING): INTEGER
			-- Get class ID by name, 0 if not found
		require
			name_not_empty: a_name /= Void and then not a_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := db.fetch_with ("SELECT id FROM classes WHERE name = ? COLLATE NOCASE", <<a_name>>)
			if not l_result.is_empty then
				Result := l_result.first.integer_value ("id")
			end
		end

	all_class_names: ARRAYED_LIST [STRING]
			-- Get all class names in database
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (100)
			l_result := db.fetch ("SELECT name FROM classes ORDER BY name")
			across l_result.rows as row loop
				Result.extend (row.string_value ("name").to_string_8)
			end
		end

feature -- Feature Operations

	add_feature (a_class_id: INTEGER; a_name, a_kind: STRING; a_line, a_column: INTEGER)
			-- Add a feature to a class
		require
			class_exists: a_class_id > 0
			name_not_empty: a_name /= Void and then not a_name.is_empty
			kind_not_empty: a_kind /= Void and then not a_kind.is_empty
		do
			db.run_sql_with (
				"INSERT INTO features (class_id, name, kind, line, column) VALUES (?, ?, ?, ?, ?)",
				<<a_class_id, a_name, a_kind, a_line, a_column>>)
		end

	add_feature_full (a_class_id: INTEGER; a_name, a_kind: STRING; a_line, a_column: INTEGER;
	                  a_return_type, a_signature, a_precondition, a_postcondition, a_header_comment: STRING;
	                  a_is_deferred, a_is_frozen: BOOLEAN; a_export_status: STRING)
			-- Add feature with all attributes
		require
			class_exists: a_class_id > 0
			name_not_empty: a_name /= Void and then not a_name.is_empty
		do
			db.run_sql_with (
				"INSERT INTO features (class_id, name, kind, line, column, return_type, signature, " +
				"precondition, postcondition, header_comment, is_deferred, is_frozen, export_status) " +
				"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
				<<a_class_id, a_name, a_kind, a_line, a_column,
				  a_return_type, a_signature, a_precondition, a_postcondition, a_header_comment,
				  bool_to_int (a_is_deferred), bool_to_int (a_is_frozen), a_export_status>>)
		end

	find_feature (a_class_name, a_feature_name: STRING): detachable TUPLE [file_path: STRING; line, column: INTEGER; signature, comment: STRING]
			-- Find feature in class
		require
			class_not_empty: a_class_name /= Void and then not a_class_name.is_empty
			feature_not_empty: a_feature_name /= Void and then not a_feature_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := db.fetch_with (
				"SELECT c.file_path, f.line, f.column, f.signature, f.header_comment " +
				"FROM features f JOIN classes c ON f.class_id = c.id " +
				"WHERE c.name = ? COLLATE NOCASE AND f.name = ? COLLATE NOCASE",
				<<a_class_name, a_feature_name>>)
			if not l_result.is_empty then
				Result := [l_result.first.string_value ("file_path").to_string_8,
				           l_result.first.integer_value ("line"),
				           l_result.first.integer_value ("column"),
				           l_result.first.string_value ("signature").to_string_8,
				           l_result.first.string_value ("header_comment").to_string_8]
			end
		end

	features_for_class (a_class_name: STRING): ARRAYED_LIST [TUPLE [name, kind, signature: STRING; line: INTEGER]]
			-- Get all features for a class
		require
			name_not_empty: a_class_name /= Void and then not a_class_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (20)
			l_result := db.fetch_with (
				"SELECT f.name, f.kind, f.signature, f.line " +
				"FROM features f JOIN classes c ON f.class_id = c.id " +
				"WHERE c.name = ? COLLATE NOCASE ORDER BY f.line",
				<<a_class_name>>)
			across l_result.rows as row loop
				Result.extend ([row.string_value ("name").to_string_8,
				               row.string_value ("kind").to_string_8,
				               row.string_value ("signature").to_string_8,
				               row.integer_value ("line")])
			end
		end

	all_features_named (a_name: STRING): ARRAYED_LIST [TUPLE [class_name, file_path: STRING; line: INTEGER]]
			-- Find all features with given name across all classes
		require
			name_not_empty: a_name /= Void and then not a_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (10)
			l_result := db.fetch_with (
				"SELECT c.name as class_name, c.file_path, f.line " +
				"FROM features f JOIN classes c ON f.class_id = c.id " +
				"WHERE f.name = ? COLLATE NOCASE",
				<<a_name>>)
			across l_result.rows as row loop
				Result.extend ([row.string_value ("class_name").to_string_8,
				               row.string_value ("file_path").to_string_8,
				               row.integer_value ("line")])
			end
		end

	all_features: ARRAYED_LIST [TUPLE [name, class_name, kind, signature: STRING; line: INTEGER]]
			-- Get ALL features from all classes (for completion)
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (200)
			l_result := db.fetch (
				"SELECT f.name, c.name as class_name, f.kind, f.signature, f.line " +
				"FROM features f JOIN classes c ON f.class_id = c.id " +
				"ORDER BY f.name")
			across l_result.rows as row loop
				Result.extend ([row.string_value ("name").to_string_8,
				               row.string_value ("class_name").to_string_8,
				               row.string_value ("kind").to_string_8,
				               row.string_value ("signature").to_string_8,
				               row.integer_value ("line")])
			end
		end

	search_symbols (a_query: STRING): ARRAYED_LIST [TUPLE [name, kind, container, file_path: STRING; line: INTEGER]]
			-- Search for symbols matching query (for workspace symbol search)
		require
			query_not_void: a_query /= Void
		local
			l_result: SIMPLE_SQL_RESULT
			l_pattern: STRING
		do
			create Result.make (50)
			l_pattern := "%%" + a_query + "%%"

			-- Search classes
			l_result := db.fetch_with (
				"SELECT name, 'class' as kind, '' as container, file_path, line FROM classes " +
				"WHERE name LIKE ? COLLATE NOCASE " +
				"UNION ALL " +
				"SELECT f.name, f.kind, c.name as container, c.file_path, f.line FROM features f " +
				"JOIN classes c ON f.class_id = c.id " +
				"WHERE f.name LIKE ? COLLATE NOCASE " +
				"LIMIT 100",
				<<l_pattern, l_pattern>>)
			across l_result.rows as row loop
				Result.extend ([row.string_value ("name").to_string_8,
				               row.string_value ("kind").to_string_8,
				               row.string_value ("container").to_string_8,
				               row.string_value ("file_path").to_string_8,
				               row.integer_value ("line")])
			end
		end

feature -- Type Reference Operations (Client/Supplier)

	add_type_reference (a_from_class_id: INTEGER; a_to_type_name: STRING; a_context: STRING)
			-- Record that a_from_class uses a_to_type_name
			-- Context: "attribute", "local", "argument", "return", "creation", "inherit"
		require
			class_exists: a_from_class_id > 0
			type_not_empty: a_to_type_name /= Void and then not a_to_type_name.is_empty
		do
			db.run_sql_with (
				"INSERT OR IGNORE INTO type_references (from_class_id, to_type_name, context) VALUES (?, ?, ?)",
				<<a_from_class_id, a_to_type_name.as_upper, a_context>>)
		end

	suppliers_of (a_class_name: STRING): ARRAYED_LIST [STRING]
			-- Get types that a_class_name uses (its suppliers)
		require
			name_not_empty: a_class_name /= Void and then not a_class_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (10)
			l_result := db.fetch_with (
				"SELECT DISTINCT tr.to_type_name FROM type_references tr " +
				"JOIN classes c ON tr.from_class_id = c.id " +
				"WHERE c.name = ? COLLATE NOCASE " +
				"ORDER BY tr.to_type_name",
				<<a_class_name>>)
			across l_result.rows as row loop
				Result.extend (row.string_value ("to_type_name").to_string_8)
			end
		end

	clients_of (a_class_name: STRING): ARRAYED_LIST [STRING]
			-- Get classes that use a_class_name (its clients)
		require
			name_not_empty: a_class_name /= Void and then not a_class_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (10)
			l_result := db.fetch_with (
				"SELECT DISTINCT c.name FROM type_references tr " +
				"JOIN classes c ON tr.from_class_id = c.id " +
				"WHERE tr.to_type_name = ? COLLATE NOCASE " +
				"ORDER BY c.name",
				<<a_class_name>>)
			across l_result.rows as row loop
				Result.extend (row.string_value ("name").to_string_8)
			end
		end

	clear_type_references (a_class_id: INTEGER)
			-- Clear type references for a class (before reparsing)
		require
			class_exists: a_class_id > 0
		do
			db.run_sql_with ("DELETE FROM type_references WHERE from_class_id = ?", <<a_class_id>>)
		end

feature -- Inheritance Operations

	add_inheritance (a_child_id: INTEGER; a_parent_name: STRING)
			-- Add inheritance relationship
		require
			child_exists: a_child_id > 0
			parent_not_empty: a_parent_name /= Void and then not a_parent_name.is_empty
		do
			db.run_sql_with (
				"INSERT INTO inheritance (child_id, parent_name) VALUES (?, ?)",
				<<a_child_id, a_parent_name>>)
		end

	parents_of (a_class_name: STRING): ARRAYED_LIST [STRING]
			-- Get parent class names
		require
			name_not_empty: a_class_name /= Void and then not a_class_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (5)
			l_result := db.fetch_with (
				"SELECT i.parent_name FROM inheritance i " +
				"JOIN classes c ON i.child_id = c.id " +
				"WHERE c.name = ? COLLATE NOCASE",
				<<a_class_name>>)
			across l_result.rows as row loop
				Result.extend (row.string_value ("parent_name").to_string_8)
			end
		end

feature -- File Operations

	file_mtime (a_path: STRING): INTEGER_64
			-- Get stored mtime for file, 0 if not found
		require
			path_not_empty: a_path /= Void and then not a_path.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := db.fetch_with ("SELECT file_mtime FROM classes WHERE file_path = ? LIMIT 1", <<a_path>>)
			if not l_result.is_empty then
				Result := l_result.first.integer_64_value ("file_mtime")
			end
		end

	clear_file (a_path: STRING)
			-- Remove all symbols from a file (before reparsing)
		require
			path_not_empty: a_path /= Void and then not a_path.is_empty
		do
			-- Features and inheritance are deleted by CASCADE
			db.run_sql_with ("DELETE FROM classes WHERE file_path = ?", <<a_path>>)
		end

feature -- Diagnostics

	add_error (a_file_path: STRING; a_line, a_column: INTEGER; a_message, a_severity: STRING)
			-- Add a parse error
		require
			path_not_empty: a_file_path /= Void and then not a_file_path.is_empty
			message_not_empty: a_message /= Void and then not a_message.is_empty
		do
			db.run_sql_with (
				"INSERT INTO parse_errors (file_path, line, column, message, severity) VALUES (?, ?, ?, ?, ?)",
				<<a_file_path, a_line, a_column, a_message, a_severity>>)
		end

	errors_for_file (a_path: STRING): ARRAYED_LIST [TUPLE [line, column: INTEGER; message, severity: STRING]]
			-- Get all errors for a file
		require
			path_not_empty: a_path /= Void and then not a_path.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (5)
			l_result := db.fetch_with (
				"SELECT line, column, message, severity FROM parse_errors WHERE file_path = ?",
				<<a_path>>)
			across l_result.rows as row loop
				Result.extend ([row.integer_value ("line"),
				               row.integer_value ("column"),
				               row.string_value ("message").to_string_8,
				               row.string_value ("severity").to_string_8])
			end
		end

	clear_errors (a_path: STRING)
			-- Clear errors for a file
		require
			path_not_empty: a_path /= Void and then not a_path.is_empty
		do
			db.run_sql_with ("DELETE FROM parse_errors WHERE file_path = ?", <<a_path>>)
		end

	all_file_paths: ARRAYED_LIST [STRING]
			-- Get all indexed file paths
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (50)
			l_result := db.fetch ("SELECT DISTINCT file_path FROM classes ORDER BY file_path")
			across l_result.rows as row loop
				Result.extend (row.string_value ("file_path").to_string_8)
			end
		end

feature -- Lifecycle

	close
			-- Close database
		do
			db.close
		end

feature {NONE} -- Schema

	ensure_schema
			-- Create tables if they don't exist
		do
			db.run_sql ("PRAGMA foreign_keys = ON")

			db.run_sql ("CREATE TABLE IF NOT EXISTS classes (" +
				"id INTEGER PRIMARY KEY, " +
				"name TEXT NOT NULL UNIQUE, " +
				"file_path TEXT NOT NULL, " +
				"line INTEGER NOT NULL, " +
				"column INTEGER NOT NULL, " +
				"is_deferred INTEGER DEFAULT 0, " +
				"is_expanded INTEGER DEFAULT 0, " +
				"is_frozen INTEGER DEFAULT 0, " +
				"header_comment TEXT, " +
				"file_mtime INTEGER NOT NULL DEFAULT 0" +
				")")

			db.run_sql ("CREATE INDEX IF NOT EXISTS idx_classes_name ON classes(name)")
			db.run_sql ("CREATE INDEX IF NOT EXISTS idx_classes_file ON classes(file_path)")

			db.run_sql ("CREATE TABLE IF NOT EXISTS features (" +
				"id INTEGER PRIMARY KEY, " +
				"class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE, " +
				"name TEXT NOT NULL, " +
				"kind TEXT NOT NULL, " +
				"line INTEGER NOT NULL, " +
				"column INTEGER NOT NULL, " +
				"return_type TEXT, " +
				"signature TEXT, " +
				"precondition TEXT, " +
				"postcondition TEXT, " +
				"header_comment TEXT, " +
				"is_deferred INTEGER DEFAULT 0, " +
				"is_frozen INTEGER DEFAULT 0, " +
				"export_status TEXT DEFAULT 'ANY'" +
				")")

			db.run_sql ("CREATE INDEX IF NOT EXISTS idx_features_class ON features(class_id)")
			db.run_sql ("CREATE INDEX IF NOT EXISTS idx_features_name ON features(name)")

			db.run_sql ("CREATE TABLE IF NOT EXISTS inheritance (" +
				"id INTEGER PRIMARY KEY, " +
				"child_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE, " +
				"parent_name TEXT NOT NULL, " +
				"parent_id INTEGER REFERENCES classes(id), " +
				"rename_clause TEXT, " +
				"redefine_list TEXT, " +
				"undefine_list TEXT, " +
				"select_list TEXT" +
				")")

			db.run_sql ("CREATE INDEX IF NOT EXISTS idx_inheritance_child ON inheritance(child_id)")

			db.run_sql ("CREATE TABLE IF NOT EXISTS arguments (" +
				"id INTEGER PRIMARY KEY, " +
				"feature_id INTEGER NOT NULL REFERENCES features(id) ON DELETE CASCADE, " +
				"name TEXT NOT NULL, " +
				"arg_type TEXT NOT NULL, " +
				"position INTEGER NOT NULL" +
				")")

			db.run_sql ("CREATE TABLE IF NOT EXISTS locals (" +
				"id INTEGER PRIMARY KEY, " +
				"feature_id INTEGER NOT NULL REFERENCES features(id) ON DELETE CASCADE, " +
				"name TEXT NOT NULL, " +
				"local_type TEXT NOT NULL, " +
				"line INTEGER NOT NULL" +
				")")

			db.run_sql ("CREATE TABLE IF NOT EXISTS parse_errors (" +
				"id INTEGER PRIMARY KEY, " +
				"file_path TEXT NOT NULL, " +
				"line INTEGER NOT NULL, " +
				"column INTEGER NOT NULL, " +
				"message TEXT NOT NULL, " +
				"severity TEXT DEFAULT 'error'" +
				")")

			db.run_sql ("CREATE INDEX IF NOT EXISTS idx_errors_file ON parse_errors(file_path)")

			-- Type references table for client/supplier relationships
			db.run_sql ("CREATE TABLE IF NOT EXISTS type_references (" +
				"id INTEGER PRIMARY KEY, " +
				"from_class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE, " +
				"to_type_name TEXT NOT NULL, " +
				"context TEXT NOT NULL, " +
				"UNIQUE(from_class_id, to_type_name, context)" +
				")")

			db.run_sql ("CREATE INDEX IF NOT EXISTS idx_typeref_from ON type_references(from_class_id)")
			db.run_sql ("CREATE INDEX IF NOT EXISTS idx_typeref_to ON type_references(to_type_name)")
		end

feature {NONE} -- Implementation

	db: SIMPLE_SQL_DATABASE
			-- Database connection

	bool_to_int (a_bool: BOOLEAN): INTEGER
			-- Convert boolean to SQLite integer
		do
			if a_bool then
				Result := 1
			end
		end

invariant
	db_exists: db /= Void
	path_not_empty: db_path /= Void and then not db_path.is_empty

end
