note
	description: "Handler for Contract Lens - shows flat contract view with inheritance attribution"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_CONTRACT_LENS_HANDLER

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

	get_flat_contracts (a_class_name, a_feature_name: STRING): STRING
			-- Get flat contract view for feature with inheritance attribution
			-- Returns markdown formatted string
		require
			class_name_not_empty: a_class_name /= Void and then not a_class_name.is_empty
			feature_name_not_empty: a_feature_name /= Void and then not a_feature_name.is_empty
		local
			l_contracts: ARRAYED_LIST [TUPLE [kind: STRING; text: STRING; origin: STRING]]
			l_ancestors: ARRAYED_LIST [STRING]
			l_class_path: detachable STRING
			l_feature: detachable EIFFEL_FEATURE_NODE
		do
			create Result.make_empty
			create l_contracts.make (10)

			-- Get inheritance chain
			l_ancestors := eifgens_parser.ancestor_chain (a_class_name)
			if l_ancestors.is_empty then
				l_ancestors.extend (a_class_name)
			end

			-- Walk inheritance chain from root to leaf (reverse order to show proper precedence)
			across l_ancestors.new_cursor.reversed as ancestor loop
				l_class_path := find_class_file (ancestor)
				if attached l_class_path as path then
					l_feature := find_feature_in_file (path, a_feature_name)
					if attached l_feature then
						-- Add preconditions
						if not l_feature.precondition.is_empty then
							across split_clauses (l_feature.precondition) as clause loop
								l_contracts.extend ([{STRING} "require", clause.twin, ancestor.twin])
							end
						end
						-- Add postconditions
						if not l_feature.postcondition.is_empty then
							across split_clauses (l_feature.postcondition) as clause loop
								l_contracts.extend ([{STRING} "ensure", clause.twin, ancestor.twin])
							end
						end
					end
				end
			end

			-- Format output
			if not l_contracts.is_empty then
				Result.append ("**Flat Contracts:**%N")
				Result.append ("%N*Preconditions:*%N")
				across l_contracts as c loop
					if c.kind.same_string ("require") then
						Result.append ("  - `" + c.text + "` ← *" + c.origin + "*%N")
					end
				end
				Result.append ("%N*Postconditions:*%N")
				across l_contracts as c loop
					if c.kind.same_string ("ensure") then
						Result.append ("  - `" + c.text + "` ← *" + c.origin + "*%N")
					end
				end
			end

			log_debug ("Contract lens for " + a_class_name + "." + a_feature_name + ": " + l_contracts.count.out + " clauses")
		ensure
			result_not_void: Result /= Void
		end

	get_feature_origin (a_class_name, a_feature_name: STRING): detachable STRING
			-- Find which ancestor class originally defined this feature
		require
			class_name_not_empty: a_class_name /= Void and then not a_class_name.is_empty
			feature_name_not_empty: a_feature_name /= Void and then not a_feature_name.is_empty
		local
			l_ancestors: ARRAYED_LIST [STRING]
			l_class_path: detachable STRING
			l_feature: detachable EIFFEL_FEATURE_NODE
		do
			-- Get inheritance chain
			l_ancestors := eifgens_parser.ancestor_chain (a_class_name)

			-- Walk from root to find first definition
			across l_ancestors.new_cursor.reversed as ancestor until Result /= Void loop
				l_class_path := find_class_file (ancestor)
				if attached l_class_path as path then
					l_feature := find_feature_in_file (path, a_feature_name)
					if attached l_feature then
						Result := ancestor.twin
					end
				end
			end
		end

feature {NONE} -- Implementation

	find_class_file (a_class_name: STRING): detachable STRING
			-- Find file path for class (workspace or compiled)
		require
			class_name_not_empty: not a_class_name.is_empty
		local
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
		do
			l_class_info := symbol_db.find_class (a_class_name)
			if attached l_class_info then
				Result := l_class_info.file_path
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

	split_clauses (a_contract_text: STRING): ARRAYED_LIST [STRING]
			-- Split contract text into individual clauses
			-- Handles "tag: expression" and bare expressions
		require
			text_not_void: a_contract_text /= Void
		local
			l_lines: LIST [STRING]
			l_line: STRING
		do
			create Result.make (5)

			-- Split by newlines and filter empty/comment lines
			l_lines := a_contract_text.split ('%N')
			across l_lines as line loop
				l_line := line.twin
				l_line.left_adjust
				l_line.right_adjust
				if not l_line.is_empty and then not l_line.starts_with ("--") then
					Result.extend (l_line)
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	log_debug (a_msg: STRING)
			-- Log debug message
		do
			logger.log_debug (a_msg)
		end

end
