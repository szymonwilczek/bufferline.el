/**
 * Live Emacs Configurator & Responsive Tabline Engine
 * Author: Szymon Wilczek (2026)
 * License: GPL-3.0
 */

(() => {
    'use strict';

    const MOCK_BUFFERS = [
        {
            id: 1,
            name: 'init.el',
            dir: '~/.config/emacs/',
            pinned: true,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#7f5af0',
            mode: 'emacs-lisp',
            size: '2.8KiB',
            code: `;;; init.el --- Emacs initial configuration -*- lexical-binding: t; -*-

(use-package bufferline
  :load-path "~/Documents/GitHub/bufferline.el"
  :demand t
  :config
  (global-bufferline-mode 1))

(provide 'init)`
        },
        {
            id: 2,
            name: 'bufferline.el',
            dir: 'src/',
            pinned: true,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#7f5af0',
            mode: 'emacs-lisp',
            size: '4.2KiB',
            code: `;;; bufferline.el --- Modern buffer tabs for Emacs -*- lexical-binding: t; -*-

(require 'tab-line)
(require 'bufferline-config)
(require 'bufferline-ui)

;;;###autoload
(define-minor-mode global-bufferline-mode
  "Global bufferline tab-line mode."
  :global t
  :group 'bufferline
  (if global-bufferline-mode
      (global-tab-line-mode 1)
    (global-tab-line-mode -1)))

(provide 'bufferline)`
        },
        {
            id: 3,
            name: 'main.c',
            dir: 'src/client/',
            pinned: false,
            modified: true,
            readOnly: false,
            icon: '',
            iconColor: '#599eff',
            mode: 'c-ts',
            diags: { err: 1, warn: 0 },
            size: '1.4KiB',
            code: `#include <stdio.h>
#include <stdlib.h>
#include "client.h"

int main(int argc, char **argv) {
    printf("Connecting to daemon...\\n");
    client_init();
    return 0;
}`
        },
        {
            id: 4,
            name: 'main.c',
            dir: 'src/server/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#599eff',
            mode: 'c-ts',
            size: '3.1KiB',
            code: `#include <stdio.h>
#include <unistd.h>
#include "server.h"

int main(int argc, char **argv) {
    printf("Listening on port 8080...\\n");
    server_run();
    return 0;
}`
        },
        {
            id: 5,
            name: 'config.rs',
            dir: 'core/src/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#dea584',
            mode: 'rust-ts',
            size: '5.6KiB',
            code: `use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub indicator_width: u32,
    pub separator_style: String,
}`
        },
        {
            id: 6,
            name: 'constants.rs',
            dir: 'core/src/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#dea584',
            mode: 'rust-ts',
            size: '2.1KiB',
            code: `pub const DEFAULT_SEPARATOR: &str = "▎";
pub const DEFAULT_INDICATOR_WIDTH: u32 = 3;
pub const MAX_NAME_LENGTH: usize = 18;`
        },
        {
            id: 7,
            name: 'README.org',
            dir: './',
            pinned: false,
            modified: false,
            readOnly: true,
            icon: '',
            iconColor: '#77aa33',
            mode: 'org',
            size: '8.3KiB',
            code: `* bufferline.el
An opinionated, minimalist bufferline for GNU Emacs built on tab-line.

** Features
- Deterministic FIFO ordering
- Pixel-perfect (heh, maybe?) indicator bar
- Nerd-icons integration`
        },
        {
            id: 8,
            name: 'ui-mod.el',
            dir: 'modules/ui/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#7f5af0',
            mode: 'emacs-lisp',
            size: '2.6KiB',
            code: `;;; UI styling and typography
(set-face-attribute 'default nil :family "Typus Mono 95" :height 120)
(global-display-line-numbers-mode 1)
(provide 'ui-mod)`
        },
        {
            id: 9,
            name: 'modeline.el',
            dir: 'modules/ui/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#7f5af0',
            mode: 'emacs-lisp',
            size: '5.2KiB',
            code: `;;; Modeline rendering engine
(defun my/render-modeline ()
  (concat (my/modeline-evil-mode-info)
          (my/modeline-filename)))`
        },
        {
            id: 10,
            name: 'bufferline-ui.el',
            dir: 'lisp/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#7f5af0',
            mode: 'emacs-lisp',
            size: '9.8KiB',
            code: `(defun bufferline-ui-tab-name-format (tab tabs)
  (let* ((buffer (cdr (assq 'buffer tab)))
         (active (cdr (assq 'selected tab))))
    (concat sep icon name)))`
        },
        {
            id: 11,
            name: 'package.json',
            dir: 'web/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#fbc02d',
            mode: 'json-ts',
            size: '512B',
            code: `{
  "name": "bufferline-configurator",
  "version": "1.0.0",
  "private": true
}`
        },
        {
            id: 12,
            name: 'styles.css',
            dir: 'web/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#42a5f5',
            mode: 'css-ts',
            size: '6.4KiB',
            code: `:root {
  --emacs-bg: #111111;
  --emacs-fg: #cfdfd5;
}`
        },
        {
            id: 13,
            name: 'app.js',
            dir: 'web/',
            pinned: false,
            modified: false,
            readOnly: false,
            icon: '',
            iconColor: '#ffd54f',
            mode: 'js-ts',
            size: '12.2KiB',
            code: `// Live preview state manager
console.log("bufferline.el preview initialized");`
        },
        {
            id: 14,
            name: 'LICENSE',
            dir: './',
            pinned: false,
            modified: false,
            readOnly: true,
            icon: '',
            iconColor: '#b0bec5',
            mode: 'text',
            size: '35KiB',
            code: `GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007`
        }
    ];

    const PALETTES = {
        'ef-bio': {
            bg: '#111111', bgDim: '#222522', bgAlt: '#303230',
            fg: '#cfdfd5', fgDim: '#808f80', comment: '#b7a07f',
            keyword: '#00c089', string: '#af9fff', fn: '#7fc500',
            type: '#7fcfdf', warning: '#cfc04f', error: '#ef6560', indicator: '#cfdfd5'
        },
        'ef-autumn': {
            bg: '#0f0e06', bgDim: '#26211d', bgAlt: '#36322f',
            fg: '#cfbcba', fgDim: '#887c8a', comment: '#cf9f7f',
            keyword: '#c48702', string: '#f06a3f', fn: '#3dbbb0',
            type: '#2fa526', warning: '#c48702', error: '#f06a3f', indicator: '#cfbcba'
        },
        'ef-dark': {
            bg: '#000000', bgDim: '#1a1a1a', bgAlt: '#2b2b2b',
            fg: '#d0d0d0', fgDim: '#857f8f', comment: '#cf9f8f',
            keyword: '#af85ff', string: '#6a9fff', fn: '#e580ea',
            type: '#00a692', warning: '#bf9032', error: '#f47360', indicator: '#d0d0d0'
        },
        'modus-vivendi': {
            bg: '#000000', bgDim: '#1e1e1e', bgAlt: '#2b2b2b',
            fg: '#ffffff', fgDim: '#989898', comment: '#989898',
            keyword: '#b6a0ff', string: '#79a8ff', fn: '#feacd0',
            type: '#6ae4b9', warning: '#fec43f', error: '#ff5f59', indicator: '#ffffff'
        },
        'catppuccin-mocha': {
            bg: '#1e1e2e', bgDim: '#181825', bgAlt: '#11111b',
            fg: '#cdd6f4', fgDim: '#a6adc8', comment: '#6c7086',
            keyword: '#cba6f7', string: '#a6e3a1', fn: '#89b4fa',
            type: '#f9e2af', warning: '#fab387', error: '#f38ba8', indicator: '#cdd6f4'
        },
        'tokyo-night': {
            bg: '#1a1b26', bgDim: '#16161e', bgAlt: '#24283b',
            fg: '#c0caf5', fgDim: '#9aa5ce', comment: '#565f89',
            keyword: '#bb9af7', string: '#9ece6a', fn: '#7aa2f7',
            type: '#2ac3de', warning: '#e0af68', error: '#f7768e', indicator: '#c0caf5'
        },
        'gruvbox-dark': {
            bg: '#282828', bgDim: '#1d2021', bgAlt: '#3c3836',
            fg: '#ebdbb2', fgDim: '#a89984', comment: '#928374',
            keyword: '#fb4934', string: '#b8bb26', fn: '#8ec07c',
            type: '#fabd2f', warning: '#fe8019', error: '#cc241d', indicator: '#ebdbb2'
        },
        'nord': {
            bg: '#2e3440', bgDim: '#242933', bgAlt: '#3b4252',
            fg: '#eceff4', fgDim: '#d8dee9', comment: '#616e88',
            keyword: '#81a1c1', string: '#a3be8c', fn: '#88c0d0',
            type: '#8fbcbb', warning: '#ebcb8b', error: '#bf616a', indicator: '#eceff4'
        }
    };

    const SEPARATORS = {
        vertical: { type: 'pixel', left: '▎', right: '', pixel: 3 },
        bar: { type: 'glyph', left: '│', right: '' },
        thick_bar: { type: 'glyph', left: '┃', right: '' },
        thin: { type: 'pixel', left: '▏', right: '', pixel: 2 },
        thick: { type: 'pixel', left: '▌', right: '', pixel: 5 },
        slant: { type: 'powerline', left: '', right: '' },
        slope: { type: 'powerline', left: '', right: '' },
        padded_slant: { type: 'powerline', left: ' ', right: ' ' },
        none: { type: 'none', left: '', right: '' }
    };

    const state = {
        activeBufferId: 2, // bufferline.el
        separatorStyle: 'vertical',
        indicatorWidth: 3,
        leftMargin: 8,
        topPadding: 0,
        tabPaddingVertical: 4,
        tabPaddingHorizontal: 2,
        iconSpacing: 1,
        sortBy: 'fifo',
        numbersMode: 'none',
        duplicateDepth: 1,
        themePreset: 'ef-autumn',
        fontPreset: 'typus-mono-95',
        showIcons: true,
        showModified: true,
        showReadOnly: true,
        showPinned: true,
        showDuplicates: true,
        showDiagnostics: true,
        showTruncMarkers: true,
        activePkgManager: 'use-package',
        customPalette: null
    };

    const FONT_FAMILIES = {
        'typus-mono-95': "'Typus Mono 95', 'Typus Mono', 'JetBrains Mono', Menlo, monospace",
        'jetbrains-mono': "'JetBrains Mono', 'Typus Mono 95', Menlo, monospace",
        'fira-code': "'Fira Code', 'JetBrains Mono', monospace",
        'cascadia-code': "'Cascadia Code', 'JetBrains Mono', monospace",
        'iosevka': "'Iosevka', 'JetBrains Mono', monospace",
        'source-code-pro': "'Source Code Pro', 'JetBrains Mono', monospace",
        'system-mono': "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace"
    };

    const DOM = {
        emacsFrame: document.getElementById('emacsFrame'),
        bufferlineBar: document.getElementById('bufferlineBar'),
        bufferlineContainer: document.getElementById('bufferlineContainer'),
        editorGutter: document.getElementById('editorGutter'),
        editorContent: document.getElementById('editorContent'),
        
        // form controls
        separatorStyle: document.getElementById('separatorStyle'),
        indicatorWidth: document.getElementById('indicatorWidth'),
        valIndicatorWidth: document.getElementById('valIndicatorWidth'),
        leftMargin: document.getElementById('leftMargin'),
        valLeftMargin: document.getElementById('valLeftMargin'),
        topPadding: document.getElementById('topPadding'),
        valTopPadding: document.getElementById('valTopPadding'),
        tabPaddingVertical: document.getElementById('tabPaddingVertical'),
        valTabPaddingVertical: document.getElementById('valTabPaddingVertical'),
        tabPaddingHorizontal: document.getElementById('tabPaddingHorizontal'),
        valTabPaddingHorizontal: document.getElementById('valTabPaddingHorizontal'),
        iconSpacing: document.getElementById('iconSpacing'),
        valIconSpacing: document.getElementById('valIconSpacing'),
        sortBy: document.getElementById('sortBy'),
        numbersMode: document.getElementById('numbersMode'),
        duplicateDepth: document.getElementById('duplicateDepth'),
        valDuplicateDepth: document.getElementById('valDuplicateDepth'),
        themePreset: document.getElementById('themePreset'),
        fontPreset: document.getElementById('fontPreset'),
        customThemeContainer: document.getElementById('customThemeContainer'),
        customThemeInput: document.getElementById('customThemeInput'),
        btnLoadTheme: document.getElementById('btnLoadTheme'),
        
        // toggles
        showIcons: document.getElementById('showIcons'),
        showModified: document.getElementById('showModified'),
        showReadOnly: document.getElementById('showReadOnly'),
        showPinned: document.getElementById('showPinned'),
        showDuplicates: document.getElementById('showDuplicates'),
        showDiagnostics: document.getElementById('showDiagnostics'),
        showTruncMarkers: document.getElementById('showTruncMarkers'),
        
        // snippet and clipboard
        codeSnippetOutput: document.getElementById('codeSnippetOutput'),
        pkgSwitcher: document.getElementById('pkgSwitcher'),
        btnCopyCode: document.getElementById('btnCopyCode'),
        toastMessage: document.getElementById('toastMessage')
    };

    function applyTheme(themeKey) {
        const palette = state.customPalette || PALETTES[themeKey] || PALETTES['ef-bio'];
        const root = document.documentElement;

        root.style.setProperty('--emacs-bg', palette.bg);
        root.style.setProperty('--emacs-bg-dim', palette.bgDim);
        root.style.setProperty('--emacs-bg-alt', palette.bgAlt);
        root.style.setProperty('--emacs-fg', palette.fg);
        root.style.setProperty('--emacs-fg-dim', palette.fgDim);
        root.style.setProperty('--emacs-comment', palette.comment);
        root.style.setProperty('--emacs-keyword', palette.keyword);
        root.style.setProperty('--emacs-string', palette.string);
        root.style.setProperty('--emacs-fn', palette.fn);
        root.style.setProperty('--emacs-type', palette.type);
        root.style.setProperty('--emacs-warning', palette.warning);
        root.style.setProperty('--emacs-error', palette.error);
        root.style.setProperty('--emacs-indicator', palette.indicator);
    }

    function parseElispTheme(code) {
        const findHex = (pattern) => {
            const match = code.match(pattern);
            return match ? match[1] : null;
        };

        const bg = findHex(/bg-main\s+["'](#[0-9a-fA-F]{6})["']/) ||
              findHex(/background\s+["'](#[0-9a-fA-F]{6})["']/) || '#111111';
        const fg = findHex(/fg-main\s+["'](#[0-9a-fA-F]{6})["']/) ||
              findHex(/foreground\s+["'](#[0-9a-fA-F]{6})["']/) || '#cfdfd5';
        const keyword = findHex(/keyword\s+["'](#[0-9a-fA-F]{6})["']/) || '#00c089';
        const comment = findHex(/comment\s+["'](#[0-9a-fA-F]{6})["']/) || '#b7a07f';
        const string = findHex(/string\s+["'](#[0-9a-fA-F]{6})["']/) || '#af9fff';

        return {
            bg, bgDim: '#222522', bgAlt: '#303230',
            fg, fgDim: '#808f80', comment,
            keyword, string, fn: '#7fc500', type: '#7fcfdf',
            warning: '#cfc04f', error: '#ef6560', indicator: fg
        };
    }

    function getPreparedBuffers() {
        let list = [...MOCK_BUFFERS];

        // detect duplicates
        const counts = {};
        list.forEach(b => counts[b.name] = (counts[b.name] || 0) + 1);

        list = list.map(b => {
            const isDup = counts[b.name] > 1;
            let dirPrefix = '';
            if (isDup && state.showDuplicates) {
                const parts = b.dir.replace(/\/$/, '').split('/').filter(Boolean);
                const depth = Math.min(state.duplicateDepth, parts.length);
                const sliced = parts.slice(parts.length - depth);
                dirPrefix = sliced.length ? sliced.join('/') + '/' : '';
            }
            return { ...b, isDuplicate: isDup, dirPrefix };
        });

        // sort (pinned first)
        list.sort((a, b) => {
            if (a.pinned && !b.pinned) return -1;
            if (!a.pinned && b.pinned) return 1;

            if (state.sortBy === 'name') return a.name.localeCompare(b.name);
            if (state.sortBy === 'extension') {
                const extA = a.name.split('.').pop() || '';
                const extB = b.name.split('.').pop() || '';
                return extA.localeCompare(extB);
            }
            if (state.sortBy === 'directory') return a.dir.localeCompare(b.dir);
            return a.id - b.id; // FIFO
        });

        return list;
    }

    function estimateTabCharWidth(buf, idx) {
        let w = buf.name.length;
        if (buf.dirPrefix) w += buf.dirPrefix.length;
        if (state.showIcons) w += (2 + state.iconSpacing);
        if (state.showPinned && buf.pinned) w += 2;
        if (state.showModified && buf.modified) w += 2;
        if (state.showReadOnly && buf.readOnly) w += 2;
        if (state.showDiagnostics && buf.diags) w += 4;
        if (state.numbersMode === 'ordinal') w += (`${idx + 1}. `).length;
        else if (state.numbersMode === 'buffer-id') w += (`${buf.id}. `).length;
        else if (state.numbersMode === 'both') w += (`${idx + 1}:${buf.id} `).length;
        w += (state.tabPaddingHorizontal + 2);
        return Math.max(8, w);
    }

    function computeVisibleTabs(allBuffers) {
        const containerWidth = DOM.bufferlineContainer.clientWidth || 800;
        const charPx = 9.2; // approx monospace char width at 15px
        const availChars = Math.max(20, Math.floor((containerWidth - state.leftMargin - 20) / charPx));

        if (!state.showTruncMarkers || allBuffers.length <= 1) {
            return { visible: allBuffers, leftCount: 0, rightCount: 0 };
        }

        const activeIdx = Math.max(0, allBuffers.findIndex(b => b.id === state.activeBufferId));
        let before = allBuffers.slice(0, activeIdx);
        const current = [allBuffers[activeIdx]];
        let after = allBuffers.slice(activeIdx + 1);

        let beforeLens = before.map((b, i) => estimateTabCharWidth(b, i));
        const currentLen = estimateTabCharWidth(current[0], activeIdx);
        let afterLens = after.map((b, i) => estimateTabCharWidth(b, activeIdx + 1 + i));

        let leftCount = 0;
        let rightCount = 0;

        const calcTotal = () => {
            const bSum = beforeLens.reduce((a, c) => a + c, 0);
            const aSum = afterLens.reduce((a, c) => a + c, 0);
            const mLeft = leftCount > 0 ? 5 : 0;
            const mRight = rightCount > 0 ? 5 : 0;
            return bSum + currentLen + aSum + mLeft + mRight;
        };

        while ((before.length > 0 || after.length > 0) && calcTotal() > availChars) {
            const bSum = beforeLens.reduce((a, c) => a + c, 0);
            const aSum = afterLens.reduce((a, c) => a + c, 0);

            if (before.length > 0 && (bSum >= aSum || after.length === 0)) {
                before.shift();
                beforeLens.shift();
                leftCount++;
            } else if (after.length > 0) {
                after.pop();
                afterLens.pop();
                rightCount++;
            } else {
                break;
            }
        }

        return {
            visible: [...before, ...current, ...after],
            leftCount,
            rightCount
        };
    }

    function renderTabline() {
        const allBuffers = getPreparedBuffers();
        const { visible, leftCount, rightCount } = computeVisibleTabs(allBuffers);

        DOM.bufferlineBar.innerHTML = '';

        // container top/bottom padding
        DOM.bufferlineContainer.style.paddingTop = `${state.topPadding}px`;
        DOM.bufferlineContainer.style.paddingBottom = `${state.topPadding}px`;

        // left margin
        if (state.leftMargin > 0 && leftCount === 0) {
            const leftGap = document.createElement('div');
            leftGap.style.width = `${state.leftMargin}px`;
            leftGap.style.flexShrink = '0';
            DOM.bufferlineBar.appendChild(leftGap);
        }

        // left overflow arrow
        if (state.showTruncMarkers && leftCount > 0) {
            const leftMarker = document.createElement('div');
            leftMarker.className = 'tab-overflow-marker';
            leftMarker.title = 'Previous hidden buffers (click or S-TAB)';
            leftMarker.innerHTML = `<span class="overflow-count">${leftCount}</span><span class="overflow-arrow"></span>`;
            leftMarker.addEventListener('click', () => cycleBuffer(-1));
            DOM.bufferlineBar.appendChild(leftMarker);
        }

        // render visible tabs
        visible.forEach((buf) => {
            const originalIdx = allBuffers.findIndex(b => b.id === buf.id);
            const isActive = buf.id === state.activeBufferId;
            const tabEl = document.createElement('div');
            tabEl.className = `emacs-tab ${isActive ? 'active' : ''}`;
            tabEl.dataset.id = buf.id;

            // content wrapper
            const contentEl = document.createElement('div');
            contentEl.className = 'tab-content';
            contentEl.style.paddingTop = `${state.tabPaddingVertical}px`;
            contentEl.style.paddingBottom = `${state.tabPaddingVertical}px`;
            contentEl.style.paddingRight = `${state.tabPaddingHorizontal * 8}px`;

            // separator / indicator
            const styleDef = SEPARATORS[state.separatorStyle] || SEPARATORS.vertical;

            if (styleDef.type === 'pixel') {
                const indEl = document.createElement('span');
                indEl.className = 'tab-sep-left pixel-bar';
                const w = (state.separatorStyle === 'thin' ? 2 : (state.separatorStyle === 'thick' ? 5 : state.indicatorWidth));
                indEl.style.width = `${w}px`;
                tabEl.appendChild(indEl);
            } else if (styleDef.type === 'glyph') {
                const indEl = document.createElement('span');
                indEl.className = 'tab-sep-left glyph';
                indEl.textContent = styleDef.left;
                indEl.style.color = isActive ? 'var(--emacs-indicator)' : 'var(--emacs-comment)';
                tabEl.appendChild(indEl);
            } else if (styleDef.type === 'powerline') {
                const indEl = document.createElement('span');
                indEl.className = 'tab-sep-left glyph';
                indEl.textContent = styleDef.left;
                indEl.style.color = isActive ? 'var(--emacs-bg)' : 'var(--emacs-bg-dim)';
                indEl.style.backgroundColor = 'var(--emacs-bg-alt)';
                tabEl.appendChild(indEl);
            }

            // pin icon
            if (state.showPinned && buf.pinned) {
                const pin = document.createElement('span');
                pin.className = 'tab-pin-icon';
                pin.textContent = '';
                contentEl.appendChild(pin);
            }

            // file icon
            const icon = document.createElement('span');
            icon.className = 'tab-file-icon';
            if (state.showIcons && buf.icon) {
                icon.textContent = buf.icon;
                icon.style.color = buf.iconColor || 'var(--emacs-fg)';
            } else {
                icon.style.width = '8px';
            }
            contentEl.appendChild(icon);

            // label: number prefix + directory prefix + base name
            const label = document.createElement('span');
            label.className = 'tab-label';
            label.style.marginLeft = `${state.iconSpacing * 8}px`;

            if (state.numbersMode !== 'none') {
                const num = document.createElement('span');
                num.className = 'tab-num-prefix';
                if (state.numbersMode === 'ordinal') num.textContent = `${originalIdx + 1}. `;
                else if (state.numbersMode === 'buffer-id') num.textContent = `${buf.id}. `;
                else if (state.numbersMode === 'both') num.textContent = `${originalIdx + 1}:${buf.id} `;
                label.appendChild(num);
            }

            if (buf.dirPrefix) {
                const dir = document.createElement('span');
                dir.className = 'tab-dir-prefix';
                dir.textContent = buf.dirPrefix;
                label.appendChild(dir);
            }

            const name = document.createElement('span');
            name.className = 'tab-base-name';
            name.textContent = buf.name;
            label.appendChild(name);

            contentEl.appendChild(label);

            // read-only
            if (state.showReadOnly && buf.readOnly) {
                const ro = document.createElement('span');
                ro.className = 'tab-ro-icon';
                ro.textContent = '';
                contentEl.appendChild(ro);
            }

            // modified
            if (state.showModified && buf.modified) {
                const mod = document.createElement('span');
                mod.className = 'tab-mod-icon';
                mod.textContent = '●';
                contentEl.appendChild(mod);
            }

            // diagnostics
            if (state.showDiagnostics && buf.diags) {
                const isError = buf.diags.err > 0;
                const diag = document.createElement('span');
                diag.className = `tab-diag-badge ${isError ? 'error' : 'warning'}`;

                const diagIcon = document.createElement('span');
                diagIcon.className = 'diag-icon';
                diagIcon.textContent = isError ? '' : '';
                diag.appendChild(diagIcon);

                const diagCount = document.createElement('span');
                diagCount.className = 'diag-count';
                diagCount.textContent = `${isError ? buf.diags.err : buf.diags.warn}`;
                diag.appendChild(diagCount);

                contentEl.appendChild(diag);
            }

            tabEl.appendChild(contentEl);

            // right separator
            if (styleDef.type === 'powerline' && styleDef.right) {
                const rightSepEl = document.createElement('span');
                rightSepEl.className = 'tab-sep-right glyph';
                rightSepEl.textContent = styleDef.right;
                rightSepEl.style.color = isActive ? 'var(--emacs-bg)' : 'var(--emacs-bg-dim)';
                rightSepEl.style.backgroundColor = 'var(--emacs-bg-alt)';
                tabEl.appendChild(rightSepEl);
            }

            // tab selection click
            tabEl.addEventListener('click', () => {
                state.activeBufferId = buf.id;
                renderAll();
            });

            DOM.bufferlineBar.appendChild(tabEl);
        });

        // right overflow arrow
        if (state.showTruncMarkers && rightCount > 0) {
            const rightMarker = document.createElement('div');
            rightMarker.className = 'tab-overflow-marker';
            rightMarker.title = 'Next hidden buffers (click or TAB)';
            rightMarker.innerHTML = `<span class="overflow-arrow"></span><span class="overflow-count">${rightCount}</span>`;
            rightMarker.addEventListener('click', () => cycleBuffer(1));
            DOM.bufferlineBar.appendChild(rightMarker);
        }
    }

    function cycleBuffer(direction) {
        const buffers = getPreparedBuffers();
        const currentIdx = buffers.findIndex(b => b.id === state.activeBufferId);
        let nextIdx = (currentIdx + direction + buffers.length) % buffers.length;
        state.activeBufferId = buffers[nextIdx].id;
        renderAll();
    }

    function renderEditor() {
        const activeBuf = MOCK_BUFFERS.find(b => b.id === state.activeBufferId) || MOCK_BUFFERS[0];
        const lines = activeBuf.code.split('\n');
        DOM.editorGutter.innerHTML = lines.map((_, i) => `<div>${i + 1}</div>`).join('');

        const highlighted = lines.map(line => {
            let l = line.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
            if (l.trim().startsWith(';')) return `<span class="syn-comment">${l}</span>`;
            l = l.replace(/\b(use-package|require|define-minor-mode|provide|int|void|return|pub|struct|use|fn|const|let)\b/g, '<span class="syn-keyword">$1</span>');
            l = l.replace(/\b([a-zA-Z0-9_-]+)(?=\()/g, '<span class="syn-fn">$1</span>');
            l = l.replace(/(["'][^"']*["'])/g, '<span class="syn-string">$1</span>');
            return l;
        }).join('\n');

        DOM.editorContent.innerHTML = `<pre><code>${highlighted}</code></pre>`;
    }

    function generateElispCode() {
        const customLines = [];
        if (state.separatorStyle !== 'vertical') customLines.push(`  (bufferline-separator-style '${state.separatorStyle})`);
        if (state.indicatorWidth !== 3) customLines.push(`  (bufferline-indicator-width ${state.indicatorWidth})`);
        if (state.leftMargin !== 8) customLines.push(`  (bufferline-left-margin ${state.leftMargin})`);
        if (state.topPadding !== 0) customLines.push(`  (bufferline-top-padding ${state.topPadding})`);
        if (state.tabPaddingVertical !== 4) customLines.push(`  (bufferline-tab-padding-vertical ${state.tabPaddingVertical})`);
        if (state.tabPaddingHorizontal !== 2) customLines.push(`  (bufferline-tab-padding-horizontal ${state.tabPaddingHorizontal})`);
        if (state.iconSpacing !== 1) customLines.push(`  (bufferline-icon-spacing ${state.iconSpacing})`);
        if (state.sortBy !== 'fifo') customLines.push(`  (bufferline-sort-by '${state.sortBy})`);
        if (state.numbersMode !== 'none') customLines.push(`  (bufferline-numbers '${state.numbersMode})`);
        if (state.duplicateDepth !== 1) customLines.push(`  (bufferline-duplicate-prefix-depth ${state.duplicateDepth})`);
        if (!state.showIcons) customLines.push('  (bufferline-show-buffer-icons nil)');
        if (!state.showModified) customLines.push('  (bufferline-show-modified nil)');
        if (!state.showReadOnly) customLines.push('  (bufferline-show-read-only nil)');
        if (!state.showPinned) customLines.push('  (bufferline-show-pinned nil)');
        if (!state.showDuplicates) customLines.push('  (bufferline-show-duplicate-prefix nil)');
        if (state.showDiagnostics) customLines.push('  (bufferline-show-diagnostics t)');
        if (!state.showTruncMarkers) customLines.push('  (bufferline-show-trunc-markers nil)');

        const lines = [];
        lines.push('(use-package bufferline');
        if (state.activePkgManager === 'use-package') {
            lines.push('  :ensure t');
        } else if (state.activePkgManager === 'package-vc') {
            lines.push('  :vc (:url "https://github.com/szymonwilczek/bufferline.el")');
        } else if (state.activePkgManager === 'elpaca') {
            lines.push('  :ensure (:host github :repo "szymonwilczek/bufferline.el")');
        } else if (state.activePkgManager === 'straight') {
            lines.push('  :straight (:host github :repo "szymonwilczek/bufferline.el")');
        }

        if (customLines.length > 0) {
            lines.push('  :custom');
            lines.push(...customLines);
        }

        lines.push('  :config');
        lines.push('  (global-bufferline-mode 1))');

        DOM.codeSnippetOutput.textContent = lines.join('\n');
    }

    function renderAll() {
        renderTabline();
        renderEditor();
        generateElispCode();
    }

    function initListeners() {
        // keyboard navigation
        window.addEventListener('keydown', (e) => {
            if (document.activeElement === DOM.customThemeInput) return;
            if (e.key === 'Tab') {
                e.preventDefault();
                cycleBuffer(e.shiftKey ? -1 : 1);
            }
        });

        // responsive tabline recalculation
        window.addEventListener('resize', () => {
            renderTabline();
        });

        DOM.separatorStyle.addEventListener('change', (e) => {
            state.separatorStyle = e.target.value;
            renderAll();
        });

        DOM.indicatorWidth.addEventListener('input', (e) => {
            state.indicatorWidth = parseInt(e.target.value, 10);
            DOM.valIndicatorWidth.textContent = `${state.indicatorWidth}px`;
            renderAll();
        });

        DOM.leftMargin.addEventListener('input', (e) => {
            state.leftMargin = parseInt(e.target.value, 10);
            DOM.valLeftMargin.textContent = `${state.leftMargin}px`;
            renderAll();
        });

        DOM.topPadding.addEventListener('input', (e) => {
            state.topPadding = parseInt(e.target.value, 10);
            DOM.valTopPadding.textContent = `${state.topPadding}px`;
            renderAll();
        });

        DOM.tabPaddingVertical.addEventListener('input', (e) => {
            state.tabPaddingVertical = parseInt(e.target.value, 10);
            DOM.valTabPaddingVertical.textContent = `${state.tabPaddingVertical}px`;
            renderAll();
        });

        DOM.tabPaddingHorizontal.addEventListener('input', (e) => {
            state.tabPaddingHorizontal = parseInt(e.target.value, 10);
            DOM.valTabPaddingHorizontal.textContent = `${state.tabPaddingHorizontal} sp`;
            renderAll();
        });

        DOM.iconSpacing.addEventListener('input', (e) => {
            state.iconSpacing = parseInt(e.target.value, 10);
            DOM.valIconSpacing.textContent = `${state.iconSpacing} sp`;
            renderAll();
        });

        DOM.sortBy.addEventListener('change', (e) => {
            state.sortBy = e.target.value;
            renderAll();
        });

        DOM.numbersMode.addEventListener('change', (e) => {
            state.numbersMode = e.target.value;
            renderAll();
        });

        DOM.duplicateDepth.addEventListener('input', (e) => {
            state.duplicateDepth = parseInt(e.target.value, 10);
            DOM.valDuplicateDepth.textContent = `${state.duplicateDepth}`;
            renderAll();
        });

        // theme preset
        DOM.themePreset.addEventListener('change', (e) => {
            state.themePreset = e.target.value;
            if (state.themePreset === 'custom') {
                DOM.customThemeContainer.classList.remove('hidden');
            } else {
                DOM.customThemeContainer.classList.add('hidden');
                state.customPalette = null;
                applyTheme(state.themePreset);
            }
            renderAll();
        });

        // font family preset
        DOM.fontPreset.addEventListener('change', (e) => {
            state.fontPreset = e.target.value;
            const stack = FONT_FAMILIES[state.fontPreset] || FONT_FAMILIES['typus-mono-95'];
            document.documentElement.style.setProperty('--font-mono', stack);
            renderAll();
        });

        // custom theme loader
        DOM.btnLoadTheme.addEventListener('click', async () => {
            const input = DOM.customThemeInput.value.trim();
            if (!input) return;

            if (input.startsWith('http://') || input.startsWith('https://')) {
                try {
                    const res = await fetch(input);
                    const text = await res.text();
                    state.customPalette = parseElispTheme(text);
                    applyTheme('custom');
                    renderAll();
                    showToast('Custom theme loaded from URL.');
                } catch (err) {
                    alert('Could not fetch theme from URL (CORS restricted). You can paste the raw elisp code directly into the field.');
                }
            } else {
                state.customPalette = parseElispTheme(input);
                applyTheme('custom');
                renderAll();
                showToast('Custom theme applied.');
            }
        });

        const toggleMap = [
            { el: DOM.showIcons, prop: 'showIcons' },
            { el: DOM.showModified, prop: 'showModified' },
            { el: DOM.showReadOnly, prop: 'showReadOnly' },
            { el: DOM.showPinned, prop: 'showPinned' },
            { el: DOM.showDuplicates, prop: 'showDuplicates' },
            { el: DOM.showDiagnostics, prop: 'showDiagnostics' },
            { el: DOM.showTruncMarkers, prop: 'showTruncMarkers' }
        ];

        toggleMap.forEach(({ el, prop }) => {
            el.addEventListener('change', (e) => {
                state[prop] = e.target.checked;
                renderAll();
            });
        });

        // Package Switcher Tabs
        DOM.pkgSwitcher.addEventListener('click', (e) => {
            const btn = e.target.closest('.pkg-btn');
            if (!btn) return;
            DOM.pkgSwitcher.querySelectorAll('.pkg-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.activePkgManager = btn.dataset.pkg;
            generateElispCode();
        });

        // Copy to Clipboard
        DOM.btnCopyCode.addEventListener('click', () => {
            const code = DOM.codeSnippetOutput.textContent;
            navigator.clipboard.writeText(code).then(() => {
                showToast('Configuration copied to clipboard.');
            });
        });
    }

    function showToast(msg) {
        DOM.toastMessage.textContent = msg;
        DOM.toastMessage.classList.add('show');
        setTimeout(() => {
            DOM.toastMessage.classList.remove('show');
        }, 2200);
    }

    // ==========================================================================
    // Init
    // ==========================================================================
    function init() {
        applyTheme(state.themePreset);
        initListeners();
        renderAll();
    }

    document.addEventListener('DOMContentLoaded', init);
})();
