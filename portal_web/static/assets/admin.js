const adminLoginCard = document.getElementById('adminLoginCard');
const adminPanel = document.getElementById('adminPanel');
const adminLoginForm = document.getElementById('adminLoginForm');
const adminLoginMsg = document.getElementById('adminLoginMsg');
const adminPerfilMsg = document.getElementById('adminPerfilMsg');
const usuarioForm = document.getElementById('usuarioForm');
const usuarioMsg = document.getElementById('usuarioMsg');
const usuarioList = document.getElementById('usuarioList');
const usuarioSearch = document.getElementById('usuarioSearch');
const pacienteForm = document.getElementById('pacienteForm');
const pacienteMsg = document.getElementById('pacienteMsg');
const pacienteList = document.getElementById('pacienteList');
const pacienteSearch = document.getElementById('pacienteSearch');
const catalogoForm = document.getElementById('catalogoForm');
const catalogoMsg = document.getElementById('catalogoMsg');
const catalogoList = document.getElementById('catalogoList');
const catalogoSearch = document.getElementById('catalogoSearch');
const exameForm = document.getElementById('exameForm');
const exameMsg = document.getElementById('exameMsg');
const examePacienteSelect = document.getElementById('examePacienteSelect');
const importarExamesForm = document.getElementById('importarExamesForm');
const importarExamesMsg = document.getElementById('importarExamesMsg');
const adminList = document.getElementById('adminList');
const adminSearch = document.getElementById('adminSearch');
const serverApiKey = document.getElementById('serverApiKey');
const serverMsg = document.getElementById('serverMsg');
const backupHorario = document.getElementById('backupHorario');
const superDangerPanel = document.getElementById('superDangerPanel');
const excluirTudoMsg = document.getElementById('excluirTudoMsg');

const graduacoes = ['','Recruta','Soldado','Cabo','Sargento','Subtenente','Aspirante','Tenente','Capitão','Major','Tenente-Coronel','Coronel','General','Marechal'];
const postos = {Sargento: ['1º','2º','3º'], Tenente: ['1º','2º'], General: ['Brigada','Divisão','Exército']};
let pacientesCache = [];

function adminToken() { return sessionStorage.getItem('kristalAdminToken') || ''; }
function adminPerfil() { return sessionStorage.getItem('kristalAdminPerfil') || ''; }
function isSuperUsuario() { return adminPerfil() === 'SUPER_USUARIO'; }
function adminHeaders() { return { Authorization: `Bearer ${adminToken()}` }; }
function adminJsonHeaders() { return { ...adminHeaders(), Accept: 'application/json' }; }
function serverApiHeaders() { return { 'X-API-Key': serverApiKey.value.trim(), Accept: 'application/json' }; }

function configureMilitarSelects() {
  document.querySelectorAll('.militar-graduacao').forEach((select) => {
    select.innerHTML = graduacoes.map((item) => `<option value="${escapeAttr(item)}">${escapeHtml(item || 'Sem graduação')}</option>`).join('');
    select.addEventListener('change', () => atualizarPosto(select));
  });
  document.querySelectorAll('.militar-posto').forEach((select) => { select.innerHTML = '<option value="">Sem posto</option>'; });
}

function atualizarPosto(graduacaoSelect) {
  const postoSelect = graduacaoSelect.closest('form').querySelector('.militar-posto');
  const options = postos[graduacaoSelect.value] || [];
  postoSelect.innerHTML = '<option value="">Sem posto</option>' + options.map((item) => `<option value="${escapeAttr(item)}">${escapeHtml(item)}</option>`).join('');
}

function aplicarMascaras() {
  ['pacienteCpf','pacientePreccp','pacienteIdentidade','pacienteTelefone','usuarioIdentidade'].forEach((id) => {
    const input = document.getElementById(id);
    if (input) input.addEventListener('input', () => { input.value = somenteDigitos(input.value); });
  });
  ['catalogoValorCheio','catalogoValorIndenizar20'].forEach((id) => {
    const input = document.getElementById(id);
    if (input) input.addEventListener('blur', () => { input.value = formatarCampoMoeda(input.value); });
  });
  const valorCheio = document.getElementById('catalogoValorCheio');
  valorCheio?.addEventListener('input', atualizarValorIndenizar);
  valorCheio?.addEventListener('blur', atualizarValorIndenizar);
  exameForm?.querySelector('input[name="valor"]')?.addEventListener('blur', (event) => { event.target.value = formatarCampoMoeda(event.target.value); });
}

