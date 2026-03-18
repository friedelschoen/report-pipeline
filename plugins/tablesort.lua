-- tablesort.lua
-- Sorteer een pandoc-tabel op basis van een marker in de header cell:
--   !s=asc
--   !s=desc,i
--   !s=asc,num
--   !s=desc,date
--
-- Ondersteunde opties:
--   asc / desc   : oplopend / aflopend
--   i            : ignore case
--   num          : numeriek sorteren
--   date         : datum sorteren
--
-- Voorbeeld:
--   | Naam !s=asc,i | Score !s=desc,num |
--
-- Alleen de eerste kolom met !s=... wordt gebruikt.
-- De marker wordt uit de headertekst verwijderd.

local stringify = pandoc.utils.stringify

local function trim(s)
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local function split_params(s)
  local out = {}
  for part in s:gmatch("([^,]+)") do
    out[#out + 1] = trim(part)
  end
  return out
end

local function parse_sort_spec(str)
  -- zoekt !s=[...]
  local spec = nil
  local cleaned = str:gsub("!s=%S", function(inner)
    if not spec then
      spec = {
        order = "asc",
        ignorecase = false,
        numeric = false,
        date = false,
      }

      for _, p in ipairs(split_params(inner)) do
        if p == "asc" then
          spec.order = "asc"
        elseif p == "desc" then
          spec.order = "desc"
        elseif p == "i" then
          spec.ignorecase = true
        elseif p == "num" then
          spec.numeric = true
        elseif p == "date" then
          spec.date = true
        else
          io.stderr:write(string.format(
            "[tablesort.lua] onbekende sorteeroptie '%s'\n", p
          ))
        end
      end
    end
    return ""
  end)

  cleaned = cleaned:gsub("%s%s+", " ")
  cleaned = trim(cleaned)

  return cleaned, spec
end

local function process_cell_for_sort_marker(cell)
  local spec = nil

  for b = 1, #cell.contents do
    local block = cell.contents[b]
    if block.t == "Plain" or block.t == "Para" then
      for i = 1, #block.content do
        local el = block.content[i]
        if el.t == "Str" then
          local cleaned, found = parse_sort_spec(el.text)
          if found and not spec then
            spec = found
          end
          el.text = cleaned
          block.content[i] = el
        end
      end
      cell.contents[b] = block
    end
  end

  return cell, spec
end

local function get_header_cells(tbl)
  if tbl.head and tbl.head.rows and #tbl.head.rows > 0 then
    return tbl.head.rows[1].cells
  end
  return nil
end

local function cell_text(cell)
  return trim(stringify(cell))
end

local function row_cell_text(row, idx)
  if not row or not row.cells or not row.cells[idx] then
    return ""
  end
  return cell_text(row.cells[idx])
end

local function parse_number(s)
  s = trim(s)
  if s == "" then
    return nil
  end

  -- simpele normalisatie:
  -- "1.234,56" -> "1234.56"
  -- "1,234.56" blijft tricky; hier kiezen we voor pragmatisch gedrag
  local has_comma = s:find(",", 1, true) ~= nil
  local has_dot = s:find(".", 1, true) ~= nil

  if has_comma and has_dot then
    -- als komma na laatste punt komt, neem Europese notatie aan
    local last_comma = s:match("^.*(),")
    local last_dot = s:match("^.*().")
    if last_comma and last_dot and last_comma > last_dot then
      s = s:gsub("%.", "")
      s = s:gsub(",", ".")
    else
      s = s:gsub(",", "")
    end
  elseif has_comma and not has_dot then
    s = s:gsub(",", ".")
  end

  return tonumber(s)
end

local function parse_date(s)
  s = trim(s)
  if s == "" then
    return nil
  end

  -- Ondersteunde vormen:
  -- YYYY-MM-DD
  -- YYYY/MM/DD
  -- YYYY.MM.DD
  -- DD-MM-YYYY
  -- DD/MM/YYYY
  -- DD.MM.YYYY
  -- optioneel met tijd: HH:MM[:SS]
  local y, m, d, hh, mm, ss

  y, m, d, hh, mm, ss =
    s:match("^(%d%d%d%d)[%-/%.](%d%d?)[%-/%.](%d%d?)%s+(%d%d?):(%d%d):?(%d%d?)?$")
  if y then
    return os.time{
      year = tonumber(y),
      month = tonumber(m),
      day = tonumber(d),
      hour = tonumber(hh) or 0,
      min = tonumber(mm) or 0,
      sec = tonumber(ss) or 0,
    }
  end

  y, m, d = s:match("^(%d%d%d%d)[%-/%.](%d%d?)[%-/%.](%d%d?)$")
  if y then
    return os.time{
      year = tonumber(y),
      month = tonumber(m),
      day = tonumber(d),
      hour = 0, min = 0, sec = 0,
    }
  end

  d, m, y, hh, mm, ss =
    s:match("^(%d%d?)[%-/%.](%d%d?)[%-/%.](%d%d%d%d)%s+(%d%d?):(%d%d):?(%d%d?)?$")
  if d then
    return os.time{
      year = tonumber(y),
      month = tonumber(m),
      day = tonumber(d),
      hour = tonumber(hh) or 0,
      min = tonumber(mm) or 0,
      sec = tonumber(ss) or 0,
    }
  end

  d, m, y = s:match("^(%d%d?)[%-/%.](%d%d?)[%-/%.](%d%d%d%d)$")
  if d then
    return os.time{
      year = tonumber(y),
      month = tonumber(m),
      day = tonumber(d),
      hour = 0, min = 0, sec = 0,
    }
  end

  return nil
end

local function normalize_value(raw, spec)
  if spec.numeric then
    local n = parse_number(raw)
    if n ~= nil then
      return 0, n
    end
    return 1, raw
  end

  if spec.date then
    local t = parse_date(raw)
    if t ~= nil then
      return 0, t
    end
    return 1, raw
  end

  if spec.ignorecase then
    raw = raw:lower()
  end
  return 0, raw
end

local function compare_rows(a, b, colidx, spec)
  local av = row_cell_text(a.row, colidx)
  local bv = row_cell_text(b.row, colidx)

  local akind, anorm = normalize_value(av, spec)
  local bkind, bnorm = normalize_value(bv, spec)

  -- Eerst vergelijkbare types prioriteren:
  -- kind 0 = succesvol geconverteerd / normale string
  -- kind 1 = fallback
  if akind ~= bkind then
    if spec.order == "desc" then
      return akind > bkind
    else
      return akind < bkind
    end
  end

  if anorm == bnorm then
    return a.index < b.index
  end

  if spec.order == "desc" then
    return anorm > bnorm
  else
    return anorm < bnorm
  end
end

local function sort_rows(rows, colidx, spec)
  local wrapped = {}
  for i, row in ipairs(rows) do
    wrapped[i] = { row = row, index = i }
  end

  table.sort(wrapped, function(a, b)
    return compare_rows(a, b, colidx, spec)
  end)

  local out = {}
  for i, item in ipairs(wrapped) do
    out[i] = item.row
  end
  return out
end

function Table(tbl)
  local cells = get_header_cells(tbl)
  if not cells then
    return tbl
  end

  local sort_col = nil
  local sort_spec = nil

  for i = 1, #cells do
    local cell, spec = process_cell_for_sort_marker(cells[i])
    cells[i] = cell

    if spec and not sort_col then
      sort_col = i
      sort_spec = spec
    elseif spec and sort_col then
      io.stderr:write(string.format(
        "[tablesort.lua] meerdere !s=[...] markers gevonden; alleen kolom %d wordt gebruikt.\n",
        sort_col
      ))
    end
  end

  tbl.head.rows[1].cells = cells

  if not sort_col then
    return tbl
  end

  if not tbl.bodies then
    return tbl
  end

  for bi = 1, #tbl.bodies do
    local body = tbl.bodies[bi]
    if body.body and #body.body > 1 then
      body.body = sort_rows(body.body, sort_col, sort_spec)
      tbl.bodies[bi] = body
    end
  end

  return tbl
end