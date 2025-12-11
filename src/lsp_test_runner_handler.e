note
	description: "Handler for test discovery and execution - AutoTest replacement for VS Code"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_TEST_RUNNER_HANDLER

create
	make

feature {NONE} -- Initialization

	make (a_db: LSP_SYMBOL_DATABASE; a_logger: LSP_LOGGER; a_workspace: STRING)
			-- Create handler with database, logger, and workspace root
		require
			db_not_void: a_db /= Void
			logger_not_void: a_logger /= Void
			workspace_not_empty: a_workspace /= Void and then not a_workspace.is_empty
		do
			symbol_db := a_db
			logger := a_logger
			workspace_root := a_workspace
			create parser.make
		ensure
			db_set: symbol_db = a_db
			logger_set: logger = a_logger
			workspace_set: workspace_root = a_workspace
		end

feature -- Access

	symbol_db: LSP_SYMBOL_DATABASE
			-- Symbol database

	logger: LSP_LOGGER
			-- Logger for debugging

	workspace_root: STRING
			-- Workspace root directory

	parser: EIFFEL_PARSER
			-- Eiffel source parser

feature -- Test Discovery

	discover_tests: SIMPLE_JSON_ARRAY
			-- Discover all test classes and methods in workspace
			-- Returns array of test items suitable for VS Code Test API
		local
			l_test_classes: ARRAYED_LIST [TUPLE [class_name: STRING; file_path: STRING]]
			l_item: SIMPLE_JSON_OBJECT
			l_children: SIMPLE_JSON_ARRAY
		do
			create Result.make
			l_test_classes := find_test_classes

			across l_test_classes as tc loop
				l_item := create_test_class_item (tc.class_name, tc.file_path)
				l_children := discover_test_methods (tc.class_name, tc.file_path)
				l_item.put_array (l_children, "children").do_nothing
				Result.add_object (l_item).do_nothing
			end

			log_debug ("Discovered " + l_test_classes.count.out + " test classes")
		ensure
			result_not_void: Result /= Void
		end

	discover_test_methods (a_class_name, a_file_path: STRING): SIMPLE_JSON_ARRAY
			-- Discover test methods in a test class
		require
			class_name_not_empty: not a_class_name.is_empty
			file_path_not_empty: not a_file_path.is_empty
		local
			l_methods: ARRAYED_LIST [TUPLE [name: STRING; line: INTEGER]]
			l_item: SIMPLE_JSON_OBJECT
		do
			create Result.make
			l_methods := find_test_methods (a_file_path)

			across l_methods as m loop
				l_item := create_test_method_item (a_class_name, m.name, a_file_path, m.line)
				Result.add_object (l_item).do_nothing
			end
		ensure
			result_not_void: Result /= Void
		end