function mostrarPainel() {
  adminLoginCard.classList.add('hidden');
  adminPanel.classList.remove('hidden');
  adminPerfilMsg.textContent = `Perfil autenticado: ${adminPerfil() || 'ADMIN'}. ${isSuperUsuario() ? 'Modificação permitida.' : 'Consulta, relatórios e download apenas.'}`;
  document.querySelectorAll('.admin-edit-only').forEach((el) => el.classList.toggle('hidden', !isSuperUsuario()));
  superDangerPanel.classList.toggle('hidden', !isSuperUsuario());
  serverApiKey.value = localStorage.getItem('kristalServerApiKey') || '';
  if (backupHorario) backupHorario.disabled = !isSuperUsuario();
  void carregarHorarioBackup();
}

async function responseJson(response) {
  const text = await response.text();
  if (!text) return {};
  return JSON.parse(text);
}

adminLoginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  adminLoginMsg.textContent = 'Validando...';
  const form = new FormData();
  form.append('login', document.getElementById('adminLogin').value.trim());
  form.append('senha', document.getElementById('adminSenha').value);
  const response = await fetch('/api/admin/login', { method: 'POST', body: form });
  const data = await responseJson(response);
  if (!response.ok) { adminLoginMsg.textContent = data.detail || 'Acesso inválido.'; return; }
  sessionStorage.setItem('kristalAdminToken', data.token);
  sessionStorage.setItem('kristalAdminPerfil', data.perfil);
  mostrarPainel();
  await carregarTudo();
});

document.getElementById('adminLogoutBtn').addEventListener('click', () => { sessionStorage.clear(); location.reload(); });
document.getElementById('buscarUsuariosBtn')?.addEventListener('click', buscarUsuarios);
document.getElementById('buscarPacientesBtn').addEventListener('click', buscarPacientes);
document.getElementById('buscarCatalogoBtn').addEventListener('click', buscarCatalogo);
document.getElementById('buscarHistoricoBtn').addEventListener('click', () => buscarLaudos(true));
document.getElementById('buscarRecentesBtn').addEventListener('click', () => buscarLaudos(false));
document.getElementById('limparUsuarioBtn')?.addEventListener('click', limparUsuarioForm);
document.getElementById('limparPacienteBtn').addEventListener('click', limparPacienteForm);
document.getElementById('limparCatalogoBtn').addEventListener('click', limparCatalogoForm);
document.getElementById('gerarCodigoPacienteBtn')?.addEventListener('click', () => { document.getElementById('codigoAcessoPaciente').value = gerarCodigoAcesso(); });
document.getElementById('salvarServerApiKeyBtn').addEventListener('click', () => { const value = serverApiKey.value.trim(); if (!value) { serverMsg.textContent = 'Informe a chave API do servidor.'; return; } localStorage.setItem('kristalServerApiKey', value); serverMsg.textContent = 'Chave API salva neste navegador.'; });
document.getElementById('testarServerStatusBtn').addEventListener('click', () => chamarServidorProtegido('/api/server/status', 'GET', 'Status protegido'));
document.getElementById('backupManualServidorBtn').addEventListener('click', () => chamarServidorProtegido('/api/server/backup', 'POST', 'Backup manual'));
document.getElementById('salvarBackupHorarioBtn')?.addEventListener('click', salvarHorarioBackup);
document.getElementById('excluirTudoBtn').addEventListener('click', excluirTodosDados);

usuarioForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  usuarioMsg.textContent = 'Salvando usuário...';
  const response = await fetch('/api/admin/usuarios', { method: 'POST', headers: adminHeaders(), body: new FormData(usuarioForm) });
  const data = await responseJson(response);
  if (!response.ok) { usuarioMsg.textContent = data.detail || 'Erro ao salvar usuário.'; return; }
  usuarioMsg.textContent = `Usuário salvo. ID: ${data.id}`;
  limparUsuarioForm();
  await buscarUsuarios();
});

pacienteForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  pacienteMsg.textContent = 'Salvando paciente...';
  const pacienteId = document.getElementById('pacienteId').value.trim();
  const form = new FormData(pacienteForm);
  form.delete('id');
  const url = pacienteId ? `/api/admin/pacientes/${encodeURIComponent(pacienteId)}` : '/api/admin/pacientes';
  const method = pacienteId ? 'PUT' : 'POST';
  if (!pacienteId && !document.getElementById('codigoAcessoPaciente').value.trim()) { pacienteMsg.textContent = 'Gere ou informe o código de acesso para novo paciente.'; return; }
  const response = await fetch(url, { method, headers: adminHeaders(), body: form });
  const data = await responseJson(response);
  if (!response.ok) { pacienteMsg.textContent = data.detail || 'Erro ao salvar paciente.'; return; }
  pacienteMsg.textContent = `Paciente salvo. ID permanente: ${data.id}`;
  limparPacienteForm();
  await buscarPacientes();
});

exameForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  exameMsg.textContent = 'Salvando exame...';
  const response = await fetch('/api/admin/exames', { method: 'POST', headers: adminHeaders(), body: new FormData(exameForm) });
  const data = await responseJson(response);
  if (!response.ok) { exameMsg.textContent = data.detail || 'Erro ao salvar exame.'; return; }
  exameMsg.textContent = `Exame sincronizado. ID: ${data.id}`;
  exameForm.reset();
  await buscarLaudos(true);
});

importarExamesForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  importarExamesMsg.textContent = 'Importando exames...';
  const response = await fetch('/api/admin/exames/importar', { method: 'POST', headers: adminHeaders(), body: new FormData(importarExamesForm) });
  const data = await responseJson(response);
  if (!response.ok) { importarExamesMsg.textContent = data.detail || 'Erro ao importar exames.'; return; }
  importarExamesMsg.textContent = `Importados: ${data.total_importados}. Erros: ${(data.erros || []).length}.`;
  await buscarLaudos(true);
});

catalogoForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  catalogoMsg.textContent = 'Salvando catálogo...';
  const response = await fetch('/api/admin/catalogo-exames', { method: 'POST', headers: adminHeaders(), body: new FormData(catalogoForm) });
  const data = await responseJson(response);
  if (!response.ok) { catalogoMsg.textContent = data.detail || 'Erro ao salvar catálogo.'; return; }
  catalogoMsg.textContent = `Catálogo salvo. ID: ${data.id}`;
  limparCatalogoForm();
  await buscarCatalogo();
});

