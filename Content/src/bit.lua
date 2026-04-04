-- Lua 5.3+ bit 兼容模块
-- 旧代码 require "bit" 使用 LuaJIT 的 bit 库
return {
    band   = function(a, b) return a & b end,
    bor    = function(a, b) return a | b end,
    bxor   = function(a, b) return a ~ b end,
    bnot   = function(a) return ~a end,
    lshift = function(a, n) return a << n end,
    rshift = function(a, n) return a >> n end,
    arshift = function(a, n) return a >> n end,
    tobit  = function(x) return x & 0xFFFFFFFF end,
    tohex  = function(x, n)
        local fmt = n and n <= 8 and string.format("%%0%dx", n) or "%x"
        return string.format(fmt, x & 0xFFFFFFFF)
    end,
}
