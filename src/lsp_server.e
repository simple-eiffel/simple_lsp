note
	description: "[
		Main LSP server - handles JSON-RPC communication and dispatches to handlers.
		Uses Design by Contract for robustness and aggressive logging for debugging.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_SERVER

create
	make

feature {NONE} -- Initialization

	make (a_workspace_root: STRING)
			-- Create LSP server for workspace
		require
			root_not_void: a_workspace_root /= Void
			root_not_empty: not a_workspace_root.is_empty
		local
			l_db_dir: STRING
		do
			workspace_root := a_workspace_root
			create json.default_create

			-- Ensure .eiffel_lsp directory exists
			l_db_dir := workspace_root + "/.eiffel_lsp"
			ensure_directory (l_db_dir)

			create symbol_db.make (l_db_dir + "/symbols.db")
			create parser.make
			create logger.make (l_db_dir + "/lsp.log")
			is_initialized := False
			is_running := False

			log_info ("LSP Server initialized for workspace: " + a_workspace_root)
		ensure
			root_set: workspace_root = a_workspace_root
			not_initialized: not is_initialized
			not_running: not is_running
			json_created: json /= Void
			db_created: symbol_db /= Void
			parser_created: parser /= Void
			logger_created: logger /= Void
		end

feature -- Access

	workspace_root: STRING
			-- Root directory of workspace

	is_initialized: BOOLEAN
			-- Has client sent initialize request?

	is_running: BOOLEAN
			-- Is server running?

feature -- Main Loop

	run
			-- Main server loop - read requests, process, respond
		require
			not_already_running: not is_running
		local
			l_content: detachable STRING
		do
			is_running := True
			log_info ("Server entering main loop")
			from
			until
				not is_running or io.input.end_of_file
			loop
				l_content := read_message
				if attached l_content as content then
					log_debug ("Received message: " + content.head (200))
					process_message (content)
				end
			end
			if io.input.end_of_file then
				log_info ("EOF detected - client disconnected")
			end
			log_info ("Server exited main loop")
			shutdown
		ensure
			stopped: not is_running
		end

	shutdown
			-- Shutdown the server
		do
			log_info ("Server shutting down")
			is_running := False
			symbol_db.close
			logger.close
		ensure
			not_running: not is_running
		end

feature {NONE} -- Message I/O

	read_message: detachable STRING
			-- Read LSP message from stdin (Content-Length header + JSON body)
		local
			l_line: STRING
			l_content_length: INTEGER
			l_body: STRING
			l_header_done: BOOLEAN
		do
			log_debug ("Waiting for message...")
			-- Read headers until blank line
			l_content_length := 0
			l_header_done := False
			from
			until
				l_header_done or io.input.end_of_file
			loop
				io.read_line
				if io.input.end_of_file then
					log_debug ("EOF reached while reading headers")
					l_header_done := True
				else
					l_line := io.last_string.twin
					log_debug ("Header line raw [" + l_line.count.out + " chars]: '" + l_line + "'")
					l_line.right_adjust
					l_line.left_adjust
					log_debug ("Header line trimmed [" + l_line.count.out + " chars]: '" + l_line + "'")
					if l_line.is_empty then
						log_debug ("Empty line - headers done")
						l_header_done := True
					elseif l_line.starts_with ("Content-Length:") then
						l_content_length := extract_content_length (l_line)
						log_debug ("Parsed Content-Length: " + l_content_length.out)
					elseif l_line.starts_with ("Content-Type:") then
						log_debug ("Ignoring Content-Type header")
					else
						log_debug ("Unknown header: " + l_line)
					end
				end
			end

			-- Read body
			if l_content_length > 0 then
				log_debug ("Reading body of " + l_content_length.out + " bytes")
				create l_body.make (l_content_length)
				io.read_stream (l_content_length)
				l_body := io.last_string.twin
				log_debug ("Read body [" + l_body.count.out + " chars]")
				Result := l_body
			else
				log_debug ("No content length or zero - no body to read")
			end
		ensure
			result_has_content: Result /= Void implies not Result.is_empty
		end

	write_message (a_json: STRING)
			-- Write LSP message to stdout
			-- Note: Use %N only - Windows console auto-converts to %R%N
		require
			json_not_void: a_json /= Void
			json_not_empty: not a_json.is_empty
		local
			l_header: STRING
		do
			log_debug ("Sending: " + a_json.head (200))
			-- Build complete message with header
			-- LSP requires CRLF but Windows auto-converts LF to CRLF on console output
			create l_header.make (50)
			l_header.append ("Content-Length: ")
			l_header.append_integer (a_json.count)
			l_header.append ("%N%N")
			-- Write header and body
			io.put_string (l_header)
			io.put_string (a_json)
			-- Force flush to ensure VS Code receives the message
			io.output.flush
			log_debug ("Message sent and flushed")
		end

	extract_content_length (a_header: STRING): INTEGER
			-- Extract content length from header line
		require
			header_not_void: a_header /= Void
			header_has_prefix: a_header.starts_with ("Content-Length:")
		local
			l_parts: LIST [STRING]
		do
			l_parts := a_header.split (':')
			if l_parts.count >= 2 then
				l_parts.i_th (2).left_adjust
				l_parts.i_th (2).right_adjust
				if l_parts.i_th (2).is_integer then
					Result := l_parts.i_th (2).to_integer
				end
			end
		ensure
			non_negative: Result >= 0
		end

