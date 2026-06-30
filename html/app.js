const tablet = document.getElementById('tablet');
const applicantView = document.getElementById('applicantView');
const toast = document.getElementById('toast');
const confirmModal = document.getElementById('confirmModal');

let dashboardData = { questions: [], players: [], logs: [], stats: {} };
let localQuestions = [];
let currentFilter = 'all';
let searchQuery = '';
let autoRefreshInterval = null;
let confirmCallback = null;
let selectedPlayer = null;
let localeUi = {};
let currentLocale = 'de';

const pageTabKeys = {
    dashboard: ['nav_dashboard', 'i-chart', 'blue'],
    actions: ['nav_players', 'i-people', 'teal'],
    questions: ['nav_questions', 'i-doc', 'purple'],
    tools: ['nav_tools', 'i-wrench', 'orange'],
    logs: ['nav_logs', 'i-list', 'gray']
};

const actionLabelKeys = {
    eingereist: 'action_eingereist',
    skin_gegeben: 'action_skin_gegeben',
    einreise_entzogen: 'action_einreise_entzogen',
    notiz: 'action_notiz',
    startgeld: 'action_startgeld',
    freeze: 'action_freeze',
    unfreeze: 'action_unfreeze'
};

const actionColors = {
    eingereist: 'green',
    skin_gegeben: 'purple',
    einreise_entzogen: 'red',
    notiz: '',
    startgeld: 'green'
};

function t(key, ...args) {
    let str = localeUi[key] || key;
    args.forEach(arg => {
        str = str.replace('%s', arg);
    });
    return str;
}

function getDateLocale() {
    return currentLocale === 'en' ? 'en-US' : 'de-DE';
}

function getActionLabel(action) {
    const key = actionLabelKeys[action];
    return key ? t(key) : action;
}

function applyLocale() {
    document.documentElement.lang = currentLocale;
    document.title = `${t('app_title')} Tablet`;

    document.querySelectorAll('[data-i18n]').forEach(el => {
        if (el.id === 'confirmTitle' || el.id === 'confirmText') return;
        el.textContent = t(el.dataset.i18n);
    });

    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
        el.placeholder = t(el.dataset.i18nPlaceholder);
    });
}

function loadLocale(data, config) {
    if (data?.localeUi) localeUi = data.localeUi;
    if (data?.locale) currentLocale = data.locale;
    else if (config?.locale) currentLocale = config.locale;
    applyLocale();
}

function isPlayerEingereist(player) {
    if (!player) return false;
    const value = player.eingereist;
    return value === true || value === 1 || value === '1';
}

function getPlayerStatusLabel(player) {
    return isPlayerEingereist(player) ? t('status_admitted') : t('status_waiting');
}

function getPlayerStatusClass(player) {
    return isPlayerEingereist(player) ? 'done' : 'pending';
}

function setPlayerEntryStatusLocal(playerId, eingereist, staffName) {
    if (!dashboardData.players) return;

    const player = dashboardData.players.find(p => p.id === playerId);
    if (player) {
        player.eingereist = eingereist;
        player.eingereist_by = eingereist ? (staffName || dashboardData.staffName || null) : null;
    }

    if (selectedPlayer?.id === playerId && player) {
        selectedPlayer = { ...player };
    }

    renderDashboard();
    renderPlayers();
    renderSelectedPlayer();
}

function post(endpoint, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(r => r.json()).catch(() => ({}));
}

function showToast(msg) {
    toast.textContent = msg;
    toast.classList.remove('hidden');
    setTimeout(() => toast.classList.add('hidden'), 2800);
}

function showGameNotify(msg) {
    const stack = document.getElementById('notifyStack');
    if (!stack) return;

    const el = document.createElement('div');
    el.className = 'notify-banner';
    el.innerHTML = `
        <span class="icon-box sm blue notify-icon"><svg class="icon" width="14" height="14"><use xlink:href="#i-airplane"/></svg></span>
        <span>${escapeHtml(msg)}</span>
    `;
    stack.appendChild(el);

    setTimeout(() => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(-8px)';
        el.style.transition = '0.3s ease';
        setTimeout(() => el.remove(), 300);
    }, 4500);
}

function showConfirm(title, text, onOk) {
    document.getElementById('confirmTitle').textContent = title;
    document.getElementById('confirmText').textContent = text;
    confirmCallback = onOk;
    confirmModal.classList.remove('hidden');
}

function getTargetId() {
    const val = document.getElementById('targetId').value;
    const id = parseInt(val, 10);
    if (!id || id < 1) {
        showToast(t('toast_select_player'));
        return null;
    }
    return id;
}

