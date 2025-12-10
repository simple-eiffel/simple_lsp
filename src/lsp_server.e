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
			create document_cache.make (10)
			create eifgens_parser.default_create
			create rename_handler.make (symbol_db, logger)
			create hover_handler.make (symbol_db, logger, eifgens_parser)
			create completion_handler.make (symbol_db, logger)
			create navigation_handler.make (symbol_db, logger, parser)
			is_initialized := False
			is_running := False
			eifgens_loaded := False

			log_info ("simple_lsp v" + Version + " starting for workspace: " + a_workspace_root)
		ensure
			root_set: workspace_root = a_workspace_root
			not_initialized: not is_initialized
			not_running: not is_running
			json_created: json /= Void
			db_created: symbol_db /= Void
			parser_created: parser /= Void
			logger_created: logger /= Void
			cache_created: document_cache /= Void
			eifgens_parser_created: eifgens_parser /= Void
			rename_handler_created: rename_handler /= Void
			hover_handler_created: hover_handler /= Void
			completion_handler_created: completion_handler /= Void
			navigation_handler_created: navigation_handler /= Void
		end

feature -- Constants

	Version: STRING = "0.6.0"
			-- LSP server version (update on each release)

feature -- Access

	workspace_root: STRING
			-- Root directory of workspace

	is_initialized: BOOLEAN
			-- Has client sent initialize request?

	is_running: BOOLEAN
			-- Is server running?

	rename_handler: LSP_RENAME_HANDLER
			-- Handler for rename operations

	hover_handler: LSP_HOVER_HANDLER
			-- Handler for hover operations

	completion_handler: LSP_COMPLETION_HANDLER
			-- Handler for completion operations

	navigation_handler: LSP_NAVIGATION_HANDLER
			-- Handler for navigation operations (definition, references, symbols)

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
			elseif a_msg.method.same_string ("textDocument/signatureHelp") then
				handle_signature_help (a_msg)
			elseif a_msg.method.same_string ("textDocument/rename") then
				handle_rename (a_msg)
			elseif a_msg.method.same_string ("textDocument/prepareRename") then
				handle_prepare_rename (a_msg)
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
			l_server_info: SIMPLE_JSON_OBJECT
			l_root_path: STRING
			l_db_dir: STRING
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

					-- Re-create logger and database in the new workspace location
					l_db_dir := workspace_root + "/.eiffel_lsp"
					ensure_directory (l_db_dir)
					logger.close
					create logger.make (l_db_dir + "/lsp.log")
					symbol_db.close
					create symbol_db.make (l_db_dir + "/symbols.db")
					-- Re-create handlers with new database and logger references
					create rename_handler.make (symbol_db, logger)
					create hover_handler.make (symbol_db, logger, eifgens_parser)
					create completion_handler.make (symbol_db, logger)
					create navigation_handler.make (symbol_db, logger, parser)
					log_info ("Re-initialized logger and database at: " + l_db_dir)
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
			l_capabilities.put_object (create_signature_help_options, "signatureHelpProvider").do_nothing
			l_capabilities.put_boolean (True, "renameProvider").do_nothing

			-- Build server info (shows in VS Code output)
			create l_server_info.make
			l_server_info.put_string ("simple_lsp", "name").do_nothing
			l_server_info.put_string (Version, "version").do_nothing

			create l_result.make
			l_result.put_object (l_capabilities, "capabilities").do_nothing
			l_result.put_object (l_server_info, "serverInfo").do_nothing

			send_response (a_msg.id, l_result)
			is_initialized := True
			log_info ("Server v" + Version + " initialized successfully")
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
			load_eifgens_metadata
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
			-- Handle textDocument/didChange - re-parse for diagnostics and cache content
		require
			msg_not_void: a_msg /= Void
		local
			l_uri, l_path: STRING
			l_text: detachable STRING
			l_ast: EIFFEL_AST
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			log_debug ("Document changed: " + l_path)

			-- Extract the new content from contentChanges
			if attached a_msg.params as l_params then
				if attached l_params.array_item ("contentChanges") as l_changes then
					if l_changes.count > 0 then
						if attached l_changes.item (1) as l_change and then l_change.is_object then
							if attached l_change.as_object.string_item ("text") as l_txt then
								l_text := l_txt.to_string_8
							end
						end
					end
				end
			end

			-- Cache the document content and re-parse for diagnostics
			if attached l_text and then not l_text.is_empty then
				-- Cache the content for signature help and other features
				document_cache.force (l_text, l_path)
				log_debug ("Cached document content for: " + l_path + " (" + l_text.count.out + " chars)")

				l_ast := parser.parse_string (l_text)
				if l_ast.has_errors then
					publish_diagnostics (l_uri, l_ast.parse_errors)
				else
					clear_diagnostics (l_uri)
				end
			end
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
			-- Handle textDocument/definition - delegates to navigation_handler
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
				l_location := navigation_handler.find_definition (l_word)
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
			-- Handle textDocument/hover - delegates to hover_handler
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
				l_hover := hover_handler.get_hover_info (l_word)
			end

			if attached l_hover then
				send_response (a_msg.id, l_hover)
			else
				send_null_response (a_msg.id)
			end
		end

	handle_completion (a_msg: LSP_MESSAGE)
			-- Handle textDocument/completion - delegates to completion_handler
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_items: SIMPLE_JSON_ARRAY
		do
			log_debug ("Completion requested")
			l_items := completion_handler.get_completion_items
			send_response_array (a_msg.id, l_items)
		end

	handle_document_symbol (a_msg: LSP_MESSAGE)
			-- Handle textDocument/documentSymbol - delegates to navigation_handler
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
			l_symbols := navigation_handler.get_document_symbols (l_path)
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

