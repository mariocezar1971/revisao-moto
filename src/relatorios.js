// =====================================================================
// REVISAO-MOTO :: Relatorios - CSV, agregados, exports
// =====================================================================
// Responsavel por:
// - Buscar dados de historico com filtros
// - Gerar CSV de inspecoes e itens
// - Agregar dados para relatorios gerenciais
// - Estatisticas gerais (dashboard)
// =====================================================================

// ================================================================
// BUSCA COM FILTROS
// ================================================================
/**
 * Busca inspecoes aplicando filtros opcionais.
 * @param {Object} filtros { placa, mecanico, status, modelo, dataDe, dataAte }
 */
async function buscarInspecoes(filtros = {}) {
    let query = window.sb.from('vw_timeline_inspecoes').select('*');

    if (filtros.placa)     query = query.ilike('placa', `%${filtros.placa}%`);
    if (filtros.mecanico)  query = query.ilike('mecanico_nome', `%${filtros.mecanico}%`);
    if (filtros.status)    query = query.eq('status', filtros.status);
    if (filtros.dataDe)    query = query.gte('data_inicio', filtros.dataDe);
    if (filtros.dataAte)   query = query.lte('data_inicio', filtros.dataAte + 'T23:59:59');

    query = query.order('data_inicio', { ascending: false }).limit(500);

    const { data, error } = await query;
    if (error) throw error;

    // Filtro de modelo eh no client (nao tem coluna direta na view)
    let resultado = data || [];
    if (filtros.modelo && resultado.length > 0) {
        // Precisa join com motos+modelo — buscar em lote
        const motoIds = [...new Set(resultado.map(r => r.moto_id))];
        const { data: motos } = await window.sb.from('vw_motos_status')
            .select('id, modelo').in('id', motoIds);
        const motoModelo = {};
        (motos || []).forEach(m => { motoModelo[m.id] = m.modelo; });
        resultado = resultado.filter(r => motoModelo[r.moto_id] === filtros.modelo);
    }
    return resultado;
}

/**
 * Lista todos os mecanicos que ja fizeram inspecao (para dropdown de filtro).
 */
async function listarMecanicos() {
    const { data, error } = await window.sb
        .from('inspecoes')
        .select('mecanico_nome')
        .not('mecanico_nome', 'is', null)
        .order('mecanico_nome');
    if (error) throw error;
    const unicos = [...new Set((data || []).map(d => d.mecanico_nome))];
    return unicos.filter(Boolean).sort();
}

/**
 * Lista modelos disponiveis (para dropdown).
 */
async function listarModelos() {
    const { data, error } = await window.sb.from('modelos')
        .select('id, nome').eq('ativo', true).order('nome');
    if (error) throw error;
    return data || [];
}

// ================================================================
// EXPORT CSV
// ================================================================
/**
 * Escapa um valor para CSV: envolve em aspas se contiver virgula, aspas ou quebra.
 */
function csvEscape(valor) {
    if (valor === null || valor === undefined) return '';
    const s = String(valor);
    if (s.includes(',') || s.includes('"') || s.includes('\n') || s.includes('\r')) {
        return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
}

/**
 * Converte array de objetos em CSV com BOM UTF-8 (Excel-friendly).
 */
function objsParaCsv(objetos, colunas = null) {
    if (!objetos || objetos.length === 0) return '';
    const cols = colunas || Object.keys(objetos[0]);
    const linhas = [cols.map(csvEscape).join(',')];
    for (const obj of objetos) {
        linhas.push(cols.map(c => csvEscape(obj[c])).join(','));
    }
    // BOM UTF-8 (\uFEFF) para Excel abrir com acentos corretos
    return '\uFEFF' + linhas.join('\r\n');
}

/**
 * Dispara download de um blob com o nome dado.
 */
function baixarBlob(blob, nomeArquivo) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = nomeArquivo;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
        try { document.body.removeChild(a); } catch(_) {}
        URL.revokeObjectURL(url);
    }, 200);
}

/**
 * Exporta cabecalho das inspecoes filtradas para CSV.
 */
