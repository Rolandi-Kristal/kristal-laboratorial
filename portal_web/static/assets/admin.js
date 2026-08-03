const adminLoginCard = document.getElementById('adminLoginCard');
const adminPanel = document.getElementById('adminPanel');
const adminLoginForm = document.getElementById('adminLoginForm');
const adminLoginMsg = document.getElementById('adminLoginMsg');
const pacienteForm = document.getElementById('pacienteForm');
const pacienteMsg = document.getElementById('pacienteMsg');
const exameForm = document.getElementById('exameForm');
const exameMsg = document.getElementById('exameMsg');
const catalogoForm = document.getElementById('catalogoForm');
const catalogoMsg = document.getElementById('catalogoMsg');
const adminList = document.getElementById('adminList');
const adminSearch = document.getElementById('adminSearch');
const pacienteList = document.getElementById('pacienteList');
const pacienteSearch = document.getElementById('pacienteSearch');
const catalogoList = document.getElementById('catalogoList');
const catalogoSearch = document.getElementById('catalogoSearch');
const gerarCodigoPacienteBtn = document.getElementById('gerarCodigoPacienteBtn');
const superDangerPanel = document.getElementById('superDangerPanel');
const excluirTudoMsg = document.getElementById('excluirTudoMsg');
const adminPerfilMsg = document.getElementById('adminPerfilMsg');
const serverApiKey = document.getElementById('serverApiKey');
const serverMsg = document.getElementById('serverMsg');

function adminToken() { return localStorage.getItem('kristalAdminToken') || ''; }
function adminPerfil() { return localStorage.getItem('kristalAdminPerfil') || ''; }
function adminHeaders() { return { Authorization: `Bearer ${adminToken()}` }; }
function adminJsonHeaders() { return { ...adminHeaders(), Accept: 'application/json' }; }
function serverApiHeaders() { return { 'X-API-Key': serverApiKey.value.trim(), Accept: 'application/json' }; }
function isSuperUsuario() { return adminPerfil() === 'SUPER_USUARIO'; }

function gerarCodigoAcesso() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  crypto.getRandomValues(new Uint32Array(8)).forEach((value) => {
    code += alphabet[value % alphabet.length];
  });
  return code;
}

function mostrarPainel() {
  adminLoginCard.classList.add('hidden');
  adminPanel.classList.remove('hidden');
  adminPerfilMsg.textContent = `Perfil autenticado: ${adminPerfil() || 'ADMINISTRATIVO'}`;
  if (isSuperUsuario()) superDangerPanel.classList.remove('hidden');
  serverApiKey.value = localStorage.getItem('kristalServerApiKey') || '';
}

async function responseJson(response) {
  const text = await response.text();
  if (!text) return {};
  return JSON.parse(text);
}

if (gerarCodigoPacienteBtn) {
  gerarCodigoPacienteBtn.addEventListener('click', () => {
    document.getElementById('codigoAcessoPaciente').value = gerarCodigoAcesso();
  });
}

document.getElementById('limparPacienteBtn').addEventListener('click', () => limparPacienteForm());
document.getElementById('limparCatalogoBtn').addEventListener('click', () => limparCatalogoForm());
document.getElementById('buscarPacientesBtn').addEventListener('click', buscarPacientes);
document.getElementById('buscarCatalogoBtn').addEventListener('click', buscarCatalogo);
document.getElementById('buscarHistoricoBtn').addEventListener('click', () => buscarLaudos(true));
document.getElementById('buscarRecentesBtn').addEventListener('click', () => buscarLaudos(false));
document.getElementById('adminLogoutBtn').addEventListener('click', () => {
  localStorage.removeItem('kristalAdminToken');
  localStorage.removeItem('kristalAdminPerfil');
  location.reload();
});

document.getElementById('excluirTudoBtn').addEventListener('click', excluirTodosDados);

