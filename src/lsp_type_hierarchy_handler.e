note
	description: "Handler for LSP Type Hierarchy - shows inheritance tree visualization"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_TYPE_HIERARCHY_HANDLER

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

feature -- Operations

	prepare_type_hierarchy (a_class_name: STRING): detachable SIMPLE_JSON_ARRAY
			-- Prepare type hierarchy item for class
			-- Returns array with single TypeHierarchyItem or null if not a class
		require
			class_name_not_void: a_class_name /= Void
		local
			l_result: SIMPLE_JSON_ARRAY
			l_item: SIMPLE_JSON_OBJECT
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_class_upper: STRING
		do
			l_class_upper := a_class_name.as_upper

			-- Find class in database
			l_class_info := symbol_db.find_class (l_class_upper)
			if attached l_class_info then
				create l_result.make
				l_item := make_type_hierarchy_item (l_class_upper, l_class_info.file_path, l_class_info.line)
				l_result.add_object (l_item).do_nothing
				Result := l_result

				log_debug ("Prepared type hierarchy for: " + l_class_upper)
			elseif eifgens_parser.has_class (l_class_upper) then
				-- Compiled class (stdlib)
				create l_result.make
				l_item := make_type_hierarchy_item (l_class_upper, "", 1)
				l_result.add_object (l_item).do_nothing
				Result := l_result

				log_debug ("Prepared type hierarchy for compiled class: " + l_class_upper)
			end
		end

	get_supertypes (a_class_name: STRING): SIMPLE_JSON_ARRAY
			-- Get parent types (what this class inherits from)
			-- Uses ancestor_chain and extracts direct parents (first level after self)
		require
			class_name_not_void: a_class_name /= Void
		local
			l_chain: ARRAYED_LIST [STRING]
			l_item: SIMPLE_JSON_OBJECT
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_class_upper: STRING
		do
			create Result.make
			l_class_upper := a_class_name.as_upper

			-- Get full ancestor chain and extract immediate parents
			-- The chain is breadth-first: [self, parent1, parent2, ..., grandparents, ...]
			-- We want just the immediate parents (skip self, take until we hit grandparents)
			l_chain := eifgens_parser.ancestor_chain (l_class_upper)

			-- Skip first entry (self), take next entries as direct parents
			-- This is a simplification - ideally we'd have direct parent info
			if l_chain.count > 1 then
				across l_chain as parent loop
					if not parent.same_string (l_class_upper) then
						l_class_info := symbol_db.find_class (parent)
						if attached l_class_info then
							l_item := make_type_hierarchy_item (parent, l_class_info.file_path, l_class_info.line)
						else
							-- Compiled class
							l_item := make_type_hierarchy_item (parent, "", 1)
						end
						Result.add_object (l_item).do_nothing
					end
				end
			end

			log_debug ("Found " + Result.count.out + " supertypes for " + a_class_name)
		ensure
			result_not_void: Result /= Void
		end

	get_subtypes (a_class_name: STRING): SIMPLE_JSON_ARRAY
			-- Get child types (what classes inherit from this)
		require
			class_name_not_void: a_class_name /= Void
		local
			l_children: ARRAYED_LIST [STRING]
			l_item: SIMPLE_JSON_OBJECT
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
		do
			create Result.make
			l_children := find_direct_descendants (a_class_name)

			across l_children as child loop
				l_class_info := symbol_db.find_class (child)
				if attached l_class_info then
					l_item := make_type_hierarchy_item (child, l_class_info.file_path, l_class_info.line)
					Result.add_object (l_item).do_nothing
				end
			end

			log_debug ("Found " + Result.count.out + " subtypes for " + a_class_name)
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	find_direct_descendants (a_class_name: STRING): ARRAYED_LIST [STRING]
			-- Find all classes that directly inherit from given class
		require
			class_name_not_void: a_class_name /= Void
		local
			l_chain: ARRAYED_LIST [STRING]
			l_class_upper: STRING
		do
			create Result.make (10)
			l_class_upper := a_class_name.as_upper

			-- Check all workspace classes to see if they inherit from this class
			across symbol_db.all_class_names as class_name loop
				l_chain := eifgens_parser.ancestor_chain (class_name)
				-- If our target is in the chain (but not the class itself), it's a descendant
				if l_chain.count > 1 then
					across l_chain as ancestor loop
						-- Skip self (first entry)
						if not ancestor.same_string (class_name) and then ancestor.as_upper.same_string (l_class_upper) then
							Result.extend (class_name.twin)
						end
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	make_type_hierarchy_item (a_class_name, a_file_path: STRING; a_line: INTEGER): SIMPLE_JSON_OBJECT
			-- Create a TypeHierarchyItem
		require
			class_name_not_void: a_class_name /= Void
			file_path_not_void: a_file_path /= Void
		local
			l_range: SIMPLE_JSON_OBJECT
		do
			create Result.make
			Result.put_string (a_class_name, "name").do_nothing
			Result.put_integer (5, "kind").do_nothing -- Class = 5

			if not a_file_path.is_empty then
				Result.put_string (path_to_uri (a_file_path), "uri").do_nothing
			else
				Result.put_string ("", "uri").do_nothing
			end

			l_range := make_range (a_line - 1, 0, a_line - 1, a_class_name.count)
			Result.put_object (l_range, "range").do_nothing
			Result.put_object (l_range, "selectionRange").do_nothing

			-- Store class name for later calls
			Result.put_string (a_class_name, "data").do_nothing
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
