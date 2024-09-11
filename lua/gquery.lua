
function dbg ( input )
    if type( input ) == "table" then
        PrintTable( input )
    else
        MsgN( input )
    end
end

--[=======================================[--
        gQuery
        A jQuery clone for Garry's Mod.
                            by hen
--]=======================================]--

local gfn = {}
local mt = {
    __index = function(self, key)
        if tonumber(key) then
            return self.dat[key]
        elseif gfn[key] then
            return gfn[key]
        else
            return gfn.fn( self, key )
        end
    end,
    __len = function( self )
        print(100)
    end,
    __tostring = function( self )
        local ret = "["
        local first = true
        for k,v in ipairs( self.dat ) do
            if first then
                first = false
                ret = ret .. tostring(v)
            else
                ret = ret .. ",\n" .. tostring(v)
            end
        end
        ret = ret .. "]\n"
        return ret
    end,
    __call = function( self, _, ... )
        return pairs(self.dat)(self.dat, ...)
    end
}

function gfn:new( dat )

    local obj = { dat = dat }
    return setmetatable( obj, mt )

end

function gfn:fn( key )
    local _self = self
    return function( self, ... )
        local ret

        for k,v in pairs( _self.dat ) do
            if v[key] then
                local r = v[key]( v, unpack({...}) )
                if not ret then
                    ret = r
                end
            end
        end

        if type(ret) ~= "nil" then
            return ret
        else
            return _self
        end
    end
end

function gfn:print()
    print( self )
end

local gQuery = {
    prototype = {
        __call = function ( self, ... )
            local args = { ... }

            if type( args[1] ) == "table" then
                return gfn:new( args[1] )
            elseif type( args[1] ) == "string" then
                local ret = {}
                local str = args[1]
                local regex = string.gsub( str, "([%%%=%-%?%(%)%[%]%^%$])", "%%%1" )
                regex = "^" .. string.gsub( str, "%*", "%.%*" ) .. "$"
                for k,v in pairs( ents.GetAll() ) do
                    if string.match( v:GetClass(), regex ) then
                        table.insert(ret,v)
                    end
                end
                return g(ret)
            else
                return g(args)
            end
        end
    },
    Create = function( class )
        return g( ents.Create( class ) )
    end
}
g = setmetatable( gQuery, gQuery.prototype )

local Entity = FindMetaTable("Entity")
Entity.SetEyeTargetEng = Entity.SetEyeTargetEng or Entity.SetEyeTarget
function Entity:SetEyeTarget( pos )
    self:SetEyeTargetEng( pos )
    self.eyeTargetPos = pos
end

function Entity:GetEyeTarget()
    return self.eyeTargetPos or Vector( 180, 0, 0 )
end