feature {NONE} -- Diagnostics

	publish_diagnostics (a_uri: STRING; a_errors: ARRAYED_LIST [EIFFEL_PARSE_ERROR])
			-- Publish diagnostics to client (red squiggles)
		require
			uri_not_void: a_uri /= Void
			uri_not_empty: not a_uri.is_empty
			errors_not_void: a_errors /= Void
		local
			l_params: SIMPLE_JSON_OBJECT
			l_diagnostics: SIMPLE_JSON_ARRAY
			l_diag: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_start_pos, l_end_pos: SIMPLE_JSON_OBJECT
			l_severity: INTEGER
		do
			create l_diagnostics.make

			across a_errors as err loop
				-- Create diagnostic object
				create l_diag.make

				-- Range (start and end position)
				create l_start_pos.make
				l_start_pos.put_integer (err.line - 1, "line").do_nothing  -- LSP is 0-based
				l_start_pos.put_integer (err.column - 1, "character").do_nothing

				create l_end_pos.make
				l_end_pos.put_integer (err.line - 1, "line").do_nothing
				l_end_pos.put_integer (err.column + 10, "character").do_nothing  -- Highlight ~10 chars

				create l_range.make
				l_range.put_object (l_start_pos, "start").do_nothing
				l_range.put_object (l_end_pos, "end").do_nothing

				l_diag.put_object (l_range, "range").do_nothing

				-- Severity: LSP uses 1=Error, 2=Warning, 3=Information, 4=Hint
				-- Our parser uses same values, so direct mapping works
				l_severity := err.severity
				if l_severity < 1 or l_severity > 4 then
					l_severity := 1 -- Default to error
				end
				l_diag.put_integer (l_severity, "severity").do_nothing

				-- Source
				l_diag.put_string ("eiffel-lsp", "source").do_nothing

				-- Message
				l_diag.put_string (err.message, "message").do_nothing

				l_diagnostics.add_object (l_diag).do_nothing
			end

			-- Build params
			create l_params.make
			l_params.put_string (a_uri, "uri").do_nothing
			l_params.put_array (l_diagnostics, "diagnostics").do_nothing

			-- Send notification
			send_notification ("textDocument/publishDiagnostics", l_params)
			log_info ("Published " + a_errors.count.out + " diagnostics for: " + a_uri)
		end

	clear_diagnostics (a_uri: STRING)
			-- Clear all diagnostics for a document
		require
			uri_not_void: a_uri /= Void
			uri_not_empty: not a_uri.is_empty
		local
			l_params: SIMPLE_JSON_OBJECT
			l_empty: SIMPLE_JSON_ARRAY
		do
			create l_empty.make
			create l_params.make
			l_params.put_string (a_uri, "uri").do_nothing
			l_params.put_array (l_empty, "diagnostics").do_nothing
			send_notification ("textDocument/publishDiagnostics", l_params)
			log_debug ("Cleared diagnostics for: " + a_uri)
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
			l_uri: STRING
		do
			create l_file.make (a_path)
			if l_file.exists then
				l_mtime := l_file.modified_timestamp
				l_uri := path_to_uri (a_path)

				log_debug ("Indexing: " + a_path)
				l_content := l_file.read_text.to_string_8
				l_ast := parser.parse_string (l_content)

				-- Always publish diagnostics (either errors or clear)
				if l_ast.has_errors then
					publish_diagnostics (l_uri, l_ast.parse_errors)
					log_warning ("Parse errors in: " + a_path)
					across l_ast.parse_errors as err loop
						log_warning ("  Line " + err.line.out + ": " + err.message)
					end
				else
					-- No errors - clear any previous diagnostics
					clear_diagnostics (l_uri)

					-- Index the file if it changed
					if symbol_db.file_mtime (a_path) < l_mtime then
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
									-- Also record as type reference (inherit context)
									symbol_db.add_type_reference (l_class_id, parent.parent_name, "inherit")
								end

								-- Extract type references for suppliers
								extract_type_references (l_class_id, cls)
							end
							log_debug ("Indexed class: " + cls.name + " with " + cls.features.count.out + " features")
						end
					end
				end
			else
				log_warning ("File not found: " + a_path)
			end
		end

