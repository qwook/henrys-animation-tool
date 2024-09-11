-- "Beer-Ware License" (Revision: Pabst Blue Ribbon)
-- <qwookiejar@gmail.com> wrote this file. As long as you retain this notice you
-- can do whatever with this stuff. Unlike Poul-Henning Kamp's license, if we
-- meet some day, and you think this stuff is worth it, you can buy me a PBR
-- in return.

-- version 0.0.4 added booleans

local string, table, type, pairs, tonumber = string, table, type, pairs, tonumber;
local print = print;

local
	CompileString,
	setfenv,
	Vector,
	Angle
	=
	CompileString,
	setfenv,
	Vector,
	Angle

module( "honsolo" );

local regex_endquotes = "](=*)]";
local regex_unescaped = "^[%a_][%a%d_]*$";
local regex_digits = "^%d+$";
local norm_dquotes = "\"";
local norm_quotes = "'";
local norm_newline = "\n";

extensions = {};

-- Add your extensions here I guess.
-- Name the child after the datatype. AKA whatever you get with type().
-- eg. string, number, Vector, Entity, Angle

-- The below extension is not guaranteed to work, this is due to me not having GMOD to test it out on.
function extensions.Vector( data )
    return "Vector(" .. data.x .. "," .. data.y .. "," .. data.z .. ")"
end

function extensions.Angle( data )
    return "Angle(" .. data.p .. "," .. data.y .. "," .. data.r .. ")"
end

function extensions.Entity( data )
    return "nil"
end

function extensions.PhysObj( data )
    return "nil"
end

function escape_key( str )
    if string.find(str, regex_unescaped) then
        return str;
    else
        if tonumber(str) then
            return "[" .. str .. "]";
        else
            return "[" .. escape_string(str) .. "]";
        end
    end
end

local controls = {
    ["\""] = "\\\"";
    ["\a"] = "\\a";
    ["\b"] = "\\b";
    ["\f"] = "\\\"";
    ["\n"] = "\\\"";
    ["\r"] = "\\\"";
    ["\t"] = "\\\"";
    ["\v"] = "\\\"";
    ["\\"] = "\\\\";
    ["\'"] = "\\'";
    ["\0"] = "\\0";
}
local function control_escape( char )
    return controls[char];
end

function escape_string( str, out )
    local use_big_string_escape = false;

    local dquotes = string.find(str, norm_dquotes);
    local quotes = string.find(str, norm_quotes);

    if ( not quotes and dquotes ) then
        return norm_quotes .. str:gsub("%c", control_escape) .. norm_quotes;
    end

    if ( not dquotes ) then
        return norm_dquotes .. str:gsub("%c", control_escape) .. norm_dquotes;
    end

    local escape_count = grab_string_escape_count( str );

    return "[" .. ("="):rep(escape_count) .. "[" .. str .. "]" .. ("="):rep(escape_count) .. "]";

end

function grab_string_escape_count( str )
    local max_num = 0;
    local unescaped = {};
    local finding_unescapers = true
    local gend = 0;
    while ( finding_unescapers ) do
        local start, fend, match  = string.find(str, regex_endquotes, gend );
        gend = fend;
        if not match then
            finding_unescapers = false;
        else
            unescaped[match:len()] = true;
        end
        while ( unescaped[max_num] ) do
            max_num = max_num + 1;
        end
    end
    return max_num
end

function encode( data, pretty, indent, out, child )
    -- first time calling initiate all variables
    indent = indent or 0;
    out = out or {};

    local t = type( data );
    if t == "string" then
        return escape_string(data);
    elseif t == "number" then
        return data;
    elseif t == "boolean" then
        if data then
            return "true";
        end
        return "false";
    elseif t == "table" then
        if ( pretty ) then table.insert( out, "\n" ); table.insert(out, ("    "):rep(indent)) end
        table.insert( out, "{" );

        local first = true;
        for key, value in pairs( data ) do
            indent = indent + 1;
            if not first then
                table.insert( out, "," );
            end
            if ( pretty ) then table.insert( out, "\n" ); table.insert(out, ("    "):rep(indent)) end
            table.insert( out, escape_key(key) );
            if ( pretty ) then table.insert( out, " " ); end
            table.insert( out, "=" );
            if ( pretty ) then table.insert( out, " " ); end
            table.insert( out, encode(value, pretty, indent, out, true) );
            indent = indent - 1;
            first = false;
        end

        if ( pretty ) then table.insert( out, "\n" ); table.insert(out, ("    "):rep(indent)) end
        table.insert( out, "}" );

        if child then
            return "";
        end
    elseif extensions[t] then
        return extensions[t]( data, pretty, indent );
    end

    return table.concat(out);
end

function decode(str)
	local fn = CompileString("return " .. str, "testlua");
	setfenv(fn, {Vector=Vector, Angle=Angle});
	return fn();
end
