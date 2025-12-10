note
	description: "Handler for LSP hover operations"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_HOVER_HANDLER

create
	make

feature {NONE} -- Initialization

	make (a_db: LSP_SYMBOL_DATABASE; a_logger: LSP_LOGGER; a_eifgens_parser: EIFGENS_METADATA_PARSER)
			-- Create handler with database, logger, and EIFGENs parser
		require
			db_not_void: a_db /= Void
			logger_not_void: a_logger /= Void
			parser_not_void: a_eifgens_parser /= Void
		do
			symbol_db := a_db
			logger := a_logger
			eifgens_parser := a_eifgens_parser
			eifgens_loaded := False
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

	eifgens_loaded: BOOLEAN
			-- Is EIFGENs metadata loaded?

feature -- Status Setting

	set_eifgens_loaded (a_loaded: BOOLEAN)
			-- Set whether EIFGENs metadata is loaded
		do
			eifgens_loaded := a_loaded
		ensure
			loaded_set: eifgens_loaded = a_loaded
		end

feature -- Operations

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

feature {NONE} -- Implementation

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