feature {NONE} -- Type Reference Extraction

	extract_type_references (a_class_id: INTEGER; a_class: EIFFEL_CLASS_NODE)
			-- Extract type references from class for supplier tracking
		require
			class_id_valid: a_class_id > 0
			class_not_void: a_class /= Void
		local
			l_type: STRING
		do
			-- Clear old references for this class
			symbol_db.clear_type_references (a_class_id)

			-- Process each feature
			across a_class.features as feat loop
				-- Return type (function)
				if attached feat.return_type as rt and then not rt.is_empty then
					l_type := extract_base_type (rt)
					if is_user_type (l_type) then
						symbol_db.add_type_reference (a_class_id, l_type, "return")
					end
				end

				-- Argument types
				across feat.arguments as arg loop
					l_type := extract_base_type (arg.arg_type)
					if is_user_type (l_type) then
						symbol_db.add_type_reference (a_class_id, l_type, "argument")
					end
				end

				-- Local types
				across feat.locals as loc loop
					l_type := extract_base_type (loc.local_type)
					if is_user_type (l_type) then
						symbol_db.add_type_reference (a_class_id, l_type, "local")
					end
				end
			end
		end

	extract_base_type (a_type: STRING): STRING
			-- Extract base type from possibly generic/detachable type
			-- "detachable ARRAYED_LIST [STRING]" -> "ARRAYED_LIST"
			-- "like Current" -> ""
		require
			type_not_void: a_type /= Void
		local
			l_work: STRING
			l_bracket: INTEGER
		do
			l_work := a_type.twin
			l_work.left_adjust
			l_work.right_adjust

			-- Remove "detachable" or "attached" prefix
			if l_work.starts_with ("detachable ") then
				l_work := l_work.substring (12, l_work.count)
			elseif l_work.starts_with ("attached ") then
				l_work := l_work.substring (10, l_work.count)
			end
			l_work.left_adjust

			-- Handle "like" anchored types
			if l_work.starts_with ("like") then
				Result := ""
			else
				-- Remove generic parameters
				l_bracket := l_work.index_of ('[', 1)
				if l_bracket > 0 then
					Result := l_work.substring (1, l_bracket - 1)
					Result.right_adjust
				else
					Result := l_work
				end
			end
		ensure
			result_exists: Result /= Void
		end

	is_user_type (a_type: STRING): BOOLEAN
			-- Is this a type we should track? (not basic types or empty)
		require
			type_not_void: a_type /= Void
		do
			if a_type.is_empty then
				Result := False
			elseif a_type.same_string ("BOOLEAN") then
				Result := False
			elseif a_type.same_string ("INTEGER") or a_type.same_string ("INTEGER_32") then
				Result := False
			elseif a_type.same_string ("INTEGER_8") or a_type.same_string ("INTEGER_16") or a_type.same_string ("INTEGER_64") then
				Result := False
			elseif a_type.same_string ("NATURAL") or a_type.same_string ("NATURAL_32") then
				Result := False
			elseif a_type.same_string ("NATURAL_8") or a_type.same_string ("NATURAL_16") or a_type.same_string ("NATURAL_64") then
				Result := False
			elseif a_type.same_string ("REAL") or a_type.same_string ("REAL_32") or a_type.same_string ("REAL_64") then
				Result := False
			elseif a_type.same_string ("DOUBLE") then
				Result := False
			elseif a_type.same_string ("CHARACTER") or a_type.same_string ("CHARACTER_8") or a_type.same_string ("CHARACTER_32") then
				Result := False
			elseif a_type.same_string ("POINTER") then
				Result := False
			else
				Result := True
			end
		end

