note
	description: "ECF target definition"
	date: "$Date$"
	revision: "$Revision$"

class
	ECF_TARGET

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize target
		do
			create name.make_empty
			create extends.make_empty
			create root_class.make_empty
			create root_feature.make_empty
		end

feature -- Access

	name: STRING_32
			-- Target name

	extends: STRING_32
			-- Parent target name (if any)

	root_class: STRING_32
			-- Root class name (if specified)

	root_feature: STRING_32
			-- Root feature name (if specified)

	all_classes: BOOLEAN
			-- Is this a library target with all_classes="true"?

feature -- Status

	is_library_target: BOOLEAN
			-- Is this a library target (no specific root)?
		do
			Result := all_classes and root_class.is_empty
		end

	has_parent: BOOLEAN
			-- Does this target extend another?
		do
			Result := not extends.is_empty
		end

end