feature {NONE} -- Message Processing

	process_message (a_content: STRING)
			-- Process incoming JSON-RPC message
		require
			content_not_void: a_content /= Void
			content_not_empty: not a_content.is_empty
		local
			l_parsed: detachable SIMPLE_JSON_VALUE
			l_msg: LSP_MESSAGE
		do
			l_parsed := json.parse (a_content)
			if attached l_parsed and then l_parsed.is_object then
				create l_msg.make_from_json (l_parsed.as_object)
				log_info ("Processing: " + l_msg.method + " (id=" + l_msg.id.out + ")")
				dispatch_message (l_msg)
			else
				log_error ("Failed to parse JSON message")
			end
		end

	dispatch_message (a_msg: LSP_MESSAGE)
			-- Dispatch message to appropriate handler
		require
			msg_not_void: a_msg /= Void
		do
			if a_msg.method.same_string ("initialize") then
				handle_initialize (a_msg)
			elseif a_msg.method.same_string ("initialized") then
				handle_initialized (a_msg)
			elseif a_msg.method.same_string ("shutdown") then
				handle_shutdown (a_msg)
			elseif a_msg.method.same_string ("exit") then
				handle_exit (a_msg)
			elseif a_msg.method.same_string ("textDocument/didOpen") then
				handle_did_open (a_msg)
			elseif a_msg.method.same_string ("textDocument/didChange") then
				handle_did_change (a_msg)
			elseif a_msg.method.same_string ("textDocument/didSave") then
				handle_did_save (a_msg)
			elseif a_msg.method.same_string ("textDocument/didClose") then
				handle_did_close (a_msg)
			elseif a_msg.method.same_string ("textDocument/definition") then
				handle_definition (a_msg)
			elseif a_msg.method.same_string ("textDocument/hover") then
				handle_hover (a_msg)
			elseif a_msg.method.same_string ("textDocument/completion") then
				handle_completion (a_msg)
			elseif a_msg.method.same_string ("textDocument/documentSymbol") then
				handle_document_symbol (a_msg)
			elseif a_msg.method.same_string ("workspace/symbol") then
				handle_workspace_symbol (a_msg)
			elseif a_msg.method.same_string ("textDocument/references") then
				handle_references (a_msg)
			else
				log_warning ("Unknown method: " + a_msg.method)
			end
		end

