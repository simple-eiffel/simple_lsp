note
	description: "Handler for LSP Go to Implementation - jump to implementations of deferred features"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_IMPLEMENTATION_HANDLER

create
	make

feature {NONE} -- Initialization

	make (a_db: LSP_SYMBOL_DATABASE; a_logger: LSP_LOGGER; a_eifgens_parser: EIFGENS_METADATA_PARSER)
			-- Create handler with database, logger, and EIFGENs parser
		require
			db_not_void: a_db /= Void
			logger_not_void: a_logger /= Void
			eifgens_parser_not_void: a_eifgens_parser /= Void
		do
			symbol_db := a_db
			logger := a_logger
			eifgens_parser := a_eifgens_parser
			create parser.make
		ensure
			db_set: symbol_db = a_db
			logger_set: logger = a_logger
			eifgens_parser_set: eifgens_parser = a_eifgens_parser
		end

feature -- Access

	symbol_db: LSP_SYMBOL_DATABASE
			-- Symbol database

	logger: LSP_LOGGER
			-- Logger for debugging

	eifgens_parser: EIFGENS_METADATA_PARSER
			-- EIFGENs metadata parser for inheritance info

	parser: EIFFEL_PARSER
			-- Eiffel source parser

feature -- Operations

	get_implementations (a_class_name, a_feature_name: STRING): SIMPLE_JSON_ARRAY
			-- Get implementations of a deferred feature
			-- Returns array of Location objects pointing to concrete implementations
		require
			class_name_not_void: a_class_name /= Void
			feature_name_not_void: a_feature_name /= Void
		local
			l_implementations: ARRAYED_LIST [TUPLE [class_name: STRING; file_path: STRING; line: INTEGER]]
			l_location: SIMPLE_JSON_OBJECT
		do
			create Result.make
			l_implementations := find_implementations (a_class_name, a_feature_name)

			across l_implementations as impl loop
				l_location := make_location (impl.file_path, impl.line)
				Result.add_object (l_location).do_nothing
			end

			log_debug ("Found " + Result.count.out + " implementations for " + a_class_name + "." + a_feature_name)
		ensure
			result_not_void: Result /= Void
		end

	is_deferred_feature (a_class_name, a_feature_name: STRING): BOOLEAN
			-- Check if feature is deferred in the given class
		require
			class_name_not_void: a_class_name /= Void
			feature_name_not_void: a_feature_name /= Void
		local
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_feature: detachable EIFFEL_FEATURE_NODE
		do
			l_class_info := symbol_db.find_class (a_class_name.as_upper)
			if attached l_class_info then
				l_feature := find_feature_in_file (l_class_info.file_path, a_feature_name)
				if attached l_feature then
					Result := l_feature.is_deferred
				end
			end
		end

feature {NONE} -- Implementation

	find_implementations (a_class_name, a_feature_name: STRING): ARRAYED_LIST [TUPLE [class_name: STRING; file_path: STRING; line: INTEGER]]
			-- Find all classes that implement this deferred feature
		require
			class_name_not_void: a_class_name /= Void
			feature_name_not_void: a_feature_name /= Void
		local
			l_class_upper: STRING
			l_chain: ARRAYED_LIST [STRING]
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_feature: detachable EIFFEL_FEATURE_NODE
		do
			create Result.make (10)
			l_class_upper := a_class_name.as_upper

			-- Search all workspace classes
			across symbol_db.all_class_names as class_name loop
				-- Check if this class inherits from our target class
				l_chain := eifgens_parser.ancestor_chain (class_name)
				if chain_contains (l_chain, l_class_upper) and then not class_name.same_string (l_class_upper) then
					-- This class inherits from target - check if it has a concrete implementation
					l_class_info := symbol_db.find_class (class_name)
					if attached l_class_info then
						l_feature := find_feature_in_file (l_class_info.file_path, a_feature_name)
						if attached l_feature and then not l_feature.is_deferred then
							-- Found concrete implementation
							Result.extend ([class_name.twin, l_class_info.file_path.twin, l_feature.line])
						end
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	chain_contains (a_chain: ARRAYED_LIST [STRING]; a_class_name: STRING): BOOLEAN
			-- Check if chain contains class name
		require
			chain_not_void: a_chain /= Void
			class_name_not_void: a_class_name /= Void
		do
			across a_chain as item loop
				if item.as_upper.same_string (a_class_name) then
					Result := True
				end
			end
		end

	find_feature_in_file (a_path, a_feature_name: STRING): detachable EIFFEL_FEATURE_NODE
			-- Find feature in source file
		require
			path_not_empty: not a_path.is_empty
			feature_name_not_empty: not a_feature_name.is_empty
		local
			l_ast: EIFFEL_AST
			l_feature_lower: STRING
		do
			l_ast := parser.parse_file (a_path)
			l_feature_lower := a_feature_name.as_lower

			across l_ast.classes as cls until Result /= Void loop
				across cls.features as feat until Result /= Void loop
					if feat.name.as_lower.same_string (l_feature_lower) then
						Result := feat
					end
				end
			end
		end

	make_location (a_file_path: STRING; a_line: INTEGER): SIMPLE_JSON_OBJECT
			-- Create LSP Location object
		require
			file_path_not_void: a_file_path /= Void
		local
			l_range: SIMPLE_JSON_OBJECT
		do
			create Result.make
			Result.put_string (path_to_uri (a_file_path), "uri").do_nothing
			l_range := make_range (a_line - 1, 0, a_line - 1, 0)
			Result.put_object (l_range, "range").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	make_range (a_start_line, a_start_char, a_end_line, a_end_char: INTEGER): SIMPLE_JSON_OBJECT
			-- Create LSP range object
		local
			l_start, l_end: SIMPLE_JSON_OBJECT
		do
			create Result.make
			create l_start.make
			l_start.put_integer (a_start_line, "line").do_nothing
			l_start.put_integer (a_start_char, "character").do_nothing
			create l_end.make
			l_end.put_integer (a_end_line, "line").do_nothing
			l_end.put_integer (a_end_char, "character").do_nothing
			Result.put_object (l_start, "start").do_nothing
			Result.put_object (l_end, "end").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	path_to_uri (a_path: STRING): STRING
			-- Convert file path to URI
		require
			path_not_void: a_path /= Void
		do
			create Result.make_from_string ("file:///")
			Result.append (a_path.twin)
			Result.replace_substring_all ("\", "/")
		ensure
			result_not_void: Result /= Void
		end

	log_debug (a_msg: STRING)
			-- Log debug message
		do
			logger.log_debug (a_msg)
		end

end
