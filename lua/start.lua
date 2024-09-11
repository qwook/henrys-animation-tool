
local oInclude = include

include = function( str ) RunString( file.Read(str, "LUA") ) end

include( "autorun/hat_init.lua" )

include = oInclude