// =====================================================================
// REVISAO-MOTO :: Offline - IndexedDB + fila de sincronizacao
// =====================================================================
// Estrategia:
// - Cache de catalogo (modelos, revisoes, itens) em IndexedDB
// - Operacoes de escrita: online -> direto Supabase; offline -> fila local
// - Sync automatico ao voltar online (evento 'online')
// - Fotos capturadas offline: blob no IndexedDB, upload ao sincronizar
// - Retry com backoff exponencial (max 5 tentativas)
// =====================================================================

const DB_NOME = 'revisao_moto_offline';
const DB_VERSAO = 1;
const SYNC_INTERVAL_MS = 30000;  // tenta sync a cada 30s se online
const MAX_TENTATIVAS = 5;

// Object stores
const STORES = {
    CATALOGO:    'catalogo',           // key: 'modelos' | 'revisoes' | 'itens_{revisao_id}'
    INSPECOES:   'inspecoes_locais',   // key: inspecao_id (UUID)
    PENDENTES:   'pending_operations', // key: auto-increment
    FOTOS:       'fotos_pendentes'     // key: '{inspecao_id}/{item_id}'
};

let dbInstance = null;
let syncEmAndamento = false;

// ================================================================
// ABRIR/UPGRADE DO BANCO
// ================================================================
function abrirDb() {
    if (dbInstance) return Promise.resolve(dbInstance);
    return new Promise((resolve, reject) => {
        const req = indexedDB.open(DB_NOME, DB_VERSAO);

        req.onupgradeneeded = (e) => {
            const db = e.target.result;
            if (!db.objectStoreNames.contains(STORES.CATALOGO)) {
                db.createObjectStore(STORES.CATALOGO);
            }
            if (!db.objectStoreNames.contains(STORES.INSPECOES)) {
                db.createObjectStore(STORES.INSPECOES);
            }
            if (!db.objectStoreNames.contains(STORES.PENDENTES)) {
                const s = db.createObjectStore(STORES.PENDENTES, {
                    keyPath: 'id', autoIncrement: true
                });
                s.createIndex('criado_em', 'criado_em');
                s.createIndex('tipo', 'tipo');
            }
            if (!db.objectStoreNames.contains(STORES.FOTOS)) {
                db.createObjectStore(STORES.FOTOS);
            }
        };

        req.onsuccess = () => { dbInstance = req.result; resolve(dbInstance); };
        req.onerror = () => reject(req.error);
    });
}

async function tx(storeName, modo = 'readonly') {
    const db = await abrirDb();
    return db.transaction(storeName, modo).objectStore(storeName);
}

function promisify(request) {
    return new Promise((resolve, reject) => {
        request.onsuccess = () => resolve(request.result);
        request.onerror   = () => reject(request.error);
    });
}

// ================================================================
// CATALOGO - CACHE READ-THROUGH
// ================================================================
async function cacheGet(chave) {
    const store = await tx(STORES.CATALOGO);
    return promisify(store.get(chave));
}

async function cacheSet(chave, valor) {
    const store = await tx(STORES.CATALOGO, 'readwrite');
    return promisify(store.put({ valor, cacheado_em: Date.now() }, chave));
}

async function cacheLimpar() {
    const store = await tx(STORES.CATALOGO, 'readwrite');
    return promisify(store.clear());
}

/**
 * Cacheia catalogo essencial (modelos, revisoes, itens de todas as revisoes).
 * Chamar ao carregar app quando online, ou manualmente.
 */
async function cachearCatalogo() {
    if (!window.sb || !navigator.onLine) return { sucesso: false, motivo: 'offline' };
    try {
        const [modelos, revisoes] = await Promise.all([
            window.sb.from('modelos').select('*').eq('ativo', true),
            window.sb.from('revisoes').select('*').order('modelo_id, km')
        ]);
        if (modelos.error) throw modelos.error;
        if (revisoes.error) throw revisoes.error;

        await cacheSet('modelos', modelos.data || []);
        await cacheSet('revisoes', revisoes.data || []);

        // Itens de todas as revisoes
        const { data: itens, error: eItens } = await window.sb
            .from('vw_checklist_completo').select('*').order('ordem');
        if (eItens) throw eItens;

        // Agrupa por revisao_id
        const porRevisao = {};
        (itens || []).forEach(it => {
            const k = `itens_${it.revisao_id}`;
            if (!porRevisao[k]) porRevisao[k] = [];
            porRevisao[k].push(it);
        });
        for (const [chave, arr] of Object.entries(porRevisao)) {
            await cacheSet(chave, arr);
        }

        return { sucesso: true, modelos: (modelos.data || []).length,
                 revisoes: (revisoes.data || []).length,
                 itens: (itens || []).length };
    } catch (e) {
        console.error('cachearCatalogo:', e);
        return { sucesso: false, motivo: e.message };
    }
}

