// whip_gunny: the weapon bench (client/attachments.lua)

let workbenchData = {
    attachments: [],
    categories: {},
    attachmentDefs: {},
    weaponAttachments: {}
};

let state = {
    selectedWeapon: null,   // the gun on the bench: the one in the player's hand
    isOpen: false,
    isDragging: false,
    lastMouseX: 0,
    lastMouseY: 0
};

// The bench's icons: 24 x 24, drawn in currentColor, as whip's own glyphs are (whip_core html/js/glyphs.js). A slot's
// is named by its category's `icon` (items/attachments.lua).
const svg = (body) => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"'
    + ' stroke-linejoin="round" aria-hidden="true">' + body + '</svg>';
const ICONS = {
    scope:      svg('<circle cx="12" cy="12" r="7"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>'),
    muzzle:     svg('<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.5" fill="currentColor"/>'),
    barrel:     svg('<path d="M3 9h18M3 15h18M6 6v12"/>'),
    grip:       svg('<rect x="8" y="3" width="8" height="18" rx="3"/><path d="M8 9h8M8 13h8"/>'),
    flashlight: svg('<path d="M13 2 5 14h6l-1 8 8-12h-6z"/>'),
    slot:       svg('<circle cx="12" cy="12" r="6"/>'),
    close:      svg('<path d="M6 6l12 12M18 6 6 18"/>'),
    installed:  svg('<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9.5"/>'),
    remove:     svg('<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>'),
    add:        svg('<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>'),
    blocked:    svg('<circle cx="12" cy="12" r="9"/><path d="M5.6 5.6l12.8 12.8"/>'),
    working:    svg('<path d="M12 3a9 9 0 1 1-9 9"/>'),
    done:       svg('<path d="M5 12.5 10 17.5 19 7"/>'),
    failed:     svg('<path d="M6 6l12 12M18 6 6 18"/>'),
    rotate:     svg('<path d="M20 11a8 8 0 0 0-14.3-4.9L4 8M4 4v4h4M4 13a8 8 0 0 0 14.3 4.9L20 16M20 20v-4h-4"/>'),
};
const iconOf = (name) => ICONS[name] || ICONS.slot;

const workbench = document.getElementById('workbench');
const benchTitle = document.getElementById('benchTitle');
const slotsContainer = document.getElementById('slotsContainer');
const optionsPopup = document.getElementById('optionsPopup');
const popupTitle = document.getElementById('popupTitle');
const popupIcon = document.getElementById('popupIcon');
const popupContent = document.getElementById('popupContent');
const popupClose = document.getElementById('popupClose');
const statusIndicator = document.getElementById('statusIndicator');
const statusIcon = document.getElementById('statusIcon');
const statusText = document.getElementById('statusText');

// Once, as the page loads: the fixed icons, Escape, and the drag that turns the gun.
function init() {
    // The page's fixed icons (index.html's data-icon)
    document.querySelectorAll('[data-icon]').forEach((el) => { el.innerHTML = iconOf(el.dataset.icon); });

    popupClose.addEventListener('click', closePopup);

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (!optionsPopup.classList.contains('hidden')) {
                closePopup();
            } else {
                close();
            }
        }
    });

    // A click anywhere but the list or a slot shuts the list.
    document.addEventListener('click', (e) => {
        if (!optionsPopup.classList.contains('hidden') &&
            !optionsPopup.contains(e.target) &&
            !e.target.closest('.slot-box')) {
            closePopup();
        }
    });

    // A drag on empty space turns the gun (client/attachments.lua turns the model); not on the list, a slot or the
    // control strip.
    document.addEventListener('mousedown', (e) => {
        if (e.target.closest('#optionsPopup') ||
            e.target.closest('.slot-box') ||
            e.target.closest('#controlStrip')) {
            return;
        }

        if (state.selectedWeapon) {
            state.isDragging = true;
            state.lastMouseX = e.clientX;
            state.lastMouseY = e.clientY;
            document.body.style.cursor = 'grabbing';
        }
    });

    // A fast mouse fires many moves a frame: they are added up and sent at most once a frame.
    let turn = null;
    document.addEventListener('mousemove', (e) => {
        if (!state.isDragging) return;

        const deltaX = e.clientX - state.lastMouseX;
        const deltaY = e.clientY - state.lastMouseY;

        state.lastMouseX = e.clientX;
        state.lastMouseY = e.clientY;

        if (turn) { turn.deltaX += deltaX; turn.deltaY += deltaY; return; }
        turn = { deltaX, deltaY };
        requestAnimationFrame(() => {
            const sent = turn;
            turn = null;
            fetch(`https://${GetParentResourceName()}/rotateWeapon`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(sent)
            }).catch(() => {});
        });
    });

    document.addEventListener('mouseup', () => {
        if (state.isDragging) {
            state.isDragging = false;
            document.body.style.cursor = 'default';
        }
    });
}

