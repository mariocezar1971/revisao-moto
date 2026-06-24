// =====================================================================
// REVISAO-MOTO :: Autenticacao
// =====================================================================

/**
 * Faz login com email e senha.
 */
async function fazerLogin(email, senha) {
  const { data, error } = await window.sb.auth.signInWithPassword({
    email: email,
    password: senha
  });

  if (error) {
    return { sucesso: false, erro: error.message };
  }

  return { sucesso: true, usuario: data.user };
}

/**
 * Cadastra novo usuario (mecanico ou admin).
 * Em uso interno, voce pode criar usuarios direto no Supabase Dashboard.
 */
async function cadastrarUsuario(email, senha, nomeCompleto) {
  const { data, error } = await window.sb.auth.signUp({
    email: email,
    password: senha,
    options: {
      data: {
        nome_completo: nomeCompleto
      }
    }
  });

  if (error) {
    return { sucesso: false, erro: error.message };
  }

  return { sucesso: true, usuario: data.user };
}

/**
 * Recupera sessao ativa (usado no boot do app).
 */
async function recuperarSessao() {
  const { data: { session } } = await window.sb.auth.getSession();
  return session;
}

window.fazerLogin = fazerLogin;
window.cadastrarUsuario = cadastrarUsuario;
window.recuperarSessao = recuperarSessao;
