note
	description: "Test application for SIMPLE_LSP"
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the tests.
		do
			create tests
			print ("Running SIMPLE_LSP tests...%N%N")

			passed := 0
			failed := 0

			run_test (agent tests.test_message_creation, "test_message_creation")
			run_test (agent tests.test_notification_message, "test_notification_message")
			run_test (agent tests.test_message_from_json, "test_message_from_json")
			run_test (agent tests.test_symbol_database_creation, "test_symbol_database_creation")
			run_test (agent tests.test_add_and_find_class, "test_add_and_find_class")
			run_test (agent tests.test_add_and_find_feature, "test_add_and_find_feature")
			run_test (agent tests.test_file_uris_round_trip, "test_file_uris_round_trip")
			run_test (agent tests.test_definition_uris_for_posix_and_windows_paths, "test_definition_uris_for_posix_and_windows_paths")
			run_test (agent tests.test_rename_uris_round_trip_a_real_file, "test_rename_uris_round_trip_a_real_file")

			print ("%N========================%N")
			print ("Results: " + passed.out + " passed, " + failed.out + " failed%N")

			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Implementation

	tests: LIB_TESTS

	passed: INTEGER
	failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			print ("  FAIL: " + a_name + "%N")
			if attached (create {EXCEPTION_MANAGER}).last_exception as l_e and then attached l_e.description as l_why then
				print ("        " + {UTF_CONVERTER}.string_32_to_utf_8_string_8 (l_why.to_string_32) + "%N")
			end
			failed := failed + 1
			l_retried := True
			retry
		end

end