async function carregarTudo() { await Promise.all([buscarUsuarios(), buscarPacientes(), buscarCatalogo(), buscarLaudos(true)]); }
async function buscarUsuarios() {
  if (!usuarioList) return;
  usuarioList.innerHTML = '<p>Consultando...</p>';
  const response = await fetch(`/api/admin/usuarios?q=${encodeURIComponent(usuarioSearch.value || '')}`, { headers: adminJsonHeaders() });
  const rows = await responseJson(response);
  if (!response.ok) { usuarioList.innerHTML = `<p>${escapeHtml(rows.detail || 'Acesso negado.')}</p>`; return; }
  usuarioList.innerHTML = rows.length ? rows.map((row) => `<div class="item"><strong>${escapeHtml(row.nome || '')}</strong><div class="meta">Login: ${escapeHtml(row.login || '')} | Perfil: ${escapeHtml(row.perfil || '')}<br>Graduação: ${escapeHtml(row.graduacao || '')} ${escapeHtml(row.posto || '')} | Identidade: ${escapeHtml(row.identidade_militar || '')}<br>Ativo: ${row.ativo === '1' ? 'SIM' : 'NÃO'}</div>${isSuperUsuario() ? `<div class="actions"><a href="#" onclick='editarUsuario(${toAttrJson(row)})'>Editar</a></div>` : ''}</div>`).join('') : '<p>Nenhum usuário encontrado.</p>';
}
async function buscarPacientes() {
  pacienteList.innerHTML = '<p>Consultando...</p>';
  const response = await fetch(`/api/admin/pacientes?q=${encodeURIComponent(pacienteSearch.value || '')}`, { headers: adminJsonHeaders() });
  const rows = await responseJson(response);
  if (!response.ok) { pacienteList.innerHTML = `<p>${escapeHtml(rows.detail || 'Acesso negado.')}</p>`; return; }
  pacientesCache = Array.isArray(rows) ? rows : [];
  preencherPacientesSelect();
  pacienteList.innerHTML = pacientesCache.length ? pacientesCache.map((row) => `<div class="item"><strong>${escapeHtml(row.nome || '')}</strong><div class="meta">ID permanente: ${escapeHtml(row.id || '')}<br>CPF: ${escapeHtml(row.cpf || '')} | PREC-CP: ${escapeHtml(row.preccp || '')} | Identidade militar: ${escapeHtml(row.identidade_militar || '')}<br>Telefone: ${escapeHtml(row.telefone || '')} | E-mail: ${escapeHtml(row.email || '')}</div>${isSuperUsuario() ? `<div class="actions"><a href="#" onclick='editarPaciente(${toAttrJson(row)})'>Editar</a><a href="#" onclick="arquivarPaciente('${escapeAttr(row.id)}')">Arquivar</a></div>` : ''}</div>`).join('') : '<p>Nenhum paciente encontrado.</p>';
}
function preencherPacientesSelect() { examePacienteSelect.innerHTML = '<option value="">Selecione o paciente</option>' + pacientesCache.map((row) => `<option value="${escapeAttr(row.id)}">${escapeHtml(row.nome)} - CPF ${escapeHtml(row.cpf)} - ID ${escapeHtml(row.id)}</option>`).join(''); }
async function buscarCatalogo() {
  catalogoList.innerHTML = '<p>Consultando...</p>';
  const response = await fetch(`/api/admin/catalogo-exames?q=${encodeURIComponent(catalogoSearch.value || '')}`, { headers: adminJsonHeaders() });
  const rows = await responseJson(response);
  if (!response.ok) { catalogoList.innerHTML = `<p>${escapeHtml(rows.detail || 'Acesso negado.')}</p>`; return; }
  catalogoList.innerHTML = rows.length ? rows.map((row) => `<div class="item"><strong>${escapeHtml(row.mne || '')} - ${escapeHtml(row.nome || '')}</strong><div class="meta">SIRE: ${escapeHtml(row.codigo_sire || '')} | Setor: ${escapeHtml(row.setor || '')} | Material: ${escapeHtml(row.material || '')}<br>Unidade: ${escapeHtml(row.unidade || '')} | Valor: ${escapeHtml(formatarMoedaBRL(row.valor_cheio))} | 20%: ${escapeHtml(formatarMoedaBRL(row.valor_indenizar_20))}<br>Equipamento: ${escapeHtml(row.equipamento || '')} | Ativo: ${row.ativo === '1' ? 'SIM' : 'NÃO'}</div>${isSuperUsuario() ? `<div class="actions"><a href="#" onclick='editarCatalogo(${toAttrJson(row)})'>Editar</a><a href="#" onclick="inativarCatalogo('${escapeAttr(row.id)}')">Inativar</a></div>` : ''}</div>`).join('') : '<p>Nenhum exame cadastrado no catálogo.</p>';
}
async function buscarLaudos(historico) {
  adminList.innerHTML = '<p>Consultando...</p>';
  const response = await fetch(`/api/admin/exames?q=${encodeURIComponent(adminSearch.value || '')}&historico=${historico}`, { headers: adminJsonHeaders() });
  const rows = await responseJson(response);
  if (!response.ok) { adminList.innerHTML = `<p>${escapeHtml(rows.detail || 'Acesso negado ou sessão expirada.')}</p>`; return; }
  adminList.innerHTML = rows.length ? rows.map((row) => `<div class="item exam-row"><div><strong>${escapeHtml(row.exame_nome || '')}</strong>${row.critico === 'SIM' ? '<span class="critico"> • CRÍTICO</span>' : ''}<div class="meta">Paciente: ${escapeHtml(row.paciente_nome || '')}<br>CPF: ${escapeHtml(row.cpf || '')} | PREC-CP: ${escapeHtml(row.preccp || '')}<br>Resultado: ${escapeHtml(row.valor || '')} ${escapeHtml(row.unidade || '')}<br>Liberado: ${escapeHtml(row.liberado_em || '')}</div></div><div class="actions"><a href="#" onclick="baixarAdmin('${escapeAttr(row.id)}')">Download</a></div></div>`).join('') : '<p>Nenhum exame encontrado.</p>';
}
function editarUsuario(row) { document.getElementById('usuarioId').value = row.id || ''; document.getElementById('usuarioNome').value = row.nome || ''; document.getElementById('usuarioLogin').value = row.login || ''; document.getElementById('usuarioPerfil').value = row.perfil || 'ADMIN'; document.getElementById('usuarioGraduacao').value = row.graduacao || ''; atualizarPosto(document.getElementById('usuarioGraduacao')); document.getElementById('usuarioPosto').value = row.posto || ''; document.getElementById('usuarioIdentidade').value = row.identidade_militar || ''; document.getElementById('usuarioAtivo').value = row.ativo === '0' ? '0' : '1'; document.getElementById('usuarioSenha').value = ''; usuarioMsg.textContent = `Editando usuário ${row.id || ''}. Senha só muda se preenchida.`; }
function editarPaciente(row) { document.getElementById('pacienteId').value = row.id || ''; document.getElementById('pacienteIdView').value = row.id || ''; document.getElementById('pacienteNome').value = row.nome || ''; document.getElementById('pacienteCpf').value = row.cpf || ''; document.getElementById('pacientePreccp').value = row.preccp || ''; document.getElementById('pacienteIdentidade').value = row.identidade_militar || ''; document.getElementById('pacienteNascimento').value = row.nascimento || ''; document.getElementById('pacienteTelefone').value = row.telefone || ''; document.getElementById('pacienteEmail').value = row.email || ''; document.getElementById('codigoAcessoPaciente').value = ''; pacienteMsg.textContent = `Editando paciente ${row.id || ''}. Código de acesso só muda se preenchido.`; }
function editarCatalogo(row) { ['Id','Mne','CodigoSire','Nome','Setor','Material','Metodo','Unidade','Referencia','ValorCheio','ValorIndenizar20','Equipamento'].forEach(() => {}); document.getElementById('catalogoId').value = row.id || ''; document.getElementById('catalogoMne').value = row.mne || ''; document.getElementById('catalogoCodigoSire').value = row.codigo_sire || ''; document.getElementById('catalogoNome').value = row.nome || ''; document.getElementById('catalogoSetor').value = row.setor || ''; document.getElementById('catalogoMaterial').value = row.material || ''; document.getElementById('catalogoMetodo').value = row.metodo || ''; document.getElementById('catalogoUnidade').value = row.unidade || ''; document.getElementById('catalogoReferencia').value = row.referencia || ''; document.getElementById('catalogoValorCheio').value = formatarCampoMoeda(row.valor_cheio || ''); document.getElementById('catalogoValorIndenizar20').value = formatarCampoMoeda(row.valor_indenizar_20 || ''); document.getElementById('catalogoEquipamento').value = row.equipamento || ''; document.getElementById('catalogoAtivo').value = row.ativo === '0' ? '0' : '1'; catalogoMsg.textContent = `Editando exame do catálogo ${row.id || ''}.`; }
async function arquivarPaciente(id) { if (!id || !confirm('Confirma arquivar logicamente este paciente?')) return; const response = await fetch(`/api/admin/pacientes/${encodeURIComponent(id)}`, { method: 'DELETE', headers: adminHeaders() }); const data = await responseJson(response); pacienteMsg.textContent = response.ok ? `Paciente arquivado. ID: ${data.id}` : (data.detail || 'Erro ao arquivar paciente.'); await buscarPacientes(); }
async function inativarCatalogo(id) { if (!id || !confirm('Confirma inativar este item do catálogo?')) return; const response = await fetch(`/api/admin/catalogo-exames/${encodeURIComponent(id)}`, { method: 'DELETE', headers: adminHeaders() }); const data = await responseJson(response); catalogoMsg.textContent = response.ok ? `Catálogo inativado. ID: ${data.id}` : (data.detail || 'Erro ao inativar catálogo.'); await buscarCatalogo(); }
async function baixarAdmin(id) { const response = await fetch(`/api/laudos/${encodeURIComponent(id)}/download`, { headers: adminHeaders() }); if (!response.ok) { adminList.innerHTML = '<p>Falha ao baixar laudo.</p>'; return; } const blob = await response.blob(); const url = URL.createObjectURL(blob); const a = document.createElement('a'); a.href = url; a.download = `laudo_${id}.pdf`; a.click(); URL.revokeObjectURL(url); }
async function carregarHorarioBackup() {
  const response = await fetch('/api/server/backup/config', { headers: adminJsonHeaders() });
  const data = await responseJson(response);
  if (response.ok && backupHorario) backupHorario.value = data.horario || '23:00';
}

