return function()
  local sln = vim.fs.find(function(name, _)
    return name:match("%.sln$") or name:match("%.slnx$")
  end, { limit = 1, type = "file", path = vim.uv.cwd() })
  local fsproj = vim.fs.find(function(name, _)
    return name:match("%.fsproj$")
  end, { limit = 1, type = "file", path = vim.uv.cwd() })
  local has_sln = next(sln) ~= nil
  local has_proj = next(fsproj) ~= nil
  local append_fname = not has_sln and not has_proj
  local args
  if append_fname then
    args = { "--format", "msbuild", "lint" }
  else
    local file
    if has_sln then
      file = sln[1]
    elseif has_proj then
      file = fsproj[1]
    end
    args = { "--format", "msbuild", "lint", file }
  end

  return {
    name = "fsharplint",
    cmd = "dotnet-fsharplint",
    args = args,
    stdin = false,
    append_fname = append_fname,
    stream = "stdout",
    ignore_exitcode = true,
    parser = function(out, buf, _)
      -- TODO: not sure how to do buf-specific linting
      -- it seems all messed up on diagnostic locations
      local lines = vim.split(out, "\n")
      return vim
        .iter(lines)
        :filter(function(line)
          return not line:match("^=+") and not line:match("^%s*$")
        end)
        :map(function(line)
          local lnum, col, code, msg = line:match("%(%d+,%d+,(%d+),(%d+)%):FSharpLint warning (.-): (.+)$")
          ---@type vim.Diagnostic
          return {
            bufnr = buf,
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = "fsharplint",
            code = code,
          }
        end)
        :totable()
    end,
  }
end
