#pragma once

struct lua_State;

// 注册所有游戏自定义的 Lua 绑定
int register_game_bindings(lua_State* L);
