local stringify = pandoc.utils.stringify

local function latex_env(content)
  return pandoc.RawBlock("latex",
    "\\begin{plantuml}\n" ..
    content .. "\n" ..
    "\\end{plantuml}"
  )
end

function CodeBlock(el)
  for _, c in ipairs(el.classes) do
    if c == "=plantuml" then
      return latex_env(el.text)
    end
  end

  return nil
end
