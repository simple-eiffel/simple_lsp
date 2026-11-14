note
	description: "Tests for SIMPLE_LSP"
	author: "Larry Rix"
	testing: "covers"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Tests

	test_message_creation
			-- Test LSP message creation
		local
			l_msg: LSP_MESSAGE
			l_params: SIMPLE_JSON_OBJECT
		do
			create l_params.make
			l_params.put_string ("test_uri", "textDocument/uri").do_nothing
			create l_msg.make ("textDocument/definition", 1, l_params)

			assert_strings_equal ("method set", "textDocument/definition", l_msg.method)
			assert_integers_equal ("id set", 1, l_msg.id)
			assert_true ("is request", l_msg.is_request)
			assert_false ("not notification", l_msg.is_notification)
		end

	test_notification_message
			-- Test notification (no id)
		local
			l_msg: LSP_MESSAGE
		do
			create l_msg.make ("initialized", 0, Void)

			assert_true ("is notification", l_msg.is_notification)
			assert_false ("not request", l_msg.is_request)
		end

	test_message_from_json
			-- Test parsing message from JSON
		local
			l_msg: LSP_MESSAGE
			l_json: SIMPLE_JSON_OBJECT
			l_params: SIMPLE_JSON_OBJECT
		do
			create l_json.make
			l_json.put_string ("initialize", "method").do_nothing
			l_json.put_integer (1, "id").do_nothing

			create l_params.make
			l_params.put_string ("/workspace/project", "rootPath").do_nothing
			l_json.put_object (l_params, "params").do_nothing

			create l_msg.make_from_json (l_json)

			assert_strings_equal ("method parsed", "initialize", l_msg.method)
			assert_integers_equal ("id parsed", 1, l_msg.id)
			assert_attached ("params parsed", l_msg.params)
		end

	test_symbol_database_creation
			-- Test symbol database creation
		local
			l_db: LSP_SYMBOL_DATABASE
			l_path: STRING
		do
			l_path := "test_symbols.db"
			create l_db.make (l_path)

			assert_attached ("db created", l_db)
			assert_strings_equal ("path set", l_path, l_db.db_path)

			l_db.close
			delete_test_file (l_path)
		end

	test_add_and_find_class
			-- Test adding and finding a class
		local
			l_db: LSP_SYMBOL_DATABASE
			l_path: STRING
			l_result: detachable TUPLE [id: INTEGER; file_path: STRING; line, column: INTEGER]
		do
			l_path := "test_symbols2.db"
			create l_db.make (l_path)

			l_db.add_class ("MY_CLASS", "/path/to/my_class.e", 7, 1, 0)
			l_result := l_db.find_class ("MY_CLASS")

			assert_attached ("class found", l_result)
			if attached l_result as r then
				assert_strings_equal ("file path correct", "/path/to/my_class.e", r.file_path)
				assert_integers_equal ("line correct", 7, r.line)
				assert_integers_equal ("column correct", 1, r.column)
			end

			l_result := l_db.find_class ("my_class")
			assert_attached ("case insensitive", l_result)

			l_db.close
			delete_test_file (l_path)
		end

	test_add_and_find_feature
			-- Test adding and finding features
		local
			l_db: LSP_SYMBOL_DATABASE
			l_path: STRING
			l_class_id: INTEGER
			l_result: detachable TUPLE [file_path: STRING; line, column: INTEGER; signature, comment: STRING]
		do
			l_path := "test_symbols3.db"
			create l_db.make (l_path)

			l_db.add_class ("FEATURE_TEST", "/path/to/feature_test.e", 7, 1, 0)
			l_class_id := l_db.class_id ("FEATURE_TEST")
			assert_true ("class id found", l_class_id > 0)

			l_db.add_feature (l_class_id, "my_feature", "procedure", 15, 2)
			l_result := l_db.find_feature ("FEATURE_TEST", "my_feature")

			assert_attached ("feature found", l_result)
			if attached l_result as r then
				assert_integers_equal ("feature line", 15, r.line)
			end

			l_db.close
			delete_test_file (l_path)
		end

