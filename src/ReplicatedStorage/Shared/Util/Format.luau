--!strict

local Format = {}

-- 1234567 -> "1,234,567"
function Format.Commas(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then
		sign, s = "-", string.sub(s, 2)
	end
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return sign .. out
end

function Format.Cash(n: number): string
	return "$" .. Format.Commas(n)
end

return Format