feature {NONE} -- Lifecycle Handlers

	handle_initialize (a_msg: LSP_MESSAGE)
			-- Handle initialize request
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_result: SIMPLE_JSON_OBJECT
			l_capabilities: SIMPLE_JSON_OBJECT
			l_text_doc_sync: SIMPLE_JSON_OBJECT
			l_completion_options: SIMPLE_JSON_OBJECT
			l_root_path: STRING
		do
			log_info ("Handling initialize request")

			-- Extract workspace root from params
			if attached a_msg.params as l_params then
				-- Try rootPath first (deprecated but simpler)
				if attached l_params.string_item ("rootPath") as l_rp then
					l_root_path := l_rp.to_string_8
					log_info ("Got rootPath: " + l_root_path)
				-- Then try rootUri
				elseif attached l_params.string_item ("rootUri") as l_uri then
					l_root_path := uri_to_path (l_uri.to_string_8)
					log_info ("Got rootUri converted to: " + l_root_path)
				end
				if attached l_root_path and then not l_root_path.is_empty then
					workspace_root := l_root_path
					log_info ("Updated workspace_root to: " + workspace_root)
				end
			end

			-- Build server capabilities
			create l_text_doc_sync.make
			l_text_doc_sync.put_integer (1, "openClose").do_nothing
			l_text_doc_sync.put_integer (1, "change").do_nothing

			create l_completion_options.make
			l_completion_options.put_boolean (True, "resolveProvider").do_nothing
			l_completion_options.put_array (create_trigger_chars, "triggerCharacters").do_nothing

			create l_capabilities.make
			l_capabilities.put_object (l_text_doc_sync, "textDocumentSync").do_nothing
			l_capabilities.put_boolean (True, "definitionProvider").do_nothing
			l_capabilities.put_boolean (True, "hoverProvider").do_nothing
			l_capabilities.put_object (l_completion_options, "completionProvider").do_nothing
			l_capabilities.put_boolean (True, "documentSymbolProvider").do_nothing
			l_capabilities.put_boolean (True, "workspaceSymbolProvider").do_nothing
			l_capabilities.put_boolean (True, "referencesProvider").do_nothing

			create l_result.make
			l_result.put_object (l_capabilities, "capabilities").do_nothing

			send_response (a_msg.id, l_result)
			is_initialized := True
			log_info ("Server initialized successfully")
		ensure
			initialized: is_initialized
		end

	handle_initialized (a_msg: LSP_MESSAGE)
			-- Handle initialized notification
		require
			msg_not_void: a_msg /= Void
		do
			log_info ("Client sent initialized - starting workspace indexing")
			index_workspace
		end

	handle_shutdown (a_msg: LSP_MESSAGE)
			-- Handle shutdown request
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		do
			log_info ("Handling shutdown request")
			send_response (a_msg.id, Void)
		end

	handle_exit (a_msg: LSP_MESSAGE)
			-- Handle exit notification
		require
			msg_not_void: a_msg /= Void
		do
			log_info ("Handling exit notification")
			shutdown
		end

feature {NONE} -- Document Handlers

	handle_did_open (a_msg: LSP_MESSAGE)
			-- Handle textDocument/didOpen
		require
			msg_not_void: a_msg /= Void
		local
			l_uri, l_path: STRING
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			log_info ("Document opened: " + l_path)
			if not l_path.is_empty then
				parse_and_index_file (l_path)
			end
		end

	handle_did_change (a_msg: LSP_MESSAGE)
			-- Handle textDocument/didChange
		require
			msg_not_void: a_msg /= Void
		do
			log_debug ("Document changed (will re-index on save)")
		end

	handle_did_save (a_msg: LSP_MESSAGE)
			-- Handle textDocument/didSave
		require
			msg_not_void: a_msg /= Void
		local
			l_uri, l_path: STRING
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			log_info ("Document saved: " + l_path)
			if not l_path.is_empty then
				parse_and_index_file (l_path)
			end
		end

	handle_did_close (a_msg: LSP_MESSAGE)
			-- Handle textDocument/didClose
		require
			msg_not_void: a_msg /= Void
		do
			log_debug ("Document closed: " + a_msg.text_document_uri)
		end

