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

	name: STRING_32 assign set_name
			-- Target name

	extends: STRING_32 assign set_extends
			-- Parent target name (if any)

	root_class: STRING_32 assign set_root_class
			-- Root class name (if specified)

	root_feature: STRING_32 assign set_root_feature
			-- Root feature name (if specified)

	all_classes: BOOLEAN assign set_all_classes
			-- Is this a library target with all_classes="true"?

feature -- Element change

	set_name (a_name: STRING_32)
			-- Set `name'.
		do
			name := a_name
		ensure
			name_set: name = a_name
		end

	set_extends (a_extends: STRING_32)
			-- Set `extends'.
		do
			extends := a_extends
		ensure
			extends_set: extends = a_extends
		end

	set_root_class (a_root_class: STRING_32)
			-- Set `root_class'.
		do
			root_class := a_root_class
		ensure
			root_class_set: root_class = a_root_class
		end

	set_root_feature (a_root_feature: STRING_32)
			-- Set `root_feature'.
		do
			root_feature := a_root_feature
		ensure
			root_feature_set: root_feature = a_root_feature
		end

	set_all_classes (a_all_classes: BOOLEAN)
			-- Set `all_classes'.
		do
			all_classes := a_all_classes
		ensure
			all_classes_set: all_classes = a_all_classes
		end

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
