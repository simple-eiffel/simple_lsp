note
	description: "Handler for LSP navigation operations (definition, references, symbols)"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_NAVIGATION_HANDLER

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

	-- TODO: Move definition, references, symbols handling code here from LSP_SERVER

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
