note
	description: "ECF cluster (source directory) definition"
	date: "$Date$"
	revision: "$Revision$"

class
	ECF_CLUSTER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize cluster
		do
			create name.make_empty
			create location.make_empty
			create resolved_path.make_empty
			create target_name.make_empty
		end

feature -- Access

	name: STRING_32 assign set_name
			-- Cluster name

	location: STRING_32 assign set_location
			-- Original location from ECF (may be relative like .\src\)

	resolved_path: STRING_32 assign set_resolved_path
			-- Resolved absolute path

	target_name: STRING_32 assign set_target_name
			-- Target this cluster belongs to

	is_recursive: BOOLEAN assign set_is_recursive
			-- Should subdirectories be included?

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

	set_is_recursive (a_is_recursive: BOOLEAN)
			-- Set `is_recursive'.
		do
			is_recursive := a_is_recursive
		ensure
			is_recursive_set: is_recursive = a_is_recursive
		end

feature -- Status

	is_relative: BOOLEAN
			-- Is location a relative path?
		do
			Result := location.starts_with (".\") or
				location.starts_with ("./") or
				(not location.starts_with ("$") and not location.starts_with ("/") and
				 (location.count < 2 or else location[2] /= ':'))
		end

end
