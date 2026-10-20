/**
 * sideview.js - Core frontend engine for Sideview 2D Infinite Canvas
 * Manages panzoom, draggable table cards, snap-to-edge docking, synchronized scrolling,
 * cell highlighting, SVG bezier field connections, inline renaming, and Shiny messaging.
 */

(function (global) {
  'use strict';

  // Helper to safely dispatch Shiny input values
  function sendToShiny(name, value) {
    if (typeof global.Shiny !== 'undefined' && typeof global.Shiny.setInputValue === 'function') {
      global.Shiny.setInputValue(name, value, { priority: 'event' });
    } else {
      // Standalone mode / browser console fallback
      if (typeof console !== 'undefined' && console.debug) {
        console.debug('[Sideview Event]', name, value);
      }
    }
  }

  function SideviewEngine(containerElement, options) {
    var self = this;
    this.container = typeof containerElement === 'string'
      ? document.querySelector(containerElement)
      : containerElement;

    if (!this.container) {
      throw new Error('Sideview container element not found');
    }

    this.options = Object.assign({
      snapThreshold: 20,
      snapToEdge: true,
      minScale: 0.15,
      maxScale: 3.5,
      cards: []
    }, options);

    this.cards = new Map();
    this.connections = [];
    this.activePort = null;
    this.selectedColor = null;
    this.syncScrollCards = new Set();
    this.isSyncingScroll = false;
    this.panzoom = null;
    this.generatedCode = '';

    this.initDOM();
    this.initPanzoom();
    this.initEventListeners();
    this.initExistingCards();

    if (this.options.cards && this.options.cards.length > 0) {
      this.options.cards.forEach(function (cardData, index) {
        self.addCard(cardData, index);
      });
    }

    this.registerShinyHandlers();
  }

  SideviewEngine.prototype.initDOM = function () {
    var self = this;

    // Ensure container has class
    if (!this.container.classList.contains('sideview-container')) {
      this.container.classList.add('sideview-container');
    }

    // Viewport and Canvas
    this.canvas = this.container.querySelector('.sideview-canvas');
    if (!this.canvas) {
      this.canvas = document.createElement('div');
      this.canvas.className = 'sideview-canvas';
      this.container.appendChild(this.canvas);
    }

    this.viewport = this.canvas.querySelector('.sideview-viewport');
    if (!this.viewport) {
      this.viewport = document.createElement('div');
      this.viewport.className = 'sideview-viewport';
      this.canvas.appendChild(this.viewport);
    }

    // SVG Connector overlay
    this.svg = this.viewport.querySelector('.sideview-connector-svg');
    if (!this.svg) {
      this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      this.svg.setAttribute('class', 'sideview-connector-svg');
      this.svg.setAttribute('width', '100%');
      this.svg.setAttribute('height', '100%');
      this.viewport.appendChild(this.svg);
    }

    // Toolbar
    if (!this.container.querySelector('.sideview-toolbar')) {
      var toolbar = document.createElement('div');
      toolbar.className = 'sideview-toolbar';
      toolbar.innerHTML = [
        '<button class="sideview-btn" data-action="zoom-in" title="Zoom In">+</button>',
        '<button class="sideview-btn" data-action="zoom-out" title="Zoom Out">-</button>',
        '<button class="sideview-btn" data-action="zoom-reset" title="Reset View">100%</button>',
        '<span class="sideview-toolbar-divider"></span>',
        '<button class="sideview-btn active" data-action="toggle-snap" title="Snap to Edge">Snap</button>',
        '<button class="sideview-btn" data-action="toggle-drawer" title="Toggle Drawer">Drawer</button>'
      ].join('');
      this.container.appendChild(toolbar);
    }

    // Palette
    if (!this.container.querySelector('.sideview-palette')) {
      var palette = document.createElement('div');
      palette.className = 'sideview-palette';
      palette.innerHTML = [
        '<span class="sideview-palette-label">Highlight:</span>',
        '<div class="sideview-swatch sideview-swatch-blue" data-color="blue" title="Blue"></div>',
        '<div class="sideview-swatch sideview-swatch-green" data-color="green" title="Green"></div>',
        '<div class="sideview-swatch sideview-swatch-amber" data-color="amber" title="Amber"></div>',
        '<div class="sideview-swatch sideview-swatch-rose" data-color="rose" title="Rose"></div>',
        '<div class="sideview-swatch sideview-swatch-purple" data-color="purple" title="Purple"></div>',
        '<div class="sideview-swatch sideview-swatch-clear" data-color="clear" title="Clear Highlight"></div>'
      ].join('');
      this.container.appendChild(palette);
    }

    // Action Drawer
    if (!this.container.querySelector('.sideview-drawer')) {
      var drawer = document.createElement('div');
      drawer.className = 'sideview-drawer collapsed';
      drawer.innerHTML = [
        '<div class="sideview-drawer-header">',
        '  <span class="sideview-drawer-title">Tidyverse Operations</span>',
        '  <button class="sideview-icon-btn" data-action="close-drawer">&times;</button>',
        '</div>',
        '<div class="sideview-drawer-tabs">',
        '  <button class="sideview-drawer-tab active" data-tab="join">Join</button>',
        '  <button class="sideview-drawer-tab" data-tab="filter">Filter</button>',
        '  <button class="sideview-drawer-tab" data-tab="arrange">Arrange</button>',
        '  <button class="sideview-drawer-tab" data-tab="mutate">Mutate</button>',
        '  <button class="sideview-drawer-tab" data-tab="recode">Recode</button>',
        '  <button class="sideview-drawer-tab" data-tab="discrepancy">Discrepancy</button>',
        '</div>',
        '<div class="sideview-drawer-content">',
        '  <p class="sideview-drawer-desc">Connect columns to generate join or mutation pipelines.</p>',
        '  <pre class="sideview-code-block"><code class="sideview-code-text"># Connect two columns to generate pipeline code</code></pre>',
        '</div>',
        '<div class="sideview-drawer-actions">',
        '  <button class="sideview-btn sideview-btn-primary" data-action="inject-script" title="Insert code into active RStudio script">Insert Script</button>',
        '  <button class="sideview-btn" data-action="send-console-exit" title="Send code to RStudio console and exit gadget to execute immediately">Run & Exit</button>',
        '  <button class="sideview-btn" data-action="eval-env" title="Execute code immediately in active R session environment">Run in R</button>',
        '  <button class="sideview-btn" data-action="send-console" title="Queue code to RStudio console (executes when gadget closes)">Run Console</button>',
        '  <button class="sideview-btn" data-action="copy-code">Copy</button>',
        '  <button class="sideview-btn sideview-btn-danger" data-action="clear-operation" title="Clear current operations, connector lines, and generated code">Clear</button>',
        '  <label class="sideview-autoclear-wrap" title="Automatically clear operations after inserting into script or copying"><input type="checkbox" class="sideview-autoclear-toggle" /> Auto-clear</label>',
        '</div>'
      ].join('');
      this.container.appendChild(drawer);
    }

    // AI Natural Language Prompt Bar
    if (!this.container.querySelector('.sideview-ai-bar')) {
      var aiBar = document.createElement('div');
      aiBar.className = 'sideview-ai-bar';
      aiBar.innerHTML = [
        '<span class="sideview-ai-icon">&#10024;</span>',
        '<input type="text" class="sideview-ai-input" placeholder="Ask AI: e.g., join patients and labs on ID, impute missing values..." />',
        '<button class="sideview-ai-send" data-action="send-ai">Send</button>'
      ].join('');
      this.container.appendChild(aiBar);
    }
  };

  SideviewEngine.prototype.initPanzoom = function () {
    var self = this;
    if (typeof global.Panzoom !== 'function') {
      console.warn('Panzoom library is not loaded');
      return;
    }

    this.panzoom = global.Panzoom(this.viewport, {
      canvas: true,
      minScale: this.options.minScale,
      maxScale: this.options.maxScale,
      excludeClass: 'sideview-card'
    });

    this.viewport.addEventListener('panzoomchange', function () {
      self.updateConnectors();
    });
  };

  SideviewEngine.prototype.initEventListeners = function () {
    var self = this;

    // Palette swatch selection
    this.container.addEventListener('click', function (e) {
      var swatch = e.target.closest('.sideview-swatch');
      if (swatch) {
        var color = swatch.dataset.color;
        var swatches = self.container.querySelectorAll('.sideview-swatch');
        swatches.forEach(function (s) { s.classList.remove('active'); });

        if (self.selectedColor === color) {
          self.selectedColor = null;
        } else {
          self.selectedColor = color;
          swatch.classList.add('active');
        }
      }
    });

    // Toolbar button clicks
    this.container.addEventListener('click', function (e) {
      var btn = e.target.closest('[data-action]');
      if (!btn) return;
      var action = btn.dataset.action;

      var rect = self.container.getBoundingClientRect();
      var centerPoint = { clientX: rect.left + rect.width / 2, clientY: rect.top + rect.height / 2 };

      if (action === 'zoom-in' && self.panzoom) {
        self.panzoom.zoomToPoint(self.panzoom.getScale() * 1.25, centerPoint);
      } else if (action === 'zoom-out' && self.panzoom) {
        self.panzoom.zoomToPoint(self.panzoom.getScale() * 0.8, centerPoint);
      } else if (action === 'zoom-reset' && self.panzoom) {
        self.panzoom.reset();
      } else if (action === 'minimize-card') {
        var card = btn.closest('.sideview-card');
        if (card) {
          var b = card.querySelector('.sideview-card-body');
          if (b) {
            b.style.display = b.style.display === 'none' ? '' : 'none';
          }
        }
      } else if (action === 'toggle-snap') {
        self.options.snapToEdge = !self.options.snapToEdge;
        btn.classList.toggle('active', self.options.snapToEdge);
      } else if (action === 'toggle-drawer') {
        var drawer = self.container.querySelector('.sideview-drawer');
        if (drawer) drawer.classList.toggle('collapsed');
      } else if (action === 'close-drawer') {
        var dr = self.container.querySelector('.sideview-drawer');
        if (dr) dr.classList.add('collapsed');
      } else if (action === 'inject-script') {
        sendToShiny('inject_script', { code: self.generatedCode });
        if (self.shouldAutoClear()) {
          self.clearOperations(true);
          self.showToast('Code inserted into script and operations cleared!', 'success');
        } else {
          self.showToast('Code inserted into script! (Click Clear to reset)', 'success');
        }
      } else if (action === 'send-console') {
        self.showToast('Queuing code to RStudio console...', 'warning');
        sendToShiny('send_console', { code: self.generatedCode });
      } else if (action === 'send-console-exit') {
        self.showToast('Executing in RStudio console and closing gadget...', 'success');
        sendToShiny('send_console_and_exit', { code: self.generatedCode });
      } else if (action === 'eval-env') {
        self.showToast('Evaluating in R environment...', 'info');
        sendToShiny('eval_env', { code: self.generatedCode });
      } else if (action === 'copy-code') {
        if (navigator.clipboard && self.generatedCode) {
          navigator.clipboard.writeText(self.generatedCode);
          btn.textContent = 'Copied!';
          setTimeout(function () { btn.textContent = 'Copy'; }, 1500);
          if (self.shouldAutoClear()) {
            self.clearOperations(true);
            self.showToast('Code copied to clipboard and operations cleared!', 'success');
          } else {
            self.showToast('Code copied to clipboard! (Click Clear to reset)', 'info');
          }
        }
      } else if (action === 'clear-operation') {
        self.clearOperations();
      }
    });

    // Click directly on an SVG connector spline to disconnect it
    this.container.addEventListener('click', function (e) {
      var path = e.target.closest('.sideview-connector-path');
      if (!path) return;
      e.stopPropagation();
      var connId = path.dataset.connId;
      if (connId) {
        self.removeConnection(connId);
      }
    });

    // Right-click contextmenu on SVG spline or port to disconnect
    this.container.addEventListener('contextmenu', function (e) {
      var path = e.target.closest('.sideview-connector-path');
      if (path) {
        e.preventDefault();
        e.stopPropagation();
        var connId = path.dataset.connId;
        if (connId) self.removeConnection(connId);
        return;
      }

      var port = e.target.closest('.sideview-col-port');
      if (port) {
        var colName = port.dataset.colName;
        var cardEl = port.closest('.sideview-card');
        var cardName = cardEl ? cardEl.dataset.cardName : '';
        var connsToRemove = self.connections.filter(function (c) {
          return (c.fromTable === cardName && c.fromCol === colName) ||
                 (c.toTable === cardName && c.toCol === colName);
        });
        if (connsToRemove.length > 0) {
          e.preventDefault();
          e.stopPropagation();
          connsToRemove.forEach(function (c) { self.removeConnection(c.id); });
        }
      }
    });

    // Drawer tab switching
    this.container.addEventListener('click', function (e) {
      var tab = e.target.closest('.sideview-drawer-tab');
      if (!tab) return;
      var tabs = self.container.querySelectorAll('.sideview-drawer-tab');
      tabs.forEach(function (t) { t.classList.remove('active'); });
      tab.classList.add('active');

      var tabName = tab.dataset.tab;
      if (tabName === 'discrepancy' && self.connections.length > 0) {
        var lastConn = self.connections[self.connections.length - 1];
        sendToShiny('discrepancy_check', {
          table1: lastConn.fromTable,
          col1: lastConn.fromCol,
          table2: lastConn.toTable,
          col2: lastConn.toCol
        });
      }
    });

    // AI Natural Language input submit
    var aiInput = this.container.querySelector('.sideview-ai-input');
    var aiSendBtn = this.container.querySelector('[data-action="send-ai"]');

    function submitAI() {
      if (!aiInput) return;
      var prompt = aiInput.value.trim();
      if (!prompt) return;

      var tableNames = Array.from(self.cards.values()).map(function (c) { return c.name; });
      sendToShiny('run_ai_prompt', {
        prompt: prompt,
        tables: tableNames
      });
      aiInput.value = '';
    }

    if (aiSendBtn) {
      aiSendBtn.addEventListener('click', submitAI);
    }
    if (aiInput) {
      aiInput.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') submitAI();
      });
    }

    // Cell & Column Highlighting on Table Click
    this.container.addEventListener('click', function (e) {
      if (!self.selectedColor) return;

      var th = e.target.closest('th');
      var td = e.target.closest('td');

      if (th && !e.target.closest('.sideview-col-port') && !e.target.closest('.sideview-rename-input')) {
        // Column highlight
        var colIdx = th.cellIndex;
        var table = th.closest('table');
        var cardEl = th.closest('.sideview-card');
        var cardId = cardEl ? cardEl.dataset.cardId : null;
        var colName = th.dataset.colName;

        var highlightClass = self.selectedColor === 'clear' ? '' : 'sv-highlight-' + self.selectedColor;
        var allCellsInCol = table.querySelectorAll('tbody tr td:nth-child(' + (colIdx + 1) + ')');

        allCellsInCol.forEach(function (cell) {
          // Remove old highlight classes
          cell.className = cell.className.replace(/sv-highlight-\w+/g, '').replace('sideview-cell-highlight', '').trim();
          if (highlightClass) {
            cell.classList.add(highlightClass, 'sideview-cell-highlight');
          }
        });

        sendToShiny('sideview_highlight_changed', {
          card_id: cardId,
          col_name: colName,
          row_idx: null,
          color: self.selectedColor
        });
      } else if (td) {
        // Individual cell highlight
        var cellHighlightClass = self.selectedColor === 'clear' ? '' : 'sv-highlight-' + self.selectedColor;
        td.className = td.className.replace(/sv-highlight-\w+/g, '').replace('sideview-cell-highlight', '').trim();
        if (cellHighlightClass) {
          td.classList.add(cellHighlightClass, 'sideview-cell-highlight');
        }

        var cellCard = td.closest('.sideview-card');
        var cellTable = td.closest('table');
        var thCol = cellTable.querySelectorAll('th')[td.cellIndex];

        sendToShiny('sideview_highlight_changed', {
          card_id: cellCard ? cellCard.dataset.cardId : null,
          col_name: thCol ? thCol.dataset.colName : null,
          row_idx: td.parentElement.rowIndex,
          color: self.selectedColor
        });
      }
    });

    // Sort Column Click
    this.container.addEventListener('click', function (e) {
      var sortBtn = e.target.closest('[data-action="sort-col"]');
      if (!sortBtn) return;
      e.stopPropagation();
      var cardEl = sortBtn.closest('.sideview-card');
      var th = sortBtn.closest('th');
      if (!cardEl || !th) return;
      var colName = sortBtn.dataset.colName || th.dataset.colName;
      self.sortColumn(cardEl, colName, th.cellIndex, sortBtn);
    });

    // Filter Column Click
    this.container.addEventListener('click', function (e) {
      var filterBtn = e.target.closest('[data-action="filter-col"]');
      if (!filterBtn) return;
      e.stopPropagation();
      var cardEl = filterBtn.closest('.sideview-card');
      var th = filterBtn.closest('th');
      if (!cardEl || !th) return;
      var colName = filterBtn.dataset.colName || th.dataset.colName;
      self.openFilterPopover(cardEl, colName, th.cellIndex, filterBtn);
    });

    // Column Connection Port Handling
    this.container.addEventListener('click', function (e) {
      var port = e.target.closest('.sideview-col-port');
      if (!port) return;

      e.stopPropagation();
      var cardEl = port.closest('.sideview-card');
      var cardId = cardEl.dataset.cardId;
      var cardName = cardEl.dataset.cardName;
      var colName = port.dataset.colName;

      if (!self.activePort) {
        // Start connection
        self.activePort = { cardId: cardId, cardName: cardName, colName: colName, element: port };
        port.classList.add('connecting');
      } else {
        // Attempt connect
        if (self.activePort.cardId === cardId) {
          // Cannot connect within same card
          self.activePort.element.classList.remove('connecting');
          self.activePort = null;
          return;
        }

        // Establish connection
        self.activePort.element.classList.remove('connecting');
        self.addConnection({
          fromCard: self.activePort.cardId,
          fromTable: self.activePort.cardName,
          fromCol: self.activePort.colName,
          fromElement: self.activePort.element,
          toCard: cardId,
          toTable: cardName,
          toCol: colName,
          toElement: port,
          type: 'left_join'
        });

        self.activePort = null;
      }
    });

    // Inline Column Renaming via Double Click on column name
    this.container.addEventListener('dblclick', function (e) {
      var colNameEl = e.target.closest('.sideview-col-name');
      if (!colNameEl) return;

      var currentName = colNameEl.textContent.trim();
      var cardEl = colNameEl.closest('.sideview-card');
      var cardName = cardEl ? cardEl.dataset.cardName : '';
      var th = colNameEl.closest('th');

      var input = document.createElement('input');
      input.type = 'text';
      input.className = 'sideview-rename-input';
      input.value = currentName;

      colNameEl.style.display = 'none';
      colNameEl.parentNode.insertBefore(input, colNameEl);
      input.focus();
      input.select();

      function finishRename() {
        input.removeEventListener('blur', finishRename);
        var newName = input.value.trim();
        input.remove();
        colNameEl.style.display = '';

        if (newName && newName !== currentName) {
          colNameEl.textContent = newName;
          if (th) {
            th.dataset.colName = newName;
            var port = th.querySelector('.sideview-col-port');
            if (port) port.dataset.colName = newName;
          }
          sendToShiny('column_renamed', {
            table: cardName,
            old_col: currentName,
            new_col: newName
          });
        }
      }

      input.addEventListener('blur', finishRename);
      input.addEventListener('keydown', function (evt) {
        if (evt.key === 'Enter') {
          input.removeEventListener('blur', finishRename);
          finishRename();
        } else if (evt.key === 'Escape') {
          input.removeEventListener('blur', finishRename);
          input.remove();
          colNameEl.style.display = '';
        }
      });
    });
  };

  /**
   * Add a table card to the canvas
   */
  SideviewEngine.prototype.addCard = function (cardData, index) {
    var self = this;
    var cardId = cardData.id || 'card_' + (index !== undefined ? index : Date.now());
    var cardName = cardData.name || 'Table_' + (index + 1);

    var cardEl = document.createElement('div');
    cardEl.className = 'sideview-card panzoom-exclude';
    cardEl.dataset.cardId = cardId;
    cardEl.dataset.cardName = cardName;

    // Positioning
    var initialX = cardData.x !== undefined ? cardData.x : 40 + (index * 360);
    var initialY = cardData.y !== undefined ? cardData.y : 60 + ((index % 2) * 50);
    cardEl.style.left = initialX + 'px';
    cardEl.style.top = initialY + 'px';

    // Build Card Header
    var header = document.createElement('div');
    header.className = 'sideview-card-header';
    var dimsText = cardData.dims ? cardData.dims[0] + ' × ' + cardData.dims[1] : '';
    header.innerHTML = [
      '<div class="sideview-card-title-group">',
      '  <span class="sideview-card-title">' + cardName + '</span>',
      '  <span class="sideview-badge sideview-badge-type">' + (cardData.type || 'grid') + '</span>',
      dimsText ? '  <span class="sideview-badge">' + dimsText + '</span>' : '',
      '</div>',
      '<div class="sideview-card-actions">',
      '  <button class="sideview-icon-btn" data-action="sync-scroll" title="Synchronize vertical scrolling">&#128279;</button>',
      '  <button class="sideview-icon-btn" data-action="minimize-card" title="Minimize">&minus;</button>',
      '</div>'
    ].join('');
    cardEl.appendChild(header);

    // Build Card Body
    var body = document.createElement('div');
    body.className = 'sideview-card-body';

    if (cardData.type === 'grid' && cardData.data) {
      var table = document.createElement('table');
      table.className = 'sideview-table';

      // Header row
      var thead = document.createElement('thead');
      var headerRow = document.createElement('tr');
      var colNames = Object.keys(cardData.data);
      var colTypes = cardData.col_types || {};

      colNames.forEach(function (colName) {
        var th = document.createElement('th');
        th.dataset.colName = colName;
        var colType = colTypes[colName] || '';
        th.innerHTML = [
          '<div class="col-header-wrap">',
          '  <div class="col-header-left">',
          '    <span class="sideview-col-name">' + colName + '</span>',
          colType ? '    <span class="sideview-col-type">(' + colType + ')</span>' : '',
          '  </div>',
          '  <div class="col-header-tools">',
          '    <button class="sideview-th-btn sideview-sort-btn" data-action="sort-col" data-col-name="' + colName + '" title="Sort column (Asc / Desc / Reset)">⇅</button>',
          '    <button class="sideview-th-btn sideview-filter-btn" data-action="filter-col" data-col-name="' + colName + '" title="Filter column">🔍</button>',
          '    <span class="sideview-col-port" data-col-name="' + colName + '" title="Connect to map field"></span>',
          '  </div>',
          '</div>'
        ].join('');
        headerRow.appendChild(th);
      });
      thead.appendChild(headerRow);
      table.appendChild(thead);

      // Body rows
      var tbody = document.createElement('tbody');
      var numRows = cardData.data[colNames[0]] ? cardData.data[colNames[0]].length : 0;
      for (var r = 0; r < numRows; r++) {
        var tr = document.createElement('tr');
        colNames.forEach(function (colName) {
          var td = document.createElement('td');
          var val = cardData.data[colName][r];
          td.textContent = (val === null || val === undefined) ? 'NA' : val;
          if (typeof val === 'number') {
            td.classList.add('is-number');
          }
          tr.appendChild(td);
        });
        tbody.appendChild(tr);
      }
      table.appendChild(tbody);
      body.appendChild(table);
    } else if (cardData.html_content) {
      body.innerHTML = cardData.html_content;
    }

    cardEl.appendChild(body);
    this.viewport.appendChild(cardEl);

    // Register card in memory
    var cardMeta = {
      id: cardId,
      name: cardName,
      element: cardEl,
      body: body,
      x: initialX,
      y: initialY
    };
    this.cards.set(cardId, cardMeta);

    // Setup Drag and Drop
    this.setupCardDrag(cardEl, cardMeta);

    // Setup Synchronized Scroll
    this.setupScrollSync(cardMeta);
  };

  /**
   * Drag and drop table cards with snap-to-edge docking logic
   */
  SideviewEngine.prototype.setupCardDrag = function (cardEl, cardMeta) {
    var self = this;
    var header = cardEl.querySelector('.sideview-card-header');

    var isDragging = false;
    var startPointerX = 0;
    var startPointerY = 0;
    var startCardX = 0;
    var startCardY = 0;

    header.addEventListener('pointerdown', function (e) {
      if (e.target.closest('button') || e.target.closest('input')) return;

      isDragging = true;
      cardEl.classList.add('is-dragging');
      header.setPointerCapture(e.pointerId);

      var scale = self.panzoom ? self.panzoom.getScale() : 1;
      startPointerX = e.clientX;
      startPointerY = e.clientY;
      startCardX = parseFloat(cardEl.style.left) || 0;
      startCardY = parseFloat(cardEl.style.top) || 0;

      function onPointerMove(moveEvent) {
        if (!isDragging) return;

        var scaleCurrent = self.panzoom ? self.panzoom.getScale() : 1;
        var dx = (moveEvent.clientX - startPointerX) / scaleCurrent;
        var dy = (moveEvent.clientY - startPointerY) / scaleCurrent;

        var targetX = startCardX + dx;
        var targetY = startCardY + dy;

        // Snap-to-edge calculation
        if (self.options.snapToEdge) {
          var snapThreshold = self.options.snapThreshold || 20;
          var cardWidth = cardEl.offsetWidth;
          var cardHeight = cardEl.offsetHeight;

          self.cards.forEach(function (other, otherId) {
            if (otherId === cardMeta.id) return;

            var otherEl = other.element;
            var ox = parseFloat(otherEl.style.left) || 0;
            var oy = parseFloat(otherEl.style.top) || 0;
            var ow = otherEl.offsetWidth;
            var oh = otherEl.offsetHeight;

            // Snap left-to-left
            if (Math.abs(targetX - ox) < snapThreshold) {
              targetX = ox;
            }
            // Snap left-to-right edge
            else if (Math.abs(targetX - (ox + ow + 16)) < snapThreshold) {
              targetX = ox + ow + 16;
            }
            // Snap right-to-left edge
            else if (Math.abs((targetX + cardWidth + 16) - ox) < snapThreshold) {
              targetX = ox - cardWidth - 16;
            }

            // Snap top-to-top
            if (Math.abs(targetY - oy) < snapThreshold) {
              targetY = oy;
            }
            // Snap top-to-bottom edge
            else if (Math.abs(targetY - (oy + oh + 16)) < snapThreshold) {
              targetY = oy + oh + 16;
            }
          });
        }

        cardEl.style.left = targetX + 'px';
        cardEl.style.top = targetY + 'px';
        cardMeta.x = targetX;
        cardMeta.y = targetY;

        // Update SVG bezier connectors during drag
        self.updateConnectors();
      }

      function onPointerUp(upEvent) {
        if (!isDragging) return;
        isDragging = false;
        cardEl.classList.remove('is-dragging');
        header.releasePointerCapture(upEvent.pointerId);

        header.removeEventListener('pointermove', onPointerMove);
        header.removeEventListener('pointerup', onPointerUp);

        sendToShiny('sideview_card_moved', {
          card_id: cardMeta.id,
          x: cardMeta.x,
          y: cardMeta.y
        });
      }

      header.addEventListener('pointermove', onPointerMove);
      header.addEventListener('pointerup', onPointerUp);
    });
  };

  /**
   * Scan and initialize pre-rendered DOM cards (e.g. from Shiny Gadget mode)
   */
  SideviewEngine.prototype.initExistingCards = function () {
    var self = this;
    if (!this.viewport) return;
    var existingCards = this.viewport.querySelectorAll('.sideview-card');
    existingCards.forEach(function (cardEl, index) {
      var cardId = cardEl.dataset.cardId || cardEl.id || ('card_' + index);
      var cardName = cardEl.dataset.cardName || ('Table_' + (index + 1));
      var body = cardEl.querySelector('.sideview-card-body');
      var cardMeta = {
        id: cardId,
        name: cardName,
        element: cardEl,
        body: body,
        x: parseFloat(cardEl.style.left) || 0,
        y: parseFloat(cardEl.style.top) || 0
      };
      self.cards.set(cardId, cardMeta);
      self.setupCardDrag(cardEl, cardMeta);
      self.setupScrollSync(cardMeta);
    });
  };

  /**
   * Synchronized vertical scroll handler for linked table pairs
   */
  SideviewEngine.prototype.setupScrollSync = function (cardMeta) {
    var self = this;
    var syncBtn = cardMeta.element.querySelector('[data-action="sync-scroll"]');
    var body = cardMeta.body;
    if (!body) return;

    if (syncBtn) {
      syncBtn.addEventListener('click', function () {
        if (self.syncScrollCards.has(cardMeta.id)) {
          self.syncScrollCards.delete(cardMeta.id);
          syncBtn.classList.remove('active');
        } else {
          self.syncScrollCards.add(cardMeta.id);
          syncBtn.classList.add('active');
        }
      });
    }

    body.addEventListener('scroll', function () {
      self.updateConnectors();
      if (self.isSyncingScroll || !self.syncScrollCards.has(cardMeta.id)) return;
      if (self.syncScrollCards.size < 2) return;

      var maxScroll = body.scrollHeight - body.clientHeight;
      if (maxScroll <= 0) return;
      var scrollRatio = body.scrollTop / maxScroll;

      self.isSyncingScroll = true;
      self.syncScrollCards.forEach(function (otherId) {
        if (otherId === cardMeta.id) return;
        var other = self.cards.get(otherId);
        if (other && other.body) {
          var otherMax = other.body.scrollHeight - other.body.clientHeight;
          var targetTop = scrollRatio * otherMax;
          if (Math.abs(other.body.scrollTop - targetTop) > 1) {
            other.body.scrollTop = targetTop;
          }
        }
      });
      requestAnimationFrame(function () {
        self.isSyncingScroll = false;
      });
    });
  };

  /**
   * Field click-to-connect field mapping with SVG bezier curves
   */
  SideviewEngine.prototype.addConnection = function (connData) {
    var self = this;
    var connId = 'conn_' + Date.now();

    var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('class', 'sideview-connector-path');
    path.dataset.connId = connId;

    var titleEl = document.createElementNS('http://www.w3.org/2000/svg', 'title');
    titleEl.textContent = 'Click to disconnect ' + connData.fromCol + ' ↔ ' + connData.toCol;
    path.appendChild(titleEl);

    this.svg.appendChild(path);

    var connection = Object.assign({ id: connId, path: path }, connData);
    this.connections.push(connection);

    this.updateConnectors();

    // Trigger Tidyverse join code generation
    var joinCode = connData.fromTable + ' %>%\n  dplyr::left_join(' +
      connData.toTable + ', by = c("' + connData.fromCol + '" = "' + connData.toCol + '"))';
    this.updateDrawerCode(joinCode);

    sendToShiny('column_mapped', {
      from_table: connData.fromTable,
      from_col: connData.fromCol,
      to_table: connData.toTable,
      to_col: connData.toCol,
      join_type: connData.type || 'left_join'
    });
  };

  /**
   * Compute cubic bezier curve path string between two ports
   */
  /**
   * Remove a single connection by ID and update code
   */
  SideviewEngine.prototype.removeConnection = function (connId) {
    var self = this;
    var index = -1;
    for (var i = 0; i < this.connections.length; i++) {
      if (this.connections[i].id === connId) {
        index = i;
        break;
      }
    }
    if (index === -1) return;

    var conn = this.connections[index];
    if (conn.path && conn.path.parentNode) {
      conn.path.parentNode.removeChild(conn.path);
    }
    this.connections.splice(index, 1);

    // Recompute code based on remaining connections
    if (this.connections.length > 0) {
      var lastConn = this.connections[this.connections.length - 1];
      var joinCode = lastConn.fromTable + ' %>%
  dplyr::left_join(' +
        lastConn.toTable + ', by = c("' + lastConn.fromCol + '" = "' + lastConn.toCol + '"))';
      this.updateDrawerCode(joinCode);
    } else {
      this.generatedCode = '';
      var codeText = this.container.querySelector('.sideview-code-text');
      if (codeText) {
        codeText.textContent = '# Connect two columns to generate pipeline code';
      }
    }

    this.showToast('Disconnected ' + conn.fromCol + ' ↔ ' + conn.toCol, 'info');
    sendToShiny('column_disconnected', {
      conn_id: connId,
      from_table: conn.fromTable,
      from_col: conn.fromCol,
      to_table: conn.toTable,
      to_col: conn.toCol
    });
  };

  SideviewEngine.prototype.getBezierPath = function (p1, p2) {
    var dir = p2.x >= p1.x ? 1 : -1;
    var dx = Math.max(40, Math.abs(p2.x - p1.x) * 0.45) * dir;
    return 'M ' + p1.x + ' ' + p1.y + ' C ' + (p1.x + dx) + ' ' + p1.y + ', ' +
      (p2.x - dx) + ' ' + p2.y + ', ' + p2.x + ' ' + p2.y;
  };

  /**
   * Redraw all SVG connector splines based on current port coordinates in viewport space
   */
  SideviewEngine.prototype.updateConnectors = function () {
    var self = this;
    var viewportRect = this.viewport.getBoundingClientRect();
    var scale = this.panzoom ? this.panzoom.getScale() : 1;

    this.connections.forEach(function (conn) {
      if (!conn.fromElement || !conn.toElement || !conn.path) return;

      var r1 = conn.fromElement.getBoundingClientRect();
      var r2 = conn.toElement.getBoundingClientRect();

      var p1 = {
        x: (r1.left + r1.width / 2 - viewportRect.left) / scale,
        y: (r1.top + r1.height / 2 - viewportRect.top) / scale
      };

      var p2 = {
        x: (r2.left + r2.width / 2 - viewportRect.left) / scale,
        y: (r2.top + r2.height / 2 - viewportRect.top) / scale
      };

      conn.path.setAttribute('d', self.getBezierPath(p1, p2));
    });
  };

  SideviewEngine.prototype.updateDrawerCode = function (code) {
    this.generatedCode = code;
    var drawer = this.container.querySelector('.sideview-drawer');
    var codeText = this.container.querySelector('.sideview-code-text');
    if (codeText) codeText.textContent = code;
    if (drawer) drawer.classList.remove('collapsed');
  };

  /**
   * Display a status toast banner
   */
  /**
   * Check if auto-clear checkbox is checked
   */
  SideviewEngine.prototype.shouldAutoClear = function () {
    var toggle = this.container.querySelector('.sideview-autoclear-toggle');
    return toggle ? toggle.checked : false;
  };

  /**
   * Clear all active operations, connector curves, port selections, and generated code
   */
  SideviewEngine.prototype.clearOperations = function (silent) {
    var self = this;

    // 1. Remove all SVG connector paths from the DOM
    if (this.connections && this.connections.length > 0) {
      this.connections.forEach(function (conn) {
        if (conn.path && conn.path.parentNode) {
          conn.path.parentNode.removeChild(conn.path);
        }
      });
    }
    this.connections = [];

    if (this.svg) {
      var extraPaths = this.svg.querySelectorAll('.sideview-connector-path');
      extraPaths.forEach(function (p) { p.remove(); });
    }

    // 2. Clear port selections
    if (this.selectedPort) {
      this.selectedPort.classList.remove('active', 'selected', 'connecting');
      this.selectedPort = null;
    }
    var activePorts = this.container.querySelectorAll('.sideview-col-port.active, .sideview-col-port.selected');
    activePorts.forEach(function (p) { p.classList.remove('active', 'selected'); });

    // 2b. Reset all column sort indicators and row filters
    var pop = document.querySelector('.sideview-filter-popover');
    if (pop) pop.remove();
    this.container.querySelectorAll('.sideview-row-filtered').forEach(function (r) {
      r.classList.remove('sideview-row-filtered');
    });
    this.container.querySelectorAll('.sideview-sort-btn').forEach(function (b) {
      b.textContent = '⇅';
      b.classList.remove('active');
    });
    this.container.querySelectorAll('.sideview-filter-btn').forEach(function (b) {
      b.classList.remove('active');
    });
    this.container.querySelectorAll('thead th').forEach(function (th) {
      th.dataset.sortState = 'none';
    });

    // 3. Clear discrepancy highlighting
    var discCells = this.container.querySelectorAll('.sideview-discrepancy-fuzzy, .sideview-discrepancy-diff');
    discCells.forEach(function (c) {
      c.classList.remove('sideview-discrepancy-fuzzy', 'sideview-discrepancy-diff');
    });

    // 4. Reset generated code and drawer UI
    this.generatedCode = '';
    var codeText = this.container.querySelector('.sideview-code-text');
    if (codeText) {
      codeText.textContent = '# Connect two columns to generate pipeline code';
    }

    // 5. Notify user if not silent
    if (!silent) {
      this.showToast('Tidyverse operations and connectors cleared.', 'info');
    }
  };

  /**
   * Switch active tab in Action Drawer
   */
  SideviewEngine.prototype.activateDrawerTab = function (tabName) {
    var tabs = this.container.querySelectorAll('.sideview-drawer-tab');
    tabs.forEach(function (t) {
      if (t.dataset.tab === tabName) {
        t.classList.add('active');
      } else {
        t.classList.remove('active');
      }
    });
  };

  /**
   * Interactive Column Sorting (Asc -> Desc -> Reset)
   */
  SideviewEngine.prototype.sortColumn = function (cardEl, colName, colIndex, btn) {
    var self = this;
    var table = cardEl.querySelector('.sideview-table');
    if (!table) return;
    var tbody = table.querySelector('tbody');
    if (!tbody) return;

    var th = table.querySelectorAll('thead th')[colIndex];
    if (!th) return;

    var currentState = th.dataset.sortState || 'none';
    var nextState = 'asc';
    if (currentState === 'asc') nextState = 'desc';
    else if (currentState === 'desc') nextState = 'none';

    // Reset sort indicators on all headers in this table
    table.querySelectorAll('thead th').forEach(function (otherTh) {
      otherTh.dataset.sortState = 'none';
      var sBtn = otherTh.querySelector('.sideview-sort-btn');
      if (sBtn) {
        sBtn.textContent = '⇅';
        sBtn.classList.remove('active');
      }
    });

    th.dataset.sortState = nextState;

    // Get all rows
    var rows = Array.from(tbody.querySelectorAll('tr'));
    rows.forEach(function (r, idx) {
      if (!r.dataset.rowIndex) r.dataset.rowIndex = idx;
    });

    if (nextState === 'none') {
      // Restore initial order
      rows.sort(function (a, b) {
        return parseInt(a.dataset.rowIndex, 10) - parseInt(b.dataset.rowIndex, 10);
      });
      btn.textContent = '⇅';
      btn.classList.remove('active');
      self.showToast('Reset column sort order on ' + colName, 'info');
    } else {
      btn.classList.add('active');
      btn.textContent = nextState === 'asc' ? '▲' : '▼';

      rows.sort(function (a, b) {
        var cellA = a.cells[colIndex] ? a.cells[colIndex].textContent.trim() : '';
        var cellB = b.cells[colIndex] ? b.cells[colIndex].textContent.trim() : '';

        var numA = parseFloat(cellA);
        var numB = parseFloat(cellB);
        var isNum = !isNaN(numA) && !isNaN(numB) && cellA !== '' && cellB !== '';

        var cmp = 0;
        if (isNum) {
          cmp = numA - numB;
        } else {
          cmp = cellA.localeCompare(cellB, undefined, { numeric: true, sensitivity: 'base' });
        }
        return nextState === 'asc' ? cmp : -cmp;
      });

      var cardName = cardEl.dataset.cardName || 'df';
      var arrangeArg = nextState === 'desc' ? 'dplyr::desc(' + colName + ')' : colName;
      var arrangeCode = cardName + ' %>%
  dplyr::arrange(' + arrangeArg + ')';

      self.activateDrawerTab('arrange');
      self.updateDrawerCode(arrangeCode);
      self.showToast('Sorted ' + colName + ' (' + (nextState === 'asc' ? 'ascending' : 'descending') + ')', 'success');

      sendToShiny('column_sorted', {
        table: cardName,
        column: colName,
        direction: nextState,
        code: arrangeCode
      });
    }

    rows.forEach(function (r) { tbody.appendChild(r); });
    self.updateConnectors();
  };

  /**
   * Interactive Column Filter Popover
   */
  SideviewEngine.prototype.openFilterPopover = function (cardEl, colName, colIndex, btn) {
    var self = this;
    var existing = document.querySelector('.sideview-filter-popover');
    if (existing) {
      var isSame = existing._sourceBtn === btn;
      existing.remove();
      if (isSame) return;
    }

    var cardName = cardEl.dataset.cardName || 'df';
    var popover = document.createElement('div');
    popover.className = 'sideview-filter-popover';
    popover._sourceBtn = btn;

    popover.innerHTML = [
      '<div class="sideview-filter-popover-header">',
      '  <span>Filter: ' + colName + '</span>',
      '  <button class="sideview-icon-btn sideview-filter-close" title="Close">&times;</button>',
      '</div>',
      '<select class="sideview-filter-select">',
      '  <option value="contains">contains</option>',
      '  <option value="equals">equals (==)</option>',
      '  <option value="not_equals">not equals (!=)</option>',
      '  <option value="gt">greater than (&gt;)</option>',
      '  <option value="gte">greater or equal (&gt;=)</option>',
      '  <option value="lt">less than (&lt;)</option>',
      '  <option value="lte">less or equal (&lt;=)</option>',
      '</select>',
      '<input type="text" class="sideview-filter-input" placeholder="Value..." />',
      '<div class="sideview-filter-actions">',
      '  <button class="sideview-filter-clear">Clear</button>',
      '  <button class="sideview-filter-apply">Apply</button>',
      '</div>'
    ].join('');

    document.body.appendChild(popover);

    var btnRect = btn.getBoundingClientRect();
    popover.style.left = Math.min(window.innerWidth - 240, Math.max(10, btnRect.left - 80)) + 'px';
    popover.style.top = (btnRect.bottom + 6) + 'px';

    var select = popover.querySelector('.sideview-filter-select');
    var input = popover.querySelector('.sideview-filter-input');
    input.focus();

    popover.querySelector('.sideview-filter-close').addEventListener('click', function () {
      popover.remove();
    });

    popover.querySelector('.sideview-filter-clear').addEventListener('click', function () {
      var table = cardEl.querySelector('.sideview-table');
      if (table) {
        table.querySelectorAll('tbody tr').forEach(function (tr) {
          tr.classList.remove('sideview-row-filtered');
        });
      }
      btn.classList.remove('active');
      popover.remove();
      self.updateConnectors();
      self.showToast('Cleared filter on ' + colName, 'info');
    });

    function applyFilter() {
      var val = input.value.trim();
      if (!val) {
        popover.remove();
        return;
      }
      var op = select.value;
      var table = cardEl.querySelector('.sideview-table');
      if (!table) return;

      var rows = table.querySelectorAll('tbody tr');
      var matchedCount = 0;
      var numVal = parseFloat(val);
      var isNumFilter = !isNaN(numVal);

      rows.forEach(function (tr) {
        var cell = tr.cells[colIndex];
        var text = cell ? cell.textContent.trim() : '';
        var numCell = parseFloat(text);
        var match = false;

        if (op === 'contains') {
          match = text.toLowerCase().indexOf(val.toLowerCase()) !== -1;
        } else if (op === 'equals') {
          match = isNumFilter && !isNaN(numCell) ? numCell === numVal : text.toLowerCase() === val.toLowerCase();
        } else if (op === 'not_equals') {
          match = isNumFilter && !isNaN(numCell) ? numCell !== numVal : text.toLowerCase() !== val.toLowerCase();
        } else if (op === 'gt') {
          match = !isNaN(numCell) && numCell > numVal;
        } else if (op === 'gte') {
          match = !isNaN(numCell) && numCell >= numVal;
        } else if (op === 'lt') {
          match = !isNaN(numCell) && numCell < numVal;
        } else if (op === 'lte') {
          match = !isNaN(numCell) && numCell <= numVal;
        }

        if (match) {
          tr.classList.remove('sideview-row-filtered');
          matchedCount++;
        } else {
          tr.classList.add('sideview-row-filtered');
        }
      });

      btn.classList.add('active');

      var condExpr = '';
      if (op === 'contains') {
        condExpr = 'stringr::str_detect(' + colName + ', "' + val + '")';
      } else if (op === 'equals') {
        condExpr = isNumFilter ? colName + ' == ' + val : colName + ' == "' + val + '"';
      } else if (op === 'not_equals') {
        condExpr = isNumFilter ? colName + ' != ' + val : colName + ' != "' + val + '"';
      } else if (op === 'gt') {
        condExpr = colName + ' > ' + val;
      } else if (op === 'gte') {
        condExpr = colName + ' >= ' + val;
      } else if (op === 'lt') {
        condExpr = colName + ' < ' + val;
      } else if (op === 'lte') {
        condExpr = colName + ' <= ' + val;
      }

      var filterCode = cardName + ' %>%
  dplyr::filter(' + condExpr + ')';
      self.activateDrawerTab('filter');
      self.updateDrawerCode(filterCode);
      self.showToast('Filtered ' + colName + ' (' + matchedCount + '/' + rows.length + ' rows)', 'success');

      sendToShiny('column_filtered', {
        table: cardName,
        column: colName,
        operator: op,
        value: val,
        condition: condExpr,
        code: filterCode
      });

      popover.remove();
      self.updateConnectors();
    }

    popover.querySelector('.sideview-filter-apply').addEventListener('click', applyFilter);
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') applyFilter();
      else if (e.key === 'Escape') popover.remove();
    });
  };

  SideviewEngine.prototype.showToast = function (message, type) {
    var toast = document.createElement('div');
    toast.className = 'sideview-toast ' + (type ? 'sideview-toast-' + type : '');
    toast.textContent = message;
    this.container.appendChild(toast);
    setTimeout(function () {
      toast.classList.add('visible');
    }, 10);
    setTimeout(function () {
      toast.classList.remove('visible');
      setTimeout(function () { toast.remove(); }, 300);
    }, 4500);
  };

  SideviewEngine.prototype.registerShinyHandlers = function () {
    var self = this;
    if (typeof global.Shiny === 'undefined' || typeof global.Shiny.addCustomMessageHandler !== 'function') {
      return;
    }

    // Code update from R server
    global.Shiny.addCustomMessageHandler('sideview_console_result', function (data) {
      if (data && data.message) {
        self.showToast(data.message, data.success ? 'success' : 'warning');
      }
    });

    global.Shiny.addCustomMessageHandler('sideview_inject_result', function (data) {
      if (data && data.message) {
        self.showToast(data.message, data.success ? 'success' : 'warning');
      }
    });

    global.Shiny.addCustomMessageHandler('sideview_eval_result', function (data) {
      if (data && data.message) {
        self.showToast(data.message, data.success ? 'success' : 'danger');
      }
    });

    global.Shiny.addCustomMessageHandler('sideview_code_update', function (data) {
      if (data && data.code) {
        self.updateDrawerCode(data.code);
      }
    });

    // Discrepancy report update
    global.Shiny.addCustomMessageHandler('sideview_discrepancies', function (data) {
      if (!data) return;

      var targetCards = [];
      if (data.from_table) {
        var c1 = self.container.querySelector('[data-card-name="' + data.from_table + '"]');
        if (c1) targetCards.push(c1);
      }
      if (data.to_table) {
        var c2 = self.container.querySelector('[data-card-name="' + data.to_table + '"]');
        if (c2) targetCards.push(c2);
      }
      var scope = targetCards.length > 0 ? targetCards : [self.container];

      var searchCells = [];
      scope.forEach(function (el) {
        var found = el.querySelectorAll('td');
        for (var i = 0; i < found.length; i++) {
          searchCells.push(found[i]);
        }
      });

      // Highlight discrepancy cells in connected tables
      if (data.fuzzy_matches && Array.isArray(data.fuzzy_matches)) {
        data.fuzzy_matches.forEach(function (pair) {
          searchCells.forEach(function (c) {
            if (c.textContent.trim() === String(pair.x) || c.textContent.trim() === String(pair.y)) {
              c.classList.add('sideview-discrepancy-fuzzy');
            }
          });
        });
      }

      if (data.only_in_x || data.only_in_y) {
        var diffValues = (data.only_in_x || []).concat(data.only_in_y || []);
        searchCells.forEach(function (c) {
          if (diffValues.indexOf(c.textContent.trim()) !== -1) {
            c.classList.add('sideview-discrepancy-diff');
          }
        });
      }
    });
  };

  // Factory entry point for Sideview
  function initSideview(container, options) {
    var target = container;
    if (!target) {
      target = document.querySelector('.sideview-container') || document.body;
    }
    var instance = new SideviewEngine(target, options);
    target._sideviewInstance = instance;
    return instance;
  }

  // Export globally
  global.initSideview = initSideview;
  global.Sideview = {
    init: initSideview,
    Engine: SideviewEngine
  };

})(typeof window !== 'undefined' ? window : this);
