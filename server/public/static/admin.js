/* HemoGuard Studio UI enhancements. Progressive enhancement only: native forms and routes remain intact. */
(() => {
  'use strict';
  const $ = (selector, scope = document) => scope.querySelector(selector);
  const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));
  const motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const saveFlag = (key, value) => { try { sessionStorage.setItem(key, value); } catch (_) {} };
  const readFlag = key => { try { return sessionStorage.getItem(key); } catch (_) { return null; } };
  const clearFlag = key => { try { sessionStorage.removeItem(key); } catch (_) {} };
  function toast(message) {
    const region = $('#toast-region');
    if (!region) return;
    const item = document.createElement('div');
    item.className = 'toast';
    item.setAttribute('role', 'status');
    const mark = document.createElement('span');
    mark.className = 'toast-mark';
    mark.textContent = '✦';
    const content = document.createElement('span');
    content.textContent = message;
    item.append(mark, content);
    region.append(item);
    setTimeout(() => item.remove(), 4300);
  }
  function busyForm(form) {
    form.addEventListener('submit', event => {
      if (event.defaultPrevented || !form.checkValidity()) return;
      const button = $('button[type="submit"]', form);
      if (!button || button.disabled) return;
      button.classList.add('is-submitting');
      button.disabled = true;
      button.setAttribute('aria-busy', 'true');
      // Preserve normal native form submission. A disabled button does not disable inputs.
    });
  }

  const loginForm = $('[data-login-form]');
  if (loginForm) {
    if ($('.auth-error')) clearFlag('hg-login-pending');
    const pass = $('#login-password');
    const reveal = $('[data-toggle-password]');
    const caps = $('#caps-warning');
    if (reveal && pass) {
      reveal.addEventListener('click', () => {
        const showing = pass.type === 'password';
        pass.type = showing ? 'text' : 'password';
        reveal.textContent = showing ? 'Hide' : 'Show';
        reveal.setAttribute('aria-label', showing ? 'Hide password' : 'Show password');
        reveal.setAttribute('aria-pressed', String(showing));
        pass.focus();
      });
      pass.addEventListener('keyup', e => { if (caps && e.getModifierState) caps.hidden = !e.getModifierState('CapsLock'); });
      pass.addEventListener('blur', () => { if (caps) caps.hidden = true; });
    }
    loginForm.addEventListener('submit', event => {
      if (event.defaultPrevented || !loginForm.checkValidity()) return;
      saveFlag('hg-login-pending', '1');
      const button = $('button[type="submit"]', loginForm);
      if (button) {
        $('.button-text', button).textContent = 'Verifying credentials…';
        button.classList.add('is-submitting');
        button.setAttribute('aria-busy', 'true');
        button.disabled = true;
      }
    });
  } else if ($('.admin-page') && readFlag('hg-login-pending') === '1') {
    clearFlag('hg-login-pending');
    toast('Welcome back. Your workspace is ready.');
  }

  $$('[data-enhanced-form]').forEach(busyForm);

  // Search only current table rows. This does not alter reporting counts or query the backend.
  $$('[data-table-search]').forEach(input => {
    const table = document.getElementById(input.dataset.tableSearch);
    if (!table) return;
    const rows = $$('tbody tr:not(.empty-row)', table);
    const empty = $(`[data-empty-for="${input.dataset.tableSearch}"]`);
    input.addEventListener('input', () => {
      const value = input.value.trim().toLocaleLowerCase();
      let matched = 0;
      rows.forEach(row => {
        const visible = row.textContent.toLocaleLowerCase().includes(value);
        row.hidden = !visible;
        if (visible) matched++;
      });
      if (empty) empty.hidden = !rows.length || matched > 0;
    });
  });

  const planType = $('[data-access-plan]');
  const planUnit = $('[data-access-unit]');
  if (planType && planUnit) {
    const updateUnit = () => {
      const months = $('option[value="months"]', planUnit);
      if (months) months.disabled = planType.value === 'trial';
      if (planType.value === 'trial') planUnit.value = 'days';
    };
    planType.addEventListener('change', updateUnit);
    updateUnit();
  }
  const planAction = $('[data-plan-action]');
  const planDuration = $('[data-plan-duration]');
  const renewalUnit = $('[data-plan-unit]');
  if (planAction && planDuration && renewalUnit) {
    const update = () => {
      const action = planAction.value;
      const stopped = action.startsWith('stop_');
      const isTrial = action.endsWith('_trial');
      planDuration.disabled = stopped;
      renewalUnit.disabled = stopped;
      const months = $('option[value="months"]', renewalUnit);
      if (months) months.disabled = isTrial;
      if (isTrial) renewalUnit.value = 'days';
    };
    planAction.addEventListener('change', update);
    update();
  }

  const logoutForm = $('[data-logout-form]');
  const modal = $('#logout-modal');
  if (logoutForm && modal) {
    const confirmButton = $('[data-confirm-logout]', modal);
    const stayButton = $('[data-stay]', modal);
    const dialog = $('.logout-modal', modal);
    const transition = $('#session-transition');
    const trigger = $('button[type="submit"]', logoutForm);
    let submitting = false;
    const close = () => {
      modal.hidden = true;
      document.body.style.overflow = '';
      trigger?.focus();
    };
    logoutForm.addEventListener('submit', event => {
      if (submitting) return;
      event.preventDefault();
      modal.hidden = false;
      document.body.style.overflow = 'hidden';
      stayButton?.focus();
    });
    stayButton?.addEventListener('click', close);
    modal.addEventListener('click', event => { if (event.target === modal) close(); });
    document.addEventListener('keydown', event => {
      if (modal.hidden) return;
      if (event.key === 'Escape') { event.preventDefault(); close(); }
      if (event.key === 'Tab') {
        const buttons = [stayButton, confirmButton];
        const current = buttons.indexOf(document.activeElement);
        if (event.shiftKey && current === 0) { event.preventDefault(); confirmButton?.focus(); }
        if (!event.shiftKey && current === 1) { event.preventDefault(); stayButton?.focus(); }
      }
    });
    confirmButton?.addEventListener('click', () => {
      if (submitting) return;
      submitting = true;
      modal.hidden = true;
      if (transition) transition.hidden = false;
      clearFlag('hg-login-pending');
      // The server, not this animation, revokes the session and clears the cookie.
      window.setTimeout(() => HTMLFormElement.prototype.submit.call(logoutForm), motionOK ? 620 : 0);
    });
    dialog?.addEventListener('click', event => event.stopPropagation());
  }
})();

