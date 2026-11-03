-- ~/.config/yazi/init.lua

-- Abgerundeter Rahmen um alle Spalten
require("full-border"):setup({ set = "rounded" })

-- Git-Status (M, A, ?, …) neben Dateien
require("git"):setup()

-- Starship-Prompt als Kopfzeile
require("starship"):setup()

-- Größe + Änderungsdatum rechts neben jeder Datei
function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	if time == 0 then
		time = ""
	elseif os.date("%Y", time) == os.date("%Y") then
		time = os.date("%d.%m. %H:%M", time)
	else
		time = os.date("%d.%m.%Y", time)
	end
	local size = self._file:size()
	return string.format("%s  %s", size and ya.readable_size(size) or "-", time)
end

-- Besitzer:Gruppe in der Statuszeile
Status:children_add(function()
	local h = cx.active.current.hovered
	if not h or ya.target_family() ~= "unix" then
		return ""
	end
	return ui.Line({
		ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg("magenta"),
		":",
		ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg("magenta"),
		" ",
	})
end, 500, Status.RIGHT)
