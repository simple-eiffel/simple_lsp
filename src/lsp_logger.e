note
	description: "[
		Logger for LSP server - writes timestamped messages to log file.
		Essential for debugging VS Code integration since stdout is used for LSP protocol.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_LOGGER

create
	make

feature {NONE} -- Initialization

	make (a_log_path: STRING)
			-- Create logger writing to file
		require
			path_not_void: a_log_path /= Void
			path_not_empty: not a_log_path.is_empty
		do
			log_path := a_log_path
			log_level := Level_debug -- Verbose by default for troubleshooting
			create log_file.make_open_append (a_log_path)
			log_raw ("=== LSP Logger Started ===")
			log_raw ("Log level: DEBUG")
		ensure
			path_set: log_path = a_log_path
			file_open: log_file.is_open_write
		end

feature -- Access

	log_path: STRING
			-- Path to log file

	log_level: INTEGER
			-- Current log level

feature -- Log Levels

	Level_error: INTEGER = 1
	Level_warning: INTEGER = 2
	Level_info: INTEGER = 3
	Level_debug: INTEGER = 4

feature -- Logging

	log_error (a_message: STRING)
			-- Log error message
		require
			message_not_void: a_message /= Void
		do
			if log_level >= Level_error then
				log_with_level ("ERROR", a_message)
			end
		end

	log_warning (a_message: STRING)
			-- Log warning message
		require
			message_not_void: a_message /= Void
		do
			if log_level >= Level_warning then
				log_with_level ("WARN ", a_message)
			end
		end

	log_info (a_message: STRING)
			-- Log info message
		require
			message_not_void: a_message /= Void
		do
			if log_level >= Level_info then
				log_with_level ("INFO ", a_message)
			end
		end

	log_debug (a_message: STRING)
			-- Log debug message
		require
			message_not_void: a_message /= Void
		do
			if log_level >= Level_debug then
				log_with_level ("DEBUG", a_message)
			end
		end

feature -- Configuration

	set_level_error
			-- Only log errors
		do
			log_level := Level_error
			log_info ("Log level changed to ERROR")
		ensure
			level_set: log_level = Level_error
		end

	set_level_warning
			-- Log warnings and above
		do
			log_level := Level_warning
			log_info ("Log level changed to WARNING")
		ensure
			level_set: log_level = Level_warning
		end

	set_level_info
			-- Log info and above
		do
			log_level := Level_info
			log_info ("Log level changed to INFO")
		ensure
			level_set: log_level = Level_info
		end

	set_level_debug
			-- Log everything
		do
			log_level := Level_debug
			log_info ("Log level changed to DEBUG")
		ensure
			level_set: log_level = Level_debug
		end

feature -- Lifecycle

	close
			-- Close log file
		do
			log_raw ("=== LSP Logger Closed ===")
			if log_file.is_open_write then
				log_file.close
			end
		ensure
			closed: not log_file.is_open_write
		end

	flush
			-- Flush log buffer
		do
			if log_file.is_open_write then
				log_file.flush
			end
		end

feature {NONE} -- Implementation

	log_file: PLAIN_TEXT_FILE
			-- Log file handle

	log_with_level (a_level, a_message: STRING)
			-- Write log entry with timestamp and level
		require
			level_not_void: a_level /= Void
			message_not_void: a_message /= Void
		local
			l_timestamp: STRING
			l_entry: STRING
		do
			l_timestamp := current_timestamp
			create l_entry.make (100)
			l_entry.append (l_timestamp)
			l_entry.append (" [")
			l_entry.append (a_level)
			l_entry.append ("] ")
			l_entry.append (a_message)
			log_raw (l_entry)
		end

	log_raw (a_line: STRING)
			-- Write raw line to log
		require
			line_not_void: a_line /= Void
		do
			if log_file.is_open_write then
				log_file.put_string (a_line)
				log_file.put_new_line
				log_file.flush
			end
		end

	current_timestamp: STRING
			-- Current timestamp in ISO format
		local
			l_time: TIME
			l_date: DATE
		do
			create l_date.make_now
			create l_time.make_now
			create Result.make (25)
			Result.append (l_date.year.out)
			Result.append ("-")
			if l_date.month < 10 then Result.append ("0") end
			Result.append (l_date.month.out)
			Result.append ("-")
			if l_date.day < 10 then Result.append ("0") end
			Result.append (l_date.day.out)
			Result.append ("T")
			if l_time.hour < 10 then Result.append ("0") end
			Result.append (l_time.hour.out)
			Result.append (":")
			if l_time.minute < 10 then Result.append ("0") end
			Result.append (l_time.minute.out)
			Result.append (":")
			if l_time.second < 10 then Result.append ("0") end
			Result.append (l_time.second.out)
		ensure
			result_not_void: Result /= Void
			result_not_empty: not Result.is_empty
		end

invariant
	path_not_void: log_path /= Void
	path_not_empty: not log_path.is_empty
	log_file_exists: log_file /= Void
	valid_level: log_level >= Level_error and log_level <= Level_debug

end