function switchTab(tabName) {
    document.querySelectorAll('.nav-item').forEach(t => {
        t.classList.toggle('active', t.dataset.tab === tabName);
    });
    document.querySelectorAll('.tab-content').forEach(c => {
        c.classList.toggle('active', c.id === `tab-${tabName}`);
    });

    const [titleKey, iconId, iconColor] = pageTabKeys[tabName] || ['nav_dashboard', 'i-chart', 'blue'];
    document.getElementById('pageTitle').textContent = t(titleKey);

    const pageIcon = document.getElementById('pageIcon');
    if (pageIcon) {
        pageIcon.className = `icon-box md page-icon ${iconColor}`;
        pageIcon.innerHTML = `<svg class="icon" width="22" height="22"><use xlink:href="#${iconId}"/></svg>`;
    }
}

function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function getInitial(name) {
    return (name || '?').charAt(0).toUpperCase();
}

function updateClock() {
    const now = new Date();
    const time = now.toLocaleTimeString(getDateLocale(), { hour: '2-digit', minute: '2-digit' });
    document.getElementById('liveTime').textContent = time;
    document.getElementById('liveDate').textContent = now.toLocaleDateString(getDateLocale(), { weekday: 'short', day: '2-digit', month: 'short' });
    const sb = document.getElementById('sbTime');
    if (sb) sb.textContent = time;
}

function renderDashboard() {
    const stats = dashboardData.stats || {};
    const players = dashboardData.players || [];

    document.getElementById('statPlayers').textContent = players.length;
    document.getElementById('statPending').textContent = stats.pendingOnline ?? players.filter(p => !isPlayerEingereist(p)).length;
    document.getElementById('statTotalEntry').textContent = stats.totalEntry ?? 0;
    document.getElementById('statTodayEntry').textContent = stats.todayEntry ?? 0;
    document.getElementById('statQuestions').textContent = localQuestions.length;
    document.getElementById('navPending').textContent = stats.pendingOnline ?? players.filter(p => !isPlayerEingereist(p)).length;

    renderActivityFeed();
}

function renderActivityFeed() {
    const feed = document.getElementById('activityFeed');
    feed.innerHTML = '';
    const logs = (dashboardData.logs || []).slice(0, 8);

    if (logs.length === 0) {
        feed.innerHTML = `<p style="color:#8ba3c7;font-size:13px">${escapeHtml(t('no_activities'))}</p>`;
        return;
    }

    logs.forEach(log => {
        const el = document.createElement('div');
        el.className = 'activity-item';
        const color = actionColors[log.action] || 'blue';
        const action = getActionLabel(log.action);
        const time = log.created_at ? new Date(log.created_at).toLocaleTimeString(getDateLocale(), { hour: '2-digit', minute: '2-digit' }) : '';
        const iconName = log.action === 'eingereist' ? 'i-check-circle' : log.action === 'skin_gegeben' ? 'i-shirt' : log.action === 'einreise_entzogen' ? 'i-x-circle' : 'i-note';
        const colorClass = color === 'green' ? 'green' : color === 'red' ? 'red' : color === 'purple' ? 'purple' : 'blue';
        el.innerHTML = `
            <span class="icon-box sm ${colorClass}"><svg class="icon" width="14" height="14"><use xlink:href="#${iconName}"/></svg></span>
            <span class="activity-text"><strong>${escapeHtml(action)}</strong> — ${escapeHtml(log.staff_name)} → ${escapeHtml(log.target_name)}</span>
            <span class="activity-meta">${escapeHtml(time)}</span>
        `;
        feed.appendChild(el);
    });
}

function getFilteredPlayers() {
    let players = dashboardData.players || [];

    if (currentFilter === 'pending') players = players.filter(p => !isPlayerEingereist(p));
    if (currentFilter === 'done') players = players.filter(p => isPlayerEingereist(p));

    if (searchQuery) {
        const q = searchQuery.toLowerCase();
        players = players.filter(p =>
            p.name.toLowerCase().includes(q) || String(p.id).includes(q)
        );
    }

    return players;
}

function selectPlayer(player) {
    selectedPlayer = player;
    document.getElementById('targetId').value = player.id;
    renderPlayers();
    renderSelectedPlayer();
}

