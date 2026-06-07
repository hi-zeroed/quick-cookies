import Foundation

enum MarkdownRendererRuntime {
    static func visibleRuntimeScript() -> String {
        #"""
        (function () {
            const bridgeState = {
                virtualize: false,
                overscanScreens: 4,
                blockOrder: [],
                blockWrappers: new Map(),
                blockHTML: new Map(),
                blockHeights: new Map(),
                rafToken: 0,
                continuationRequestPending: false,
                shellReusePhaseHook: null
            };

            const contentEl = function () {
                return document.getElementById('content');
            };

            const postMessage = function (name, body) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
                    window.webkit.messageHandlers[name].postMessage(body);
                }
            };

            const hasMeaningfulSelection = function () {
                const selection = window.getSelection();
                return !!selection && !selection.isCollapsed && selection.toString().trim().length > 0;
            };

            const notifySelectionState = function () {
                postMessage('markdownSelectionStateChanged', hasMeaningfulSelection());
            };

            const notifyBootstrapReady = function () {
                postMessage('markdownBootstrapReady', true);
            };

            const notifyShellReusePhase = function (phase) {
                if (typeof bridgeState.shellReusePhaseHook !== 'function') {
                    return;
                }

                try {
                    bridgeState.shellReusePhaseHook(phase);
                } catch (error) {
                    // Ignore instrumentation errors so preview rendering still completes.
                }
            };

            const scheduleVirtualization = function () {
                if (bridgeState.rafToken) {
                    cancelAnimationFrame(bridgeState.rafToken);
                }
                bridgeState.rafToken = requestAnimationFrame(runVirtualization);
            };

            const maybeRequestMore = function () {
                if (bridgeState.continuationRequestPending) {
                    return;
                }

                const content = contentEl();
                if (!content) {
                    return;
                }

                const scrollHeight = Math.max(
                    content.scrollHeight || 0,
                    document.documentElement ? document.documentElement.scrollHeight || 0 : 0,
                    document.body ? document.body.scrollHeight || 0 : 0
                );
                const viewportBottom = window.scrollY + window.innerHeight;
                const remainingDistance = scrollHeight - viewportBottom;
                const threshold = Math.max(window.innerHeight * 1.5, 720);

                if (remainingDistance > threshold) {
                    return;
                }

                bridgeState.continuationRequestPending = true;
                postMessage('markdownContinuationRequested', {
                    viewportBottom: viewportBottom,
                    scrollHeight: scrollHeight,
                    remainingDistance: remainingDistance
                });
            };

            const measureWrapper = function (wrapper) {
                if (!wrapper) {
                    return;
                }

                const body = wrapper.querySelector('.markdown-block-body');
                if (!body || wrapper.dataset.virtualized === 'true') {
                    return;
                }

                const measured = body.getBoundingClientRect().height || body.scrollHeight || body.offsetHeight || 0;
                if (measured > 0) {
                    const id = wrapper.dataset.blockId;
                    bridgeState.blockHeights.set(id, measured);
                    wrapper.style.minHeight = Math.ceil(measured) + 'px';
                    wrapper.dataset.blockHeight = String(measured);
                }
            };

            const highlightCodeBlock = function (codeEl, languageHint) {
                if (typeof hljs === 'undefined' || !codeEl) {
                    return;
                }

                const rawText = codeEl.textContent || '';

                try {
                    if (languageHint && hljs.getLanguage(languageHint)) {
                        const highlighted = hljs.highlight(rawText, {
                            language: languageHint,
                            ignoreIllegals: true
                        });
                        codeEl.innerHTML = highlighted.value;
                        codeEl.classList.add('hljs');
                        codeEl.classList.add('language-' + languageHint);
                        return;
                    }

                    const autoHighlighted = hljs.highlightAuto(rawText);
                    codeEl.innerHTML = autoHighlighted.value;
                    codeEl.classList.add('hljs');
                    if (autoHighlighted.language) {
                        codeEl.classList.add('language-' + autoHighlighted.language);
                    }
                } catch (error) {
                    codeEl.textContent = rawText;
                }
            };

            const applyImageMetadata = function (root, block) {
                if (!block.imageMetas || !Array.isArray(block.imageMetas) || block.imageMetas.length === 0) {
                    return;
                }

                const isLikelyLocalImageSource = function (source) {
                    if (!source) {
                        return false;
                    }

                    return !/^(?:https?:|data:|blob:)/i.test(source);
                };

                const metasBySource = new Map();
                block.imageMetas.forEach(function (meta) {
                    metasBySource.set(meta.source, meta);
                });

                root.querySelectorAll('img').forEach(function (img) {
                    const source = img.getAttribute('src') || '';
                    const meta = metasBySource.get(source);
                    const explicitWidth = img.getAttribute('width');
                    const explicitHeight = img.getAttribute('height');
                    if (meta && meta.resolvedSourceURL) {
                        img.setAttribute('src', meta.resolvedSourceURL);
                    }
                    if (isLikelyLocalImageSource(source)) {
                        // Relative/file-backed assets are part of the previewed
                        // document itself, so delaying them behind lazy-loading
                        // can leave README-style hero images permanently blank
                        // in WKWebView even though the src resolves correctly.
                        img.setAttribute('loading', 'eager');
                        img.setAttribute('decoding', 'sync');
                    } else {
                        img.setAttribute('loading', 'lazy');
                        img.setAttribute('decoding', 'async');
                    }
                    img.addEventListener('error', function () {
                        img.classList.add('qc-image-broken');
                        img.removeAttribute('width');
                        img.removeAttribute('height');
                        img.style.aspectRatio = 'auto';
                    }, { once: true });

                    if (!meta) {
                        return;
                    }

                    if (meta.width && meta.height && !explicitWidth && !explicitHeight) {
                        img.setAttribute('width', String(meta.width));
                        img.setAttribute('height', String(meta.height));
                        img.style.aspectRatio = meta.width + ' / ' + meta.height;
                    } else if (explicitWidth && explicitHeight) {
                        img.style.aspectRatio = explicitWidth + ' / ' + explicitHeight;
                    }
                });
            };

            const stabilizeTables = function (root) {
                root.querySelectorAll('table').forEach(function (table) {
                    if (table.parentElement && table.parentElement.classList.contains('qc-table-wrap')) {
                        return;
                    }

                    const wrapper = document.createElement('div');
                    wrapper.className = 'qc-table-wrap';
                    table.parentNode.insertBefore(wrapper, table);
                    wrapper.appendChild(table);
                });
            };

            const renderBlockHTML = function (block) {
                const host = document.createElement('div');
                host.innerHTML = marked.parse(block.markdown || '');

                applyImageMetadata(host, block);
                stabilizeTables(host);

                host.querySelectorAll('pre code').forEach(function (codeEl) {
                    highlightCodeBlock(codeEl, block.codeLanguage || null);
                });

                return host.innerHTML;
            };

            const buildBlockWrapper = function (block) {
                const wrapper = document.createElement('section');
                wrapper.className = 'markdown-block-shell';
                wrapper.dataset.blockId = block.id;
                wrapper.dataset.kind = block.kind;
                wrapper.dataset.virtualized = 'false';

                if (block.preferredHeight) {
                    wrapper.style.minHeight = Math.ceil(Number(block.preferredHeight)) + 'px';
                }

                const body = document.createElement('div');
                body.className = 'markdown-block-body';
                body.innerHTML = renderBlockHTML(block);
                wrapper.appendChild(body);

                bridgeState.blockHTML.set(block.id, body.innerHTML);
                return wrapper;
            };

            const renderBatchFragment = function (batch) {
                if (!batch || !Array.isArray(batch.blocks) || batch.blocks.length === 0) {
                    return null;
                }

                const fragment = document.createDocumentFragment();
                batch.blocks.forEach(function (block) {
                    const wrapper = buildBlockWrapper(block);
                    bridgeState.blockOrder.push(block.id);
                    bridgeState.blockWrappers.set(block.id, wrapper);
                    fragment.appendChild(wrapper);
                });

                return fragment;
            };

            const measureAllRenderedBlocks = function () {
                bridgeState.blockOrder.forEach(function (id) {
                    const wrapper = bridgeState.blockWrappers.get(id);
                    if (wrapper) {
                        measureWrapper(wrapper);
                    }
                });
            };

            const appendBlocks = function (batch, options) {
                if (!batch || !Array.isArray(batch.blocks) || batch.blocks.length === 0) {
                    return;
                }

                const settings = options || {};
                const fragment = renderBatchFragment(batch);
                if (!fragment) {
                    return;
                }

                contentEl().appendChild(fragment);
                measureAllRenderedBlocks();

                bridgeState.continuationRequestPending = false;
                scheduleVirtualization();

                if (settings.notifyReady) {
                    notifyBootstrapReady();
                }

                if (settings.requestMore !== false) {
                    requestAnimationFrame(maybeRequestMore);
                }
            };

            const registerBootstrapSnapshot = function (snapshot) {
                bridgeState.blockOrder = Array.isArray(snapshot && snapshot.blockOrder) ? snapshot.blockOrder.slice() : [];
                bridgeState.blockWrappers = new Map();
                bridgeState.blockHTML = new Map();
                bridgeState.blockHeights = new Map();
                bridgeState.virtualize = !!(snapshot && snapshot.shouldVirtualize);
                bridgeState.overscanScreens = Math.max(2, Number(snapshot && snapshot.overscanScreens) || 4);

                const content = contentEl();
                if (!content) {
                    return;
                }

                if (snapshot && snapshot.renderedBlocks) {
                    snapshot.renderedBlocks.forEach(function (block) {
                        bridgeState.blockHTML.set(block.id, block.html || '');
                        if (typeof block.height === 'number' && block.height > 0) {
                            bridgeState.blockHeights.set(block.id, block.height);
                        }
                    });
                }

                if (snapshot && snapshot.blockHeights) {
                    Object.keys(snapshot.blockHeights).forEach(function (id) {
                        const height = Number(snapshot.blockHeights[id]) || 0;
                        if (height > 0) {
                            bridgeState.blockHeights.set(id, height);
                        }
                    });
                }

                const renderedIntoEmptyContent = content.querySelectorAll('.markdown-block-shell').length === 0;

                if (renderedIntoEmptyContent && snapshot && snapshot.renderedBlocks) {
                    const fragment = document.createDocumentFragment();
                    snapshot.renderedBlocks.forEach(function (block) {
                        const wrapper = document.createElement('section');
                        wrapper.className = 'markdown-block-shell';
                        wrapper.dataset.blockId = block.id;
                        wrapper.dataset.kind = block.kind;
                        wrapper.dataset.virtualized = 'false';

                        const resolvedHeight = block.height || bridgeState.blockHeights.get(block.id) || 0;
                        if (resolvedHeight > 0) {
                            wrapper.style.minHeight = Math.ceil(resolvedHeight) + 'px';
                            wrapper.dataset.blockHeight = String(resolvedHeight);
                        }

                        const body = document.createElement('div');
                        body.className = 'markdown-block-body';
                        body.innerHTML = block.html || '';
                        wrapper.appendChild(body);
                        bridgeState.blockWrappers.set(block.id, wrapper);
                        bridgeState.blockHTML.set(block.id, body.innerHTML);
                        fragment.appendChild(wrapper);
                    });
                    notifyShellReusePhase('bootstrap-render');
                    content.appendChild(fragment);
                    notifyShellReusePhase('bootstrap-attach');
                } else {
                    notifyShellReusePhase('bootstrap-render');
                    notifyShellReusePhase('bootstrap-attach');
                }

                if (!renderedIntoEmptyContent) {
                    content.querySelectorAll('.markdown-block-shell').forEach(function (wrapper) {
                        const id = wrapper.dataset.blockId;
                        if (!id) {
                            return;
                        }

                        bridgeState.blockWrappers.set(id, wrapper);

                        const body = wrapper.querySelector('.markdown-block-body');
                        if (body) {
                            bridgeState.blockHTML.set(id, body.innerHTML);
                        }

                        const snapshotHeight = bridgeState.blockHeights.get(id);
                        if (snapshotHeight) {
                            wrapper.style.minHeight = Math.ceil(snapshotHeight) + 'px';
                            wrapper.dataset.blockHeight = String(snapshotHeight);
                        }
                    });
                }

                notifyShellReusePhase('bootstrap-measure');
                scheduleVirtualization();
                notifyShellReusePhase('bootstrap-post');
                notifyBootstrapReady();
            };

            const restoreBlock = function (wrapper, id) {
                if (wrapper.dataset.virtualized !== 'true') {
                    measureWrapper(wrapper);
                    return;
                }

                let body = wrapper.querySelector('.markdown-block-body');
                if (!body) {
                    body = document.createElement('div');
                    body.className = 'markdown-block-body';
                    wrapper.appendChild(body);
                }

                body.innerHTML = bridgeState.blockHTML.get(id) || '';
                wrapper.dataset.virtualized = 'false';
                measureWrapper(wrapper);
            };

            const virtualizeBlock = function (wrapper, id, height) {
                if (wrapper.dataset.virtualized === 'true') {
                    return;
                }

                const body = wrapper.querySelector('.markdown-block-body');
                if (!body) {
                    return;
                }

                bridgeState.blockHTML.set(id, body.innerHTML);
                body.innerHTML = '';
                wrapper.dataset.virtualized = 'true';
                wrapper.style.minHeight = Math.ceil(height) + 'px';
                wrapper.dataset.blockHeight = String(height);
            };

            const restoreAllBlocks = function () {
                bridgeState.blockOrder.forEach(function (id) {
                    const wrapper = bridgeState.blockWrappers.get(id);
                    if (wrapper) {
                        restoreBlock(wrapper, id);
                    }
                });
            };

            const runVirtualization = function () {
                bridgeState.rafToken = 0;

                bridgeState.blockOrder.forEach(function (id) {
                    const wrapper = bridgeState.blockWrappers.get(id);
                    if (wrapper) {
                        measureWrapper(wrapper);
                    }
                });

                if (!bridgeState.virtualize) {
                    restoreAllBlocks();
                    return;
                }

                const viewportTop = window.scrollY;
                const viewportBottom = viewportTop + window.innerHeight;
                const overscan = window.innerHeight * bridgeState.overscanScreens;

                bridgeState.blockOrder.forEach(function (id) {
                    const wrapper = bridgeState.blockWrappers.get(id);
                    if (!wrapper) {
                        return;
                    }

                    const height = bridgeState.blockHeights.get(id) || Number(wrapper.dataset.blockHeight) || wrapper.offsetHeight || 44;
                    const top = wrapper.offsetTop;
                    const bottom = top + height;
                    const shouldKeep = bottom >= (viewportTop - overscan) && top <= (viewportBottom + overscan);

                    if (shouldKeep) {
                        restoreBlock(wrapper, id);
                    } else {
                        virtualizeBlock(wrapper, id, height);
                    }
                });
            };

            window.__quickCookiesMarkdown = {
                bootstrapSnapshot: function (snapshot) {
                    registerBootstrapSnapshot(snapshot || {});
                },
                bootstrapBatch: function (batch) {
                    bridgeState.blockOrder = [];
                    bridgeState.blockWrappers = new Map();
                    bridgeState.blockHTML = new Map();
                    bridgeState.blockHeights = new Map();
                    bridgeState.continuationRequestPending = false;
                    contentEl().innerHTML = '';
                    if (!batch || !Array.isArray(batch.blocks) || batch.blocks.length === 0) {
                        notifyShellReusePhase('bootstrap-render');
                        notifyShellReusePhase('bootstrap-attach');
                        notifyShellReusePhase('bootstrap-measure');
                        notifyShellReusePhase('bootstrap-post');
                        appendBlocks(batch, {
                            notifyReady: true,
                            requestMore: false
                        });
                        return;
                    }

                    const fragment = renderBatchFragment(batch);
                    notifyShellReusePhase('bootstrap-render');
                    if (fragment) {
                        contentEl().appendChild(fragment);
                    }
                    notifyShellReusePhase('bootstrap-attach');
                    measureAllRenderedBlocks();
                    notifyShellReusePhase('bootstrap-measure');
                    bridgeState.continuationRequestPending = false;
                    scheduleVirtualization();
                    notifyShellReusePhase('bootstrap-post');
                    notifyBootstrapReady();
                },
                configure: function (options) {
                    bridgeState.virtualize = !!(options && options.virtualize);
                    bridgeState.overscanScreens = Math.max(2, Number(options && options.overscanScreens) || bridgeState.overscanScreens || 4);
                    scheduleVirtualization();
                },
                setShellReusePhaseHook: function (hook) {
                    bridgeState.shellReusePhaseHook = typeof hook === 'function' ? hook : null;
                },
                reset: function () {
                    bridgeState.blockOrder = [];
                    bridgeState.blockWrappers = new Map();
                    bridgeState.blockHTML = new Map();
                    bridgeState.blockHeights = new Map();
                    bridgeState.continuationRequestPending = false;
                    if (bridgeState.rafToken) {
                        cancelAnimationFrame(bridgeState.rafToken);
                        bridgeState.rafToken = 0;
                    }
                    contentEl().innerHTML = '';
                },
                appendBatch: function (batch) {
                    appendBlocks(batch, { requestMore: true });
                },
                requestMoreIfNeeded: function () {
                    bridgeState.continuationRequestPending = false;
                    maybeRequestMore();
                },
                markContinuationComplete: function () {
                    bridgeState.continuationRequestPending = true;
                },
                refreshTheme: function () {
                    scheduleVirtualization();
                }
            };

            document.addEventListener('selectionchange', notifySelectionState);
            document.addEventListener('mouseup', notifySelectionState);
            document.addEventListener('keyup', notifySelectionState);
            document.addEventListener('contextmenu', function (event) {
                notifySelectionState();

                if (!hasMeaningfulSelection()) {
                    event.preventDefault();
                    event.stopPropagation();
                    event.stopImmediatePropagation();
                }
            }, true);

            window.addEventListener('scroll', function () {
                scheduleVirtualization();
                maybeRequestMore();
            }, { passive: true });
            window.addEventListener('resize', function () {
                scheduleVirtualization();
                maybeRequestMore();
            });

            if (window.bootstrapSnapshot) {
                registerBootstrapSnapshot(window.bootstrapSnapshot);
            }

            requestAnimationFrame(notifySelectionState);
            requestAnimationFrame(maybeRequestMore);
        })();
        """#
    }

    static func prerenderRuntimeScript() -> String {
        #"""
        (function () {
            const contentEl = function () {
                return document.getElementById('content');
            };

            const highlightCodeBlock = function (codeEl, languageHint) {
                if (typeof hljs === 'undefined' || !codeEl) {
                    return;
                }

                const rawText = codeEl.textContent || '';

                try {
                    if (languageHint && hljs.getLanguage(languageHint)) {
                        const highlighted = hljs.highlight(rawText, {
                            language: languageHint,
                            ignoreIllegals: true
                        });
                        codeEl.innerHTML = highlighted.value;
                        codeEl.classList.add('hljs');
                        codeEl.classList.add('language-' + languageHint);
                        return;
                    }

                    const autoHighlighted = hljs.highlightAuto(rawText);
                    codeEl.innerHTML = autoHighlighted.value;
                    codeEl.classList.add('hljs');
                    if (autoHighlighted.language) {
                        codeEl.classList.add('language-' + autoHighlighted.language);
                    }
                } catch (error) {
                    codeEl.textContent = rawText;
                }
            };

            const applyImageMetadata = function (root, block) {
                if (!block.imageMetas || !Array.isArray(block.imageMetas) || block.imageMetas.length === 0) {
                    return;
                }

                const metasBySource = new Map();
                block.imageMetas.forEach(function (meta) {
                    metasBySource.set(meta.source, meta);
                });

                root.querySelectorAll('img').forEach(function (img) {
                    const source = img.getAttribute('src') || '';
                    const meta = metasBySource.get(source);
                    const explicitWidth = img.getAttribute('width');
                    const explicitHeight = img.getAttribute('height');
                    if (meta && meta.resolvedSourceURL) {
                        img.setAttribute('src', meta.resolvedSourceURL);
                    }
                    img.setAttribute('loading', 'eager');
                    img.setAttribute('decoding', 'sync');

                    if (!meta) {
                        return;
                    }

                    if (meta.width && meta.height && !explicitWidth && !explicitHeight) {
                        img.setAttribute('width', String(meta.width));
                        img.setAttribute('height', String(meta.height));
                        img.style.aspectRatio = meta.width + ' / ' + meta.height;
                    } else if (explicitWidth && explicitHeight) {
                        img.style.aspectRatio = explicitWidth + ' / ' + explicitHeight;
                    }
                });
            };

            const stabilizeTables = function (root) {
                root.querySelectorAll('table').forEach(function (table) {
                    if (table.parentElement && table.parentElement.classList.contains('qc-table-wrap')) {
                        return;
                    }

                    const wrapper = document.createElement('div');
                    wrapper.className = 'qc-table-wrap';
                    table.parentNode.insertBefore(wrapper, table);
                    wrapper.appendChild(table);
                });
            };

            const renderBlockHTML = function (block) {
                const host = document.createElement('div');
                host.innerHTML = marked.parse(block.markdown || '');

                applyImageMetadata(host, block);
                stabilizeTables(host);

                host.querySelectorAll('pre code').forEach(function (codeEl) {
                    highlightCodeBlock(codeEl, block.codeLanguage || null);
                });

                return host.innerHTML;
            };

            window.__quickCookiesMarkdownPrerender = {
                renderSnapshot: function (payload) {
                    const container = contentEl();
                    container.innerHTML = '';

                    const renderedBlocks = [];
                    const blockOrder = [];
                    const blockHeights = {};
                    const fragment = document.createDocumentFragment();

                    (payload.blocks || []).forEach(function (block) {
                        const wrapper = document.createElement('section');
                        wrapper.className = 'markdown-block-shell';
                        wrapper.dataset.blockId = block.id;
                        wrapper.dataset.kind = block.kind;
                        wrapper.dataset.virtualized = 'false';

                        const body = document.createElement('div');
                        body.className = 'markdown-block-body';
                        body.innerHTML = renderBlockHTML(block);
                        wrapper.appendChild(body);

                        fragment.appendChild(wrapper);
                        blockOrder.push(block.id);
                        renderedBlocks.push({
                            id: block.id,
                            kind: block.kind,
                            html: body.innerHTML,
                            height: null
                        });
                    });

                    container.appendChild(fragment);

                    renderedBlocks.forEach(function (renderedBlock) {
                        const selector = '.markdown-block-shell[data-block-id="' + renderedBlock.id.replace(/"/g, '\\"') + '"]';
                        const wrapper = container.querySelector(selector);
                        if (!wrapper) {
                            return;
                        }

                        const body = wrapper.querySelector('.markdown-block-body');
                        const measured = body
                            ? (body.getBoundingClientRect().height || body.scrollHeight || body.offsetHeight || 0)
                            : 0;

                        if (measured > 0) {
                            renderedBlock.height = measured;
                            blockHeights[renderedBlock.id] = measured;
                            wrapper.style.minHeight = Math.ceil(measured) + 'px';
                            wrapper.dataset.blockHeight = String(measured);
                        }
                    });

                    return JSON.stringify({
                        renderedBlocks: renderedBlocks,
                        blockOrder: blockOrder,
                        blockHeights: blockHeights,
                        shouldVirtualize: !!payload.shouldVirtualize,
                        overscanScreens: Math.max(2, Number(payload.overscanScreens) || 4)
                    });
                }
            };
        })();
        """#
    }
}
