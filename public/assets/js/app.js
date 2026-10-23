/* ==========================================================================
   智美成ERP系统 · 前端脚本(无外部依赖)
   ========================================================================== */
(function () {
  'use strict';

  const ERP = window.ERP || {};

  /* ---------------------------------------------------------- 工具 */
  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));

  function csrfHeaders() {
    return { 'X-CSRF-Token': ERP.csrf || '', 'X-Requested-With': 'XMLHttpRequest' };
  }

  function fmtMoney(n) {
    const v = Number(n || 0);
    return '¥' + v.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function fmtQty(n) {
    const v = Number(n || 0);
    return String(Math.round(v * 10000) / 10000);
  }

  /* ---------------------------------------------------------- 菜单折叠 */
  function initMenu() {
    const btn = $('#menuToggle');
    if (!btn) return;
    const saved = localStorage.getItem('erp_menu_collapsed');
    if (saved === '1') document.body.classList.add('collapsed');
    btn.addEventListener('click', function () {
      document.body.classList.toggle('collapsed');
      localStorage.setItem('erp_menu_collapsed', document.body.classList.contains('collapsed') ? '1' : '0');
    });
  }

  /* ---------------------------------------------------------- 在线人数 */
  function initOnline() {
    const chip = $('#onlineChip');
    const count = $('#onlineCount');
    if (!count) return;
    let timer = null;

    const poll = function () {
      fetch('/presence/heartbeat', { headers: csrfHeaders(), credentials: 'same-origin' })
        .then(r => r.json())
        .then(d => {
          if (d && d.code === 0 && d.data) {
            count.textContent = d.data.online;
            chip.title = '当前在线 ' + d.data.online + ' 人';
          }
        })
        .catch(() => {});
    };
    poll();
    timer = setInterval(poll, 15000);
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) { clearInterval(timer); timer = null; }
      else if (!timer) { poll(); timer = setInterval(poll, 15000); }
    });
  }

  /* ---------------------------------------------------------- 编辑占用心跳 */
  function initPresence() {
    const meta = document.getElementById('presenceMeta');
    if (!meta) return;
    const resourceType = meta.dataset.resourceType || '';
    const resourceId = meta.dataset.resourceId || '';
    const module = meta.dataset.module || '';
    if (!resourceType || !resourceId) return;

    const bar = $('#presenceBar');
    const barText = $('#presenceText');

    const beat = function () {
      const editing = document.hasFocus() ? '1' : '0';
      const dirty = (document.body.dataset.dirty === '1') ? '1' : '0';
      fetch('/presence/heartbeat?' + new URLSearchParams({
        module: module,
        resource_type: resourceType,
        resource_id: resourceId,
        editing: editing,
        dirty: dirty
      }), { headers: csrfHeaders(), credentials: 'same-origin' })
        .then(r => r.json())
        .then(d => {
          if (!d || d.code !== 0 || !d.data) return;
          const editors = d.data.editors || [];
          if (editors.length > 0) {
            bar.classList.remove('hidden');
            barText.textContent = '提示:' + editors.map(e => e.user).join('、') + ' 正在同时编辑此单据,保存时会做冲突校验。';
          } else {
            bar.classList.add('hidden');
          }
        })
        .catch(() => {});
    };
    beat();
    setInterval(beat, 6000);

    // 标记未保存
    const form = document.querySelector('form.doc-form');
    if (form) {
      form.addEventListener('input', function () { document.body.dataset.dirty = '1'; });
      form.addEventListener('submit', function () { document.body.dataset.dirty = '0'; });
    }

    // 离开时释放编辑占用
    const release = function () {
      const data = new URLSearchParams({ resource_type: resourceType, resource_id: resourceId });
      if (navigator.sendBeacon) {
        navigator.sendBeacon('/presence/unlock', data);
      }
    };
    window.addEventListener('beforeunload', release);
  }

  /* ---------------------------------------------------------- 冲突弹窗 */
  function initConflict() {
    const modal = $('#conflictModal');
    if (!modal) return;
    const msg = $('#conflictMsg');
    const metaBox = $('#conflictMeta');

    window.ERP.showConflict = function (payload) {
      payload = payload || {};
      if (payload.updated_by_name) {
        msg.textContent = '该单据已被 ' + payload.updated_by_name + ' 修改(版本 ' + payload.current_version + ')。';
      } else {
        msg.textContent = '该单据已被其他用户修改。';
      }
      metaBox.innerHTML = '';
      if (payload.updated_at) {
        const div = document.createElement('div');
        div.textContent = '最后修改时间:' + payload.updated_at;
        metaBox.appendChild(div);
      }
      modal.hidden = false;
      $$('[data-conflict]', modal).forEach(function (btn) {
        btn.onclick = function () {
          const action = btn.getAttribute('data-conflict');
          modal.hidden = true;
          if (action === 'reload') {
            location.reload();
          } else if (action === 'force') {
            const form = document.querySelector('form.doc-form');
            if (form) {
              let hidden = form.querySelector('input[name=force]');
              if (!hidden) {
                hidden = document.createElement('input');
                hidden.type = 'hidden';
                hidden.name = 'force';
                hidden.value = '1';
                form.appendChild(hidden);
              }
              form.submit();
            }
          }
        };
      });
    };
  }

  /* ---------------------------------------------------------- 确认操作 */
  function initConfirm() {
    document.addEventListener('click', function (e) {
      const el = e.target.closest('[data-confirm]');
      if (!el) return;
      if (!window.confirm(el.getAttribute('data-confirm'))) {
        e.preventDefault();
        e.stopPropagation();
      }
    });
  }

  /* ---------------------------------------------------------- 明细行编辑 */
  function initItems() {
    const table = document.getElementById('itemsTable');
    if (!table) return;
    const body = table.querySelector('tbody');
    const addBtn = document.getElementById('addLine');
    const tpl = document.getElementById('itemTemplate');

    const renumber = function () {
      $$('tr', body).forEach(function (tr, i) {
        const no = tr.querySelector('.line-no');
        if (no) no.textContent = String(i + 1);
        const input = tr.querySelector('input[name^="items["][name$="[line_no]"]');
        if (input) input.value = String(i + 1);
      });
    };

    const recalc = function () {
      $$('tr', body).forEach(function (tr) {
        const get = function (name) {
          const el = tr.querySelector('[name$="[' + name + ']"]');
          if (!el) return 0;
          const v = parseFloat(el.value);
          return isNaN(v) ? 0 : v;
        };
        const qty = get('qty');
        const price = get('price') || get('unit_price');
        const discount = get('discount') || 100;
        const amountCell = tr.querySelector('[data-amount]');
        if (amountCell) {
          amountCell.textContent = fmtMoney(qty * price * discount / 100);
        }
      });
      // 合计
      let sumQty = 0, sumAmount = 0;
      $$('tr', body).forEach(function (tr) {
        const get = function (name) {
          const el = tr.querySelector('[name$="[' + name + ']"]');
          if (!el) return 0;
          const v = parseFloat(el.value);
          return isNaN(v) ? 0 : v;
        };
        sumQty += get('qty');
        sumAmount += get('qty') * (get('price') || get('unit_price')) * (get('discount') || 100) / 100;
      });
      const qEl = document.querySelector('[data-total-qty]');
      const aEl = document.querySelector('[data-total-amount]');
      if (qEl) qEl.textContent = fmtQty(sumQty);
      if (aEl) aEl.textContent = fmtMoney(sumAmount);
    };

    body.addEventListener('input', recalc);
    body.addEventListener('change', function (e) {
      // 选择物料后自动带出单价
      const sel = e.target.closest('select[name$="[product_id]"]');
      if (sel && sel.selectedIndex > 0) {
        const opt = sel.options[sel.selectedIndex];
        const price = opt.getAttribute('data-price');
        if (price) {
          const tr = sel.closest('tr');
          const priceEl = tr.querySelector('[name$="[price]"]');
          if (priceEl && !priceEl.value) priceEl.value = price;
        }
      }
      // 选择资产后自动带出账面地点 / 责任人
      const assetSel = e.target.closest('select[name$="[asset_id]"]');
      if (assetSel && assetSel.selectedIndex > 0) {
        const opt = assetSel.options[assetSel.selectedIndex];
        const raw = opt.getAttribute('data-book');
        if (raw) {
          try {
            const info = JSON.parse(raw);
            const tr = assetSel.closest('tr');
            const fill = (suffix, val) => {
              const el = tr.querySelector('[name$="[' + suffix + ']"]');
              if (el && !el.value && val) el.value = val;
            };
            fill('real_location', info.location);
            fill('real_keeper', info.keeper);
            const stSel = tr.querySelector('select[name$="[real_status]"]');
            if (stSel && !stSel.value && info.status) stSel.value = info.status;
          } catch (err) { /* 忽略解析失败 */ }
        }
      }
      recalc();
    });

    body.addEventListener('click', function (e) {
      const btn = e.target.closest('.line-del');
      if (!btn) return;
      const tr = btn.closest('tr');
      tr.remove();
      renumber();
      recalc();
    });

    if (addBtn && tpl) {
      addBtn.addEventListener('click', function () {
        const html = tpl.innerHTML.replace(/__LINE__/g, String(Date.now()));
        const tmp = document.createElement('tbody');
        tmp.innerHTML = html;
        const tr = tmp.querySelector('tr');
        if (tr) {
          body.appendChild(tr);
          renumber();
          recalc();
        }
      });
    }

    renumber();
    recalc();
  }

  /* ---------------------------------------------------------- MRP 按不良率重算 */
  function initMrp() {
    const btn = document.getElementById('mrpRecalc');
    if (!btn) return;
    btn.addEventListener('click', function () {
      const qs = [];
      const wh = document.querySelector('select[name="warehouse_id"]');
      if (wh) qs.push('warehouse_id=' + encodeURIComponent(wh.value));
      const us = document.querySelector('input[name="use_safety"][type="checkbox"]');
      if (us && us.checked) qs.push('use_safety=1');
      $$('[data-defect]').forEach(function (el) {
        const pid = el.getAttribute('data-defect');
        const v = parseFloat(el.value);
        if (pid && !isNaN(v) && v > 0) {
          qs.push('defect%5B' + encodeURIComponent(pid) + '%5D=' + encodeURIComponent(v));
        }
      });
      window.location.href = '/production/mrp' + (qs.length ? '?' + qs.join('&') : '');
    });
  }

  /* ---------------------------------------------------------- 表单默认值带出 */
  /* ---------------------------------------------------------- 表单默认值带出 */
  function initPartner() {
    // 往来单位类型切换后,过滤客户 / 供应商
    const type = document.getElementById('f_partner_type');
    const unit = document.getElementById('f_partner_id');
    if (!type || !unit) return;
    const apply = function () {
      const want = type.value;
      let matched = false;
      Array.prototype.forEach.call(unit.options, function (opt) {
        if (!opt.value) { opt.disabled = false; return; }
        const raw = opt.getAttribute('data-book');
        let t = '';
        try { t = raw ? (JSON.parse(raw).type || '') : ''; } catch (err) { t = ''; }
        opt.disabled = (want !== '' && t !== want);
        if (!opt.disabled && opt.selected) matched = true;
      });
      if (want && !matched) unit.value = '';
    };
    type.addEventListener('change', apply);
    apply();
  }

  function initDocDefaults() {
    initPartner();
    // 选择供应商后带出其默认付款条件(付款方式 / 预付比例)
    const sup = document.getElementById('f_supplier_id');
    if (!sup) return;
    const term = document.getElementById('f_pay_term');
    const rate = document.getElementById('f_prepay_rate');
    sup.addEventListener('change', function () {
      const opt = sup.options[sup.selectedIndex];
      const raw = opt ? opt.getAttribute('data-book') : '';
      if (!raw) return;
      let info;
      try { info = JSON.parse(raw); } catch (err) { return; }
      if (term && !term.value && info.pay_term) term.value = info.pay_term;
      if (rate && !rate.value && info.prepay_rate !== undefined && info.prepay_rate !== null) {
        rate.value = info.prepay_rate;
      }
    });
  }

  /* ---------------------------------------------------------- 收付款核销联动 */
  function initSettle() {    const typeSel = document.getElementById('f_target_type');
    const billSel = document.getElementById('f_target_id');
    if (!typeSel || !billSel) return;

    function apply() {
      const want = typeSel.value;
      let currentVisible = false;
      Array.prototype.forEach.call(billSel.options, function (opt) {
        if (!opt.value) { opt.disabled = false; return; }
        const match = opt.getAttribute('data-type') === want;
        opt.disabled = !match;
        if (match && opt.selected) currentVisible = true;
      });
      if (want && !currentVisible) billSel.value = '';
    }

    typeSel.addEventListener('change', apply);
    apply();
  }

  /* ---------------------------------------------------------- AJAX 表单提交 */
  function initAjaxSubmit() {
    document.addEventListener('submit', function (e) {
      const form = e.target;
      if (!(form instanceof HTMLFormElement)) return;
      if (!form.classList.contains('ajax-form')) return;
      e.preventDefault();
      const btn = form.querySelector('[type=submit]');
      if (btn) btn.disabled = true;
      fetch(form.action, {
        method: 'POST',
        body: new FormData(form),
        headers: csrfHeaders(),
        credentials: 'same-origin'
      })
        .then(r => r.json().catch(() => ({ code: r.status, msg: '请求失败' })))
        .then(d => {
          if (d && d.code === 0) {
            if (d.data && d.data.redirect) { location.href = d.data.redirect; }
            else { location.reload(); }
          } else if (d && d.code === 409 && window.ERP.showConflict) {
            window.ERP.showConflict(d.data);
          } else {
            alert((d && d.msg) || '操作失败');
            if (btn) btn.disabled = false;
          }
        })
        .catch(() => { alert('网络错误,请重试'); if (btn) btn.disabled = false; });
    });
  }

  /* ---------------------------------------------------------- 启动 */
  document.addEventListener('DOMContentLoaded', function () {
    initMenu();
    initOnline();
    initPresence();
    initConflict();
    initConfirm();
    initItems();
    initMrp();
    initDocDefaults();
    initSettle();
    initAjaxSubmit();
  });
})();
