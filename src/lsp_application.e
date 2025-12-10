note
	description: "Main application entry point for Eiffel LSP server"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_APPLICATION

create
	make

feature {NONE} -- Initialization

	make
			-- Run LSP server
		local
			l_server: LSP_SERVER
			l_root: STRING
		do
			-- Get workspace root from command line or use current directory
			if argument_count >= 1 then
				l_root := argument (1)
			else
				l_root := "."
			end

			create l_server.make (l_root)
			l_server.run
		end

feature -- Arguments

	argument_count: INTEGER
			-- Number of command line arguments
		external
			"C inline"
		alias
			"return eif_argc - 1;"
		end

	argument (n: INTEGER): STRING
			-- Get command line argument at position n (1-based)
		require
			valid_index: n >= 1 and n <= argument_count
		local
			l_ptr: POINTER
			l_c_string: C_STRING
		do
			l_ptr := c_argument (n)
			create l_c_string.make_by_pointer (l_ptr)
			Result := l_c_string.string
		end

feature {NONE} -- C externals

	c_argument (n: INTEGER): POINTER
			-- Get C argv[n]
		external
			"C inline"
		alias
			"return eif_argv[$n];"
		end

end
