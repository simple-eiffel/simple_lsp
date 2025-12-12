note
	description: "Handler for LSP navigation operations (definition, references, symbols)"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_NAVIGATION_HANDLER

create
	make

feature {NONE} -- Initialization

	make (a_db: LSP_SYMBOL_DATABASE; a_logger: LSP_LOGGER; a_parser: EIFFEL_PARSER)
			-- Create handler with database, logger, and parser
		require
			db_not_void: a_db /= Void
			logger_not_void: a_logger /= Void
			parser_not_void: a_parser /= Void
		do
			symbol_db := a_db
			logger := a_logger
			parser := a_parser
		ensure
			db_set: symbol_db = a_db
			logger_set: logger = a_logger
			parser_set: parser = a_parser
		end

feature -- Access

	symbol_db: LSP_SYMBOL_DATABASE
			-- Symbol database

	logger: LSP_LOGGER
			-- Logger for debugging

	parser: EIFFEL_PARSER
			-- Eiffel source parser

feature -- Definition Operations

	find_definition (a_word: STRING): detachable SIMPLE_JSON_OBJECT
			-- Find definition location for word
		require
			word_not_void: a_word /= Void
			word_not_empty: not a_word.is_empty
		local
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_feature_info: detachable TUPLE [file_path: STRING; line, column: INTEGER; signature, comment: STRING]
		do
			-- Try as class name first
			l_class_info := symbol_db.find_class (a_word)
			if attached l_class_info then
				log_debug ("Found class: " + a_word)
				Result := make_location (l_class_info.file_path, l_class_info.line, l_class_info.column)
			else
				-- Try as feature name (search all classes)
				across symbol_db.all_class_names as class_name until Result /= Void loop
					l_feature_info := symbol_db.find_feature (class_name, a_word)
					if attached l_feature_info then
						log_debug ("Found feature: " + a_word + " in " + class_name)
						Result := make_location (l_feature_info.file_path, l_feature_info.line, l_feature_info.column)
					end
				end
			end
		end

feature -- Reference Operations

	find_references (a_name: STRING): SIMPLE_JSON_ARRAY
			-- Find all references to a symbol (class or feature)
		require
			name_not_void: a_name /= Void
		local
			l_location: SIMPLE_JSON_OBJECT
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
		do
			create Result.make

			if a_name.is_empty then
				-- Empty name, return empty array
			else
				-- Check if it's a class
				l_class_info := symbol_db.find_class (a_name)
				if attached l_class_info then
					l_location := make_location (l_class_info.file_path, l_class_info.line, l_class_info.column)
					Result.add_object (l_location).do_nothing
				end

				-- Find all features with this name (across all classes)
				across symbol_db.all_features_named (a_name) as feat loop
					l_location := make_location (feat.file_path, feat.line, 1)
					Result.add_object (l_location).do_nothing
				end
			end

			log_debug ("Found " + Result.count.out + " references")
		ensure
			result_not_void: Result /= Void
		end

feature -- Document Symbol Operations

	get_document_symbols (a_path: STRING): SIMPLE_JSON_ARRAY
			-- Get document symbols for file
		require
			path_not_void: a_path /= Void
			path_not_empty: not a_path.is_empty
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ast: EIFFEL_AST
			l_symbol: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_start_pos, l_end_pos: SIMPLE_JSON_OBJECT
		do
			create Result.make

			create l_file.make (a_path)
			if l_file.exists then
				l_content := l_file.load.to_string_8
				l_ast := parser.parse_string (l_content)

				across l_ast.classes as cls loop
					-- Add class symbol
					create l_symbol.make
					l_symbol.put_string (cls.name, "name").do_nothing
					l_symbol.put_integer (5, "kind").do_nothing -- Class = 5

					create l_start_pos.make
					l_start_pos.put_integer (cls.line - 1, "line").do_nothing
					l_start_pos.put_integer (cls.column - 1, "character").do_nothing

					create l_end_pos.make
					l_end_pos.put_integer (cls.line - 1, "line").do_nothing
					l_end_pos.put_integer (cls.column - 1 + cls.name.count, "character").do_nothing

					create l_range.make
					l_range.put_object (l_start_pos, "start").do_nothing
					l_range.put_object (l_end_pos, "end").do_nothing

					l_symbol.put_object (l_range, "range").do_nothing
					l_symbol.put_object (l_range, "selectionRange").do_nothing
					Result.add_object (l_symbol).do_nothing

					-- Add feature symbols
					across cls.features as feat loop
						create l_symbol.make
						l_symbol.put_string (feat.name, "name").do_nothing
						if feat.is_attribute then
							l_symbol.put_integer (8, "kind").do_nothing -- Field = 8
						else
							l_symbol.put_integer (6, "kind").do_nothing -- Method = 6
						end

						create l_start_pos.make
						l_start_pos.put_integer (feat.line - 1, "line").do_nothing
						l_start_pos.put_integer (feat.column - 1, "character").do_nothing

						create l_end_pos.make
						l_end_pos.put_integer (feat.line - 1, "line").do_nothing
						l_end_pos.put_integer (feat.column - 1 + feat.name.count, "character").do_nothing

						create l_range.make
						l_range.put_object (l_start_pos, "start").do_nothing
						l_range.put_object (l_end_pos, "end").do_nothing

						l_symbol.put_object (l_range, "range").do_nothing
						l_symbol.put_object (l_range, "selectionRange").do_nothing
						Result.add_object (l_symbol).do_nothing
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