feature {NONE} -- Feature Handlers

	handle_definition (a_msg: LSP_MESSAGE)
			-- Handle textDocument/definition - go to definition
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_uri, l_path: STRING
			l_line, l_col: INTEGER
			l_word: STRING
			l_location: detachable SIMPLE_JSON_OBJECT
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			l_line := a_msg.position_line
			l_col := a_msg.position_character

			l_word := word_at_position (l_path, l_line, l_col)
			log_info ("Definition requested for: '" + l_word + "' at " + l_path + ":" + l_line.out + ":" + l_col.out)

			if not l_word.is_empty then
				l_location := find_definition (l_word)
			end

			if attached l_location then
				log_info ("Found definition")
				send_response (a_msg.id, l_location)
			else
				log_info ("Definition not found")
				send_null_response (a_msg.id)
			end
		end

	handle_hover (a_msg: LSP_MESSAGE)
			-- Handle textDocument/hover
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_uri, l_path: STRING
			l_line, l_col: INTEGER
			l_word: STRING
			l_hover: detachable SIMPLE_JSON_OBJECT
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			l_line := a_msg.position_line
			l_col := a_msg.position_character

			l_word := word_at_position (l_path, l_line, l_col)
			log_debug ("Hover requested for: '" + l_word + "'")

			if not l_word.is_empty then
				l_hover := get_hover_info (l_word)
			end

			if attached l_hover then
				send_response (a_msg.id, l_hover)
			else
				send_null_response (a_msg.id)
			end
		end

	handle_completion (a_msg: LSP_MESSAGE)
			-- Handle textDocument/completion
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_items: SIMPLE_JSON_ARRAY
		do
			log_debug ("Completion requested")
			l_items := get_completion_items
			send_response_array (a_msg.id, l_items)
		end

	handle_document_symbol (a_msg: LSP_MESSAGE)
			-- Handle textDocument/documentSymbol
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_uri, l_path: STRING
			l_symbols: SIMPLE_JSON_ARRAY
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			log_debug ("Document symbols requested for: " + l_path)
			l_symbols := get_document_symbols (l_path)
			send_response_array (a_msg.id, l_symbols)
		end

feature {NONE} -- Response Helpers

	send_response (a_id: INTEGER; a_result: detachable SIMPLE_JSON_OBJECT)
			-- Send JSON-RPC response
		require
			valid_id: a_id >= 0
		local
			l_response: SIMPLE_JSON_OBJECT
		do
			create l_response.make
			l_response.put_string ("2.0", "jsonrpc").do_nothing
			l_response.put_integer (a_id, "id").do_nothing
			if attached a_result then
				l_response.put_object (a_result, "result").do_nothing
			else
				l_response.put_null ("result").do_nothing
			end
			write_message (l_response.as_json)
		end

	send_response_array (a_id: INTEGER; a_result: SIMPLE_JSON_ARRAY)
			-- Send JSON-RPC response with array result
		require
			valid_id: a_id >= 0
			result_not_void: a_result /= Void
		local
			l_response: SIMPLE_JSON_OBJECT
		do
			create l_response.make
			l_response.put_string ("2.0", "jsonrpc").do_nothing
			l_response.put_integer (a_id, "id").do_nothing
			l_response.put_array (a_result, "result").do_nothing
			write_message (l_response.as_json)
		end

	send_null_response (a_id: INTEGER)
			-- Send null result response
		require
			valid_id: a_id >= 0
		local
			l_response: SIMPLE_JSON_OBJECT
		do
			create l_response.make
			l_response.put_string ("2.0", "jsonrpc").do_nothing
			l_response.put_integer (a_id, "id").do_nothing
			l_response.put_null ("result").do_nothing
			write_message (l_response.as_json)
		end

	send_notification (a_method: STRING; a_params: SIMPLE_JSON_OBJECT)
			-- Send JSON-RPC notification
		require
			method_not_void: a_method /= Void
			method_not_empty: not a_method.is_empty
			params_not_void: a_params /= Void
		local
			l_notification: SIMPLE_JSON_OBJECT
		do
			create l_notification.make
			l_notification.put_string ("2.0", "jsonrpc").do_nothing
			l_notification.put_string (a_method, "method").do_nothing
			l_notification.put_object (a_params, "params").do_nothing
			write_message (l_notification.as_json)
		end

