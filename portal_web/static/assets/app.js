const loginForm = document.getElementById('loginForm');
const loginMsg = document.getElementById('loginMsg');
const loginCard = document.getElementById('loginCard');
const examesCard = document.getElementById('examesCard');
const examesList = document.getElementById('examesList');

function token() { return localStorage.getItem('kristalPacienteToken') || ''; }
function authHeaders() { return { Authorization: `Bearer ${token()}` }; }

loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  loginMsg.textContent = 'Validando acesso...';
  const form = new FormData();
  form.append('cpf', document.getElementById('cpf').value);
  form.append('codigo', document.getElementById('codigo').value);
  const response = await fetch('/api/paciente/login', { method: 'POST', body: form });
  if (!response.ok) { loginMsg.textContent = 'CPF ou código inválido.'; return; }
  const data = await response.json();
  localStorage.setItem('kristalPacienteToken', data.token);
  loginCard.classList.add('hidden');
  examesCard.classList.remove('hidden');
  await carregarExames(true);
});

document.getElementById('logoutBtn').addEventListener('click', () => {
  localStorage.removeItem('kristalPacienteToken');
  location.reload();
});
document.getElementById('historicoBtn').addEventListener('click', () => carregarExames(true));
document.getElementById('recentesBtn').addEventListener('click', () => carregarExames(false));

async function carregarExames(historico) {
  examesList.innerHTML = '<p>Carregando exames...</p>';
  const response = await fetch(`/api/paciente/exames?historico=${historico}`, { headers: authHeaders() });
  if (!response.ok) { examesList.innerHTML = '<p>Sessão expirada ou acesso negado.</p>'; return; }
  const exames = await response.json();
  if (exames.length === 0) { examesList.innerHTML = '<p>Nenhum exame encontrado.</p>'; return; }
  examesList.innerHTML = exames.map((exame) => `
    <div class="item">
      <strong>${escapeHtml(exame.exame_nome || 'Exame')}</strong>
      ${exame.critico === 'SIM' ? '<span class="critico"> • CRÍTICO</span>' : ''}
      <div class="meta">
        Valor: ${escapeHtml(exame.valor || '')} ${escapeHtml(exame.unidade || '')}<br>
        Referência: ${escapeHtml(exame.referencia || '')}<br>
        Liberado em: ${escapeHtml(exame.liberado_em || '')}<br>
        Equipamento: ${escapeHtml(exame.equipamento || '')}
      </div>
      <div class="actions">
        <a href="#" onclick="baixarLaudo('${exame.id}')">Baixar PDF</a>
        <a href="#" onclick="imprimirLaudo('${exame.id}')">Imprimir</a>
      </div>
    </div>
  `).join('');
}

async function baixarLaudo(id) {
  const response = await fetch(`/api/laudos/${encodeURIComponent(id)}/download`, { headers: authHeaders() });
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = `laudo_${id}.pdf`; a.click();
  URL.revokeObjectURL(url);
}

async function imprimirLaudo(id) {
  const response = await fetch(`/api/laudos/${encodeURIComponent(id)}/print`, { headers: authHeaders() });
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  window.open(url, '_blank');
}

function escapeHtml(value) {
  return String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'","&#039;");
}

if (token()) {
  loginCard.classList.add('hidden');
  examesCard.classList.remove('hidden');
  carregarExames(true);
}
