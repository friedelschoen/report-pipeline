function Table(tbl)
  return {
    pandoc.RawBlock("latex", "\\rowcolors{2}{tableodd}{}"),
    tbl,
    -- pandoc.RawBlock("latex", "\\hiderowcolors")
  }
end