feature {NONE} -- Indexing

	index_workspace
			-- Index all Eiffel files in workspace
		local
			l_count: INTEGER
		do
			log_info ("Starting workspace indexing: " + workspace_root)
			l_count := index_directory (workspace_root)
			log_info ("Indexed " + l_count.out + " Eiffel files")
		end

	index_directory (a_path: STRING): INTEGER
			-- Recursively index directory, return count of files indexed
		require
			path_not_void: a_path /= Void
			path_not_empty: not a_path.is_empty
		local
			l_dir: DIRECTORY
			l_entries: ARRAYED_LIST [PATH]
			l_entry_name: STRING
			l_entry_path: STRING
			l_file: SIMPLE_FILE
		do
			create l_dir.make (a_path)
			if l_dir.exists then
				l_dir.open_read
				l_entries := l_dir.entries
				across l_entries as entry loop
					l_entry_name := entry.name.to_string_8
					if not l_entry_name.same_string (".") and not l_entry_name.same_string ("..") then
						l_entry_path := a_path + "/" + l_entry_name
						create l_file.make (l_entry_path)
						if l_file.is_directory then
							-- Skip hidden directories and EIFGENs
							if not l_entry_name.starts_with (".") and not l_entry_name.same_string ("EIFGENs") then
								Result := Result + index_directory (l_entry_path)
							end
						elseif l_file.extension.same_string_general ("e") then
							parse_and_index_file (l_entry_path)
							Result := Result + 1
						end
					end
				end
				l_dir.close
			end
		ensure
			non_negative: Result >= 0
		end

	parse_and_index_file (a_path: STRING)
			-- Parse file and index symbols
		require
			path_not_void: a_path /= Void
			path_not_empty: not a_path.is_empty
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ast: EIFFEL_AST
			l_class_id: INTEGER
			l_mtime: INTEGER
		do
			create l_file.make (a_path)
			if l_file.exists then
				l_mtime := l_file.modified_timestamp
				-- Check if file needs re-indexing
				if symbol_db.file_mtime (a_path) < l_mtime then
					log_debug ("Indexing: " + a_path)
					l_content := l_file.read_text.to_string_8
					l_ast := parser.parse_string (l_content)

					if not l_ast.has_errors then
						across l_ast.classes as cls loop
							-- Clear old data for this file
							symbol_db.clear_file (a_path)

							-- Add class
							symbol_db.add_class_full (
								cls.name,
								a_path,
								cls.line,
								cls.column,
								cls.is_deferred,
								cls.is_expanded,
								cls.is_frozen,
								cls.header_comment,
								l_mtime
							)

							l_class_id := symbol_db.class_id (cls.name)
							if l_class_id > 0 then
								-- Add features
								across cls.features as feat loop
									symbol_db.add_feature_full (
										l_class_id,
										feat.name,
										feat.kind_string,
										feat.line,
										feat.column,
										if attached feat.return_type as rt then rt else "" end,
										feat.signature,
										feat.precondition,
										feat.postcondition,
										feat.header_comment,
										feat.is_deferred,
										feat.is_frozen,
										feat.export_status
									)
								end

								-- Add inheritance
								across cls.parents as parent loop
									symbol_db.add_inheritance (l_class_id, parent.parent_name)
								end
							end
							log_debug ("Indexed class: " + cls.name + " with " + cls.features.count.out + " features")
						end
					else
						log_warning ("Parse errors in: " + a_path)
						across l_ast.parse_errors as err loop
							log_warning ("  Line " + err.line.out + ": " + err.message)
						end
					end
				end
			else
				log_warning ("File not found: " + a_path)
			end
		end