async function obterCatalogo(chave) {
    const cache = await cacheGet(chave);
    return cache ? cache.valor : null;
}

// ================================================================
// FILA DE OPERACOES PENDENTES
// ================================================================
/**
 * Enfileira operacao para sync posterior.
 * @param {string} tipo   'update_inspecao' | 'upsert_item' | 'upload_foto'
 * @param {Object} dados  payload especifico
 */
async function enfileirarOperacao(tipo, dados) {
    const store = await tx(STORES.PENDENTES, 'readwrite');
    const op = {
        tipo, dados,
        tentativas: 0,
        ultimo_erro: null,
        criado_em: Date.now(),
        proxima_tentativa: 0
    };
    return promisify(store.add(op));
}

async function listarPendentes() {
    const store = await tx(STORES.PENDENTES);
    return promisify(store.getAll());
}

async function contarPendentes() {
    const store = await tx(STORES.PENDENTES);
    return promisify(store.count());
}

async function removerPendente(id) {
    const store = await tx(STORES.PENDENTES, 'readwrite');
    return promisify(store.delete(id));
}

async function atualizarPendente(op) {
    const store = await tx(STORES.PENDENTES, 'readwrite');
    return promisify(store.put(op));
}

// ================================================================
// FOTOS OFFLINE
// ================================================================
/**
 * Salva foto localmente (blob comprimido) para upload posterior.
 */
async function salvarFotoLocal(inspecaoId, itemId, blob) {
    const chave = `${inspecaoId}/${itemId}`;
    const store = await tx(STORES.FOTOS, 'readwrite');
    await promisify(store.put({ blob, criado_em: Date.now() }, chave));
    return chave;
}

async function obterFotoLocal(chave) {
    const store = await tx(STORES.FOTOS);
    const r = await promisify(store.get(chave));
    return r ? r.blob : null;
}

async function removerFotoLocal(chave) {
    const store = await tx(STORES.FOTOS, 'readwrite');
    return promisify(store.delete(chave));
}

async function listarChavesFotoPendente() {
    const store = await tx(STORES.FOTOS);
    return promisify(store.getAllKeys());
}

// ================================================================
// EXECUCAO DA FILA (SYNC)
// ================================================================
/**
 * Executa uma operacao pendente contra o Supabase.
 * Retorna true se sucesso (deve remover da fila).
 */
async function executarOperacao(op) {
    if (!window.sb) throw new Error('Cliente Supabase nao disponivel');
    const d = op.dados;

    switch (op.tipo) {
        case 'upsert_item':
            // d: { inspecao_id, item_id, status, valor_medido, observacao, foto_url }
            const { error: e1 } = await window.sb.from('inspecoes_itens').upsert(d, {
                onConflict: 'inspecao_id,item_id'
            });
            if (e1) throw e1;
            return true;

        case 'update_inspecao':
            // d: { id, campos: {...} }
            const { error: e2 } = await window.sb.from('inspecoes')
                .update(d.campos).eq('id', d.id);
            if (e2) throw e2;
            return true;

        case 'insert_inspecao':
            // d: registro completo
            const { error: e3 } = await window.sb.from('inspecoes').insert(d);
            if (e3) throw e3;
            return true;

        case 'upload_foto':
            // d: { inspecao_id, item_id, chave_local }
            const blob = await obterFotoLocal(d.chave_local);
            if (!blob) return true;  // foto ja foi removida, considera sucesso

            const path = `${d.inspecao_id}/${d.item_id}.jpg`;
            const { error: eUp } = await window.sb.storage
                .from('inspecoes')
                .upload(path, blob, {
                    contentType: 'image/jpeg', upsert: true, cacheControl: '3600'
                });
            if (eUp) throw eUp;

            // Atualiza inspecoes_itens.foto_url
            await window.sb.from('inspecoes_itens').update({ foto_url: path })
                .eq('inspecao_id', d.inspecao_id).eq('item_id', d.item_id);

            // Remove foto do cache local
            await removerFotoLocal(d.chave_local);
            return true;

        default:
            throw new Error(`Tipo desconhecido: ${op.tipo}`);
    }
}

/**
 * Processa a fila inteira em ordem cronologica, com retry/backoff.
 * Emite eventos: sync-inicio, sync-progresso, sync-fim.
 */