// Put the gun on the bench: on opening, and again after a fit or a removal, with what it has fitted now
function selectWeapon(weapon) {
    state.selectedWeapon = weapon;
    closePopup();

    fetch(`https://${GetParentResourceName()}/selectWeapon`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            weaponName: weapon.name,
            categories: weapon.categories,
            attachments: weapon.attachments || {}
        })
    }).catch(err => console.log('selectWeapon fetch error:', err));

    workbench.classList.add('can-drag');

    renderSlots();
}

// A ring per slot. Each starts off (hidden) until client/attachments.lua says where it is on the screen.
function renderSlots() {
    slotsContainer.innerHTML = '';

    if (!state.selectedWeapon) {
        return;
    }

    const weapon = state.selectedWeapon;
    const attachments = weapon.attachments || {};

    weapon.categories.forEach((category, index) => {
        const categoryConfig = workbenchData.categories[category];
        if (!categoryConfig) return;

        const isFilled = !!attachments[category];

        const slotBox = document.createElement('div');
        slotBox.className = 'slot-box off' + (isFilled ? ' filled' : '');
        slotBox.id = `slot-${category}`;
        slotBox.style.animationDelay = `${0.1 + index * 0.08}s`;
        slotBox.dataset.category = category;

        const icon = document.createElement('i');
        icon.innerHTML = iconOf(categoryConfig.icon || category);
        slotBox.appendChild(icon);

        const label = document.createElement('span');
        label.className = 'slot-label';
        label.textContent = categoryConfig.label;
        slotBox.appendChild(label);

        slotBox.addEventListener('click', (e) => {
            e.stopPropagation();
            openSlotOptions(category, slotBox);
        });

        slotsContainer.appendChild(slotBox);
    });
    padRefresh();
}

// Where each slot is on the screen now (0..1 across and down), or off it: a slot off the screen is hidden, not moved.
function updateSlotPositions(positions) {
    if (!state.selectedWeapon) return;

    for (const [category, pos] of Object.entries(positions)) {
        const slotBox = document.getElementById(`slot-${category}`);
        if (!slotBox) continue;

        slotBox.classList.toggle('off', !pos.visible);
        if (pos.visible) {
            slotBox.style.left = `${pos.x * 100}%`;
            slotBox.style.top = `${pos.y * 100}%`;
        }
    }
    // On a controller, the first slot on the screen is ringed as soon as there is one, so the first A opens it.
    if (padOn && !padKey && !popupOpen()) {
        padKey = padFirst();
        padMark();
    }
}

// A slot's list, beside the slot it was opened from.
function openSlotOptions(category, slotElement) {
    const categoryConfig = workbenchData.categories[category];
    popupTitle.textContent = categoryConfig?.label || category;
    popupIcon.innerHTML = iconOf(categoryConfig?.icon || category);

    // To the slot's right, or its left where the right runs off the screen; never off the top or bottom.
    const rect = slotElement.getBoundingClientRect();
    let popupX = rect.right + 15;
    let popupY = rect.top - 20;
    if (popupX + 280 > window.innerWidth) {
        popupX = rect.left - 290;
    }
    if (popupY + 320 > window.innerHeight) {
        popupY = window.innerHeight - 330;
    }
    if (popupY < 20) {
        popupY = 20;
    }

    optionsPopup.style.left = `${popupX}px`;
    optionsPopup.style.top = `${popupY}px`;

    buildOptionsPopup(category);

    optionsPopup.classList.remove('hidden');

    document.querySelectorAll('.slot-box').forEach(el => el.classList.remove('selected'));
    slotElement.classList.add('selected');
}