feature {NONE} -- Definition Finding

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

feature {NONE} -- Hover Info

	get_hover_info (a_word: STRING): detachable SIMPLE_JSON_OBJECT
			-- Get hover information for word
		require
			word_not_void: a_word /= Void
			word_not_empty: not a_word.is_empty
		local
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
			l_feature_info: detachable TUPLE [file_path: STRING; line, column: INTEGER; signature, comment: STRING]
			l_content: STRING
			l_contents: SIMPLE_JSON_OBJECT
		do
			-- Try as class name
			l_class_info := symbol_db.find_class (a_word)
			if attached l_class_info then
				create l_content.make_from_string ("**class " + a_word.as_upper + "**")
				create Result.make
				create l_contents.make
				l_contents.put_string ("markdown", "kind").do_nothing
				l_contents.put_string (l_content, "value").do_nothing
				Result.put_object (l_contents, "contents").do_nothing
			else
				-- Try as feature
				across symbol_db.all_class_names as class_name until Result /= Void loop
					l_feature_info := symbol_db.find_feature (class_name, a_word)
					if attached l_feature_info then
						create l_content.make_from_string ("**" + a_word + "**")
						if attached l_feature_info.signature as sig and then not sig.is_empty then
							l_content.append ("%N%N```eiffel%N" + sig + "%N```")
						end
						if attached l_feature_info.comment as cmt and then not cmt.is_empty then
							l_content.append ("%N%N" + cmt)
						end
						create Result.make
						create l_contents.make
						l_contents.put_string ("markdown", "kind").do_nothing
						l_contents.put_string (l_content, "value").do_nothing
						Result.put_object (l_contents, "contents").do_nothing
					end
				end
			end
		end

feature {NONE} -- Completion

	get_completion_items: SIMPLE_JSON_ARRAY
			-- Get completion items (all classes and features)
		local
			l_item: SIMPLE_JSON_OBJECT
			l_detail: STRING
		do
			create Result.make
			log_debug ("Building completion list")

			-- Add all class names
			across symbol_db.all_class_names as class_name loop
				create l_item.make
				l_item.put_string (class_name, "label").do_nothing
				l_item.put_integer (7, "kind").do_nothing -- Class = 7
				l_item.put_string ("class", "detail").do_nothing
				Result.add_object (l_item).do_nothing
			end

			-- Add all features
			across symbol_db.all_features as feat loop
				create l_item.make
				l_item.put_string (feat.name, "label").do_nothing
				-- LSP CompletionItemKind: Method=2, Field=5, Function=3
				if feat.kind.same_string ("attribute") then
					l_item.put_integer (5, "kind").do_nothing -- Field
				elseif feat.kind.same_string ("procedure") then
					l_item.put_integer (2, "kind").do_nothing -- Method
				else
					l_item.put_integer (3, "kind").do_nothing -- Function
				end
				-- Show class name and signature in detail
				l_detail := feat.class_name
				if attached feat.signature as sig and then not sig.is_empty then
					l_detail := l_detail + " - " + sig.head (50)
				end
				l_item.put_string (l_detail, "detail").do_nothing
				Result.add_object (l_item).do_nothing
			end

			log_debug ("Completion items: " + Result.count.out)
		ensure
			result_not_void: Result /= Void
		end

	create_trigger_chars: SIMPLE_JSON_ARRAY
			-- Create array of completion trigger characters
		do
			create Result.make
			Result.add_string (".").do_nothing  -- After dot for feature calls
			Result.add_string ("_").do_nothing  -- For snake_case identifiers
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Document Symbols

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
				l_content := l_file.read_text.to_string_8
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