async function salvarHorarioBackup() {
  if (!isSuperUsuario()) {
    serverMsg.textContent = 'Apenas SUPER_USUARIO pode modificar o horário.';
    return;
  }
  if (!serverApiKey.value.trim()) {
    serverMsg.textContent = 'Informe a chave API do servidor.';
    return;
  }
  const horario = backupHorario?.value || '';
  const hour = Number(horario.slice(0, 2));
  if (!/^\d{2}:\d{2}$/.test(horario) || (hour >= 4 && hour < 18)) {
    serverMsg.textContent = 'Escolha um horário entre 18:00 e 03:59.';
    return;
  }
  serverMsg.textContent = 'Configurando tarefa automática no servidor...';
  const response = await fetch('/api/server/backup/config', {
    method: 'PUT',
    headers: { ...adminJsonHeaders(), ...serverApiHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ horario }),
  });
  const data = await responseJson(response);
  serverMsg.textContent = response.ok
    ? 'Backup automático configurado para ' + data.horario + '.'
    : (data.detail || 'Falha HTTP ' + response.status + '.');
}

async function chamarServidorProtegido(path, method, label) { if (!serverApiKey.value.trim()) { serverMsg.textContent = 'Informe a chave API do servidor.'; return; } serverMsg.textContent = `${label}: executando...`; const response = await fetch(path, { method, headers: serverApiHeaders() }); const data = await responseJson(response); serverMsg.textContent = response.ok ? `${label}: ${JSON.stringify(data)}` : (data.detail || `${label}: falha HTTP ${response.status}`); }
async function excluirTodosDados() { if (!isSuperUsuario()) { excluirTudoMsg.textContent = 'Apenas SUPER_USUARIO pode executar esta ação.'; return; } const form = new FormData(); form.append('confirmacao', document.getElementById('confirmacaoExclusaoTotal').value); const response = await fetch('/api/admin/dados/excluir-todos', { method: 'POST', headers: adminHeaders(), body: form }); const data = await responseJson(response); excluirTudoMsg.textContent = response.ok ? 'Dados arquivados logicamente.' : (data.detail || 'Erro ao arquivar dados.'); await carregarTudo(); }
function limparUsuarioForm() { usuarioForm.reset(); document.getElementById('usuarioId').value = ''; atualizarPosto(document.getElementById('usuarioGraduacao')); }
function limparPacienteForm() { pacienteForm.reset(); document.getElementById('pacienteId').value = ''; document.getElementById('pacienteIdView').value = ''; }
function limparCatalogoForm() { catalogoForm.reset(); document.getElementById('catalogoId').value = ''; document.getElementById('catalogoAtivo').value = '1'; }
function gerarCodigoAcesso() { const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; let code = ''; crypto.getRandomValues(new Uint32Array(8)).forEach((value) => { code += alphabet[value % alphabet.length]; }); return code; }
function somenteDigitos(value) { return String(value || '').replace(/\D/g, ''); }
function parseMoedaBRL(value) {
  let clean = String(value ?? '').replace(/R\$/gi, '').replace(/\s/g, '').trim();
  if (!clean || !/^[0-9.,]+$/.test(clean)) return null;
  if (clean.includes(',')) clean = clean.replace(/\./g, '').replace(',', '.');
  else if (/^\d{1,3}(\.\d{3})+$/.test(clean)) clean = clean.replace(/\./g, '');
  const parsed = Number(clean);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}
function formatarCampoMoeda(value) { const parsed = parseMoedaBRL(value); return parsed === null ? '' : parsed.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
function formatarMoedaBRL(value) { const parsed = parseMoedaBRL(value); return (parsed ?? 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }); }
function atualizarValorIndenizar() { const cheio = parseMoedaBRL(document.getElementById('catalogoValorCheio').value); document.getElementById('catalogoValorIndenizar20').value = cheio === null ? '' : formatarCampoMoeda(cheio * 0.20); }
function escapeHtml(value) { return String(value ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#039;'); }
function escapeAttr(value) { return escapeHtml(value).replaceAll('`', '&#096;'); }
function toAttrJson(row) { return escapeAttr(JSON.stringify(row)); }

configureMilitarSelects();
aplicarMascaras();
