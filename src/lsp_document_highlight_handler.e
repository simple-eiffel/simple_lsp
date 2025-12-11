note
	description: "Handler for LSP document highlight operations - highlights all occurrences of a symbol in current file"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_DOCUMENT_HIGHLIGHT_HANDLER

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

feature -- Operations

	find_highlights (a_file_path, a_word: STRING): SIMPLE_JSON_ARRAY
			-- Find all occurrences of word in a single file
			-- Returns array of DocumentHighlight objects
		require
			path_not_void: a_file_path /= Void
			word_not_void: a_word /= Void
		local
			l_file: PLAIN_TEXT_FILE
			l_line: STRING
			l_line_num: INTEGER
			l_col: INTEGER
			l_highlight: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_start, l_end: SIMPLE_JSON_OBJECT
			l_word_lower: STRING
			l_line_lower: STRING
		do
			create Result.make
			l_word_lower := a_word.as_lower

			if not a_word.is_empty then
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
						l_line_lower := l_line.as_lower

						-- Find all occurrences in this line
						from
							l_col := l_line_lower.substring_index (l_word_lower, 1)
						until
							l_col = 0
						loop
							-- Verify it's a whole word (not part of another identifier)
							if is_whole_word (l_line, l_col, a_word.count) then
								-- Create highlight object
								create l_start.make
								l_start.put_integer (l_line_num, "line").do_nothing
								l_start.put_integer (l_col - 1, "character").do_nothing

								create l_end.make
								l_end.put_integer (l_line_num, "line").do_nothing
								l_end.put_integer (l_col - 1 + a_word.count, "character").do_nothing

								create l_range.make
								l_range.put_object (l_start, "start").do_nothing
								l_range.put_object (l_end, "end").do_nothing

								create l_highlight.make
								l_highlight.put_object (l_range, "range").do_nothing
								l_highlight.put_integer (1, "kind").do_nothing -- DocumentHighlightKind.Text = 1

								Result.add_object (l_highlight).do_nothing
							end

							-- Look for next occurrence
							if l_col + a_word.count <= l_line_lower.count then
								l_col := l_line_lower.substring_index (l_word_lower, l_col + 1)
							else
								l_col := 0
							end
						end

						l_line_num := l_line_num + 1
					end
					l_file.close
				end
			end

			log_debug ("Found " + Result.count.out + " highlights in file")
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

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
