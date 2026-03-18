-- colsize.lua
-- Parse "!w=NN%" anywhere in header cell text,
-- remove it from the rendered text,
-- and apply column width fractions.

local function extract_and_strip(str)
  local pct = nil

  -- zoek !w=NN%
  local cleaned = str:gsub("!w=([0-9]+%.?[0-9]*)%%", function(n)
    if not pct then
      pct = tonumber(n)
    end
    return "" -- verwijderen uit tekst
  end)

  -- dubbele spaties opruimen
  cleaned = cleaned:gsub("%s%s+", " ")
  cleaned = cleaned:gsub("^%s+", "")
  cleaned = cleaned:gsub("%s+$", "")

  return cleaned, pct
end

local function process_cell(cell)
  local pct = nil

  for b = 1, #cell.contents do
    local block = cell.contents[b]
    if block.t == "Plain" or block.t == "Para" then
      for i = 1, #block.content do
        local el = block.content[i]
        if el.t == "Str" then
          local cleaned, p = extract_and_strip(el.text)
          if p and not pct then
            pct = p
          end
          el.text = cleaned
          block.content[i] = el
        end
      end
      cell.contents[b] = block
    end
  end

  return cell, pct
end

local function get_header_cells(tbl)
  if tbl.head and tbl.head.rows and #tbl.head.rows > 0 then
    return tbl.head.rows[1].cells
  end
  return nil
end

function Table(tbl)
  if not tbl.colspecs or #tbl.colspecs == 0 then
    return tbl
  end

  local cells = get_header_cells(tbl)
  if not cells then
    return tbl
  end

  local ncols = math.min(#cells, #tbl.colspecs)
  local widths = {}
  local specified_sum = 0
  local unspecified = {}

  for i = 1, ncols do
    local cell, pct = process_cell(cells[i])
    cells[i] = cell

    if pct then
      local frac = pct / 100
      widths[i] = frac
      specified_sum = specified_sum + frac
    else
      table.insert(unspecified, i)
    end
  end

  -- als >100%, normaliseren
  if specified_sum > 1 then
    io.stderr:write(string.format(
      "[colsize.lua] widths sum to %.1f%%, normalizing.\n",
      specified_sum * 100
    ))
    for i = 1, ncols do
      if widths[i] then
        widths[i] = widths[i] / specified_sum
      end
    end
    specified_sum = 1
  end

  local remaining = math.max(0, 1 - specified_sum)

  if #unspecified > 0 then
    local each = remaining / #unspecified
    for _, idx in ipairs(unspecified) do
      widths[idx] = each
    end
  end

  for i = 1, ncols do
    local align = tbl.colspecs[i][1]
    tbl.colspecs[i] = { align, widths[i] or 0 }
  end

  tbl.head.rows[1].cells = cells
  return tbl
end