document.getElementById('salvarServerApiKeyBtn').addEventListener('click', () => {
  const value = serverApiKey.value.trim();
  if (!value) { serverMsg.textContent = 'Informe a chave API do servidor.'; return; }
  localStorage.setItem('kristalServerApiKey', value);
  serverMsg.textContent = 'Chave API salva no navegador local.';
});
document.getElementById('testarServerStatusBtn').addEventListener('click', () => chamarServidorProtegido('/api/server/status', 'GET', 'Status protegido'));
document.getElementById('backupManualServidorBtn').addEventListener('click', () => chamarServidorProtegido('/api/server/backup', 'POST', 'Backup manual'));

adminLoginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  adminLoginMsg.textContent = 'Validando...';
  const form = new FormData();
  form.append('login', document.getElementById('adminLogin').value);
  form.append('senha', document.getElementById('adminSenha').value);
  const response = await fetch('/api/admin/login', { method: 'POST', body: form });
  const data = await responseJson(response);
  if (!response.ok) { adminLoginMsg.textContent = data.detail || 'Acesso inválido.'; return; }
  localStorage.setItem('kristalAdminToken', data.token);
  localStorage.setItem('kristalAdminPerfil', data.perfil);
  mostrarPainel();
  await Promise.all([buscarPacientes(), buscarCatalogo(), buscarLaudos(true)]);
});

pacienteForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  pacienteMsg.textContent = 'Salvando paciente...';
  const pacienteId = document.getElementById('pacienteId').value.trim();
  const form = new FormData(pacienteForm);
  form.delete('id');
  const url = pacienteId ? `/api/admin/pacientes/${encodeURIComponent(pacienteId)}` : '/api/admin/pacientes';
  const method = pacienteId ? 'PUT' : 'POST';
  if (!pacienteId && !document.getElementById('codigoAcessoPaciente').value.trim()) {
    pacienteMsg.textContent = 'Gere ou informe o código de acesso para novo paciente.';
    return;
  }
  const response = await fetch(url, { method, headers: adminHeaders(), body: form });
  const data = await responseJson(response);
  if (!response.ok) { pacienteMsg.textContent = data.detail || 'Erro ao salvar paciente.'; return; }
  pacienteMsg.textContent = `Paciente salvo. ID: ${data.id}`;
  limparPacienteForm();
  await buscarPacientes();
});

exameForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  exameMsg.textContent = 'Salvando exame...';
  const response = await fetch('/api/admin/exames', { method: 'POST', headers: adminHeaders(), body: new FormData(exameForm) });
  const data = await responseJson(response);
  if (!response.ok) { exameMsg.textContent = data.detail || 'Erro ao salvar exame.'; return; }
  exameMsg.textContent = `Exame salvo. ID: ${data.id}`;
  exameForm.reset();
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

async function buscarPacientes() {
  pacienteList.innerHTML = '<p>Consultando...</p>';
  const q = encodeURIComponent(pacienteSearch.value || '');
  const response = await fetch(`/api/admin/pacientes?q=${q}`, { headers: adminJsonHeaders() });
  const rows = await responseJson(response);
  if (!response.ok) { pacienteList.innerHTML = `<p>${escapeHtml(rows.detail || 'Acesso negado.')}</p>`; return; }
  if (rows.length === 0) { pacienteList.innerHTML = '<p>Nenhum paciente encontrado.</p>'; return; }
  pacienteList.innerHTML = rows.map((row) => `
    <div class="item">
      <strong>${escapeHtml(row.nome || '')}</strong>
      <div class="meta">ID: ${escapeHtml(row.id || '')}<br>CPF: ${escapeHtml(row.cpf || '')} | PREC-CP: ${escapeHtml(row.preccp || '')}<br>Telefone: ${escapeHtml(row.telefone || '')} | E-mail: ${escapeHtml(row.email || '')}</div>
      <div class="actions">
        <a href="#" onclick='editarPaciente(${toAttrJson(row)})'>Editar</a>
        <a href="#" onclick="excluirPaciente('${escapeAttr(row.id)}')">Excluir</a>
      </div>
    </div>
  `).join('');
}