function renderSelectedPlayer() {
    const card = document.getElementById('selectedPlayerCard');

    if (!selectedPlayer) {
        card.innerHTML = `
            <div class="sp-placeholder">
                <span class="icon-box xl gray"><svg class="icon" width="36" height="36"><use xlink:href="#i-person"/></svg></span>
                <p>${escapeHtml(t('select_player_list'))}</p>
            </div>`;
        return;
    }

    const p = selectedPlayer;
    const statusClass = getPlayerStatusClass(p);
    const statusText = getPlayerStatusLabel(p);
    const entryInfo = isPlayerEingereist(p) && p.eingereist_by
        ? escapeHtml(t('entry_by', p.eingereist_by))
        : isPlayerEingereist(p)
            ? t('entry_success_detail')
            : t('entry_not_yet');

    card.innerHTML = `
        <div class="sp-details">
            <div class="sp-avatar-lg">${getInitial(p.name)}</div>
            <div class="sp-meta">
                <h3>${escapeHtml(p.name)}</h3>
                <p>${escapeHtml(t('server_id'))}: <strong>${p.id}</strong></p>
                <p>${entryInfo}</p>
                <span class="status-badge ${statusClass}">${statusText}</span>
            </div>
        </div>`;
}

function renderPlayers() {
    const list = document.getElementById('playerList');
    list.innerHTML = '';
    const players = getFilteredPlayers();

    if (players.length === 0) {
        list.innerHTML = `<p style="color:#8ba3c7;font-size:13px;padding:16px">${escapeHtml(t('no_players'))}</p>`;
        return;
    }

    players.forEach(p => {
        const el = document.createElement('div');
        el.className = 'player-item' + (selectedPlayer?.id === p.id ? ' selected' : '');
        const statusClass = getPlayerStatusClass(p);
        const statusText = getPlayerStatusLabel(p);
        el.innerHTML = `
            <div class="player-avatar">${getInitial(p.name)}</div>
            <div class="player-info">
                <span class="player-name">${escapeHtml(p.name)}</span>
                <span class="player-id">${escapeHtml(t('player_id', p.id))}</span>
            </div>
            <span class="status-badge ${statusClass}">${statusText}</span>
            <svg class="icon chevron" width="12" height="12"><use xlink:href="#i-chevron"/></svg>
        `;
        el.addEventListener('click', () => selectPlayer(p));
        list.appendChild(el);
    });
}

function renderQuestions() {
    const list = document.getElementById('questionsList');
    list.innerHTML = '';

    localQuestions.forEach((q, i) => {
        const text = typeof q === 'object' ? q.question : q;
        const el = document.createElement('div');
        el.className = 'question-item';
        el.innerHTML = `
            <span class="question-num">${i + 1}</span>
            <input type="text" value="${escapeHtml(text)}" data-index="${i}">
            <button class="btn-remove" data-index="${i}">✕</button>
        `;
        list.appendChild(el);
    });

    list.querySelectorAll('input').forEach(input => {
        input.addEventListener('input', e => {
            localQuestions[parseInt(e.target.dataset.index, 10)] = e.target.value;
        });
    });

    list.querySelectorAll('.btn-remove').forEach(btn => {
        btn.addEventListener('click', e => {
            localQuestions.splice(parseInt(e.target.dataset.index, 10), 1);
            renderQuestions();
            renderDashboard();
        });
    });
}

function renderLogs(filterToday = false) {
    const list = document.getElementById('logsList');
    list.innerHTML = '';
    let logs = dashboardData.logs || [];
    const search = document.getElementById('logSearch')?.value?.toLowerCase() || '';

    if (filterToday) {
        const today = new Date().toDateString();
        logs = logs.filter(l => l.action === 'eingereist' && l.created_at && new Date(l.created_at).toDateString() === today);
    }

    if (search) {
        logs = logs.filter(l =>
            (l.staff_name || '').toLowerCase().includes(search) ||
            (l.target_name || '').toLowerCase().includes(search) ||
            (l.action || '').toLowerCase().includes(search)
        );
    }

    if (logs.length === 0) {
        list.innerHTML = `<p style="color:#8ba3c7;font-size:13px;padding:16px">${escapeHtml(t('no_logs'))}</p>`;
        return;
    }

    logs.forEach(log => {
        const el = document.createElement('div');
        el.className = 'log-item';
        const action = getActionLabel(log.action);
        const time = log.created_at ? new Date(log.created_at).toLocaleString(getDateLocale()) : '';
        const iconName = log.action === 'eingereist' ? 'i-check-circle' : log.action === 'skin_gegeben' ? 'i-shirt' : log.action === 'einreise_entzogen' ? 'i-x-circle' : log.action === 'startgeld' ? 'i-money' : 'i-note';
        const colorClass = actionColors[log.action] === 'green' ? 'green' : actionColors[log.action] === 'red' ? 'red' : actionColors[log.action] === 'purple' ? 'purple' : 'blue';
        el.innerHTML = `
            <div class="log-row">
                <span class="icon-box sm ${colorClass}"><svg class="icon" width="14" height="14"><use xlink:href="#${iconName}"/></svg></span>
                <div class="log-content">
                    <div class="log-action">${escapeHtml(action)}</div>
                    <div class="log-detail">${escapeHtml(log.staff_name)} → ${escapeHtml(log.target_name)}</div>
                    <div class="log-time">${escapeHtml(time)}</div>
                </div>
            </div>
        `;
        list.appendChild(el);
    });
}

