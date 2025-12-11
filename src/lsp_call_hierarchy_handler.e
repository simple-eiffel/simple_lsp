note
	description: "Handler for LSP Call Hierarchy - shows who calls this / what does this call"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_CALL_HIERARCHY_HANDLER

create
	make

feature {NONE} -- Initialization

	make (a_db: LSP_SYMBOL_DATABASE; a_logger: LSP_LOGGER)
			-- Create handler with database and logger
		require
			db_not_void: a_db /= Void
			logger_not_void: a_logger /= Void
		do
			symbol_db := a_db
			logger := a_logger
			create parser.make
		ensure
			db_set: symbol_db = a_db
			logger_set: logger = a_logger
		end

feature -- Access

	symbol_db: LSP_SYMBOL_DATABASE
			-- Symbol database

	logger: LSP_LOGGER
			-- Logger for debugging

	parser: EIFFEL_PARSER
			-- Eiffel source parser

feature -- Operations

	prepare_call_hierarchy (a_path: STRING; a_line, a_col: INTEGER; a_word: STRING): detachable SIMPLE_JSON_ARRAY
			-- Prepare call hierarchy item at position
			-- Returns array with single CallHierarchyItem or null if not on a feature
		require
			path_not_void: a_path /= Void
			word_not_void: a_word /= Void
		local
			l_result: SIMPLE_JSON_ARRAY
			l_item: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_feature_info: detachable TUPLE [file_path: STRING; line, column: INTEGER; signature, comment: STRING]
			l_class_name: detachable STRING
		do
			if not a_word.is_empty then
				-- Find feature in database
				across symbol_db.all_class_names as cn until l_class_name /= Void loop
					l_feature_info := symbol_db.find_feature (cn, a_word)
					if attached l_feature_info then
						l_class_name := cn.twin
					end
				end

				if attached l_feature_info and attached l_class_name then
					create l_result.make
					create l_item.make

					l_item.put_string (a_word, "name").do_nothing
					l_item.put_integer (12, "kind").do_nothing -- Function = 12
					l_item.put_string (l_class_name, "detail").do_nothing
					l_item.put_string (path_to_uri (l_feature_info.file_path), "uri").do_nothing

					-- Range
					l_range := make_range (l_feature_info.line - 1, 0, l_feature_info.line - 1, a_word.count)
					l_item.put_object (l_range, "range").do_nothing
					l_item.put_object (l_range, "selectionRange").do_nothing

					-- Store data for later calls
					l_item.put_string (l_class_name + "." + a_word, "data").do_nothing

					l_result.add_object (l_item).do_nothing
					Result := l_result

					log_debug ("Prepared call hierarchy for: " + l_class_name + "." + a_word)
				end
			end
		end

	get_incoming_calls (a_class_name, a_feature_name: STRING): SIMPLE_JSON_ARRAY
			-- Get callers of this feature (who calls this)
		require
			class_name_not_void: a_class_name /= Void
			feature_name_not_void: a_feature_name /= Void
		local
			l_callers: ARRAYED_LIST [TUPLE [caller_class, caller_feature, file_path: STRING; line: INTEGER]]
			l_item: SIMPLE_JSON_OBJECT
			l_from_item: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_from_ranges: SIMPLE_JSON_ARRAY
		do
			create Result.make
			l_callers := find_callers (a_feature_name)

			across l_callers as caller loop
				create l_item.make
				create l_from_item.make

				l_from_item.put_string (caller.caller_feature, "name").do_nothing
				l_from_item.put_integer (12, "kind").do_nothing -- Function
				l_from_item.put_string (caller.caller_class, "detail").do_nothing
				l_from_item.put_string (path_to_uri (caller.file_path), "uri").do_nothing

				l_range := make_range (caller.line - 1, 0, caller.line - 1, caller.caller_feature.count)
				l_from_item.put_object (l_range, "range").do_nothing
				l_from_item.put_object (l_range, "selectionRange").do_nothing

				l_item.put_object (l_from_item, "from").do_nothing

				-- fromRanges - where the call occurs
				create l_from_ranges.make
				l_from_ranges.add_object (l_range).do_nothing
				l_item.put_array (l_from_ranges, "fromRanges").do_nothing

				Result.add_object (l_item).do_nothing
			end

			log_debug ("Found " + Result.count.out + " incoming calls to " + a_feature_name)
		ensure
			result_not_void: Result /= Void
		end

	get_outgoing_calls (a_class_name, a_feature_name: STRING): SIMPLE_JSON_ARRAY
			-- Get callees from this feature (what does this call)
		require
			class_name_not_void: a_class_name /= Void
			feature_name_not_void: a_feature_name /= Void
		local
			l_callees: ARRAYED_LIST [TUPLE [callee_name, target_class, file_path: STRING; line: INTEGER]]
			l_item: SIMPLE_JSON_OBJECT
			l_to_item: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_from_ranges: SIMPLE_JSON_ARRAY
		do
			create Result.make
			l_callees := find_callees (a_class_name, a_feature_name)

			across l_callees as callee loop
				create l_item.make
				create l_to_item.make

				l_to_item.put_string (callee.callee_name, "name").do_nothing
				l_to_item.put_integer (12, "kind").do_nothing -- Function
				l_to_item.put_string (callee.target_class, "detail").do_nothing
				l_to_item.put_string (path_to_uri (callee.file_path), "uri").do_nothing

				l_range := make_range (callee.line - 1, 0, callee.line - 1, callee.callee_name.count)
				l_to_item.put_object (l_range, "range").do_nothing
				l_to_item.put_object (l_range, "selectionRange").do_nothing

				l_item.put_object (l_to_item, "to").do_nothing

				-- fromRanges - where the call occurs in our feature
				create l_from_ranges.make
				l_from_ranges.add_object (l_range).do_nothing
				l_item.put_array (l_from_ranges, "fromRanges").do_nothing

				Result.add_object (l_item).do_nothing
			end

			log_debug ("Found " + Result.count.out + " outgoing calls from " + a_feature_name)
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	find_callers (a_feature_name: STRING): ARRAYED_LIST [TUPLE [caller_class, caller_feature, file_path: STRING; line: INTEGER]]
			-- Find all features that call the given feature
		require
			feature_name_not_void: a_feature_name /= Void
		local
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_ast: EIFFEL_AST
			l_feature_lower: STRING
		do
			create Result.make (10)
			l_feature_lower := a_feature_name.as_lower

			-- Scan all workspace classes for calls to this feature
			across symbol_db.all_class_names as class_name loop
				l_class_info := symbol_db.find_class (class_name)
				if attached l_class_info then
					l_ast := parser.parse_file (l_class_info.file_path)
					across l_ast.classes as cls loop
						across cls.features as feat loop
							-- Check if this feature's body contains a call to our target
							if feature_calls (l_class_info.file_path, feat.line, l_feature_lower) then
								Result.extend ([cls.name.twin, feat.name.twin, l_class_info.file_path.twin, feat.line])
							end
						end
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	find_callees (a_class_name, a_feature_name: STRING): ARRAYED_LIST [TUPLE [callee_name, target_class, file_path: STRING; line: INTEGER]]
			-- Find all features called by the given feature
		require
			class_name_not_void: a_class_name /= Void
			feature_name_not_void: a_feature_name /= Void
		local
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_ast: EIFFEL_AST
			l_feature_lower: STRING
			l_identifiers: ARRAYED_LIST [STRING]
			l_target_info: detachable TUPLE [file_path: STRING; line, column: INTEGER; signature, comment: STRING]
			l_target_class: detachable STRING
		do
			create Result.make (10)
			l_feature_lower := a_feature_name.as_lower

			-- Find the class file
			l_class_info := symbol_db.find_class (a_class_name)
			if attached l_class_info then
				l_ast := parser.parse_file (l_class_info.file_path)
				across l_ast.classes as cls loop
					across cls.features as feat loop
						if feat.name.as_lower.same_string (l_feature_lower) then
							-- Extract identifiers from feature body
							l_identifiers := extract_identifiers_from_feature (l_class_info.file_path, feat.line)
							across l_identifiers as ident loop
								-- Check if this identifier is a known feature
								across symbol_db.all_class_names as cn until l_target_class /= Void loop
									l_target_info := symbol_db.find_feature (cn, ident)
									if attached l_target_info then
										l_target_class := cn.twin
									end
								end
								if attached l_target_info and attached l_target_class then
									Result.extend ([ident.twin, l_target_class, l_target_info.file_path.twin, l_target_info.line])
									l_target_class := Void
								end
							end
						end
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	feature_calls (a_file_path: STRING; a_feature_line: INTEGER; a_target_feature: STRING): BOOLEAN
			-- Does the feature at given line call the target feature?
			-- Simple text-based check (looks for identifier in feature body)
		require
			path_not_void: a_file_path /= Void
			target_not_void: a_target_feature /= Void
		local
			l_file: PLAIN_TEXT_FILE
			l_line: STRING
			l_line_num: INTEGER
			l_in_feature: BOOLEAN
			l_line_lower: STRING
		do
			create l_file.make_with_name (a_file_path)
			if l_file.exists and then l_file.is_readable then
				l_file.open_read
				from
					l_line_num := 1
				until
					l_file.end_of_file or Result
				loop
					l_file.read_line
					l_line := l_file.last_string.twin

					if l_line_num = a_feature_line then
						l_in_feature := True
					elseif l_in_feature then
						-- Stop at next feature or end
						l_line_lower := l_line.as_lower
						l_line_lower.left_adjust
						if l_line_lower.starts_with ("feature") or
						   l_line_lower.starts_with ("invariant") or
						   l_line_lower.starts_with ("end") then
							l_in_feature := False
						elseif contains_identifier (l_line, a_target_feature) then
							Result := True
						end
					end
					l_line_num := l_line_num + 1
				end
				l_file.close
			end
		end

	extract_identifiers_from_feature (a_file_path: STRING; a_feature_line: INTEGER): ARRAYED_LIST [STRING]
			-- Extract all identifiers from feature body (simple approach)
		require
			path_not_void: a_file_path /= Void
		local
			l_file: PLAIN_TEXT_FILE
			l_line: STRING
			l_line_num: INTEGER
			l_in_feature: BOOLEAN
			l_line_lower: STRING
			i, l_start: INTEGER
			c: CHARACTER
			l_ident: STRING
		do
			create Result.make (20)
			create l_file.make_with_name (a_file_path)
			if l_file.exists and then l_file.is_readable then
				l_file.open_read
				from
					l_line_num := 1
				until
					l_file.end_of_file
				loop
					l_file.read_line
					l_line := l_file.last_string.twin

					if l_line_num = a_feature_line then
						l_in_feature := True
					elseif l_in_feature then
						l_line_lower := l_line.as_lower
						l_line_lower.left_adjust
						if l_line_lower.starts_with ("feature") or
						   l_line_lower.starts_with ("invariant") or
						   (l_line_lower.count > 0 and then l_line_lower.item (1) /= '%T' and then l_line_lower.same_string ("end")) then
							l_in_feature := False
						else
							-- Extract identifiers from line
							from
								i := 1
								l_start := 0
							until
								i > l_line.count
							loop
								c := l_line.item (i)
								if c.is_alpha or c = '_' then
									if l_start = 0 then
										l_start := i
									end
								elseif l_start > 0 then
									l_ident := l_line.substring (l_start, i - 1)
									if not is_keyword (l_ident) and l_ident.count >= 2 then
										Result.extend (l_ident)
									end
									l_start := 0
								else
									l_start := 0
								end
								i := i + 1
							end
							if l_start > 0 then
								l_ident := l_line.substring (l_start, l_line.count)
								if not is_keyword (l_ident) and l_ident.count >= 2 then
									Result.extend (l_ident)
								end
							end
						end
					end
					l_line_num := l_line_num + 1
				end
				l_file.close
			end
		ensure
			result_not_void: Result /= Void
		end

	contains_identifier (a_line, a_ident: STRING): BOOLEAN
			-- Does line contain identifier as a whole word?
		require
			line_not_void: a_line /= Void
			ident_not_void: a_ident /= Void
		local
			l_pos: INTEGER
			l_line_lower: STRING
			l_ident_lower: STRING
			l_before, l_after: CHARACTER
		do
			l_line_lower := a_line.as_lower
			l_ident_lower := a_ident.as_lower
			l_pos := l_line_lower.substring_index (l_ident_lower, 1)
			if l_pos > 0 then
				-- Check word boundaries
				Result := True
				if l_pos > 1 then
					l_before := a_line.item (l_pos - 1)
					if l_before.is_alpha or l_before.is_digit or l_before = '_' then
						Result := False
					end
				end
				if Result and then l_pos + a_ident.count <= a_line.count then
					l_after := a_line.item (l_pos + a_ident.count)
					if l_after.is_alpha or l_after.is_digit or l_after = '_' then
						Result := False
					end
				end
			end
		end

	is_keyword (a_word: STRING): BOOLEAN
			-- Is this an Eiffel keyword?
		require
			word_not_void: a_word /= Void
		local
			l_lower: STRING
		do
			l_lower := a_word.as_lower
			Result := l_lower.same_string ("if") or
			          l_lower.same_string ("then") or
			          l_lower.same_string ("else") or
			          l_lower.same_string ("elseif") or
			          l_lower.same_string ("end") or
			          l_lower.same_string ("do") or
			          l_lower.same_string ("local") or
			          l_lower.same_string ("require") or
			          l_lower.same_string ("ensure") or
			          l_lower.same_string ("loop") or
			          l_lower.same_string ("from") or
			          l_lower.same_string ("until") or
			          l_lower.same_string ("across") or
			          l_lower.same_string ("as") or
			          l_lower.same_string ("create") or
			          l_lower.same_string ("attached") or
			          l_lower.same_string ("detachable") or
			          l_lower.same_string ("Result") or
			          l_lower.same_string ("Current") or
			          l_lower.same_string ("Void") or
			          l_lower.same_string ("True") or
			          l_lower.same_string ("False") or
			          l_lower.same_string ("and") or
			          l_lower.same_string ("or") or
			          l_lower.same_string ("not") or
			          l_lower.same_string ("implies")
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
