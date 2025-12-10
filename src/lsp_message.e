note
	description: "LSP JSON-RPC message structure"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LSP_MESSAGE

create
	make,
	make_from_json

feature {NONE} -- Initialization

	make (a_method: STRING; a_id: INTEGER; a_params: detachable SIMPLE_JSON_OBJECT)
			-- Create message
		require
			method_not_empty: a_method /= Void and then not a_method.is_empty
		do
			method := a_method
			id := a_id
			has_id := a_id > 0
			params := a_params
		ensure
			method_set: method = a_method
			id_set: id = a_id
			params_set: params = a_params
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Create from parsed JSON
		require
			json_not_void: a_json /= Void
		local
			l_id_value: detachable SIMPLE_JSON_VALUE
		do
			if attached a_json.string_item ("method") as m then
				method := m.to_string_8
			else
				method := ""
			end

			-- Handle id which can be integer or string in JSON-RPC
			if a_json.has_key ("id") then
				l_id_value := a_json.item ("id")
				if attached l_id_value then
					if l_id_value.is_integer then
						id := l_id_value.as_integer.to_integer
					elseif l_id_value.is_string then
						-- Some clients send id as string
						if l_id_value.as_string_32.is_integer then
							id := l_id_value.as_string_32.to_integer
						else
							id := 1 -- Default to 1 for non-numeric string ids
						end
					else
						id := 1 -- Has id key but not integer/string, treat as request
					end
				end
				has_id := True
			else
				has_id := False
			end

			if attached a_json.object_item ("params") as p then
				params := p
			end
		end

feature -- Access

	method: STRING
			-- Method name (e.g., "initialize", "textDocument/definition")

	id: INTEGER
			-- Request ID (0 for notifications)

	has_id: BOOLEAN
			-- Was an id present in the JSON message?

	params: detachable SIMPLE_JSON_OBJECT
			-- Request parameters

feature -- Query

	is_request: BOOLEAN
			-- Is this a request (has id)?
		do
			Result := has_id
		end

	is_notification: BOOLEAN
			-- Is this a notification (no id)?
		do
			Result := not has_id
		end

feature -- Parameter Access

	text_document_uri: STRING
			-- Extract textDocument.uri from params
		do
			Result := ""
			if attached params as p then
				if attached p.object_item ("textDocument") as td then
					if attached td.string_item ("uri") as u then
						Result := u.to_string_8
					end
				end
			end
		end

	position_line: INTEGER
			-- Extract position.line from params
		do
			if attached params as p then
				if attached p.object_item ("position") as pos then
					Result := pos.integer_item ("line").to_integer
				end
			end
		end

	position_character: INTEGER
			-- Extract position.character from params
		do
			if attached params as p then
				if attached p.object_item ("position") as pos then
					Result := pos.integer_item ("character").to_integer
				end
			end
		end

invariant
	method_exists: method /= Void

end