async function sincronizar(callbacks = {}) {
    if (!navigator.onLine) return { pulado: true, motivo: 'offline' };
    if (syncEmAndamento) return { pulado: true, motivo: 'ja_em_andamento' };
    syncEmAndamento = true;

    const { onProgresso, onErro } = callbacks;
    dispararEvento('sync-inicio');

    try {
        const pendentes = await listarPendentes();
        const agora = Date.now();
        // Filtra as que ja podem ser tentadas (respeitando backoff)
        const paraTentar = pendentes.filter(op => op.proxima_tentativa <= agora);

        let sucessos = 0, falhas = 0;
        for (const op of paraTentar) {
            try {
                if (onProgresso) onProgresso({ tipo: op.tipo, tentativa: op.tentativas + 1 });
                await executarOperacao(op);
                await removerPendente(op.id);
                sucessos++;
            } catch (e) {
                falhas++;
                op.tentativas++;
                op.ultimo_erro = e.message || String(e);
                if (op.tentativas >= MAX_TENTATIVAS) {
                    // Desistimos - deixa na fila mas marca
                    op.desistido = true;
                    if (onErro) onErro({ op, motivo: 'max_tentativas' });
                } else {
                    // Backoff exponencial: 5s, 10s, 20s, 40s, 80s
                    op.proxima_tentativa = agora + (5000 * Math.pow(2, op.tentativas - 1));
                }
                await atualizarPendente(op);
            }
        }

        dispararEvento('sync-fim', { sucessos, falhas, restam: await contarPendentes() });
        return { sucessos, falhas, restam: await contarPendentes() };
    } finally {
        syncEmAndamento = false;
    }
}

function dispararEvento(nome, detail = {}) {
    window.dispatchEvent(new CustomEvent(`offline:${nome}`, { detail }));
}

// ================================================================
// ESCRITAS COM FALLBACK AUTOMATICO
// ================================================================
/**
 * Salva item com estrategia online-first / offline-fallback.
 */
async function salvarItemInteligente(inspecaoId, itemId, dados) {
    const registro = {
        inspecao_id: inspecaoId,
        item_id: itemId,
        status: dados.status || null,
        valor_medido: dados.valor_medido || null,
        observacao: dados.observacao || null,
        foto_url: dados.foto_url || null,
        verificado_em: new Date().toISOString()
    };

    if (navigator.onLine && window.sb) {
        try {
            const { error } = await window.sb.from('inspecoes_itens')
                .upsert(registro, { onConflict: 'inspecao_id,item_id' });
            if (error) throw error;
            return { modo: 'online' };
        } catch (e) {
            console.warn('Falha online, enfileirando offline:', e.message);
            await enfileirarOperacao('upsert_item', registro);
            return { modo: 'fila', motivo: e.message };
        }
    } else {
        await enfileirarOperacao('upsert_item', registro);
        return { modo: 'fila', motivo: 'offline' };
    }
}

// ================================================================
// LISTENERS DE REDE E AUTO-SYNC
// ================================================================
let intervalSync = null;

function iniciarAutoSync() {
    // Sync quando voltar online
    window.addEventListener('online', () => {
        console.log('[offline] rede voltou, sincronizando...');
        setTimeout(sincronizar, 500);
    });
    window.addEventListener('offline', () => {
        console.log('[offline] sem rede, salvando local');
        dispararEvento('offline');
    });

    // Sync periodico enquanto online
    if (intervalSync) clearInterval(intervalSync);
    intervalSync = setInterval(() => {
        if (navigator.onLine && !syncEmAndamento) {
            contarPendentes().then(n => { if (n > 0) sincronizar(); });
        }
    }, SYNC_INTERVAL_MS);
}

function pararAutoSync() {
    if (intervalSync) { clearInterval(intervalSync); intervalSync = null; }
}

// ================================================================
// EXPORTS
// ================================================================
window.offline = {
    abrirDb,
    cachearCatalogo,
    obterCatalogo,
    cacheLimpar,
    enfileirarOperacao,
    listarPendentes,
    contarPendentes,
    removerPendente,
    salvarFotoLocal,
    obterFotoLocal,
    removerFotoLocal,
    listarChavesFotoPendente,
    sincronizar,
    salvarItemInteligente,
    iniciarAutoSync,
    pararAutoSync,
    STORES
};

// Auto-inicializa quando script carrega
if (typeof window !== 'undefined') {
    window.addEventListener('load', () => {
        iniciarAutoSync();
    });
}