feature {NONE} -- EIFGENs Metadata

	load_eifgens_metadata
			-- Load compiled metadata from EIFGENs folder for accurate semantic info
		do
			log_info ("Looking for EIFGENs metadata in: " + workspace_root)
			if eifgens_parser.load_from_project (workspace_root) then
				eifgens_loaded := True
				hover_handler.set_eifgens_loaded (True)
				log_info ("EIFGENs metadata loaded: " + eifgens_parser.class_count.out + " classes")
			else
				log_info ("No EIFGENs metadata found (project not compiled yet?)")
				eifgens_loaded := False
				hover_handler.set_eifgens_loaded (False)
			end
		end

	reload_eifgens_metadata
			-- Reload EIFGENs metadata (after compile)
		do
			log_info ("Reloading EIFGENs metadata...")
			create eifgens_parser.default_create
			load_eifgens_metadata
		end

	get_inheritance_info (a_class_name: STRING): STRING
			-- Get inheritance chain info for class (from EIFGENs metadata)
		require
			name_not_empty: not a_class_name.is_empty
		local
			l_chain: ARRAYED_LIST [STRING]
		do
			create Result.make_empty
			if eifgens_loaded and then eifgens_parser.has_class (a_class_name) then
				l_chain := eifgens_parser.ancestor_chain (a_class_name)
				if l_chain.count > 1 then
					Result := "Inherits from: "
					across l_chain as anc loop
						if not anc.same_string (a_class_name) then
							if Result.count > 16 then
								Result.append (", ")
							end
							Result.append (anc)
						end
					end
				end
			end
		ensure
			result_exists: Result /= Void
		end

	get_suppliers_info (a_class_name: STRING): STRING
			-- Get supplier classes info (types this class uses)
		require
			name_not_empty: not a_class_name.is_empty
		local
			l_suppliers: ARRAYED_LIST [STRING]
			l_first: BOOLEAN
		do
			create Result.make_empty
			l_suppliers := symbol_db.suppliers_of (a_class_name)
			if not l_suppliers.is_empty then
				l_first := True
				across l_suppliers as sup loop
					if l_first then
						l_first := False
					else
						Result.append (", ")
					end
					Result.append (sup)
				end
			end
		ensure
			result_exists: Result /= Void
		end

	get_clients_info (a_class_name: STRING): STRING
			-- Get client classes info (classes that use this type)
			-- Excludes self-references (class showing itself as client)
		require
			name_not_empty: not a_class_name.is_empty
		local
			l_clients: ARRAYED_LIST [STRING]
			l_first: BOOLEAN
		do
			create Result.make_empty
			l_clients := symbol_db.clients_of (a_class_name)
			if not l_clients.is_empty then
				l_first := True
				across l_clients as cli loop
					-- Skip self-references
					if not cli.same_string (a_class_name) then
						if l_first then
							l_first := False
						else
							Result.append (", ")
						end
						Result.append (cli)
					end
				end
			end
		ensure
			result_exists: Result /= Void
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
			l_inheritance: STRING
			l_lookup_name: STRING
			l_display_name: STRING
			l_alias_note: STRING
			l_suppliers_info: STRING
			l_clients_info: STRING
		do
			-- Resolve type aliases (INTEGER -> INTEGER_32, STRING -> STRING_8, etc.)
			l_lookup_name := resolve_type_alias (a_word.as_upper)
			l_display_name := a_word.as_upper
			if not l_lookup_name.same_string (l_display_name) then
				l_alias_note := " (alias for " + l_lookup_name + ")"
			else
				l_alias_note := ""
			end

			-- Try as class name (workspace or EIFGENs)
			l_class_info := symbol_db.find_class (l_lookup_name)
			if attached l_class_info then
				create l_content.make_from_string ("**class " + l_display_name + "**" + l_alias_note + " *(workspace)*")
				-- Add inheritance info from EIFGENs metadata
				l_inheritance := get_inheritance_info (l_lookup_name)
				if not l_inheritance.is_empty then
					l_content.append ("%N%N*" + l_inheritance + "*")
				end
				-- Add suppliers and clients
				l_suppliers_info := get_suppliers_info (l_display_name)
				if not l_suppliers_info.is_empty then
					l_content.append ("%N%N**Suppliers:** " + l_suppliers_info)
				end
				l_clients_info := get_clients_info (l_display_name)
				if not l_clients_info.is_empty then
					l_content.append ("%N%N**Clients:** " + l_clients_info)
				end
				create Result.make
				create l_contents.make
				l_contents.put_string ("markdown", "kind").do_nothing
				l_contents.put_string (l_content, "value").do_nothing
				Result.put_object (l_contents, "contents").do_nothing
			elseif eifgens_loaded and then eifgens_parser.has_class (l_lookup_name) then
				-- Class from compiled metadata (stdlib class)
				create l_content.make_from_string ("**class " + l_display_name + "**" + l_alias_note + " *(compiled)*")
				l_inheritance := get_inheritance_info (l_lookup_name)
				if not l_inheritance.is_empty then
					l_content.append ("%N%N*" + l_inheritance + "*")
				end
				-- Clients only for stdlib classes (no supplier data for non-workspace classes)
				l_clients_info := get_clients_info (l_display_name)
				if not l_clients_info.is_empty then
					l_content.append ("%N%N**Clients:** " + l_clients_info)
				end
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

	resolve_type_alias (a_name: STRING): STRING
			-- Resolve Eiffel type alias to actual class name
			-- INTEGER -> INTEGER_32, STRING -> STRING_8, etc.
		require
			name_not_empty: not a_name.is_empty
		do
			if a_name.same_string ("INTEGER") then
				Result := "INTEGER_32"
			elseif a_name.same_string ("NATURAL") then
				Result := "NATURAL_32"
			elseif a_name.same_string ("REAL") then
				Result := "REAL_32"
			elseif a_name.same_string ("DOUBLE") then
				Result := "REAL_64"
			elseif a_name.same_string ("CHARACTER") then
				Result := "CHARACTER_8"
			elseif a_name.same_string ("STRING") then
				Result := "STRING_8"
			elseif a_name.same_string ("WIDE_CHARACTER") then
				Result := "CHARACTER_32"
			else
				Result := a_name
			end
		ensure
			result_not_empty: not Result.is_empty
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

