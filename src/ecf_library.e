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

	name: STRING_32 assign set_name
			-- Library name (alias)

	location: STRING_32 assign set_location
			-- Original location from ECF (may include $ENV_VAR)

	resolved_path: STRING_32 assign set_resolved_path
			-- Resolved path with environment variables expanded

	target_name: STRING_32 assign set_target_name
			-- Target this library belongs to

	is_readonly: BOOLEAN assign set_is_readonly
			-- Is this library read-only?

feature -- Element change

	set_name (a_name: STRING_32)
			-- Set `name'.
		do
			name := a_name
		ensure
			name_set: name = a_name
		end

	set_location (a_location: STRING_32)
			-- Set `location'.
		do
			location := a_location
		ensure
			location_set: location = a_location
		end

	set_resolved_path (a_resolved_path: STRING_32)
			-- Set `resolved_path'.
		do
			resolved_path := a_resolved_path
		ensure
			resolved_path_set: resolved_path = a_resolved_path
		end

	set_target_name (a_target_name: STRING_32)
			-- Set `target_name'.
		do
			target_name := a_target_name
		ensure
			target_name_set: target_name = a_target_name
		end

	set_is_readonly (a_is_readonly: BOOLEAN)
			-- Set `is_readonly'.
		do
			is_readonly := a_is_readonly
		ensure
			is_readonly_set: is_readonly = a_is_readonly
		end

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
