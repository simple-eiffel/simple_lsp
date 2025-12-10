note
	description: "[
		ECF (Eiffel Configuration File) parser for simple_lsp.

		Extracts:
		- System name and library target
		- Targets with their root classes and extends relationships
		- Library references with resolved paths
		- Cluster definitions with source locations
		- Environment variable expansion ($VAR syntax)

		Usage:
			create parser.make
			parser.parse_file ("/path/to/project.ecf")
			if parser.is_valid then
				across parser.libraries as lib loop
					print (lib.name + " -> " + lib.resolved_path)
				end
			end
	]"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_ECF_PARSER

create
	make

feature {NONE} -- Initialization

	make
			-- Create ECF parser
		do
			create xml.make
			create system_name.make_empty
			create library_target.make_empty
			create targets.make (5)
			create libraries.make (20)
			create clusters.make (10)
			create last_errors.make (5)
			create ecf_directory.make_empty
		end

feature -- Access

	system_name: STRING_32
			-- Name of the system

	library_target: STRING_32
			-- Library target name (if this ECF can be used as a library)

	targets: ARRAYED_LIST [ECF_TARGET]
			-- All targets defined in the ECF

	libraries: ARRAYED_LIST [ECF_LIBRARY]
			-- All library references

	clusters: ARRAYED_LIST [ECF_CLUSTER]
			-- All cluster definitions

	is_valid: BOOLEAN
			-- Was last parse successful?

	last_errors: ARRAYED_LIST [STRING_32]
			-- Errors from last parse

	ecf_path: detachable STRING_32
			-- Path to the parsed ECF file

	ecf_directory: STRING_32
			-- Directory containing the ECF file

