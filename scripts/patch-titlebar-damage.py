#!/usr/bin/env python3
"""Bound hyprbars repaint to its real paint region and clear the previous region."""
from pathlib import Path
import sys


def change(root, name, old, new):
    path = root / name
    text = path.read_text()
    if new in text:
        return
    if text.count(old) != 1:
        raise ValueError('Unexpected pinned titlebar source: ' + name)
    path.write_text(text.replace(old, new, 1))


def patch(root):
    change(root, 'barDeco.hpp', 'CBox                       m_bAssignedBox;',
           'CBox                       m_bAssignedBox;\n    std::optional<CBox> m_lastPaintBox;\n    CBox paintBoxGlobal();')
    change(root, 'barDeco.cpp', '''void CHyprBar::damageEntire() {
    g_pHyprRenderer->damageBox(assignedBoxGlobal());
}''', '''CBox CHyprBar::paintBoxGlobal() {
    if (!validMapped(m_pWindow) || m_hidden || !g_pGlobalState->config.enabled->value())
        return {};
    const auto window = m_pWindow.lock();
    const auto precedence = g_pGlobalState->config.barPrecedenceOverBorder->value();
    const double rounding = window->rounding() + (precedence ? 0 : window->getRealBorderSize());
    CBox box = assignedBoxGlobal();
    box.h += std::max(0.0, rounding) * 3;
    return box.translate(window->m_floatingOffset).expand(2);
}

void CHyprBar::damageEntire() {
    if (m_lastPaintBox)
        g_pHyprRenderer->damageBox(*m_lastPaintBox);
    const auto current = paintBoxGlobal();
    if (current.w > 0 && current.h > 0) {
        g_pHyprRenderer->damageBox(current);
        m_lastPaintBox = current;
    } else
        m_lastPaintBox.reset();
}''')
    change(root, 'barDeco.cpp', 'void CHyprBar::draw(PHLMONITOR pMonitor, const float& a) {', '''void CHyprBar::draw(PHLMONITOR pMonitor, const float& a) {
    const auto current = paintBoxGlobal();
    if (!m_lastPaintBox || m_lastPaintBox->x != current.x || m_lastPaintBox->y != current.y ||
        m_lastPaintBox->w != current.w || m_lastPaintBox->h != current.h)
        damageEntire();''')
    path = root / 'barDeco.cpp'
    text = path.read_text()
    # Closing/unloading and changing native-control rules must erase the old bar too.
    destructor = 'CHyprBar::~CHyprBar() {\n    std::erase(g_pGlobalState->bars, m_self);'
    replacement = 'CHyprBar::~CHyprBar() {\n    damageEntire();\n    std::erase(g_pGlobalState->bars, m_self);'
    if replacement not in text and text.count(destructor) != 1:
        raise ValueError('Unexpected titlebar destructor.')
    text = text.replace(destructor, replacement, 1)
    text = text.replace('    if (prevHidden != m_hidden)\n        g_pDecorationPositioner->repositionDeco(this);',
                        '    if (prevHidden != m_hidden) {\n        damageEntire();\n        g_pDecorationPositioner->repositionDeco(this);\n    }')
    path.write_text(text)
    change(root, 'BarPassElement.cpp',
           'return data.deco->assignedBoxGlobal().translate(-g_pHyprRenderer->m_renderData.pMonitor->m_position).expand(10);',
           'return data.deco->paintBoxGlobal().translate(-g_pHyprRenderer->m_renderData.pMonitor->m_position);')


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
