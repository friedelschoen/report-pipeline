local stringify = pandoc.utils.stringify

local function mkcell(text)
  -- Cell inhoud is een lijst van Blocks
  return pandoc.Cell({ pandoc.Plain({ pandoc.Str(text) }) })
end

local function get_head_rows(tbl)
  if tbl.head and tbl.head.rows then
    return tbl.head.rows
  end
  return nil
end

local function iter_body_rows(tbl)
  local out = {}

  if not tbl.bodies then
    return out
  end

  for _, b in ipairs(tbl.bodies) do
    if b.head then
      for _, r in ipairs(b.head) do out[#out+1] = r end
    end
    if b.body then
      for _, r in ipairs(b.body) do out[#out+1] = r end
    end
    if b.rows then
      for _, r in ipairs(b.rows) do out[#out+1] = r end
    end
  end

  return out
end

function Table(tbl)
  local head_rows = get_head_rows(tbl)
  if not head_rows or not head_rows[1] or not head_rows[1].cells then
    return nil
  end

  -- Zoek kolomindex met header die begint met '#'
  local hash_col = nil
  for i, cell in ipairs(head_rows[1].cells) do
    local h = stringify(cell):gsub("^%s+",""):gsub("%s+$","")
    if h:match("^#") then
      hash_col = i

      -- Strip leading '#', plus eventuele spaties erna
      local newh = h:gsub("^#%s*", "")
      head_rows[1].cells[i] = mkcell(newh)

      break
    end
  end
  if not hash_col then
    return nil
  end

  local counter = nil

  for _, row in ipairs(iter_body_rows(tbl)) do
    if row.cells and row.cells[hash_col] then
      local content = stringify(row.cells[hash_col]):gsub("^%s+",""):gsub("%s+$","")
      local n = tonumber(content)

      if n then
        counter = n
      else
        if not counter then counter = 1 else counter = counter + 1 end
        row.cells[hash_col] = mkcell(tostring(counter))
      end
    end
  end

  return tbl
end