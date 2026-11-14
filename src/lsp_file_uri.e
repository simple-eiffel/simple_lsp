note
	description: "[
		LSP_FILE_URI - the one place file paths and file:// URIs turn into each other (RFC 8089).

		Every handler and the server use these, so a path makes the same URI everywhere:
			C:\proj\a.e      -> file:///C:/proj/a.e
			/Users/me/a.e    -> file:///Users/me/a.e   (three slashes: "file://" and the path's own "/")
		and a URI from the editor (VS Code sends file:///c%3A/proj/a.e) turns back into the path.
	]"
	author: "Larry Rix"
	date: "$Date$"

class
	LSP_FILE_URI

feature -- Conversion

	from_path (a_path: STRING): STRING
			-- `a_path' (Windows or POSIX) as a file:// URI.
		require
			path_not_void: a_path /= Void
		local
			l_path: STRING
		do
			l_path := a_path.twin
			l_path.replace_substring_all ("\", "/")
			Result := "file://"
			if not l_path.starts_with ("/") then
					-- a drive (C:/...) or a relative path: the authority is empty, then "/"
				Result.append_character ('/')
			end
			Result.append (escaped (l_path))
		ensure
			file_uri: Result.starts_with ("file:///")
			never_four_slashes: not Result.starts_with ("file:////")
		end

	to_path (a_uri: STRING): STRING
			-- The local path `a_uri' names: POSIX paths keep their leading "/", a drive path
			-- (file:///C:/...) does not, and on Windows the separators are backslashes.
		require
			uri_not_void: a_uri /= Void
		do
			Result := decoded (a_uri)
			if Result.starts_with ("file://") then
				Result := Result.substring (8, Result.count)
				if Result.count >= 3 and then Result.item (1) = '/' and then Result.item (3) = ':' and then Result.item (2).is_alpha then
						-- /C:/proj -> C:/proj
					Result := Result.substring (2, Result.count)
				end
				if {PLATFORM}.is_windows then
						-- the file system's own separators, so the path compares equal to one
						-- Windows gives and opens as one
					Result.replace_substring_all ("/", "\")
				end
			end
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	escaped (a_path: STRING): STRING
			-- `a_path' with the characters a URI path cannot hold as they are percent-encoded:
			-- '%' first (so nothing is encoded twice), then space and '#'.
		do
			Result := a_path.twin
			Result.replace_substring_all ("%%", "%%25")
			Result.replace_substring_all (" ", "%%20")
			Result.replace_substring_all ("#", "%%23")
		end

	decoded (a_text: STRING): STRING
			-- `a_text' with every %XX turned back into its character.
		local
			i, l_code: INTEGER
		do
			create Result.make (a_text.count)
			from i := 1 until i > a_text.count loop
				if a_text.item (i) = '%%' and then i + 2 <= a_text.count
					and then a_text.item (i + 1).is_hexa_digit and then a_text.item (i + 2).is_hexa_digit then
					l_code := hex_value (a_text.item (i + 1)) * 16 + hex_value (a_text.item (i + 2))
					Result.append_character (l_code.to_character_8)
					i := i + 3
				else
					Result.append_character (a_text.item (i))
					i := i + 1
				end
			end
		end

	hex_value (c: CHARACTER_8): INTEGER
		require
			hexa: c.is_hexa_digit
		do
			if c.is_digit then
				Result := c.code - ('0').code
			else
				Result := c.as_lower.code - ('a').code + 10
			end
		end

end