/* Superadmin profile image processing and password confirmation. */
(() => {
  'use strict';
  const input = document.querySelector('[data-avatar-input]');
  const hidden = document.querySelector('[data-profile-image-data]');
  const previewImage = document.querySelector('[data-avatar-image]');
  const fallback = document.querySelector('[data-avatar-fallback]');
  const status = document.querySelector('[data-profile-image-status]');
  const remove = document.querySelector('[data-remove-picture]');

  const setStatus = (message, isError = false) => {
    if (!status) return;
    status.textContent = message;
    status.style.color = isError ? '#b92950' : '';
  };

  if (input && hidden && previewImage) {
    input.addEventListener('change', () => {
      const file = input.files && input.files[0];
      if (!file) return;
      if (!['image/png','image/jpeg','image/webp'].includes(file.type)) {
        input.value = '';
        setStatus('Choose a PNG, JPEG or WebP image.', true);
        return;
      }
      if (file.size > 5 * 1024 * 1024) {
        input.value = '';
        setStatus('Choose an image smaller than 5 MB.', true);
        return;
      }
      setStatus('Preparing image…');
      const reader = new FileReader();
      reader.onerror = () => setStatus('This image could not be read.', true);
      reader.onload = () => {
        const image = new Image();
        image.onerror = () => setStatus('This image could not be processed.', true);
        image.onload = () => {
          const size = 384;
          const canvas = document.createElement('canvas');
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext('2d', { alpha: false });
          if (!ctx) { setStatus('Image processing is not supported in this browser.', true); return; }
          ctx.fillStyle = '#ffffff';
          ctx.fillRect(0, 0, size, size);
          const crop = Math.min(image.naturalWidth, image.naturalHeight);
          const sx = Math.max(0, (image.naturalWidth - crop) / 2);
          const sy = Math.max(0, (image.naturalHeight - crop) / 2);
          ctx.drawImage(image, sx, sy, crop, crop, 0, 0, size, size);
          const data = canvas.toDataURL('image/jpeg', 0.84);
          if (data.length > 390000) {
            setStatus('The processed image is still too large. Try a simpler photo.', true);
            return;
          }
          hidden.value = data;
          previewImage.src = data;
          previewImage.hidden = false;
          if (fallback) fallback.hidden = true;
          if (remove) remove.checked = false;
          setStatus('New picture ready. Save profile to apply it.');
        };
        image.src = String(reader.result || '');
      };
      reader.readAsDataURL(file);
    });
  }

  if (remove) {
    remove.addEventListener('change', () => {
      if (!remove.checked) return;
      if (hidden) hidden.value = '';
      if (previewImage) previewImage.hidden = true;
      if (fallback) fallback.hidden = false;
      setStatus('Current picture will be removed when you save.');
    });
  }

  const passwordForm = document.querySelector('[data-password-change-form]');
  if (passwordForm) {
    const next = passwordForm.querySelector('[name="new_password"]');
    const confirm = passwordForm.querySelector('[name="confirm_password"]');
    const checkMatch = () => {
      if (!confirm || !next) return;
      confirm.setCustomValidity(confirm.value && confirm.value !== next.value ? 'Passwords do not match.' : '');
    };
    next?.addEventListener('input', checkMatch);
    confirm?.addEventListener('input', checkMatch);
    passwordForm.addEventListener('submit', event => {
      checkMatch();
      if (event.defaultPrevented || !passwordForm.checkValidity()) return;
      const button = passwordForm.querySelector('button[type="submit"]');
      if (button) {
        button.classList.add('is-submitting');
        button.disabled = true;
        button.setAttribute('aria-busy','true');
      }
    });
  }
})();