function editarPaciente(row) {
  document.getElementById('pacienteId').value = row.id || '';
  document.getElementById('pacienteNome').value = row.nome || '';
  document.getElementById('pacienteCpf').value = row.cpf || '';
  document.getElementById('pacientePreccp').value = row.preccp || '';
  document.getElementById('pacienteCns').value = row.cns || '';
  document.getElementById('pacienteNascimento').value = row.nascimento || '';
  document.getElementById('pacienteTelefone').value = row.telefone || '';
  document.getElementById('pacienteEmail').value = row.email || '';
  document.getElementById('codigoAcessoPaciente').value = '';
  pacienteMsg.textContent = `Editando paciente ${row.id || ''}. Código de acesso só muda se preenchido.`;
}

async function excluirPaciente(id) {
  if (!id || !confirm('Confirma excluir este paciente e bloquear os exames vinculados?')) return;
  const response = await fetch(`/api/admin/pacientes/${encodeURIComponent(id)}`, { method: 'DELETE', headers: adminHeaders() });
  const data = await responseJson(response);
  if (!response.ok) { pacienteMsg.textContent = data.detail || 'Erro ao excluir paciente.'; return; }
  pacienteMsg.textContent = `Paciente excluído. ID: ${data.id}`;
  limparPacienteForm();
  await buscarPacientes();
}

async function buscarCatalogo() {
  catalogoList.innerHTML = '<p>Consultando...</p>';
  const q = encodeURIComponent(catalogoSearch.value || '');
  const response = await fetch(`/api/admin/catalogo-exames?q=${q}`, { headers: adminJsonHeaders() });
  const rows = await responseJson(response);
  if (!response.ok) { catalogoList.innerHTML = `<p>${escapeHtml(rows.detail || 'Acesso negado.')}</p>`; return; }
  if (rows.length === 0) { catalogoList.innerHTML = '<p>Nenhum exame cadastrado no catálogo.</p>'; return; }
  catalogoList.innerHTML = rows.map((row) => `
    <div class="item">
      <strong>${escapeHtml(row.mne || '')} - ${escapeHtml(row.nome || '')}</strong>
      <div class="meta">SIRE: ${escapeHtml(row.codigo_sire || '')} | Setor: ${escapeHtml(row.setor || '')} | Material: ${escapeHtml(row.material || '')}<br>Unidade: ${escapeHtml(row.unidade || '')} | Valor: ${escapeHtml(row.valor_cheio || '')} | 20%: ${escapeHtml(row.valor_indenizar_20 || '')}<br>Equipamento: ${escapeHtml(row.equipamento || '')} | Ativo: ${row.ativo === '1' ? 'SIM' : 'NAO'}</div>
      <div class="actions">
        <a href="#" onclick='editarCatalogo(${toAttrJson(row)})'>Editar</a>
        <a href="#" onclick="excluirCatalogo('${escapeAttr(row.id)}')">Excluir</a>
      </div>
    </div>
  `).join('');
}

function editarCatalogo(row) {
  document.getElementById('catalogoId').value = row.id || '';
  document.getElementById('catalogoMne').value = row.mne || '';
  document.getElementById('catalogoCodigoSire').value = row.codigo_sire || '';
  document.getElementById('catalogoNome').value = row.nome || '';
  document.getElementById('catalogoSetor').value = row.setor || '';
  document.getElementById('catalogoMaterial').value = row.material || '';
  document.getElementById('catalogoMetodo').value = row.metodo || '';
  document.getElementById('catalogoUnidade').value = row.unidade || '';
  document.getElementById('catalogoReferencia').value = row.referencia || '';
  document.getElementById('catalogoValorCheio').value = row.valor_cheio || '';
  document.getElementById('catalogoValorIndenizar20').value = row.valor_indenizar_20 || '';
  document.getElementById('catalogoEquipamento').value = row.equipamento || '';
  document.getElementById('catalogoAtivo').value = row.ativo === '0' ? '0' : '1';
  catalogoMsg.textContent = `Editando exame do catálogo ${row.id || ''}.`;
}

async function excluirCatalogo(id) {
  if (!id || !confirm('Confirma excluir este item do catálogo de exames?')) return;
  const response = await fetch(`/api/admin/catalogo-exames/${encodeURIComponent(id)}`, { method: 'DELETE', headers: adminHeaders() });
  const data = await responseJson(response);
  if (!response.ok) { catalogoMsg.textContent = data.detail || 'Erro ao excluir catálogo.'; return; }
  catalogoMsg.textContent = `Catálogo excluído. ID: ${data.id}`;
  limparCatalogoForm();
  await buscarCatalogo();
}