async function refreshData(showMsg = false) {
    const data = await post('refresh');
    if (data.players) {
        dashboardData = { ...dashboardData, ...data };
        localQuestions = (data.questions || dashboardData.questions || []).map(q => q.question || q);

        if (data.localeUi) loadLocale(data);

        if (selectedPlayer) {
            const updated = (data.players || []).find(p => p.id === selectedPlayer.id);
            if (updated) selectedPlayer = updated;
            else selectedPlayer = null;
        }

        renderDashboard();
        renderPlayers();
        renderSelectedPlayer();
        renderLogs();
        if (showMsg) showToast(t('toast_data_updated'));
    }
}

function startAutoRefresh() {
    stopAutoRefresh();
    if (document.getElementById('autoRefresh').checked) {
        autoRefreshInterval = setInterval(() => refreshData(false), 10000);
    }
}

function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
    }
}

function openTablet(data, config) {
    loadLocale(data, config);
    dashboardData = data;
    localQuestions = (data.questions || []).map(q => q.question || q);
    selectedPlayer = null;

    const staffName = data.staffName || t('staff_default');
    document.getElementById('staffName').textContent = staffName;
    document.getElementById('staffInitial').textContent = getInitial(staffName);

    if (config?.zoneRadius) {
        document.getElementById('statZone').textContent = config.zoneRadius + 'm';
    }
    if (config?.starterMoney) {
        document.getElementById('starterMoneyDisplay').textContent = '$' + config.starterMoney.toLocaleString(getDateLocale());
    }

    renderDashboard();
    renderPlayers();
    renderSelectedPlayer();
    renderQuestions();
    renderLogs();

    tablet.classList.remove('hidden');
    switchTab('dashboard');
    updateClock();
    startAutoRefresh();
}

function closeTablet() {
    tablet.classList.add('hidden');
    stopAutoRefresh();
    post('close');
}

function showApplicantQuestions(questions, staffName, localeData) {
    if (localeData?.localeUi) loadLocale(localeData);
    document.getElementById('applicantStaff').textContent = staffName || '—';
    const list = document.getElementById('applicantQuestions');
    list.innerHTML = '';
    (questions || []).forEach(q => {
        const li = document.createElement('li');
        li.textContent = q;
        list.appendChild(li);
    });

    const fill = document.querySelector('.ios-progress-fill');
    if (fill) {
        fill.style.width = '0%';
        fill.style.animation = 'none';
        void fill.offsetWidth;
        fill.style.animation = 'progressAnim 3s ease forwards';
    }

    applicantView.classList.remove('hidden');
}

// ─── Event Listeners ──────────────────────────────────────────

document.querySelectorAll('.nav-item').forEach(tab => {
    tab.addEventListener('click', () => switchTab(tab.dataset.tab));
});

document.querySelectorAll('.quick-btn').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.goto));
});

document.querySelectorAll('.seg-btn').forEach(chip => {
    chip.addEventListener('click', () => {
        document.querySelectorAll('.seg-btn').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        currentFilter = chip.dataset.filter;
        renderPlayers();
    });
});

document.getElementById('playerSearch').addEventListener('input', e => {
    searchQuery = e.target.value;
    renderPlayers();
});

document.getElementById('logSearch').addEventListener('input', () => renderLogs(false));

document.getElementById('autoRefresh').addEventListener('change', startAutoRefresh);

document.getElementById('btnClose').addEventListener('click', closeTablet);
document.getElementById('btnRefreshAll').addEventListener('click', () => refreshData(true));
document.getElementById('btnRefreshPlayers').addEventListener('click', () => refreshData(true));

document.getElementById('btnSendQuestions').addEventListener('click', () => {
    const id = getTargetId();
    if (id) post('sendQuestions', { targetId: id });
});