feature -- Workspace Symbol Operations

	get_workspace_symbols (a_query: STRING): SIMPLE_JSON_ARRAY
			-- Get workspace symbols matching query
		require
			query_not_void: a_query /= Void
		local
			l_symbol: SIMPLE_JSON_OBJECT
			l_location: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_start_pos, l_end_pos: SIMPLE_JSON_OBJECT
			l_kind: INTEGER
		do
			create Result.make
			log_debug ("Searching workspace for: '" + a_query + "'")

			across symbol_db.search_symbols (a_query) as sym loop
				create l_symbol.make
				l_symbol.put_string (sym.name, "name").do_nothing

				-- Determine symbol kind
				if sym.kind.same_string ("class") then
					l_kind := 5 -- Class
				elseif sym.kind.same_string ("attribute") then
					l_kind := 8 -- Field
				elseif sym.kind.same_string ("procedure") then
					l_kind := 6 -- Method
				else
					l_kind := 12 -- Function
				end
				l_symbol.put_integer (l_kind, "kind").do_nothing

				-- Container name (class that contains the feature)
				if attached sym.container as cont and then not cont.is_empty then
					l_symbol.put_string (cont, "containerName").do_nothing
				end

				-- Location
				create l_start_pos.make
				l_start_pos.put_integer (sym.line - 1, "line").do_nothing
				l_start_pos.put_integer (0, "character").do_nothing

				create l_end_pos.make
				l_end_pos.put_integer (sym.line - 1, "line").do_nothing
				l_end_pos.put_integer (sym.name.count, "character").do_nothing

				create l_range.make
				l_range.put_object (l_start_pos, "start").do_nothing
				l_range.put_object (l_end_pos, "end").do_nothing

				create l_location.make
				l_location.put_string (path_to_uri (sym.file_path), "uri").do_nothing
				l_location.put_object (l_range, "range").do_nothing

				l_symbol.put_object (l_location, "location").do_nothing
				Result.add_object (l_symbol).do_nothing
			end

			log_debug ("Found " + Result.count.out + " workspace symbols")
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	make_location (a_file: STRING; a_line, a_col: INTEGER): SIMPLE_JSON_OBJECT
			-- Create LSP Location object
		require
			file_not_void: a_file /= Void
			file_not_empty: not a_file.is_empty
			line_valid: a_line >= 0
			col_valid: a_col >= 0
		local
			l_range: SIMPLE_JSON_OBJECT
			l_start_pos, l_end_pos: SIMPLE_JSON_OBJECT
		do
			create l_start_pos.make
			l_start_pos.put_integer (a_line - 1, "line").do_nothing  -- LSP is 0-based
			l_start_pos.put_integer (a_col - 1, "character").do_nothing

			create l_end_pos.make
			l_end_pos.put_integer (a_line - 1, "line").do_nothing
			l_end_pos.put_integer (a_col, "character").do_nothing

			create l_range.make
			l_range.put_object (l_start_pos, "start").do_nothing
			l_range.put_object (l_end_pos, "end").do_nothing

			create Result.make
			Result.put_string (path_to_uri (a_file), "uri").do_nothing
			Result.put_object (l_range, "range").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	path_to_uri (a_path: STRING): STRING
			-- Convert file path to URI
		require
			path_not_void: a_path /= Void
		do
			Result := "file:///" + a_path.twin
			Result.replace_substring_all ("\", "/")
		ensure
			result_not_void: Result /= Void
		end

	log_info (a_msg: STRING)
			-- Log info message
		do
			logger.log_info (a_msg)
		end

	log_debug (a_msg: STRING)
			-- Log debug message
		do
			logger.log_debug (a_msg)
		end

end
