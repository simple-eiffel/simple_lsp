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

feature {NONE} -- Implementation

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
