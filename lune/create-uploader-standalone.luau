local fs = require("@lune/fs")
local serde = require("@lune/serde")

if fs.isDir("uploader-src") then
	fs.removeDir("uploader-src")
end

fs.copy("src", "uploader-src")

fs.removeFile("uploader-src/Builds/Plugin.luau")
fs.removeFile("uploader-src/Constants.luau")

fs.removeDir("uploader-src/Main/Bindings")
fs.removeDir("uploader-src/Main/Photo")
fs.removeDir("uploader-src/Main/StateManager")
fs.removeDir("uploader-src/Utilities")

for _, appName in fs.readDir("uploader-src/Main/UserInterface/Apps") do
	if appName ~= "Upload" then
		fs.removeDir("uploader-src/Main/UserInterface/Apps/" .. appName)
	end
end

local standaloneProject = serde.decode("json", fs.readFile("plugin.project.json"))
standaloneProject.tree["$path"] = "uploader-src"
standaloneProject.tree.Runner["$properties"].Source =
	"if plugin then require(script.Parent.Builds.Uploader).build(plugin) end"

fs.writeFile("uploader-plugin.project.json", serde.encode("json", standaloneProject, true))
