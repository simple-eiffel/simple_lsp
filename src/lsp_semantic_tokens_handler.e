note
	description: "Handler for LSP semantic tokens operations - provides rich syntax highlighting"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_SEMANTIC_TOKENS_HANDLER

create
	make

feature {NONE} -- Initialization

	make (a_logger: LSP_LOGGER)
			-- Create handler with logger
		require
			logger_not_void: a_logger /= Void
		do
			logger := a_logger
		ensure
			logger_set: logger = a_logger
		end

feature -- Access

	logger: LSP_LOGGER
			-- Logger for debugging

feature -- Constants

	Semantic_token_types: ARRAY [STRING]
			-- Token types for semantic highlighting (order matters - index is type ID)
		once
			Result := <<"class", "function", "variable", "parameter", "property", "keyword", "comment", "string", "number", "operator">>
		end

	Semantic_token_modifiers: ARRAY [STRING]
			-- Token modifiers for semantic highlighting
		once
			Result := <<"declaration", "definition", "readonly", "deprecated", "abstract", "defaultLibrary">>
		end

feature -- Operations

	create_options: SIMPLE_JSON_OBJECT
			-- Create semantic tokens provider options for LSP capabilities
		local
			l_legend: SIMPLE_JSON_OBJECT
			l_types, l_modifiers: SIMPLE_JSON_ARRAY
		do
			create Result.make

			-- Build legend (required)
			create l_legend.make
			create l_types.make
			across Semantic_token_types as t loop
				l_types.add_string (t).do_nothing
			end
			create l_modifiers.make
			across Semantic_token_modifiers as m loop
				l_modifiers.add_string (m).do_nothing
			end
			l_legend.put_array (l_types, "tokenTypes").do_nothing
			l_legend.put_array (l_modifiers, "tokenModifiers").do_nothing

			Result.put_object (l_legend, "legend").do_nothing
			Result.put_boolean (True, "full").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	compute_tokens (a_file_path: STRING): SIMPLE_JSON_ARRAY
			-- Compute semantic tokens for a file
			-- Returns array of integers: [deltaLine, deltaStartChar, length, tokenType, tokenModifiers, ...]
		require
			path_not_void: a_file_path /= Void
		local
			l_file: PLAIN_TEXT_FILE
			l_line: STRING
			l_line_num: INTEGER
			l_prev_line, l_prev_col: INTEGER
		do
			create Result.make
			l_prev_line := 0
			l_prev_col := 0

			create l_file.make_with_name (a_file_path)
			if l_file.exists and then l_file.is_readable then
				l_file.open_read
				from
					l_line_num := 0
				until
					l_file.end_of_file
				loop
					l_file.read_line
					l_line := l_file.last_string.twin

					-- Find contract keywords: require, ensure, invariant
					add_keyword_tokens (l_line, l_line_num, <<"require", "ensure", "invariant", "variant">>, 5, Result, l_prev_line, l_prev_col)

					-- Find class names (UPPER_CASE identifiers)
					add_class_tokens (l_line, l_line_num, Result, l_prev_line, l_prev_col)

					l_line_num := l_line_num + 1
				end
				l_file.close
			end

			log_debug ("Computed " + (Result.count // 5).out + " semantic tokens")
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	add_keyword_tokens (a_line: STRING; a_line_num: INTEGER; a_keywords: ARRAY [STRING]; a_token_type: INTEGER; a_result: SIMPLE_JSON_ARRAY; a_prev_line, a_prev_col: INTEGER)
			-- Add tokens for keywords found in line
		require
			line_not_void: a_line /= Void
			result_not_void: a_result /= Void
		local
			l_col: INTEGER
			l_delta_line, l_delta_col: INTEGER
			l_line_lower: STRING
			l_kw_lower: STRING
			l_prev_line, l_prev_col: INTEGER
		do
			l_prev_line := a_prev_line
			l_prev_col := a_prev_col
			l_line_lower := a_line.as_lower

			across a_keywords as kw loop
				l_kw_lower := kw.as_lower
				from
					l_col := l_line_lower.substring_index (l_kw_lower, 1)
				until
					l_col = 0
				loop
					if is_whole_word (a_line, l_col, kw.count) then
						-- Compute deltas
						if a_line_num = l_prev_line then
							l_delta_line := 0
							l_delta_col := l_col - 1 - l_prev_col
						else
							l_delta_line := a_line_num - l_prev_line
							l_delta_col := l_col - 1
						end

						-- Add token: deltaLine, deltaStartChar, length, tokenType, tokenModifiers
						a_result.add_integer (l_delta_line).do_nothing
						a_result.add_integer (l_delta_col).do_nothing
						a_result.add_integer (kw.count).do_nothing
						a_result.add_integer (a_token_type).do_nothing  -- keyword type
						a_result.add_integer (0).do_nothing  -- no modifiers

						l_prev_line := a_line_num
						l_prev_col := l_col - 1
					end

					-- Look for next occurrence
					if l_col + kw.count <= l_line_lower.count then
						l_col := l_line_lower.substring_index (l_kw_lower, l_col + 1)
					else
						l_col := 0
					end
				end
			end
		end

	add_class_tokens (a_line: STRING; a_line_num: INTEGER; a_result: SIMPLE_JSON_ARRAY; a_prev_line, a_prev_col: INTEGER)
			-- Add tokens for class names (UPPER_CASE_IDENTIFIERS) found in line
		require
			line_not_void: a_line /= Void
			result_not_void: a_result /= Void
		local
			i, l_start, l_len: INTEGER
			c: CHARACTER
			l_in_word: BOOLEAN
			l_is_class: BOOLEAN
			l_delta_line, l_delta_col: INTEGER
			l_prev_line, l_prev_col: INTEGER
		do
			l_prev_line := a_prev_line
			l_prev_col := a_prev_col

			from
				i := 1
				l_in_word := False
			until
				i > a_line.count
			loop
				c := a_line.item (i)

				if c.is_alpha or c = '_' or (l_in_word and c.is_digit) then
					if not l_in_word then
						l_in_word := True
						l_start := i
						l_is_class := c.is_upper
					else
						if c.is_lower then
							l_is_class := False
						end
					end
				else
					if l_in_word then
						l_len := i - l_start
						-- Only mark as class if 2+ chars and all uppercase
						if l_is_class and l_len >= 2 then
							-- Compute deltas
							if a_line_num = l_prev_line then
								l_delta_line := 0
								l_delta_col := l_start - 1 - l_prev_col
							else
								l_delta_line := a_line_num - l_prev_line
								l_delta_col := l_start - 1
							end

							-- Add token: deltaLine, deltaStartChar, length, tokenType=0 (class), tokenModifiers=0
							a_result.add_integer (l_delta_line).do_nothing
							a_result.add_integer (l_delta_col).do_nothing
							a_result.add_integer (l_len).do_nothing
							a_result.add_integer (0).do_nothing  -- class type
							a_result.add_integer (0).do_nothing  -- no modifiers

							l_prev_line := a_line_num
							l_prev_col := l_start - 1
						end
						l_in_word := False
					end
				end
				i := i + 1
			end

			-- Handle word at end of line
			if l_in_word then
				l_len := i - l_start
				if l_is_class and l_len >= 2 then
					if a_line_num = l_prev_line then
						l_delta_line := 0
						l_delta_col := l_start - 1 - l_prev_col
					else
						l_delta_line := a_line_num - l_prev_line
						l_delta_col := l_start - 1
					end
					a_result.add_integer (l_delta_line).do_nothing
					a_result.add_integer (l_delta_col).do_nothing
					a_result.add_integer (l_len).do_nothing
					a_result.add_integer (0).do_nothing
					a_result.add_integer (0).do_nothing
				end
			end
		end

	is_whole_word (a_line: STRING; a_pos, a_length: INTEGER): BOOLEAN
			-- Is the substring at a_pos a whole word (not part of larger identifier)?
		require
			line_not_void: a_line /= Void
			pos_valid: a_pos >= 1 and a_pos <= a_line.count
			length_valid: a_length >= 1
		local
			l_before, l_after: CHARACTER
		do
			Result := True
			-- Check character before
			if a_pos > 1 then
				l_before := a_line.item (a_pos - 1)
				if l_before.is_alpha or l_before.is_digit or l_before = '_' then
					Result := False
				end
			end
			-- Check character after
			if Result and then a_pos + a_length <= a_line.count then
				l_after := a_line.item (a_pos + a_length)
				if l_after.is_alpha or l_after.is_digit or l_after = '_' then
					Result := False
				end
			end
		end

	log_debug (a_msg: STRING)
			-- Log debug message
		do
			logger.log_debug (a_msg)
		end

end