feature -- Test Execution

	run_test (a_class_name, a_test_name: STRING): SIMPLE_JSON_OBJECT
			-- Run a single test and return result
		require
			class_name_not_empty: not a_class_name.is_empty
			test_name_not_empty: not a_test_name.is_empty
		local
			l_ecf_path: STRING
		do
			create Result.make
			Result.put_string (a_class_name + "." + a_test_name, "id").do_nothing

			-- Find test target ECF
			l_ecf_path := find_test_ecf
			if l_ecf_path.is_empty then
				Result.put_string ("error", "outcome").do_nothing
				Result.put_string ("No test target found (ECF with _tests suffix)", "message").do_nothing
			else
				-- For now, return "pending" - actual execution requires process management
				Result.put_string ("pending", "outcome").do_nothing
				Result.put_string ("Test execution pending - use terminal to run tests", "message").do_nothing
			end

			log_debug ("Run test: " + a_class_name + "." + a_test_name)
		ensure
			result_not_void: Result /= Void
		end

	run_all_tests: SIMPLE_JSON_ARRAY
			-- Run all discovered tests and return results
		local
			l_test_classes: ARRAYED_LIST [TUPLE [class_name: STRING; file_path: STRING]]
			l_methods: ARRAYED_LIST [TUPLE [name: STRING; line: INTEGER]]
			l_result: SIMPLE_JSON_OBJECT
		do
			create Result.make
			l_test_classes := find_test_classes

			across l_test_classes as tc loop
				l_methods := find_test_methods (tc.file_path)
				across l_methods as m loop
					l_result := run_test (tc.class_name, m.name)
					Result.add_object (l_result).do_nothing
				end
			end

			log_debug ("Ran " + Result.count.out + " tests")
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	find_test_classes: ARRAYED_LIST [TUPLE [class_name: STRING; file_path: STRING]]
			-- Find all test classes (classes inheriting from EQA_TEST_SET or TEST_SET)
		local
			l_file: RAW_FILE
			l_content: STRING
			l_class_info: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
		do
			create Result.make (20)

			-- Search all classes in symbol database
			across symbol_db.all_class_names as class_name loop
				l_class_info := symbol_db.find_class (class_name)
				if attached l_class_info then
					-- Check if file contains test inheritance
					create l_file.make_with_name (l_class_info.file_path)
					if l_file.exists and then l_file.is_readable then
						l_file.open_read
						l_file.read_stream (l_file.count.min (50000))
						l_content := l_file.last_string
						l_file.close

						if content_is_test_class (l_content) then
							Result.extend ([class_name.twin, l_class_info.file_path.twin])
						end
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	content_is_test_class (a_content: STRING): BOOLEAN
			-- Check if content indicates a test class
		require
			content_not_void: a_content /= Void
		do
			-- Look for common test base class inheritance
			Result := a_content.has_substring ("EQA_TEST_SET") or else
			          a_content.has_substring ("TEST_SET") or else
			          a_content.has_substring ("EQA_SPEC") or else
			          a_content.has_substring ("_TEST") -- Convention: classes ending in _TEST
		end

	find_test_methods (a_file_path: STRING): ARRAYED_LIST [TUPLE [name: STRING; line: INTEGER]]
			-- Find test methods in file (methods starting with "test_")
		require
			file_path_not_empty: not a_file_path.is_empty
		local
			l_ast: EIFFEL_AST
		do
			create Result.make (20)
			l_ast := parser.parse_file (a_file_path)

			across l_ast.classes as cls loop
				across cls.features as feat loop
					-- Test methods by convention start with "test_"
					if feat.name.as_lower.starts_with ("test_") then
						Result.extend ([feat.name.twin, feat.line])
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	find_test_ecf: STRING
			-- Find ECF file for test target
		local
			l_dir: DIRECTORY
			l_entries: ARRAYED_LIST [PATH]
		do
			create Result.make_empty
			create l_dir.make_with_name (workspace_root)

			if l_dir.exists then
				l_entries := l_dir.entries
				across l_entries as entry loop
					if entry.name.as_string_8.ends_with ("_tests.ecf") then
						Result := workspace_root + "/" + entry.name.as_string_8
					end
				end
			end
		ensure
			result_not_void: Result /= Void
		end

	create_test_class_item (a_class_name, a_file_path: STRING): SIMPLE_JSON_OBJECT
			-- Create test item for a test class
		require
			class_name_not_empty: not a_class_name.is_empty
			file_path_not_empty: not a_file_path.is_empty
		do
			create Result.make
			Result.put_string (a_class_name, "id").do_nothing
			Result.put_string (a_class_name, "label").do_nothing
			Result.put_string ("class", "type").do_nothing
			Result.put_string (path_to_uri (a_file_path), "uri").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	create_test_method_item (a_class_name, a_method_name, a_file_path: STRING; a_line: INTEGER): SIMPLE_JSON_OBJECT
			-- Create test item for a test method
		require
			class_name_not_empty: not a_class_name.is_empty
			method_name_not_empty: not a_method_name.is_empty
			file_path_not_empty: not a_file_path.is_empty
		local
			l_range: SIMPLE_JSON_OBJECT
		do
			create Result.make
			Result.put_string (a_class_name + "." + a_method_name, "id").do_nothing
			Result.put_string (a_method_name, "label").do_nothing
			Result.put_string ("method", "type").do_nothing
			Result.put_string (path_to_uri (a_file_path), "uri").do_nothing
			l_range := make_range (a_line - 1, 0, a_line - 1, a_method_name.count)
			Result.put_object (l_range, "range").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	make_range (a_start_line, a_start_char, a_end_line, a_end_char: INTEGER): SIMPLE_JSON_OBJECT
			-- Create LSP range object
		local
			l_start, l_end: SIMPLE_JSON_OBJECT
		do
			create Result.make
			create l_start.make
			l_start.put_integer (a_start_line, "line").do_nothing
			l_start.put_integer (a_start_char, "character").do_nothing
			create l_end.make
			l_end.put_integer (a_end_line, "line").do_nothing
			l_end.put_integer (a_end_char, "character").do_nothing
			Result.put_object (l_start, "start").do_nothing
			Result.put_object (l_end, "end").do_nothing
		ensure
			result_not_void: Result /= Void
		end

	path_to_uri (a_path: STRING): STRING
			-- Convert file path to URI
		require
			path_not_void: a_path /= Void
		do
			create Result.make_from_string ("file:///")
			Result.append (a_path.twin)
			Result.replace_substring_all ("\", "/")
		ensure
			result_not_void: Result /= Void
		end

	log_debug (a_msg: STRING)
			-- Log debug message
		do
			logger.log_debug (a_msg)
		end

end
