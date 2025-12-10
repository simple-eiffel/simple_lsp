note
	description: "Handler for LSP completion operations"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_COMPLETION_HANDLER

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

feature {NONE} -- Implementation

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
