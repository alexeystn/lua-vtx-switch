local script = assert(loadScript("/SCRIPTS/TOOLS/ledvtx.lua"))()

return { run=script.run, background=script.background, init=script.init}