feature {NONE} -- Signature Help

	create_signature_help_options: SIMPLE_JSON_OBJECT
			-- Create signature help provider options
		local
			l_triggers: SIMPLE_JSON_ARRAY
		do
			create Result.make
			create l_triggers.make
			l_triggers.add_string ("(").do_nothing  -- Trigger on open paren
			l_triggers.add_string (",").do_nothing  -- Trigger on comma (next param)
			Result.put_array (l_triggers, "triggerCharacters").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	handle_signature_help (a_msg: LSP_MESSAGE)
			-- Handle textDocument/signatureHelp - show parameter hints
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_uri, l_path: STRING
			l_line, l_col: INTEGER
			l_result: detachable SIMPLE_JSON_OBJECT
			l_feature_name: STRING
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			l_line := a_msg.position_line
			l_col := a_msg.position_character

			log_debug ("Signature help at: " + l_path + ":" + l_line.out + ":" + l_col.out)

			-- Find the feature being called
			l_feature_name := feature_at_position (l_path, l_line, l_col)
			log_debug ("Feature name for signature: '" + l_feature_name + "'")

			if not l_feature_name.is_empty then
				l_result := get_signature_help (l_feature_name, l_path, l_line, l_col)
			end

			if attached l_result then
				send_response (a_msg.id, l_result)
			else
				send_null_response (a_msg.id)
			end
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
					l_content := l_file.read_text.to_string_8
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
				l_lines := l_file.read_lines
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
			-- Handle workspace/symbol - delegates to navigation_handler
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
			l_symbols := navigation_handler.get_workspace_symbols (l_query)
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
			-- Handle textDocument/references - delegates to navigation_handler
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

			l_references := navigation_handler.find_references (l_word)
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

