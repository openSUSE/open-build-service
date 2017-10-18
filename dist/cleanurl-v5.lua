-- little helper function
function file_exists(path)
  local attr = lighty.stat(path)
  if (attr and attr["is_file"]) then
      return true
  else
      return false
  end
end

-- the magic ;)
if (not file_exists(lighty.env["physical.path"])) then
    -- file does not exist. check if we have a cached version
    lighty.env["physical.path"] = lighty.env["physical.path"] .. ".html"

    if (not file_exists(lighty.env["physical.path"])) then
        -- file still missing. pass it to the fastcgi backend
        lighty.env["uri.path"]          = "/dispatch.fcgi"
        lighty.env["physical.rel-path"] = lighty.env["uri.path"]
        lighty.env["request.orig-uri"]  = lighty.env["request.uri"]
        lighty.env["physical.path"]     = lighty.env["physical.doc-root"] .. lighty.env["physical.rel-path"]
    end
end
-- fallthrough will put it back into the lighty request loop
-- that means we get the 304 handling for free. ;)

-- debugging code
-- print ("final file is " ..  lighty.env["physical.path"])