/* Direction-aware primary navigation. Keeps normal server routes while making full-page navigation feel continuous. */
(() => {
  'use strict';
  const nav = document.querySelector('[data-main-nav]');
  if (!nav) {
    try { sessionStorage.removeItem('hg-nav-direction'); } catch (_) {}
    return;
  }
  const links = Array.from(nav.querySelectorAll('a[data-nav-index]'));
  const focus = nav.querySelector('[data-nav-focus]');
  const motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let navigating = false;

  const placeFocus = link => {
    if (!link || !focus) { nav.classList.remove('has-focus'); return; }
    nav.style.setProperty('--nav-focus-x', `${link.offsetLeft}px`);
    focus.style.width = `${link.offsetWidth}px`;
    nav.classList.add('has-focus');
  };

  const active = () => nav.querySelector('a[aria-current="page"]');

  // Place the indicator after fonts/layout settle, then keep it aligned during responsive changes.
  const settle = () => requestAnimationFrame(() => placeFocus(active()));
  settle();
  if (document.fonts?.ready) document.fonts.ready.then(settle).catch(() => {});
  window.addEventListener('resize', settle, { passive: true });

  const incomingDirection = document.documentElement.dataset.navEnter;
  if (incomingDirection) {
    try { sessionStorage.removeItem('hg-nav-direction'); } catch (_) {}
    window.setTimeout(() => { delete document.documentElement.dataset.navEnter; }, motionOK ? 520 : 0);
  }

  links.forEach(link => {
    link.addEventListener('click', event => {
      if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      if (navigating) { event.preventDefault(); return; }
      const current = active();
      const currentIndex = Number(current?.dataset.navIndex ?? -1);
      const targetIndex = Number(link.dataset.navIndex ?? -1);
      const currentUrl = new URL(window.location.href);
      const targetUrl = new URL(link.href, window.location.href);
      if (currentUrl.pathname === targetUrl.pathname && currentUrl.search === targetUrl.search) return;

      const direction = currentIndex < 0 || targetIndex >= currentIndex ? 'forward' : 'backward';
      event.preventDefault();
      navigating = true;
      links.forEach(item => item.classList.toggle('is-nav-target', item === link));
      nav.classList.add('is-moving');
      placeFocus(link);
      try { sessionStorage.setItem('hg-nav-direction', direction); } catch (_) {}

      if (!motionOK) { window.location.assign(link.href); return; }
      document.body.classList.add(`hg-nav-leaving-${direction}`);
      window.setTimeout(() => window.location.assign(link.href), 185);
    });
  });

  // Restore the correct state when returning via browser back/forward cache.
  window.addEventListener('pageshow', event => {
    if (!event.persisted) return;
    navigating = false;
    document.body.classList.remove('hg-nav-leaving-forward','hg-nav-leaving-backward');
    nav.classList.remove('is-moving');
    links.forEach(item => item.classList.remove('is-nav-target'));
    settle();
  });
})();