feature {NONE} -- Rename Symbol

	handle_rename (a_msg: LSP_MESSAGE)
			-- Handle textDocument/rename - rename symbol across workspace
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_uri, l_path: STRING
			l_line, l_col: INTEGER
			l_word: STRING
			l_new_name: STRING
			l_result: detachable SIMPLE_JSON_OBJECT
		do
			log_info ("handle_rename: starting")
			l_uri := a_msg.text_document_uri
			log_info ("handle_rename: uri=" + l_uri)
			l_path := uri_to_path (l_uri)
			log_info ("handle_rename: path=" + l_path)
			l_line := a_msg.position_line
			l_col := a_msg.position_character
			log_info ("handle_rename: line=" + l_line.out + " col=" + l_col.out)

			l_word := word_at_position (l_path, l_line, l_col)
			log_info ("handle_rename: word='" + l_word + "'")
			l_new_name := ""
			if attached a_msg.params as l_params then
				if attached l_params.string_item ("newName") as nn then
					l_new_name := nn.to_string_8
				end
			end

			log_info ("Rename requested: '" + l_word + "' -> '" + l_new_name + "'")

			if l_word /= Void and then not l_word.is_empty and then l_new_name /= Void and then not l_new_name.is_empty then
				log_info ("About to call rename_handler.compute_workspace_edit")
				log_info ("l_word='" + l_word + "' l_new_name='" + l_new_name + "'")
				if rename_handler = Void then
					log_info ("ERROR: rename_handler is Void!")
				elseif rename_handler.symbol_db = Void then
					log_info ("ERROR: rename_handler.symbol_db is Void!")
				elseif rename_handler.logger = Void then
					log_info ("ERROR: rename_handler.logger is Void!")
				else
					log_info ("rename_handler is fully attached, calling compute_workspace_edit")
					l_result := rename_handler.compute_workspace_edit (l_word, l_new_name)
					log_info ("compute_workspace_edit returned")
				end
			else
				log_info ("ERROR: l_word or l_new_name is void or empty")
			end

			if attached l_result then
				send_response (a_msg.id, l_result)
			else
				send_null_response (a_msg.id)
			end
		end

	handle_prepare_rename (a_msg: LSP_MESSAGE)
			-- Handle textDocument/prepareRename - validate rename is possible
		require
			msg_not_void: a_msg /= Void
			is_request: a_msg.is_request
		local
			l_uri, l_path: STRING
			l_line, l_col: INTEGER
			l_word: STRING
			l_result: SIMPLE_JSON_OBJECT
			l_range: SIMPLE_JSON_OBJECT
			l_start_pos, l_end_pos: SIMPLE_JSON_OBJECT
		do
			l_uri := a_msg.text_document_uri
			l_path := uri_to_path (l_uri)
			l_line := a_msg.position_line
			l_col := a_msg.position_character

			l_word := word_at_position (l_path, l_line, l_col)
			log_debug ("Prepare rename for: '" + l_word + "'")

			if not l_word.is_empty then
				-- Return the range and placeholder text
				create l_result.make

				create l_start_pos.make
				l_start_pos.put_integer (l_line, "line").do_nothing
				l_start_pos.put_integer (l_col - word_start_offset (l_path, l_line, l_col), "character").do_nothing

				create l_end_pos.make
				l_end_pos.put_integer (l_line, "line").do_nothing
				l_end_pos.put_integer (l_col - word_start_offset (l_path, l_line, l_col) + l_word.count, "character").do_nothing

				create l_range.make
				l_range.put_object (l_start_pos, "start").do_nothing
				l_range.put_object (l_end_pos, "end").do_nothing

				l_result.put_object (l_range, "range").do_nothing
				l_result.put_string (l_word, "placeholder").do_nothing

				send_response (a_msg.id, l_result)
			else
				send_null_response (a_msg.id)
			end
		end

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
			-- Find all occurrences of the symbol
			l_occurrences := find_all_occurrences (a_old_name)
			log_info ("Found " + l_occurrences.count.out + " occurrences to rename")

			if l_occurrences.count > 0 then
				create l_file_edits.make (10)
				create l_document_changes.make

				-- Group edits by file
				across l_occurrences as occ loop
					l_uri := path_to_uri (occ.file_path)
					if not l_file_edits.has (l_uri) then
						create l_edits.make
						l_file_edits.force (l_edits, l_uri)
					end
					if attached l_file_edits.item (l_uri) as l_arr then
						-- Create text edit
						create l_start_pos.make
						l_start_pos.put_integer (occ.line - 1, "line").do_nothing
						l_start_pos.put_integer (occ.col - 1, "character").do_nothing

						create l_end_pos.make
						l_end_pos.put_integer (occ.line - 1, "line").do_nothing
						l_end_pos.put_integer (occ.col - 1 + occ.length, "character").do_nothing

						create l_range.make
						l_range.put_object (l_start_pos, "start").do_nothing
						l_range.put_object (l_end_pos, "end").do_nothing

						create l_edit.make
						l_edit.put_object (l_range, "range").do_nothing
						l_edit.put_string (a_new_name, "newText").do_nothing

						l_arr.add_object (l_edit).do_nothing
					end
				end

				-- Build TextDocumentEdit objects for each file
				across l_file_edits as fe loop
					create l_text_doc_edit.make
					create l_text_doc.make
					l_text_doc.put_string (l_file_edits.key_for_iteration, "uri").do_nothing
					l_text_doc_edit.put_object (l_text_doc, "textDocument").do_nothing
					l_text_doc_edit.put_array (fe, "edits").do_nothing
					l_document_changes.add_object (l_text_doc_edit).do_nothing
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
					l_content := l_file.read_text.to_string_8
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

	word_start_offset (a_path: STRING; a_line, a_col: INTEGER): INTEGER
			-- Get offset from a_col to start of word
		require
			path_not_void: a_path /= Void
		local
			l_file: SIMPLE_FILE
			l_lines: LIST [STRING_32]
			l_line_text: STRING
			l_pos: INTEGER
		do
			create l_file.make (a_path)
			if l_file.exists then
				l_lines := l_file.read_lines
				if a_line >= 0 and a_line < l_lines.count then
					l_line_text := l_lines.i_th (a_line + 1).to_string_8
					l_pos := a_col + 1
					if l_pos >= 1 and l_pos <= l_line_text.count then
						from
						until
							l_pos <= 1 or else not is_word_char (l_line_text.item (l_pos - 1))
						loop
							l_pos := l_pos - 1
							Result := Result + 1
						end
					end
				end
			end
		ensure
			non_negative: Result >= 0
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
					-- LSP column is 0-based, Eiffel strings are 1-based
					l_start := a_col + 1
					l_end := a_col + 1

					-- Clamp to line length (cursor can be at end of line)
					if l_start > l_line_text.count then
						l_start := l_line_text.count
						l_end := l_line_text.count
					end

					-- Make sure we're within bounds
					if l_start >= 1 and l_start <= l_line_text.count then
						-- If we're on a word char, scan in both directions
						-- If not, check if previous char is a word char (cursor at end of word)
						if is_word_char (l_line_text.item (l_start)) then
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
						elseif l_start > 1 and then is_word_char (l_line_text.item (l_start - 1)) then
							-- Cursor is just after a word - scan backward from previous char
							l_start := l_start - 1
							l_end := l_start + 1
							from
							until
								l_start <= 1 or else not is_word_char (l_line_text.item (l_start - 1))
							loop
								l_start := l_start - 1
							end
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

	document_cache: HASH_TABLE [STRING, STRING]
			-- Cache of document contents by path (for unsaved changes)

	eifgens_parser: EIFGENS_METADATA_PARSER
			-- Parser for compiled EIFGENs metadata (inheritance, types)

	eifgens_loaded: BOOLEAN
			-- Has EIFGENs metadata been loaded?

invariant
	workspace_not_void: workspace_root /= Void
	workspace_not_empty: not workspace_root.is_empty
	json_exists: json /= Void
	symbol_db_exists: symbol_db /= Void
	parser_exists: parser /= Void
	logger_exists: logger /= Void
	cache_exists: document_cache /= Void
	eifgens_parser_exists: eifgens_parser /= Void

end