async function exportarCsvInspecoes(filtros = {}) {
    const inspecoes = await buscarInspecoes(filtros);
    const linhas = inspecoes.map(i => ({
        id: i.id,
        placa: i.placa,
        modelo: i.modelo || '',
        revisao_km: i.revisao_km,
        km_registrado: i.km_registrado,
        status: i.status,
        mecanico: i.mecanico_nome || '',
        cliente: i.nome_cliente_assinou || '',
        data_inicio: i.data_inicio,
        data_fim: i.data_fim || '',
        duracao_min: i.duracao_minutos != null ? Math.round(i.duracao_minutos) : '',
        total_itens: i.total_itens || 0,
        ok: i.ok_count || 0,
        nao_ok: i.nao_ok_count || 0,
        na: i.na_count || 0,
        pdf_url: i.pdf_url || '',
        hash: i.hash_integridade || ''
    }));
    const csv = objsParaCsv(linhas);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const nome = `inspecoes_${new Date().toISOString().substring(0,10)}.csv`;
    baixarBlob(blob, nome);
    return { linhas: linhas.length, nome };
}

/**
 * Exporta detalhamento (item a item) das inspecoes filtradas.
 */
async function exportarCsvItens(filtros = {}) {
    const inspecoes = await buscarInspecoes(filtros);
    if (inspecoes.length === 0) {
        return { linhas: 0, nome: null };
    }
    const ids = inspecoes.map(i => i.id);
    // Busca itens em lote
    const { data: itens, error } = await window.sb
        .from('inspecoes_itens')
        .select(`
            inspecao_id, status, valor_medido, observacao, foto_url,
            itens_checklist(categoria, descricao, valor_referencia, obrigatorio)
        `)
        .in('inspecao_id', ids);
    if (error) throw error;

    // Mapa insp -> dados
    const inspMap = {};
    inspecoes.forEach(i => { inspMap[i.id] = i; });

    const linhas = (itens || []).map(ii => {
        const insp = inspMap[ii.inspecao_id] || {};
        const c = ii.itens_checklist || {};
        return {
            inspecao_id: ii.inspecao_id,
            placa: insp.placa || '',
            data: insp.data_inicio || '',
            mecanico: insp.mecanico_nome || '',
            categoria: c.categoria || '',
            item: c.descricao || '',
            referencia: c.valor_referencia || '',
            obrigatorio: c.obrigatorio ? 'sim' : 'nao',
            status: ii.status || '',
            valor_medido: ii.valor_medido || '',
            observacao: ii.observacao || '',
            tem_foto: ii.foto_url ? 'sim' : 'nao'
        };
    });

    const csv = objsParaCsv(linhas);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const nome = `itens_inspecao_${new Date().toISOString().substring(0,10)}.csv`;
    baixarBlob(blob, nome);
    return { linhas: linhas.length, nome };
}

// ================================================================
// RELATORIOS GERENCIAIS
// ================================================================
async function estatisticasGerais() {
    const { data, error } = await window.sb.rpc('estatisticas_gerais');
    if (error) throw error;
    return (data && data[0]) || null;
}

async function inspecoesPorMecanicoMes(limite = 12) {
    const { data, error } = await window.sb
        .from('vw_inspecoes_por_mecanico_mes')
        .select('*')
        .order('mes', { ascending: false })
        .limit(limite * 10);  // varios mecanicos por mes
    if (error) throw error;
    return data || [];
}

async function itensMaisReprovados(limite = 20) {
    const { data, error } = await window.sb
        .from('vw_itens_mais_reprovados')
        .select('*')
        .limit(limite);
    if (error) throw error;
    return data || [];
}

async function motosComStatus() {
    const { data, error } = await window.sb
        .from('vw_motos_com_status_revisao')
        .select('*')
        .order('placa');
    if (error) throw error;
    return data || [];
}

async function timelineDeUmaMoto(motoId) {
    const { data, error } = await window.sb
        .from('vw_timeline_inspecoes')
        .select('*')
        .eq('moto_id', motoId)
        .order('data_inicio', { ascending: false });
    if (error) throw error;
    return data || [];
}

// ================================================================
// EXPORTS
// ================================================================
window.buscarInspecoes             = buscarInspecoes;
window.listarMecanicos             = listarMecanicos;
window.listarModelos               = listarModelos;
window.exportarCsvInspecoes        = exportarCsvInspecoes;
window.exportarCsvItens            = exportarCsvItens;
window.estatisticasGerais          = estatisticasGerais;
window.inspecoesPorMecanicoMes     = inspecoesPorMecanicoMes;
window.itensMaisReprovados         = itensMaisReprovados;
window.motosComStatus              = motosComStatus;
window.timelineDeUmaMoto           = timelineDeUmaMoto;
window.objsParaCsv                 = objsParaCsv;
