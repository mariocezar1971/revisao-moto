// =====================================================================
// REVISAO-MOTO :: Cliente Supabase
// =====================================================================
// IMPORTANTE: substitua SUPABASE_URL e SUPABASE_ANON_KEY pelos valores
// do seu projeto (Dashboard > Project Settings > API).
// Para producao, considere usar variaveis em build time ou config remota.
// =====================================================================

const SUPABASE_URL = 'https://SEU_PROJETO.supabase.co';
const SUPABASE_ANON_KEY = 'SUA_ANON_KEY_AQUI';

// Inicializa o client (assume que supabase-js ja foi carregado via CDN no HTML)
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  }
});

// Expor globalmente para uso nas outras paginas
window.sb = supabaseClient;

// =====================================================================
// Helpers de uso comum
// =====================================================================

/**
 * Retorna o usuario atual logado (ou null).
 */
async function getUsuarioAtual() {
  const { data: { user } } = await window.sb.auth.getUser();
  return user;
}

/**
 * Redireciona para login se nao estiver autenticado.
 * Use no topo de paginas restritas.
 */
async function exigirLogin() {
  const user = await getUsuarioAtual();
  if (!user) {
    window.location.href = './index.html';
    return null;
  }
  return user;
}

/**
 * Logout simples.
 */
async function logout() {
  await window.sb.auth.signOut();
  window.location.href = './index.html';
}

window.getUsuarioAtual = getUsuarioAtual;
window.exigirLogin = exigirLogin;
window.logout = logout;