document.getElementById('btnGiveSkin').addEventListener('click', () => {
    const id = getTargetId();
    if (id) post('giveSkin', { targetId: id });
});

document.getElementById('btnProcessEntry').addEventListener('click', () => {
    const id = getTargetId();
    if (!id) return;
    showConfirm(t('confirm_process_entry_title'), t('confirm_process_entry_text', id), () => {
        post('processEntry', { targetId: id }).then(() => {
            setPlayerEntryStatusLocal(id, true);
            setTimeout(() => refreshData(false), 800);
        });
    });
});

document.getElementById('btnRevokeEntry').addEventListener('click', () => {
    const id = getTargetId();
    if (!id) return;
    showConfirm(t('confirm_revoke_title'), t('confirm_revoke_text', id), () => {
        post('revokeEntry', { targetId: id }).then(() => {
            setPlayerEntryStatusLocal(id, false);
            setTimeout(() => refreshData(false), 800);
        });
    });
});

document.getElementById('btnTpToPlayer').addEventListener('click', () => {
    const id = getTargetId();
    if (id) post('tpToPlayer', { targetId: id });
});

document.getElementById('btnBringPlayer').addEventListener('click', () => {
    const id = getTargetId();
    if (id) post('bringPlayer', { targetId: id });
});

document.getElementById('btnFreezePlayer').addEventListener('click', () => {
    const id = getTargetId();
    if (id) post('freezePlayer', { targetId: id, freeze: true });
});

document.getElementById('btnUnfreezePlayer').addEventListener('click', () => {
    const id = getTargetId();
    if (id) post('freezePlayer', { targetId: id, freeze: false });
});

document.getElementById('btnSendNote').addEventListener('click', () => {
    const id = getTargetId();
    const note = document.getElementById('staffNote').value.trim();
    if (!id || !note) {
        showToast(t('toast_note_empty'));
        return;
    }
    post('saveNote', { targetId: id, note }).then(() => {
        document.getElementById('staffNote').value = '';
        showToast(t('toast_note_saved'));
    });
});

document.getElementById('btnZoneAnnounce').addEventListener('click', () => {
    const msg = document.getElementById('zoneAnnounce').value.trim();
    if (!msg) {
        showToast(t('toast_message_empty'));
        return;
    }
    post('zoneAnnounce', { message: msg }).then(() => {
        document.getElementById('zoneAnnounce').value = '';
        showToast(t('toast_announce_sent'));
    });
});

document.getElementById('btnGiveStarter').addEventListener('click', () => {
    const id = getTargetId();
    if (!id) return;
    showConfirm(t('confirm_starter_title'), t('confirm_starter_text', id), () => {
        post('giveStarter', { targetId: id });
    });
});

document.getElementById('btnShowTodayLogs').addEventListener('click', () => {
    switchTab('logs');
    renderLogs(true);
});

document.getElementById('btnAddQuestion').addEventListener('click', () => {
    localQuestions.push(t('new_question'));
    renderQuestions();
    renderDashboard();
});

document.getElementById('btnSaveQuestions').addEventListener('click', async () => {
    await post('saveQuestions', { questions: localQuestions });
    showToast(t('toast_questions_saved'));
});

document.getElementById('btnCloseApplicant').addEventListener('click', () => {
    applicantView.classList.add('hidden');
    post('closeApplicantView');
});

document.getElementById('confirmCancel').addEventListener('click', () => {
    confirmModal.classList.add('hidden');
    confirmCallback = null;
});

document.getElementById('confirmOk').addEventListener('click', () => {
    confirmModal.classList.add('hidden');
    if (confirmCallback) confirmCallback();
    confirmCallback = null;
});

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
        if (!confirmModal.classList.contains('hidden')) {
            confirmModal.classList.add('hidden');
            confirmCallback = null;
        } else if (!applicantView.classList.contains('hidden')) {
            applicantView.classList.add('hidden');
            post('closeApplicantView');
        } else if (!tablet.classList.contains('hidden')) {
            closeTablet();
        }
    }
});

setInterval(updateClock, 1000);

window.addEventListener('message', e => {
    const msg = e.data;
    if (!msg?.action) return;

    switch (msg.action) {
        case 'open':
            openTablet(msg.data, msg.config);
            break;
        case 'close':
            tablet.classList.add('hidden');
            stopAutoRefresh();
            break;
        case 'showApplicantQuestions':
            showApplicantQuestions(msg.questions, msg.staffName, msg);
            break;
        case 'toast':
            showToast(msg.message);
            break;
        case 'notify':
            showGameNotify(msg.message);
            break;
    }
});
