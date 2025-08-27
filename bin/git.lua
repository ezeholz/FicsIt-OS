local shell = require("shell")
local process = require("process")
local buffer = require("buffer")
local json = require("json")
local packageLib = require("package")
local filesystem = require("filesystem")

local inet = computer.getPCIDevices(classes.FINInternetCard)[1]

if not inet then
    shell.writeLine("Unable to get Internet Card!")
    return 1
end

local requests = {}

--- enqueue a request
---@param url string
---@param func function
local function requestCode(url, func)
    local request = inet:request(url, "GET", "")
    table.insert(requests, {request=request, func=func})
end

--- fetch url synchronously
---@param url string
local function getCode(url)
    local request = inet:request(url, "GET", "")
    local status_code, text = request:await()
    if status_code ~= 200 then
        error("unable to fetch '" .. url .. "', response code " .. status_code)
    end
    return text
end

--- request a Gist file by ID and optional filename
---@param id string
---@param filename string optional
---@param func function
local function requestGist(id, filename, func)
    if not id:find("^%w+$") then
        error("'" .. id .. "' is not a valid gist id")
    end
    local url = "https://api.github.com/gists/" .. id
    requestCode(url, function(data)
        local gist = json.decode(data)
        if not filename then
            -- take the first file by default
            for k,v in pairs(gist.files) do
                func(v.content)
                return
            end
        else
            if gist.files[filename] then
                func(gist.files[filename].content)
            else
                error("file '" .. filename .. "' not found in gist " .. id)
            end
        end
    end)
end

--- fetch gist synchronously
---@param id string
---@param filename string optional
local function getGist(id, filename)
    if not id:find("^%w+$") then
        error("'" .. id .. "' is not a valid gist id")
    end
    local url = "https://api.github.com/gists/" .. id
    local data = getCode(url)
    local gist = json.decode(data)
    if not filename then
        for k,v in pairs(gist.files) do
            return v.content
        end
    else
        if gist.files[filename] then
            return gist.files[filename].content
        else
            error("file '" .. filename .. "' not found in gist " .. id)
        end
    end
end

--- handle requests queue
local function doAllRequests()
    while #requests > 0 do
        local i = 1
        while i <= #requests do
            local request = requests[i]
            if request.request:canGet() then
                local code, data = request.request:get()
                if code ~= 200 then
                    error("unable to fetch data, response code " .. code)
                end
                request.func(data)
                table.remove(requests, i)
                i = i - 1
            end
            i = i + 1
        end
    end
end

--- save package metadata locally
local function savePackage(package)
    local copy = packageLib.convertPackageToSaved(package)
    filesystem.createDir("/.gists")
    local file = filesystem.open(filesystem.path("/.gists", copy.id .. ".json"), "w")
    file:write(json.encode(copy))
    file:close()
end

--- load all events (pre/post)
local function loadEvents(package, event)
    local function sourceVisitor(source)
        if source.content then
            return
        elseif source.type == "gist" then
            requestGist(source.gist, source.filename, function(data)
                source.content = data
            end)
        elseif source.type == "url" then
            requestCode(source.url, function(data) source.content = data end)
        end
    end

    packageLib.visitEvents(package, event, "pre", sourceVisitor)
    packageLib.visitEvents(package, event, "post", sourceVisitor)
    doAllRequests()
end

local function install(id)
    local packageScript = getGist(id)
    local parser = packageLib.createPackageParser(id)
    parser:parse(packageScript)
    local package = parser.package

    loadEvents(package, "install")

    local function doSourceVisitor(source)
        local event = load(source.content)
        event()
    end

    packageLib.visitEvents(package, "install", "pre", doSourceVisitor)

    -- create folders
    table.sort(package.folders, function(f1,f2) return f1.path<f2.path end)
    for _, folder in pairs(package.folders) do
        filesystem.createDir(folder.path)
    end

    -- write files
    table.sort(package.files, function(f1,f2) return f1.path<f2.path end)
    for _, file in pairs(package.files) do
        requestGist(file.gist, file.filename, function(data)
            local f = filesystem.open(file.path, "w")
            f:write(data)
            f:close()
        end)
    end
    doAllRequests()

    packageLib.visitEvents(package, "install", "post", doSourceVisitor)
    savePackage(package)
