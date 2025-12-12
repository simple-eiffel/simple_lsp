note
	description: "Handler for LSP signature help operations - provides parameter hints"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_SIGNATURE_HELP_HANDLER

create
	make

feature {NONE} -- Initialization

	make (a_db: LSP_SYMBOL_DATABASE; a_logger: LSP_LOGGER; a_cache: HASH_TABLE [STRING, STRING])
			-- Create handler with database, logger and document cache
		require
			db_not_void: a_db /= Void
			logger_not_void: a_logger /= Void
			cache_not_void: a_cache /= Void
		do
			symbol_db := a_db
			logger := a_logger
			document_cache := a_cache
		ensure
			db_set: symbol_db = a_db
			logger_set: logger = a_logger
			cache_set: document_cache = a_cache
		end

feature -- Access

	symbol_db: LSP_SYMBOL_DATABASE
			-- Symbol database for lookups

	logger: LSP_LOGGER
			-- Logger for debugging

	document_cache: HASH_TABLE [STRING, STRING]
			-- Cached document contents

feature -- Constants

	Trigger_characters: ARRAY [STRING]
			-- Characters that trigger signature help
		once
			Result := <<"(", ",">>
		end

feature -- Operations

	create_options: SIMPLE_JSON_OBJECT
			-- Create signature help provider options
		local
			l_triggers: SIMPLE_JSON_ARRAY
		do
			create Result.make
			create l_triggers.make
			across Trigger_characters as t loop
				l_triggers.add_string (t).do_nothing
			end
			Result.put_array (l_triggers, "triggerCharacters").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	get_signature_help (a_feature_name: STRING; a_path: STRING; a_line, a_col: INTEGER): detachable SIMPLE_JSON_OBJECT
			-- Get signature help for feature
		require
			name_not_void: a_feature_name /= Void
			name_not_empty: not a_feature_name.is_empty
		local
			l_feature_info: detachable TUPLE [file_path: STRING; line, column: INTEGER; signature, comment: STRING]
			l_signatures: SIMPLE_JSON_ARRAY
			l_sig_obj: SIMPLE_JSON_OBJECT
			l_parameters: SIMPLE_JSON_ARRAY
			l_signature: STRING
			l_active_param: INTEGER
		do
			-- Find the feature in the database
			across symbol_db.all_class_names as class_name until Result /= Void loop
				l_feature_info := symbol_db.find_feature (class_name, a_feature_name)
				if attached l_feature_info and then attached l_feature_info.signature as sig and then not sig.is_empty then
					-- Build signature help response
					create Result.make
					create l_signatures.make
					create l_sig_obj.make

					-- The signature label
					l_signature := a_feature_name
					if sig.has ('(') then
						l_signature := l_signature + " " + sig
					else
						l_signature := l_signature + sig
					end
					l_sig_obj.put_string (l_signature, "label").do_nothing

					-- Documentation
					if attached l_feature_info.comment as cmt and then not cmt.is_empty then
						l_sig_obj.put_string (cmt, "documentation").do_nothing
					end

					-- Parse parameters from signature
					l_parameters := extract_parameters (sig)
					if l_parameters.count > 0 then
						l_sig_obj.put_array (l_parameters, "parameters").do_nothing
					end

					l_signatures.add_object (l_sig_obj).do_nothing
					Result.put_array (l_signatures, "signatures").do_nothing
					Result.put_integer (0, "activeSignature").do_nothing

					-- Determine active parameter based on commas before cursor
					l_active_param := count_commas_before_cursor (a_path, a_line, a_col)
					Result.put_integer (l_active_param, "activeParameter").do_nothing

					log_info ("Signature help: " + l_signature + " (param " + l_active_param.out + ")")
				end
			end
		end

	feature_at_position (a_path: STRING; a_line, a_col: INTEGER): STRING
			-- Find feature name being called at position (look backward for identifier before '(')
		require
			path_not_void: a_path /= Void
		local
			l_file: SIMPLE_FILE
			l_lines: LIST [STRING]
			l_line_text: STRING
			l_pos: INTEGER
			l_start, l_end: INTEGER
			l_paren_depth: INTEGER
			l_found_paren: BOOLEAN
			l_content: STRING
		do
			create Result.make_empty

			-- Try to get content from cache first, fall back to file
			if document_cache.has (a_path) then
				l_content := document_cache.item (a_path)
				log_debug ("Using cached content for: " + a_path)
			else
				create l_file.make (a_path)
				if l_file.exists then
					l_content := l_file.load.to_string_8
					log_debug ("Read from disk for: " + a_path)
				end
			end

			if attached l_content then
				l_lines := l_content.split ('%N')
				if a_line >= 0 and a_line < l_lines.count then
					l_line_text := l_lines.i_th (a_line + 1)
					-- Remove carriage return if present (Windows line endings)
					if l_line_text.count > 0 and then l_line_text.item (l_line_text.count) = '%R' then
						l_line_text := l_line_text.substring (1, l_line_text.count - 1)
					end
					log_debug ("feature_at_position: line=" + l_line_text)

					-- Start from cursor position and scan backward to find the opening '('
					l_pos := (a_col).min (l_line_text.count)
					if l_pos < 1 then
						l_pos := l_line_text.count
					end

					-- Scan backward to find the opening paren, respecting nesting
					l_paren_depth := 0
					l_found_paren := False
					from
					until
						l_pos < 1 or l_found_paren
					loop
						inspect l_line_text.item (l_pos)
						when ')' then
							l_paren_depth := l_paren_depth + 1
						when '(' then
							if l_paren_depth = 0 then
								l_found_paren := True
							else
								l_paren_depth := l_paren_depth - 1
							end
						else
							-- Keep scanning
						end
						if not l_found_paren then
							l_pos := l_pos - 1
						end
					end

					if l_found_paren then
						log_debug ("Found opening paren at position: " + l_pos.out)
						-- Move before the '('
						l_pos := l_pos - 1
						-- Skip whitespace before '('
						from
						until
							l_pos < 1 or else l_line_text.item (l_pos) /= ' '
						loop
							l_pos := l_pos - 1
						end
						-- Now find the identifier (scan backward through word chars)
						l_end := l_pos
						from
						until
							l_pos < 1 or else not is_word_char (l_line_text.item (l_pos))
						loop
							l_pos := l_pos - 1
						end
						l_start := l_pos + 1

						if l_end >= l_start and l_start >= 1 then
							Result := l_line_text.substring (l_start, l_end)
							log_debug ("Found feature name: '" + Result + "'")
						end
					else
						log_debug ("No opening paren found on this line")
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	extract_parameters (a_signature: STRING): SIMPLE_JSON_ARRAY
			-- Extract parameter info from signature
			-- Input: "(a_name: STRING; a_value: INTEGER): BOOLEAN" or similar
		require
			sig_not_void: a_signature /= Void
		local
			l_params_str: STRING
			l_params: LIST [STRING]
			l_param_obj: SIMPLE_JSON_OBJECT
			l_start, l_end: INTEGER
		do
			create Result.make

			-- Find content between parentheses
			l_start := a_signature.index_of ('(', 1)
			l_end := a_signature.index_of (')', 1)

			if l_start > 0 and l_end > l_start then
				l_params_str := a_signature.substring (l_start + 1, l_end - 1)
				l_params_str.left_adjust
				l_params_str.right_adjust

				if not l_params_str.is_empty then
					-- Split by semicolon
					l_params := l_params_str.split (';')
					across l_params as param loop
						param.left_adjust
						param.right_adjust
						if not param.is_empty then
							create l_param_obj.make
							l_param_obj.put_string (param.to_string_8, "label").do_nothing
							Result.add_object (l_param_obj).do_nothing
						end
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	count_commas_before_cursor (a_path: STRING; a_line, a_col: INTEGER): INTEGER
			-- Count commas between opening paren and cursor position
		require
			path_not_void: a_path /= Void
		local
			l_file: SIMPLE_FILE
			l_lines: LIST [STRING_32]
			l_line_text: STRING
			l_pos, l_paren_depth: INTEGER
		do
			create l_file.make (a_path)
			if l_file.exists then
				l_lines := l_file.lines
				if a_line >= 0 and a_line < l_lines.count then
					l_line_text := l_lines.i_th (a_line + 1).to_string_8

					-- Find the opening paren and count commas from there
					l_paren_depth := 0
					from
						l_pos := (a_col).min (l_line_text.count)
					until
						l_pos < 1 or else (l_line_text.item (l_pos) = '(' and l_paren_depth = 0)
					loop
						inspect l_line_text.item (l_pos)
						when ')' then
							l_paren_depth := l_paren_depth + 1
						when '(' then
							l_paren_depth := l_paren_depth - 1
						when ',' then
							if l_paren_depth = 0 then
								Result := Result + 1
							end
						else
							-- Other characters, keep scanning
						end
						l_pos := l_pos - 1
					end
				end
			end
		ensure
			non_negative: Result >= 0
		end

	is_word_char (c: CHARACTER): BOOLEAN
			-- Is character a valid identifier character?
		do
			Result := c.is_alpha or c.is_digit or c = '_'
		end

	log_debug (a_msg: STRING)
			-- Log debug message
		do
			logger.log_debug (a_msg)
		end

	log_info (a_msg: STRING)
			-- Log info message
		do
			logger.log_info (a_msg)
		end

end
