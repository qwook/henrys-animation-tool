
-- Desc: prints a value to console, table.PrintTable()-style for tables, MsgN() for everything else.
function dbg ( input )
    if type( input ) == "table" then
        PrintTable( input )
    else
        MsgN( input )
    end
end

--[=====================================================================================[--
        gQuery
        A jQuery clone for Garry's Mod.
                            by hen

    A gQuery object wraps a *collection* of values (usually entities/PhysObjs). Calling a
    method on the wrapper (e.g. `wrapped:SetPos(pos)`) calls that method on every item in
    the collection instead of just one, letting HAT apply the same operation to several
    bones/physobjs/entities in one call (mirrors jQuery's `$(...).method()` fan-out).

    Entry points, both exposed as the single global `gQuery`:
        gQuery( item )        -- wrap a single value or an array of values.
        gQuery( "classname*" )-- wrap every spawned entity whose class matches the glob pattern.
        gQuery.Create( class ) -- ents.Create(class), pre-wrapped.
--]=====================================================================================]--

-- gfn is the metatable-backed "instance" layer every wrapped collection uses; keeping it
-- separate from the gQuery table below is what lets gQuery(...) return a distinct wrapped
-- object each call while still sharing one set of methods (gfn:new/fn/print).
local gfn = {}
local mt = {
    -- Desc: numeric keys index straight into the wrapped array (self.dat[key]); string keys
    -- that name a gfn method (new/fn/print) return that method; any other string key is
    -- treated as a method name to fan out to every wrapped item, via gfn:fn.
    __index = function(self, key)
        if tonumber(key) then
            return self.dat[key]
        elseif gfn[key] then
            return gfn[key]
        else
            return gfn.fn( self, key )
        end
    end,
    -- Desc: #wrapped returns how many items are in the wrapped collection.
    __len = function( self )
        return #self.dat
    end,
    -- Desc: renders the wrapped collection as "[item1,\nitem2,\n...]" for debug printing.
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
    -- Desc: calling a wrapped collection directly (rather than a method on it) iterates it,
    -- i.e. `for _, v in wrapped() do` walks self.dat like pairs(self.dat) would.
    __call = function( self, _, ... )
        return pairs(self.dat)(self.dat, ...)
    end
}

-- Desc: wraps a raw array `dat` (of entities, PhysObjs, etc.) as a gQuery collection.
function gfn:new( dat )

    local obj = { dat = dat }
    return setmetatable( obj, mt )

end

-- Desc: builds the fan-out method for `key` — calling the returned function invokes
-- `item[key](item, ...)` on every item in the collection that has that method, and returns
-- the first non-nil result (so e.g. `wrapped:GetPos()` reads back a value), or the wrapped
-- collection itself if nothing returned a value (so setters like `:SetPos()` stay chainable).
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

-- Desc: debug helper — prints the wrapped collection via its __tostring.
function gfn:print()
    print( self )
end

-- Declared as a global (not `local`) up front, before anything references it, so it's both a
-- real global other files can call (gQuery(...), gQuery.Create(...)) and not a forward
-- reference within this file.
gQuery = {}

gQuery.prototype = {
    -- Desc: this is what makes `gQuery(...)` callable. Dispatches on the first argument:
    --   table  -> wrap it directly as a collection (gfn:new).
    --   string -> treat it as a glob (`*` wildcard) over entity class names, collect
    --             every ents.GetAll() match, and wrap that.
    --   other  -> wrap the whole varargs list as a one-or-more-item collection
    --             (this is how `gQuery(somePhysObj)` ends up wrapping `{somePhysObj}`).
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
            return gQuery(ret)
        else
            return gQuery(args)
        end
    end
}

-- Desc: ents.Create(class), pre-wrapped so the result can be chained immediately.
gQuery.Create = function( class )
    return gQuery( ents.Create( class ) )
end

-- The single global entry point: `gQuery` is a table whose __call metamethod (its own
-- .prototype above) does all the actual dispatch, so `gQuery(x)` and `gQuery.Create(x)` both
-- work off one object.
gQuery = setmetatable( gQuery, gQuery.prototype )

