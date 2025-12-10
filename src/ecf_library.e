note
	description: "ECF library reference"
	date: "$Date$"
	revision: "$Revision$"

class
	ECF_LIBRARY

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize library reference
		do
			create name.make_empty
			create location.make_empty
			create resolved_path.make_empty
			create target_name.make_empty
		end

feature -- Access

	name: STRING_32
			-- Library name (alias)

	location: STRING_32
			-- Original location from ECF (may include $ENV_VAR)

	resolved_path: STRING_32
			-- Resolved path with environment variables expanded

	target_name: STRING_32
			-- Target this library belongs to

	is_readonly: BOOLEAN
			-- Is this library read-only?

feature -- Status

	is_stdlib: BOOLEAN
			-- Is this a standard library (from $ISE_LIBRARY)?
		do
			Result := location.has_substring ("$ISE_LIBRARY")
		end

	is_simple_library: BOOLEAN
			-- Is this a simple_* ecosystem library?
		do
			Result := location.has_substring ("$SIMPLE_") or
				name.starts_with ("simple_")
		end

end
