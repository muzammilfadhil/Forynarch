#!/usr/bin/env python3
"""Add a per-window title override to the reviewed hyprbars source pin."""
from pathlib import Path
import sys


def change(root, name, old, new):
    path = root / name
    text = path.read_text()
    if new in text:
        return
    if text.count(old) != 1:
        raise ValueError('The reviewed hyprbars source changed: ' + name)
    path.write_text(text.replace(old, new, 1))


def patch(root):
    path = root / 'globals.hpp'
    text = path.read_text()
    if 'titleRuleIdx = 0;' not in text:
        import re
        text, count = re.subn(r'(uint32_t\s+titleColorRuleIdx\s*=\s*0;)', r'\1\n    uint32_t titleRuleIdx = 0;', text)
        if count != 1:
            raise ValueError('Unexpected title rule field.')
        path.write_text(text)
    change(root, 'main.cpp', 'int newLuaButton(lua_State* L) {', 'int supportsAppTitles(lua_State* L) { lua_pushboolean(L, true); return 1; }\n\nint newLuaButton(lua_State* L) {')
    change(root, 'main.cpp', 'g_pGlobalState->titleColorRuleIdx = Desktop::Rule::windowEffects()->registerEffect("hyprbars:title_color");', 'g_pGlobalState->titleColorRuleIdx = Desktop::Rule::windowEffects()->registerEffect("hyprbars:title_color");\n    g_pGlobalState->titleRuleIdx = Desktop::Rule::windowEffects()->registerEffect("hyprbars:title");')
    change(root, 'main.cpp', 'HyprlandAPI::addLuaFunction(PHANDLE, "hyprbars", "add_button", ::newLuaButton);', 'HyprlandAPI::addLuaFunction(PHANDLE, "hyprbars", "add_button", ::newLuaButton);\n    HyprlandAPI::addLuaFunction(PHANDLE, "hyprbars", "supports_app_titles", ::supportsAppTitles);')
    change(root, 'main.cpp', 'Desktop::Rule::windowEffects()->unregisterEffect(g_pGlobalState->barColorRuleIdx);', 'Desktop::Rule::windowEffects()->unregisterEffect(g_pGlobalState->barColorRuleIdx);\n    Desktop::Rule::windowEffects()->unregisterEffect(g_pGlobalState->titleRuleIdx);')
    path = root / 'barDeco.hpp'
    text = path.read_text()
    if 'm_forcedTitle;' not in text:
        import re
        text, count = re.subn(r'(std::optional<CHyprColor>[^\n]*m_bForcedTitleColor[^\n]*;)', r'\1\n    std::optional<std::string> m_forcedTitle;', text)
        if count != 1:
            raise ValueError('Unexpected title color field.')
        path.write_text(text)
    path = root / 'barDeco.cpp'
    text = path.read_text()
    if 'm_forcedTitle.value_or(PWINDOW->m_title)' not in text:
        if text.count('PWINDOW->m_title') != 2:
            raise ValueError('Unexpected title renderer.')
        text = text.replace('PWINDOW->m_title', 'm_forcedTitle.value_or(PWINDOW->m_title)')
        start = text.index('void CHyprBar::updateRules()')
        brace = text.index('{', start) + 1
        text = text[:brace] + '\n    m_forcedTitle.reset();' + text[brace:]
        needle = '    if (PWINDOW->m_ruleApplicator->m_otherProps.props.contains(g_pGlobalState->nobarRuleIdx))'
        if text.count(needle) != 1:
            raise ValueError('Unexpected window rule reader.')
        text = text.replace(needle, '    if (PWINDOW->m_ruleApplicator->m_otherProps.props.contains(g_pGlobalState->titleRuleIdx))\n        m_forcedTitle = PWINDOW->m_ruleApplicator->m_otherProps.props.at(g_pGlobalState->titleRuleIdx)->effect;\n\n' + needle, 1)
        path.write_text(text)


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
