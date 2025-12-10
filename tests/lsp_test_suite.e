note
	description: "Test suite for simple_lsp"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_TEST_SUITE

inherit
	EQA_TEST_SET

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

			assert ("method set", l_msg.method.same_string ("textDocument/definition"))
			assert ("id set", l_msg.id = 1)
			assert ("is request", l_msg.is_request)
			assert ("not notification", not l_msg.is_notification)
		end

	test_notification_message
			-- Test notification (no id)
		local
			l_msg: LSP_MESSAGE
		do
			create l_msg.make ("initialized", 0, Void)

			assert ("is notification", l_msg.is_notification)
			assert ("not request", not l_msg.is_request)
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

			assert ("method parsed", l_msg.method.same_string ("initialize"))
			assert ("id parsed", l_msg.id = 1)
			assert ("params parsed", attached l_msg.params)
		end

	test_symbol_database_creation
			-- Test symbol database creation
		local
			l_db: LSP_SYMBOL_DATABASE
			l_path: STRING
		do
			l_path := "test_symbols.db"
			create l_db.make (l_path)

			assert ("db created", l_db /= Void)
			assert ("path set", l_db.db_path.same_string (l_path))

			l_db.close
			-- Clean up test file
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

			assert ("class found", attached l_result)
			if attached l_result as r then
				assert ("file path correct", r.file_path.same_string ("/path/to/my_class.e"))
				assert ("line correct", r.line = 7)
				assert ("column correct", r.column = 1)
			end

			-- Test case insensitivity
			l_result := l_db.find_class ("my_class")
			assert ("case insensitive", attached l_result)

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
			assert ("class id found", l_class_id > 0)

			l_db.add_feature (l_class_id, "my_feature", "procedure", 15, 2)
			l_result := l_db.find_feature ("FEATURE_TEST", "my_feature")

			assert ("feature found", attached l_result)
			if attached l_result as r then
				assert ("feature line", r.line = 15)
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