feature -- Parsing

	parse_file (a_path: STRING_32)
			-- Parse ECF file at `a_path'
		require
			path_not_void: a_path /= Void
			path_not_empty: not a_path.is_empty
		local
			l_doc: SIMPLE_XML_DOCUMENT
		do
			reset
			ecf_path := a_path
			ecf_directory := directory_of (a_path)

			l_doc := xml.parse_file (a_path)
			if l_doc.is_valid then
				if attached l_doc.root as l_root then
					parse_system (l_root)
					is_valid := last_errors.is_empty
				else
					last_errors.extend ("ECF has no root element")
					is_valid := False
				end
			else
				last_errors.extend ("Failed to parse ECF: " + l_doc.error_message)
				is_valid := False
			end
		end

	parse_string (a_xml: STRING_32)
			-- Parse ECF from XML string
		require
			xml_not_void: a_xml /= Void
		local
			l_doc: SIMPLE_XML_DOCUMENT
		do
			reset
			l_doc := xml.parse (a_xml)
			if l_doc.is_valid then
				if attached l_doc.root as l_root then
					parse_system (l_root)
					is_valid := last_errors.is_empty
				else
					last_errors.extend ("ECF has no root element")
					is_valid := False
				end
			else
				last_errors.extend ("Failed to parse ECF: " + l_doc.error_message)
				is_valid := False
			end
		end

feature {NONE} -- Parsing Implementation

	parse_system (a_system: SIMPLE_XML_ELEMENT)
			-- Parse <system> element
		require
			system_not_void: a_system /= Void
		do
			-- Get system attributes
			if attached a_system.attr ("name") as l_name then
				system_name := l_name
			end
			if attached a_system.attr ("library_target") as l_lib then
				library_target := l_lib
			end

			-- Parse all targets
			across a_system.elements ("target") as ic loop
				parse_target (ic)
			end
		end

	parse_target (a_target: SIMPLE_XML_ELEMENT)
			-- Parse <target> element
		require
			target_not_void: a_target /= Void
		local
			l_target: ECF_TARGET
		do
			create l_target.make
			if attached a_target.attr ("name") as l_name then
				l_target.name := l_name
			end
			if attached a_target.attr ("extends") as l_extends then
				l_target.extends := l_extends
			end

			-- Parse root class
			if attached a_target.element ("root") as l_root then
				if attached l_root.attr ("class") as l_class then
					l_target.root_class := l_class
				end
				if attached l_root.attr ("feature") as l_feature then
					l_target.root_feature := l_feature
				end
				if attached l_root.attr ("all_classes") as l_all then
					l_target.all_classes := l_all.same_string ("true")
				end
			end

			-- Parse libraries in this target
			across a_target.elements ("library") as ic loop
				parse_library (ic, l_target.name)
			end

			-- Parse clusters in this target
			across a_target.elements ("cluster") as ic loop
				parse_cluster (ic, l_target.name)
			end

			targets.extend (l_target)
		end

	parse_library (a_lib: SIMPLE_XML_ELEMENT; a_target_name: STRING_32)
			-- Parse <library> element
		require
			lib_not_void: a_lib /= Void
		local
			l_library: ECF_LIBRARY
		do
			create l_library.make
			l_library.target_name := a_target_name
			if attached a_lib.attr ("name") as l_name then
				l_library.name := l_name
			end
			if attached a_lib.attr ("location") as l_loc then
				l_library.location := l_loc
				l_library.resolved_path := resolve_path (l_loc)
			end
			if attached a_lib.attr ("readonly") as l_ro then
				l_library.is_readonly := l_ro.same_string ("true")
			end
			libraries.extend (l_library)
		end

	parse_cluster (a_cluster: SIMPLE_XML_ELEMENT; a_target_name: STRING_32)
			-- Parse <cluster> element
		require
			cluster_not_void: a_cluster /= Void
		local
			l_cluster: ECF_CLUSTER
		do
			create l_cluster.make
			l_cluster.target_name := a_target_name
			if attached a_cluster.attr ("name") as l_name then
				l_cluster.name := l_name
			end
			if attached a_cluster.attr ("location") as l_loc then
				l_cluster.location := l_loc
				l_cluster.resolved_path := resolve_path (l_loc)
			end
			if attached a_cluster.attr ("recursive") as l_rec then
				l_cluster.is_recursive := l_rec.same_string ("true")
			end
			clusters.extend (l_cluster)
		end

feature -- Path Resolution

	resolve_path (a_path: STRING_32): STRING_32
			-- Resolve environment variables and relative paths in `a_path'
		require
			path_not_void: a_path /= Void
		local
			l_result: STRING_32
			l_start, l_end: INTEGER
			l_var_name, l_var_value: detachable STRING_32
		do
			l_result := a_path.twin

			-- Expand $VAR syntax
			from
				l_start := l_result.index_of ('$', 1)
			until
				l_start = 0
			loop
				-- Find end of variable name (ends at \ or / or end of string)
				from
					l_end := l_start + 1
				until
					l_end > l_result.count or else
					l_result[l_end] = '\' or else
					l_result[l_end] = '/'
				loop
					l_end := l_end + 1
				end

				l_var_name := l_result.substring (l_start + 1, l_end - 1)
				l_var_value := get_environment_variable (l_var_name)

				if attached l_var_value as lv and then not lv.is_empty then
					l_result.replace_substring (lv, l_start, l_end - 1)
				end

				l_start := l_result.index_of ('$', l_start + 1)
			end

			-- Handle relative paths (.\ or ./)
			if l_result.starts_with (".\") or l_result.starts_with ("./") then
				if not ecf_directory.is_empty then
					l_result := ecf_directory + l_result.substring (3, l_result.count)
				end
			end

			-- Normalize path separators to forward slashes
			l_result.replace_substring_all ("\", "/")

			Result := l_result
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Environment

	get_environment_variable (a_name: STRING_32): detachable STRING_32
			-- Get environment variable value
		require
			name_not_void: a_name /= Void
		local
			l_exec: EXECUTION_ENVIRONMENT
		do
			create l_exec
			if attached l_exec.get (a_name) as l_val then
				Result := l_val
			end
		end

feature {NONE} -- Helpers

	reset
			-- Reset parser state
		do
			system_name.wipe_out
			library_target.wipe_out
			targets.wipe_out
			libraries.wipe_out
			clusters.wipe_out
			last_errors.wipe_out
			is_valid := False
			ecf_path := Void
			ecf_directory.wipe_out
		end

	directory_of (a_path: STRING_32): STRING_32
			-- Extract directory from file path
		require
			path_not_void: a_path /= Void
		local
			l_pos: INTEGER
		do
			-- Find last separator
			l_pos := a_path.last_index_of ('\', a_path.count)
			if l_pos = 0 then
				l_pos := a_path.last_index_of ('/', a_path.count)
			end
			if l_pos > 0 then
				Result := a_path.substring (1, l_pos)
			else
				create Result.make_empty
			end
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	xml: SIMPLE_XML
			-- XML parser

end