// A row of the list: its icon, its name and a line under it. Names go in as text, never as markup.
function optionRow(className, iconName, name, desc) {
    const el = document.createElement('div');
    el.className = className;
    const nameEl = document.createElement('div');
    nameEl.className = 'option-name';
    const icon = document.createElement('i');
    icon.innerHTML = iconOf(iconName);   // our own SVG
    nameEl.append(icon, ' ', name);
    const descEl = document.createElement('div');
    descEl.className = 'option-desc';
    descEl.textContent = desc;
    el.append(nameEl, descEl);
    return el;
}

// The list's rows: what is fitted (and Remove), or what the player carries for this slot, greyed where this gun
// does not take it.
function buildOptionsPopup(category) {
    popupContent.innerHTML = '';

    const currentAttachment = state.selectedWeapon?.attachments?.[category];

    if (currentAttachment) {
        const attachmentDef = workbenchData.attachmentDefs[currentAttachment];
        popupContent.appendChild(optionRow('option-item current', 'installed', attachmentDef?.label || currentAttachment,
            'Currently installed'));

        const removeEl = optionRow('option-item remove', 'remove', 'Remove Attachment', 'Return to inventory');
        removeEl.addEventListener('click', () => removeAttachment(category));
        popupContent.appendChild(removeEl);

        return;
    }

    const categoryAttachments = workbenchData.attachments.filter(att => att.category === category);

    // The bench lists what the player carries
    if (categoryAttachments.length === 0) {
        popupContent.innerHTML = '<div class="no-options">None on you<small>Carry one to fit it here</small></div>';
        return;
    }

    const weaponName = state.selectedWeapon?.name;
    const weaponSupport = workbenchData.weaponAttachments?.[weaponName]?.[category] || {};

    categoryAttachments.forEach((att, index) => {
        const isCompatible = weaponSupport[att.tier] !== undefined;
        const el = isCompatible
            ? optionRow('option-item', 'add', att.label, 'Click to install')
            : optionRow('option-item disabled', 'blocked', att.label, 'Not compatible with this weapon');
        el.style.animationDelay = `${index * 0.03}s`;
        if (isCompatible) el.addEventListener('click', () => installAttachment(att));
        popupContent.appendChild(el);
    });
}

function closePopup() {
    optionsPopup.classList.add('hidden');
    document.querySelectorAll('.slot-box').forEach(el => el.classList.remove('selected'));
}

// Fit one. The server answers with the bench as it is after (the gun and the attachments carried), drawn again here.
async function installAttachment(attachment) {
    showStatus('Installing...', 'working', true);
    closePopup();

    try {
        const response = await fetch(`https://${GetParentResourceName()}/installAttachment`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            // The attachment by its slot and pocket (the bench lists every pocket's); the gun is always the one in hand.
            body: JSON.stringify({
                attachmentSlot: attachment.slot,
                attachmentPocket: attachment.pocket
            })
        });

        const result = await response.json();
        if (!state.isOpen) return;   // shut while the server answered: nothing to show it on

        if (result.success) {
            showStatus('Installed!', 'done', false);
            statusIndicator.classList.add('success');

            if (result.data) workbenchData.attachments = result.data.attachments || [];
            selectWeapon(result.data?.weapon || state.selectedWeapon);
        } else {
            showStatus(result.message || 'Failed', 'failed', false);
        }
    } catch (err) {
        console.log('installAttachment error:', err);
        showStatus('Error', 'failed', false);
    }

    hideStatusSoon();
}