end

local function uninstall(id)
    local path = filesystem.path("/.gists", id .. ".json")
    if not filesystem.isFile(path) then
        error("package '" .. id .. "' not yet installed")
    end
    local f = buffer.create("r", filesystem.open(path, "r"))
    local packageData = f:read("a")
    f:close()
    local package = json.decode(packageData)

    loadEvents(package, "uninstall")
    local function doSourceVisitor(source)
        local event = load(source.content)
        event()
    end

    packageLib.visitEvents(package, "uninstall", "pre", doSourceVisitor)

    -- remove files
    table.sort(package.files, function(f1,f2) return f1.path>f2.path end)
    for _, file in pairs(package.files) do
        filesystem.remove(file.path)
    end

    -- remove folders
    table.sort(package.folders, function(f1,f2) return f1.path>f2.path end)
    for _, folder in pairs(package.folders) do
        filesystem.remove(folder.path)
    end

    packageLib.visitEvents(package, "uninstall", "post", doSourceVisitor)
    filesystem.remove(path)
end

--- GitHub cloning helper ---
local function ensureParentDir(filePath)
    local parent = filePath:sub(1, #filePath - #filesystem.name(filePath))
    if parent ~= "" then
        filesystem.createDir(parent)
    end
end

local function requestGitFile(user, repo, branch, path, baseFolder)
    local url = ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(user, repo, branch, path)
    requestCode(url, function(data)
        local dest = filesystem.path(baseFolder, path)
        ensureParentDir(dest)
        local f = filesystem.open(dest, "w")
        f:write(data)
        f:close()
    end)
end

local function cloneRepo(user, repo, branch)
    branch = branch or "main"
    local baseFolder = "/" .. repo
    filesystem.createDir(baseFolder)

    local apiURL = ("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"):format(user, repo, branch)
    local code, body = inet:request(apiURL, "GET", ""):await()
    if code ~= 200 or not body then
        error("Failed to fetch repo tree")
    end

    local tree = json.decode(body)
    if not tree.tree then error("Repo tree missing") end

    for _, obj in ipairs(tree.tree) do
        if obj.type == "blob" then
            requestGitFile(user, repo, branch, obj.path, baseFolder)
        end
    end

    doAllRequests()
    shell.writeLine("Repo '" .. repo .. "' cloned into folder: " .. baseFolder)
end

-- CLI handling
local args = {...}
local p = process.running()
local sub = args[1]
table.remove(args, 1)

if sub == "download" then
    local id, filename, path
    id = args[1]
    filename = args[2]
    path = filesystem.path(p.environment["PWD"], filename or id)
    local text = getGist(id, filename)
    local f = filesystem.open(path, "w")
    f:write(text)
    f:close()
elseif sub == "run" then
    local id, filename = args[1], args[2]
    local text = getGist(id, filename)
    local tmp = filesystem.open("/tmp.lua", "w")
    tmp:write(text)
    tmp:close()
    local f = filesystem.loadFile("/tmp.lua")
    f()
elseif sub == "install" then
    local id = args[1]
    if not id then
        shell.writeLine("no gist-id given to install!")
        return 1
    end
    install(id)
elseif sub == "uninstall" then
    local id = args[1]
    if not id then
        shell.writeLine("no gist-id given to uninstall!")
        return 1
    end
    uninstall(id)
elseif sub == "clone" then
    local user, repo, branch = args[1], args[2], args[3]
    if not user or not repo then
        shell.writeLine("Usage: clone <user> <repo> [branch]")
        return 1
    end
    cloneRepo(user, repo, branch)
end

return 0