async function buscarLaudos(historico) {
  adminList.innerHTML = '<p>Consultando...</p>';
  const q = encodeURIComponent(adminSearch.value || '');
  const response = await fetch(`/api/admin/exames?q=${q}&historico=${historico}`, { headers: adminJsonHeaders() });
  const rows = await responseJson(response);
  if (!response.ok) { adminList.innerHTML = `<p>${escapeHtml(rows.detail || 'Acesso negado ou sessão expirada.')}</p>`; return; }
  if (rows.length === 0) { adminList.innerHTML = '<p>Nenhum exame encontrado.</p>'; return; }
  adminList.innerHTML = rows.map((row) => `
    <div class="item">
      <strong>${escapeHtml(row.paciente_nome || '')}</strong>
      ${row.critico === 'SIM' ? '<span class="critico"> • CRÍTICO</span>' : ''}
      <div class="meta">CPF: ${escapeHtml(row.cpf || '')} | PREC-CP: ${escapeHtml(row.preccp || '')}<br>Exame: ${escapeHtml(row.exame_nome || '')}<br>Valor: ${escapeHtml(row.valor || '')} ${escapeHtml(row.unidade || '')}<br>Liberado: ${escapeHtml(row.liberado_em || '')}</div>
      <div class="actions"><a href="#" onclick="baixarAdmin('${escapeAttr(row.id)}')">Baixar PDF</a></div>
    </div>
  `).join('');
}

async function baixarAdmin(id) {
  const response = await fetch(`/api/laudos/${encodeURIComponent(id)}/download`, { headers: adminHeaders() });
  if (!response.ok) { adminList.innerHTML = '<p>Falha ao baixar laudo.</p>'; return; }
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = `laudo_${id}.pdf`; a.click();
  URL.revokeObjectURL(url);
}


async function chamarServidorProtegido(path, method, label) {
  if (!serverApiKey.value.trim()) { serverMsg.textContent = 'Informe a chave API do servidor.'; return; }
  serverMsg.textContent = `${label}: executando...`;
  const response = await fetch(path, { method, headers: serverApiHeaders() });
  const data = await responseJson(response);
  if (!response.ok) { serverMsg.textContent = data.detail || `${label}: falha HTTP ${response.status}`; return; }
  serverMsg.textContent = `${label}: ${JSON.stringify(data)}`;
}

async function excluirTodosDados() {
  if (!isSuperUsuario()) { excluirTudoMsg.textContent = 'Apenas SUPER_USUARIO pode executar esta ação.'; return; }
  const confirmacao = document.getElementById('confirmacaoExclusaoTotal').value;
  const form = new FormData();
  form.append('confirmacao', confirmacao);
  const response = await fetch('/api/admin/dados/excluir-todos', { method: 'POST', headers: adminHeaders(), body: form });
  const data = await responseJson(response);
  if (!response.ok) { excluirTudoMsg.textContent = data.detail || 'Erro ao excluir dados.'; return; }
  excluirTudoMsg.textContent = 'Dados cadastrados excluídos.';
  await Promise.all([buscarPacientes(), buscarCatalogo(), buscarLaudos(true)]);
}

function limparPacienteForm() {
  pacienteForm.reset();
  document.getElementById('pacienteId').value = '';
}

function limparCatalogoForm() {
  catalogoForm.reset();
  document.getElementById('catalogoId').value = '';
  document.getElementById('catalogoAtivo').value = '1';
}

function escapeHtml(value) {
  return String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#039;');
}

function escapeAttr(value) {
  return escapeHtml(value).replaceAll('`', '&#096;');
}

function toAttrJson(row) {
  return escapeAttr(JSON.stringify(row));
}

if (adminToken()) {
  mostrarPainel();
  Promise.all([buscarPacientes(), buscarCatalogo(), buscarLaudos(true)]);
}
