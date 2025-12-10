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

	name: STRING_32
			-- Cluster name

	location: STRING_32
			-- Original location from ECF (may be relative like .\src\)

	resolved_path: STRING_32
			-- Resolved absolute path

	target_name: STRING_32
			-- Target this cluster belongs to

	is_recursive: BOOLEAN
			-- Should subdirectories be included?

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
