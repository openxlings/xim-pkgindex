"""pytest 全局配置与 fixtures"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Every Lua a test starts first loads tests/lua/module_names.lua: the harnesses
# mock the names of spec 1, libs/ calls the modules' names (see that file).
_MODULE_NAMES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lua", "module_names.lua")
os.environ.setdefault("LUA_INIT_5_4", "@" + _MODULE_NAMES)
os.environ.setdefault("LUA_INIT", "@" + _MODULE_NAMES)


def pytest_configure(config):
    for mark in ["static", "index", "isolation", "lifecycle", "verify"]:
        config.addinivalue_line("markers", f"{mark}: L{['static','index','isolation','lifecycle','verify'].index(mark)} 测试层级")