// Take one off, the same way.
async function removeAttachment(category) {
    showStatus('Removing...', 'working', true);
    closePopup();

    try {
        const response = await fetch(`https://${GetParentResourceName()}/removeAttachment`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ category: category })
        });

        const result = await response.json();
        if (!state.isOpen) return;   // shut while the server answered: nothing to show it on

        if (result.success) {
            showStatus('Removed!', 'done', false);
            statusIndicator.classList.add('success');

            if (result.data) workbenchData.attachments = result.data.attachments || [];
            selectWeapon(result.data?.weapon || state.selectedWeapon);
        } else {
            showStatus(result.message || 'Failed', 'failed', false);
        }
    } catch (err) {
        console.log('removeAttachment error:', err);
        showStatus('Error', 'failed', false);
    }

    hideStatusSoon();
}

// The line under the gun saying what is happening. One timer hides it: a new line (a second fit started straight
// after) stops the last one's, so 'Installing...' stays up until its own answer.
let statusTimer = null;

function showStatus(text, icon = 'working', spinning = false) {
    clearTimeout(statusTimer);
    statusText.textContent = text;
    statusIcon.innerHTML = iconOf(icon);
    statusIcon.classList.toggle('gy-spin', spinning);
    statusIndicator.classList.remove('hidden', 'success');
}

function hideStatus() {
    clearTimeout(statusTimer);
    statusIndicator.classList.add('hidden');
    statusIndicator.classList.remove('success');
}

// An answer's line stays up long enough to read.
function hideStatusSoon() {
    clearTimeout(statusTimer);
    statusTimer = setTimeout(hideStatus, 1800);
}

// Shut the bench: here, then client/attachments.lua puts the camera, the gun and the focus away.
function close() {
    workbench.classList.add('hidden');
    workbench.classList.remove('can-drag');
    state.selectedWeapon = null;
    state.isOpen = false;
    state.isDragging = false;
    closePopup();
    hideStatus();

    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(err => console.log('close fetch error:', err));
}

// ============================================
// ON A CONTROLLER
// ============================================
// The browser cannot read a gamepad inside FiveM, so client/attachments.lua reads it and sends the
// presses here ('pad'); the right stick turns the weapon over there. The D-pad rings a slot round the
// weapon and A opens it; in a slot's list the D-pad walks the rows and A fits
// or takes off; B goes back a step, and from the slots shuts the bench. The ring is kept as a key, so
// it outlives the slots and lists being drawn again after a fit.

const padImg = (n) => `<img class="pad-g" src="https://cfx-nui-whip_core/html/img/pad/${n}.svg" alt="">`;
const padHintsRight = document.getElementById('padHintsRight');
const padBackText = document.getElementById('padBackText');
let padOn = false;    // a controller is driving the bench
let padKey = null;    // the ringed thing: 's:<category>' or 'o:<row>'
let padSlot = null;   // the slot key a list was opened from, for B

const popupOpen = () => !optionsPopup.classList.contains('hidden');

// What the D-pad can ring now: the open list's rows that do something, or else the slots on the screen.
function padTargets() {
    if (popupOpen()) return [...popupContent.querySelectorAll('.option-item:not(.disabled):not(.current)')];
    return [...slotsContainer.querySelectorAll('.slot-box:not(.off)')];
}

function keyOf(el) {
    if (el.classList.contains('slot-box')) return 's:' + el.dataset.category;
    return 'o:' + padTargets().indexOf(el);
}

function padFind(key) {
    if (!key) return null;
    const rest = key.slice(2);
    if (key[0] === 's') return document.getElementById('slot-' + rest);
    return popupOpen() ? padTargets()[Number(rest)] || null : null;
}

function padFirst() {
    const t = padTargets();
    return t.length ? keyOf(t[0]) : null;
}

// Light the ringed thing (none off a pad) and say what A does to it.
function padMark() {
    document.querySelectorAll('#workbench .pad-focus').forEach(el => el.classList.remove('pad-focus'));
    const el = padOn && padFind(padKey);
    if (el) {
        el.classList.add('pad-focus');
        if (!el.classList.contains('slot-box')) el.scrollIntoView({ block: 'nearest' });
    }
    padHints();
}

function padSet(el) {
    padKey = el ? keyOf(el) : null;
    padMark();
}

