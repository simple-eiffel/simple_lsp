note
	description: "Handler for LSP rename operations"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_RENAME_HANDLER

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
		ensure
			db_set: symbol_db = a_db
			logger_set: logger = a_logger
		end

feature -- Access

	symbol_db: LSP_SYMBOL_DATABASE
			-- Symbol database

	logger: LSP_LOGGER
			-- Logger for debugging

feature -- Operations

	compute_workspace_edit (a_old_name, a_new_name: STRING): detachable SIMPLE_JSON_OBJECT
			-- Compute workspace edit for renaming a_old_name to a_new_name
			-- For classes, also renames the file (CALCULATOR -> calc.e)
		require
			old_name_not_empty: not a_old_name.is_empty
			new_name_not_empty: not a_new_name.is_empty
		local
			l_document_changes: SIMPLE_JSON_ARRAY
			l_file_edits: HASH_TABLE [SIMPLE_JSON_ARRAY, STRING]
			l_occurrences: ARRAYED_LIST [TUPLE [file_path: STRING; line, col, length: INTEGER]]
			l_edit: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_start_pos, l_end_pos: SIMPLE_JSON_OBJECT
			l_edits: SIMPLE_JSON_ARRAY
			l_uri: STRING
			l_text_doc_edit: SIMPLE_JSON_OBJECT
			l_text_doc: SIMPLE_JSON_OBJECT
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_rename_file: SIMPLE_JSON_OBJECT
			l_old_uri, l_new_uri: STRING
			l_new_file_path: STRING
			l_dir_end: INTEGER
		do
			log_info ("compute_workspace_edit: '" + a_old_name + "' -> '" + a_new_name + "'")

			-- Find all occurrences of the symbol
			l_occurrences := find_all_occurrences (a_old_name)
			log_info ("Found " + l_occurrences.count.out + " occurrences to rename")

			if l_occurrences.count > 0 then
				create l_file_edits.make (10)
				create l_document_changes.make

				-- Group edits by file
				from l_occurrences.start until l_occurrences.after loop
					l_uri := path_to_uri (l_occurrences.item.file_path)
					if not l_file_edits.has (l_uri) then
						create l_edits.make
						l_file_edits.force (l_edits, l_uri)
					end
					if attached l_file_edits.item (l_uri) as l_arr then
						-- Create text edit
						create l_start_pos.make
						l_start_pos.put_integer (l_occurrences.item.line - 1, "line").do_nothing
						l_start_pos.put_integer (l_occurrences.item.col - 1, "character").do_nothing

						create l_end_pos.make
						l_end_pos.put_integer (l_occurrences.item.line - 1, "line").do_nothing
						l_end_pos.put_integer (l_occurrences.item.col - 1 + l_occurrences.item.length, "character").do_nothing

						create l_range.make
						l_range.put_object (l_start_pos, "start").do_nothing
						l_range.put_object (l_end_pos, "end").do_nothing

						create l_edit.make
						l_edit.put_object (l_range, "range").do_nothing
						l_edit.put_string (a_new_name, "newText").do_nothing

						l_arr.add_object (l_edit).do_nothing
					end
					l_occurrences.forth
				end

				-- Build TextDocumentEdit objects for each file
				from l_file_edits.start until l_file_edits.after loop
					create l_text_doc_edit.make
					create l_text_doc.make
					l_text_doc.put_string (l_file_edits.key_for_iteration, "uri").do_nothing
					l_text_doc.put_null ("version").do_nothing  -- Required by LSP spec for VersionedTextDocumentIdentifier
					l_text_doc_edit.put_object (l_text_doc, "textDocument").do_nothing
					l_text_doc_edit.put_array (l_file_edits.item_for_iteration, "edits").do_nothing
					l_document_changes.add_object (l_text_doc_edit).do_nothing
					l_file_edits.forth
				end

				-- Check if we're renaming a class - if so, also rename the file
				l_class_info := symbol_db.find_class (a_old_name)
				if attached l_class_info then
					l_old_uri := path_to_uri (l_class_info.file_path)
					-- Compute new file path: replace filename with new_name.e
					l_dir_end := l_class_info.file_path.last_index_of ('/', l_class_info.file_path.count)
					if l_dir_end = 0 then
						l_dir_end := l_class_info.file_path.last_index_of ('\', l_class_info.file_path.count)
					end
					if l_dir_end > 0 then
						l_new_file_path := l_class_info.file_path.substring (1, l_dir_end) + a_new_name.as_lower + ".e"
					else
						l_new_file_path := a_new_name.as_lower + ".e"
					end
					l_new_uri := path_to_uri (l_new_file_path)

					-- Add RenameFile operation
					create l_rename_file.make
					l_rename_file.put_string ("rename", "kind").do_nothing
					l_rename_file.put_string (l_old_uri, "oldUri").do_nothing
					l_rename_file.put_string (l_new_uri, "newUri").do_nothing
					l_document_changes.add_object (l_rename_file).do_nothing
					log_info ("Adding file rename: " + l_old_uri + " -> " + l_new_uri)
				end

				-- Build workspace edit response using documentChanges
				create Result.make
				Result.put_array (l_document_changes, "documentChanges").do_nothing
			end
		end

	find_all_occurrences (a_name: STRING): ARRAYED_LIST [TUPLE [file_path: STRING; line, col, length: INTEGER]]
			-- Find all occurrences of a_name in workspace files
		require
			name_not_empty: not a_name.is_empty
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_lines: LIST [STRING]
			l_line_num: INTEGER
			l_col: INTEGER
			l_search_upper: STRING
			l_line_str: STRING
			l_file_paths: ARRAYED_LIST [STRING]
			i, j: INTEGER
			l_path: STRING
		do
			create Result.make (20)
			l_search_upper := a_name.as_upper
			log_info ("find_all_occurrences: searching for '" + a_name + "'")

			-- Search all indexed files using from-loop
			l_file_paths := symbol_db.all_file_paths
			log_info ("find_all_occurrences: got " + l_file_paths.count.out + " file paths")
			from i := 1 until i > l_file_paths.count loop
				l_path := l_file_paths.i_th (i)
				log_debug ("find_all_occurrences: checking file " + l_path)
				create l_file.make (l_path)
				if l_file.exists then
					l_content := l_file.load.to_string_8
					l_lines := l_content.split ('%N')
					-- Use from-loop for lines
					from j := 1 until j > l_lines.count loop
						l_line_str := l_lines.i_th (j)
						l_line_num := j
						-- Search for all occurrences in this line
						from
							l_col := l_line_str.as_upper.substring_index (l_search_upper, 1)
						until
							l_col = 0
						loop
							-- Verify it's a whole word (not part of another identifier)
							if is_whole_word (l_line_str, l_col, a_name.count) then
								Result.extend ([l_path.twin, l_line_num, l_col, a_name.count])
							end
							-- Continue searching for more occurrences
							if l_col + l_search_upper.count <= l_line_str.count then
								l_col := l_line_str.as_upper.substring_index (l_search_upper, l_col + 1)
							else
								l_col := 0
							end
						end
						j := j + 1
					end
				end
				i := i + 1
			end
			log_info ("find_all_occurrences: found " + Result.count.out + " occurrences")
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