feature {NONE} -- Workspace Symbols

	handle_workspace_symbol (a_msg: LSP_MESSAGE)
			-- Handle workspace/symbol - search symbols across workspace (Ctrl+T)
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_query: STRING
			l_symbols: SIMPLE_JSON_ARRAY
		do
			l_query := ""
			if attached a_msg.params as l_params then
				if attached l_params.string_item ("query") as q then
					l_query := q.to_string_8
				end
			end
			log_info ("Workspace symbol search: '" + l_query + "'")
			l_symbols := get_workspace_symbols (l_query)
			send_response_array (a_msg.id, l_symbols)
		end

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

feature {NONE} -- Find References

	handle_references (a_msg: LSP_MESSAGE)
			-- Handle textDocument/references - find all references to symbol
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_uri, l_path: STRING
			l_line, l_col: INTEGER
			l_word: STRING
			l_references: SIMPLE_JSON_ARRAY
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			l_line := a_msg.position_line
			l_col := a_msg.position_character

			l_word := word_at_position (l_path, l_line, l_col)
			log_info ("References requested for: '" + l_word + "'")

			l_references := find_references (l_word)
			send_response_array (a_msg.id, l_references)
		end

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

feature {NONE} -- Path Helpers

	uri_to_path (a_uri: STRING): STRING
			-- Convert file:// URI to local path
		require
			uri_not_void: a_uri /= Void
		do
			Result := a_uri.twin
			-- URL decode first (%%3A -> :)
			Result := url_decode (Result)
			if Result.starts_with ("file:///") then
				Result := Result.substring (9, Result.count)
				-- Handle Windows drive letters (file:///C:/...)
				if Result.count >= 2 and then Result.item (2) = ':' then
					-- Keep as-is for Windows (D:/prod/...)
				else
					-- Unix path - add leading slash
					Result := "/" + Result
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	path_to_uri (a_path: STRING): STRING
			-- Convert local path to file:// URI
		require
			path_not_void: a_path /= Void
			path_not_empty: not a_path.is_empty
		do
			Result := "file:///"
			if a_path.count >= 2 and then a_path.item (2) = ':' then
				-- Windows path
				Result.append (a_path)
			else
				-- Unix path
				Result.append (a_path.substring (2, a_path.count))
			end
			-- URL encode spaces
			Result.replace_substring_all (" ", "%%20")
		ensure
			result_not_void: Result /= Void
			result_has_prefix: Result.starts_with ("file:///")
		end

	url_decode (a_string: STRING): STRING
			-- Decode URL-encoded string
		require
			string_not_void: a_string /= Void
		local
			i: INTEGER
			l_hex: STRING
			l_code: INTEGER
		do
			create Result.make (a_string.count)
			from i := 1 until i > a_string.count loop
				if a_string.item (i) = '%%' and then i + 2 <= a_string.count then
					l_hex := a_string.substring (i + 1, i + 2)
					if l_hex.count = 2 then
						l_code := hex_to_int (l_hex)
						if l_code > 0 then
							Result.append_character (l_code.to_character_8)
							i := i + 3
						else
							Result.append_character (a_string.item (i))
							i := i + 1
						end
					else
						Result.append_character (a_string.item (i))
						i := i + 1
					end
				else
					Result.append_character (a_string.item (i))
					i := i + 1
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	hex_to_int (a_hex: STRING): INTEGER
			-- Convert 2-char hex string to integer
		require
			hex_not_void: a_hex /= Void
			hex_two_chars: a_hex.count = 2
		local
			l_c: CHARACTER
		do
			l_c := a_hex.item (1).as_lower
			if l_c >= '0' and l_c <= '9' then
				Result := (l_c.code - ('0').code) * 16
			elseif l_c >= 'a' and l_c <= 'f' then
				Result := (l_c.code - ('a').code + 10) * 16
			end

			l_c := a_hex.item (2).as_lower
			if l_c >= '0' and l_c <= '9' then
				Result := Result + (l_c.code - ('0').code)
			elseif l_c >= 'a' and l_c <= 'f' then
				Result := Result + (l_c.code - ('a').code + 10)
			end
		ensure
			in_byte_range: Result >= 0 and Result <= 255
		end

	word_at_position (a_path: STRING; a_line, a_col: INTEGER): STRING
			-- Get word at position in file
		require
			path_not_void: a_path /= Void
			path_not_empty: not a_path.is_empty
			line_valid: a_line >= 0
			col_valid: a_col >= 0
		local
			l_file: SIMPLE_FILE
			l_lines: LIST [STRING_32]
			l_line_text: STRING
			l_start, l_end: INTEGER
		do
			create Result.make_empty
			log_debug ("word_at_position: path=" + a_path + " line=" + a_line.out + " col=" + a_col.out)
			create l_file.make (a_path)
			if l_file.exists then
				log_debug ("File exists, reading lines...")
				l_lines := l_file.read_lines
				log_debug ("Read " + l_lines.count.out + " lines")
				if a_line >= 0 and a_line < l_lines.count then
					l_line_text := l_lines.i_th (a_line + 1).to_string_8 -- LSP is 0-based
					log_debug ("Line " + (a_line + 1).out + " has " + l_line_text.count.out + " chars: '" + l_line_text.head (80) + "'")

					-- Find word boundaries
					l_start := a_col + 1
					l_end := a_col + 1

					-- Make sure we're within bounds
					if l_start >= 1 and l_start <= l_line_text.count then
						-- Scan backward
						from
						until
							l_start <= 1 or else not is_word_char (l_line_text.item (l_start - 1))
						loop
							l_start := l_start - 1
						end

						-- Scan forward
						from
						until
							l_end > l_line_text.count or else not is_word_char (l_line_text.item (l_end))
						loop
							l_end := l_end + 1
						end

						if l_end > l_start then
							Result := l_line_text.substring (l_start, l_end - 1)
							log_debug ("Found word: '" + Result + "'")
						else
							log_debug ("No word found (l_end=" + l_end.out + " l_start=" + l_start.out + ")")
						end
					else
						log_debug ("Column " + l_start.out + " out of bounds (line has " + l_line_text.count.out + " chars)")
					end
				else
					log_debug ("Line " + a_line.out + " out of range (file has " + l_lines.count.out + " lines)")
				end
			else
				log_debug ("File does not exist: " + a_path)
			end
		ensure
			result_not_void: Result /= Void
		end

	is_word_char (a_char: CHARACTER): BOOLEAN
			-- Is character part of an identifier?
		do
			Result := a_char.is_alpha or a_char.is_digit or a_char = '_'
		end

feature {NONE} -- Logging

	log_info (a_message: STRING)
			-- Log info message
		require
			message_not_void: a_message /= Void
		do
			logger.log_info (a_message)
		end

	log_debug (a_message: STRING)
			-- Log debug message
		require
			message_not_void: a_message /= Void
		do
			logger.log_debug (a_message)
		end

	log_warning (a_message: STRING)
			-- Log warning message
		require
			message_not_void: a_message /= Void
		do
			logger.log_warning (a_message)
		end

	log_error (a_message: STRING)
			-- Log error message
		require
			message_not_void: a_message /= Void
		do
			logger.log_error (a_message)
		end

feature {NONE} -- Directory Helpers

	ensure_directory (a_path: STRING)
			-- Create directory if it doesn't exist
		require
			path_not_void: a_path /= Void
			path_not_empty: not a_path.is_empty
		local
			l_dir: DIRECTORY
		do
			create l_dir.make (a_path)
			if not l_dir.exists then
				l_dir.recursive_create_dir
			end
		end

feature {NONE} -- Implementation

	json: SIMPLE_JSON
			-- JSON parser/builder

	symbol_db: LSP_SYMBOL_DATABASE
			-- Symbol database

	parser: EIFFEL_PARSER
			-- Eiffel parser

	logger: LSP_LOGGER
			-- Logger for debugging

invariant
	workspace_not_void: workspace_root /= Void
	workspace_not_empty: not workspace_root.is_empty
	json_exists: json /= Void
	symbol_db_exists: symbol_db /= Void
	parser_exists: parser /= Void
	logger_exists: logger /= Void

end