feature -- Tests: file URIs

	test_file_uris_round_trip
			-- Paths and file:// URIs turn into each other the same way for every handler: a POSIX
			-- path gives three slashes, never four (go-to-definition and rename on macOS and Linux
			-- built file:////Users/...), a Windows path's backslashes become slashes, and an
			-- editor's encoded drive (file:///c%3A/...) comes back as the path.
		local
			u: LSP_FILE_URI
		do
			create u
			assert_strings_equal ("posix", "file:///Users/me/proj/a.e", u.from_path ("/Users/me/proj/a.e"))
			assert_strings_equal ("posix back", "/Users/me/proj/a.e", u.to_path ("file:///Users/me/proj/a.e"))
			assert_strings_equal ("windows", "file:///C:/proj/src/a.e", u.from_path ("C:\proj\src\a.e"))
			assert_strings_equal ("windows back", "C:/proj/src/a.e", u.to_path ("file:///C:/proj/src/a.e"))
			assert_strings_equal ("editor's drive", "c:/proj/a.e", u.to_path ("file:///c%%3A/proj/a.e"))
			assert_strings_equal ("spaces and #", "file:///Users/me/my%%20proj/c%%23/a.e", u.from_path ("/Users/me/my proj/c#/a.e"))
			assert_strings_equal ("spaces and # back", "/Users/me/my proj/c#/a.e", u.to_path (u.from_path ("/Users/me/my proj/c#/a.e")))
			assert_strings_equal ("a percent survives", "/tmp/100%%/a.e", u.to_path (u.from_path ("/tmp/100%%/a.e")))
		end

	test_definition_uris_for_posix_and_windows_paths
			-- Go-to-definition answers a class's location with the URI of its path, for a POSIX
			-- path and a Windows path alike.
		local
			l_db: LSP_SYMBOL_DATABASE
			l_logger: LSP_LOGGER
			l_handler: LSP_NAVIGATION_HANDLER
		do
			create l_db.make ("test_uri_symbols.db")
			create l_logger.make ("test_uri.log")
			l_db.add_class ("POSIX_WIDGET", "/home/me/proj/posix_widget.e", 3, 1, 0)
			l_db.add_class ("WINDOWS_WIDGET", "C:\proj\src\windows_widget.e", 5, 1, 0)
			create l_handler.make (l_db, l_logger, create {EIFFEL_PARSER}.make)
			if attached l_handler.find_definition ("POSIX_WIDGET") as l_location then
				assert_strings_equal ("posix uri", "file:///home/me/proj/posix_widget.e", uri_of (l_location))
			else
				assert ("posix class found", False)
			end
			if attached l_handler.find_definition ("WINDOWS_WIDGET") as l_location then
				assert_strings_equal ("windows uri", "file:///C:/proj/src/windows_widget.e", uri_of (l_location))
			else
				assert ("windows class found", False)
			end
			l_db.close
			delete_test_file ("test_uri_symbols.db")
			delete_test_file ("test_uri.log")
		end

	test_rename_uris_round_trip_a_real_file
			-- Rename edits a real file under this platform's own path: every URI in the edit is a
			-- proper file URI (never four slashes), and the file's own turns back into its path.
		local
			l_db: LSP_SYMBOL_DATABASE
			l_logger: LSP_LOGGER
			l_handler: LSP_RENAME_HANDLER
			l_dir: DIRECTORY
			l_file: PLAIN_TEXT_FILE
			l_path, l_json, l_uri: STRING
			u: LSP_FILE_URI
		do
			create u
			create l_dir.make_with_path ((create {EXECUTION_ENVIRONMENT}).current_working_path.extended ("rename uri test"))
			if not l_dir.exists then
				l_dir.recursive_create_dir
			end
			l_path := l_dir.path.extended ("old_gadget.e").name.to_string_8
			create l_file.make_create_read_write (l_path)
			l_file.put_string ("class%N%TOLD_GADGET%Nend%N")
			l_file.close
			create l_db.make ("test_rename_symbols.db")
			create l_logger.make ("test_rename.log")
			l_db.add_class ("OLD_GADGET", l_path, 2, 2, 0)
			create l_handler.make (l_db, l_logger)
			if attached l_handler.compute_workspace_edit ("OLD_GADGET", "NEW_GADGET") as l_edit then
				l_json := l_edit.as_json
				l_json.replace_substring_all ("\/", "/")
				assert ("no four-slash uri: " + l_json, not l_json.has_substring ("file:////"))
				l_uri := u.from_path (l_path)
				assert ("the file's own uri: " + l_uri, l_json.has_substring (l_uri))
				assert_strings_equal ("and back", l_path.twin, u.to_path (l_uri).twin)
			else
				assert ("an edit", False)
			end
			l_db.close
			delete_test_file ("test_rename_symbols.db")
			delete_test_file ("test_rename.log")
			delete_test_file (l_path)
			l_dir.delete
		end

feature {NONE} -- Implementation

	uri_of (a_location: SIMPLE_JSON_OBJECT): STRING
			-- The "uri" of an LSP location.
		do
			if attached a_location.string_item ("uri") as l_uri then
				Result := l_uri.to_string_8
			else
				Result := "(none)"
			end
		end

	delete_test_file (a_path: STRING)
			-- Delete test file if exists
		local
			l_file: RAW_FILE
		do
			create l_file.make_with_name (a_path)
			if l_file.exists then
				l_file.delete
			end
		end

end