// After the slots are drawn again: the same thing ringed, or the first if it went.
function padRefresh() {
    if (!padOn) return;
    if (!padFind(padKey) && !popupOpen()) padKey = padFirst();
    padMark();
}

function padHints() {
    if (!padOn) return;
    const list = popupOpen();
    const el = padFind(padKey);
    padBackText.textContent = list ? 'Back' : 'Close';
    const what = !el ? '' : el.classList.contains('slot-box') ? 'Open'
        : el.classList.contains('remove') ? 'Remove' : 'Install';
    const hint = (img, text) => `<div class="control-hint esc-hint">${img}<span>${text}</span></div>`;
    padHintsRight.innerHTML = hint(padImg('dpad'), list ? 'Browse' : 'Move') + (what ? hint(padImg('a'), what) : '');
}

const centreOf = (el) => { const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; };

// A list: up and down walk it. The slots float round the weapon, so there it is the nearest one that
// way, a step off to the side counting double: within 45 degrees of the press if any is, or else
// anything on that side.
function padStep(dir) {
    const items = padTargets();
    if (!items.length) return;
    const cur = padFind(padKey);
    if (!cur || !items.includes(cur)) { padSet(items[0]); return; }
    if (popupOpen()) {
        const next = items[items.indexOf(cur) + (dir === 'down' ? 1 : dir === 'up' ? -1 : 0)];
        if (next) padSet(next);
        return;
    }
    const c = centreOf(cur);
    const [ax, ay] = { left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1] }[dir];
    let best = null, bestScore = Infinity, bestInCone = false;
    for (const el of items) {
        if (el === cur) continue;
        const p = centreOf(el);
        const along = (p.x - c.x) * ax + (p.y - c.y) * ay;
        if (along <= 4) continue;
        const across = Math.abs((p.x - c.x) * ay) + Math.abs((p.y - c.y) * ax);
        const inCone = across <= along, score = along + 2 * across;
        if (inCone && !bestInCone || inCone === bestInCone && score < bestScore) {
            best = el; bestScore = score; bestInCone = inCone;
        }
    }
    if (best) padSet(best);
}

function padPress(cmd) {
    if (!state.isOpen) return;
    if (cmd === 'up' || cmd === 'down' || cmd === 'left' || cmd === 'right') { padStep(cmd); return; }
    if (cmd === 'b') {
        if (popupOpen()) { closePopup(); padKey = padSlot; padMark(); }
        else close();
        return;
    }
    if (cmd !== 'a') return;
    const el = padFind(padKey);
    if (!el) { padStep('down'); return; }   // nothing ringed yet: ring the first
    if (el.classList.contains('slot-box')) {
        padSlot = keyOf(el);
        openSlotOptions(el.dataset.category, el);
        padKey = padFirst();
        padMark();
    } else {
        padKey = padSlot;   // fitting or taking off shuts the list: back on its slot
        el.click();
        padMark();
    }
}

function padApply(on) {
    padOn = !!on;
    workbench.classList.toggle('pad', padOn);
    if (padOn && !padFind(padKey) && !popupOpen()) padKey = padFirst();
    padMark();
}

// ============================================
// NUI MESSAGE HANDLER
// ============================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            workbenchData.attachments = data.attachments || [];
            workbenchData.categories = data.categories || {};
            workbenchData.attachmentDefs = data.attachmentDefs || {};
            workbenchData.weaponAttachments = data.weaponAttachments || {};
            benchTitle.textContent = data.label || 'Weapon Bench';

            state.selectedWeapon = null;
            state.isOpen = true;
            state.isDragging = false;
            padKey = padSlot = null;

            workbench.classList.remove('hidden');
            workbench.classList.remove('can-drag');
            closePopup();
            hideStatus();

            selectWeapon(data.weapon);
            padApply(data.pad);
            break;

        case 'close':
            workbench.classList.add('hidden');
            state.isOpen = false;
            break;

        case 'pad':
            padPress(data.cmd);
            break;

        case 'padDevice':
            padApply(data.pad);
            break;

        case 'updateSlotPositions':
            updateSlotPositions(data.positions);
            break;
    }
});

init();
