--- File system search operations for Go test discovery.

local lib_neotest = require("neotest.lib")
local scandir = require("plenary.scandir")

local logger = require("neotest-golang.lib.logging")
local path = require("neotest-golang.lib.path")

local M = {}

local state = {
  root = nil,
}

--- Find a file upwards in the directory tree and return its path, if found.
--- @param filename string Name of file to search for
--- @param start_path string Starting directory or file path to search from
--- @return string|nil Full path to found file or nil if not found
function M.file_upwards(filename, start_path)
  -- Ensure start_path is a directory
  local start_dir = vim.fn.isdirectory(start_path) == 1 and start_path
    or path.get_directory(start_path)
  local home_dir = vim.fn.expand("$HOME")

  while start_dir ~= home_dir do
    logger.debug("Searching for " .. filename .. " in " .. start_dir)

    local try_path = start_dir .. path.os_path_sep .. filename
    if vim.fn.filereadable(try_path) == 1 then
      logger.info("Found " .. filename .. " at " .. try_path)
      return try_path
    end

    -- Go up one directory
    start_dir = path.get_directory(start_dir)
  end

  return nil
end

--- Find go.mod files downward to determine monorepo root.
--- @param folderpath string Directory path to search from
--- @return string|nil Root directory path or nil if no go.mod files found
function M.root_for_tests(folderpath)
  if state.root ~= nil then
    return state.root
  end
  -- First, check for go.work or go.mod at cwd or above (stop at $HOME)
  state.root =
    lib_neotest.files.match_root_pattern("go.work", "go.mod")(folderpath)
  if state.root then
    return state.root
  end

  -- Second, find all go.mod files recursively (monorepo-style)
  local go_mod_files = scandir.scan_dir(
    folderpath,
    { search_pattern = "go%.mod$", respect_gitignore = true }
  )

  if #go_mod_files == 0 then
    -- No go.mod files found, no tests can run (disables adapter's test discovery)
    return nil
  elseif #go_mod_files == 1 then
    -- Single go.mod found, return its directory
    state.root = path.get_directory(go_mod_files[1])
    return state.root
  else
    -- Multiple go.mod files (monorepo), return the search root
    state.root = folderpath
    return state.root
  end
end

--- Get all *_test.go files in a directory recursively.
--- @param folderpath string Directory path to search in
--- @return string[] Array of full paths to test files
function M.go_test_filepaths(folderpath)
  local files = scandir.scan_dir(
    folderpath,
    { search_pattern = "_test%.go$", add_dirs = false }
  )
  return files
end

return M
