// =====================================================================
// REVISAO-MOTO :: PDF - geracao do relatorio de inspecao
// =====================================================================
// Usa jsPDF (via CDN em inspecao.html) para montar PDF A4 com:
//   - Cabecalho colorido
//   - Dados da moto e proprietario
//   - Tabela de itens com status
//   - Fotos embarcadas
//   - Assinaturas
//   - Hash SHA-256 de integridade no rodape
// =====================================================================

const PDF_CONFIG = {
    margem: 15,
    largura: 210,
    altura: 297,
    cor_primaria:  [220, 38, 38],   // vermelho RE
    cor_secundaria:[15, 23, 42],    // azul escuro
    cor_texto:     [30, 41, 59],
    cor_claro:     [148, 163, 184],
    cor_verde:     [22, 163, 74],
    cor_vermelho:  [220, 38, 38],
    cor_cinza:     [107, 114, 128]
};

/**
 * Calcula SHA-256 de um texto usando Web Crypto API.
 * Retorna hex string.
 */
async function calcularHashSha256(texto) {
    const buffer = new TextEncoder().encode(texto);
    const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
    return Array.from(new Uint8Array(hashBuffer))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('');
}

/**
 * Carrega uma imagem de URL e retorna data URL base64 para embed no PDF.
 */
async function carregarImagemComoDataUrl(url) {
    try {
        const resp = await fetch(url);
        const blob = await resp.blob();
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = reject;
            reader.readAsDataURL(blob);
        });
    } catch (e) {
        console.warn('Falha ao carregar imagem:', url, e);
        return null;
    }
}

/**
 * Coleta dados agregados da inspeção para o PDF.
 */
async function coletarDadosInspecao(inspecaoId) {
    const { data: inspecao, error: e1 } = await window.sb
        .from('inspecoes')
        .select('*, motos(*, modelos(nome, plataforma)), revisoes(km, meses, tipo)')
        .eq('id', inspecaoId)
        .single();
    if (e1) throw e1;

    const { data: itensExecutados, error: e2 } = await window.sb
        .from('inspecoes_itens')
        .select(`
            *,
            itens_checklist(ordem, categoria, descricao, valor_referencia,
                             obrigatorio, exige_foto, exige_medicao)
        `)
        .eq('inspecao_id', inspecaoId);
    if (e2) throw e2;

    // Ordena por categoria + ordem
    const ordenados = (itensExecutados || []).sort((a, b) => {
        const ca = a.itens_checklist?.categoria || '';
        const cb = b.itens_checklist?.categoria || '';
        if (ca !== cb) return ca.localeCompare(cb);
        return (a.itens_checklist?.ordem || 0) - (b.itens_checklist?.ordem || 0);
    });

    const { data: progresso } = await window.sb
        .from('vw_inspecao_progresso')
        .select('*')
        .eq('inspecao_id', inspecaoId)
        .single();

    return { inspecao, itensExecutados: ordenados, progresso: progresso || {} };
}

/**
 * Gera o PDF completo da inspecao.
 * Retorna { blob, hash }.
 */
async function gerarPdfInspecao(inspecaoId, callbacks = {}) {
    const { onProgresso } = callbacks;
    const onp = (msg) => { if (onProgresso) onProgresso(msg); };

    onp('Coletando dados...');
    const { inspecao, itensExecutados, progresso } = await coletarDadosInspecao(inspecaoId);
    const moto = inspecao.motos;
    const modelo = moto.modelos;
    const revisao = inspecao.revisoes;

    onp('Iniciando PDF...');
    if (!window.jspdf || !window.jspdf.jsPDF) {
        throw new Error('jsPDF nao carregado. Verifique CDN em inspecao.html');
    }
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ unit: 'mm', format: 'a4', compress: true });
    const M = PDF_CONFIG.margem;

    // --- Cabecalho ---
    doc.setFillColor(...PDF_CONFIG.cor_primaria);
    doc.rect(0, 0, PDF_CONFIG.largura, 25, 'F');
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(18); doc.setFont('helvetica', 'bold');
    doc.text('RELATORIO DE INSPECAO', M, 15);
    doc.setFontSize(9); doc.setFont('helvetica', 'normal');
    doc.text(`Nº ${inspecao.id.substring(0, 8).toUpperCase()}`, PDF_CONFIG.largura - M, 15, { align: 'right' });
    doc.text(`Revisao ${(revisao?.km || 0).toLocaleString('pt-BR')} km · ${revisao?.tipo || ''}`, PDF_CONFIG.largura - M, 20, { align: 'right' });

    let y = 32;

    // --- Bloco: Moto ---
    doc.setTextColor(...PDF_CONFIG.cor_texto);
    doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
    doc.text('MOTOCICLETA', M, y); y += 6;
    doc.setFont('helvetica', 'normal'); doc.setFontSize(9);
    doc.text(`Placa: ${moto.placa}`, M, y);
    doc.text(`Modelo: ${modelo.nome}`, M + 60, y); y += 5;
    doc.text(`Ano: ${moto.ano || '-'}`, M, y);
    doc.text(`Cor: ${moto.cor || '-'}`, M + 60, y); y += 5;
    doc.text(`Chassi: ${moto.chassi || '-'}`, M, y);
    doc.text(`Km: ${(inspecao.km_registrado || 0).toLocaleString('pt-BR')}`, M + 60, y); y += 8;

    // --- Bloco: Proprietario ---
    doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
    doc.text('PROPRIETARIO', M, y); y += 6;
    doc.setFont('helvetica', 'normal'); doc.setFontSize(9);
    doc.text(`Nome: ${moto.proprietario || '-'}`, M, y); y += 5;
    doc.text(`Telefone: ${moto.telefone || '-'}`, M, y);
    doc.text(`E-mail: ${moto.email || '-'}`, M + 60, y); y += 8;

    // --- Bloco: Inspecao ---
    doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
    doc.text('INSPECAO', M, y); y += 6;
    doc.setFont('helvetica', 'normal'); doc.setFontSize(9);
    const dataFmt = new Date(inspecao.data_fim || inspecao.data_inicio).toLocaleString('pt-BR');
    doc.text(`Data: ${dataFmt}`, M, y);
    doc.text(`Mecanico: ${inspecao.mecanico_nome || '-'}`, M + 60, y); y += 5;
    const resumo = `${progresso.total_itens || 0} itens · OK: ${progresso.ok_count || 0} · N-OK: ${progresso.nao_ok_count || 0} · N/A: ${progresso.na_count || 0}`;
    doc.text(resumo, M, y); y += 8;

    // --- Tabela de itens ---
    onp('Gerando tabela de itens...');
    doc.setFillColor(...PDF_CONFIG.cor_secundaria);
    doc.rect(M, y, PDF_CONFIG.largura - 2 * M, 6, 'F');
    doc.setTextColor(255, 255, 255); doc.setFont('helvetica', 'bold'); doc.setFontSize(9);
    doc.text('ITEM', M + 2, y + 4);
    doc.text('STATUS', M + 105, y + 4);
    doc.text('OBS / MEDIDA', M + 128, y + 4);
    y += 8;

    doc.setTextColor(...PDF_CONFIG.cor_texto);
    doc.setFont('helvetica', 'normal'); doc.setFontSize(8);

    let categoriaAtual = null;
    for (const it of itensExecutados) {
        if (y > 250) { doc.addPage(); y = 20; }
        const check = it.itens_checklist;
        if (!check) continue;

        // Divisor de categoria
        if (check.categoria !== categoriaAtual) {
            categoriaAtual = check.categoria;
            doc.setFillColor(240, 240, 240);
            doc.rect(M, y, PDF_CONFIG.largura - 2 * M, 5, 'F');
            doc.setFont('helvetica', 'bold');
            doc.text(check.categoria || '-', M + 2, y + 3.5);
            doc.setFont('helvetica', 'normal');
            y += 6;
        }

        // Descricao do item
        const desc = doc.splitTextToSize(check.descricao || '', 95);
        doc.text(desc, M + 2, y + 3);

        // Status colorido
        const statusMap = {
            ok:     { txt: 'OK',   cor: PDF_CONFIG.cor_verde },
            nao_ok: { txt: 'N-OK', cor: PDF_CONFIG.cor_vermelho },
            na:     { txt: 'N/A',  cor: PDF_CONFIG.cor_cinza }
        };
        const sm = statusMap[it.status] || { txt: '-', cor: PDF_CONFIG.cor_cinza };
        doc.setTextColor(...sm.cor); doc.setFont('helvetica', 'bold');
        doc.text(sm.txt, M + 105, y + 3);
        doc.setTextColor(...PDF_CONFIG.cor_texto); doc.setFont('helvetica', 'normal');

        // Obs/medida
        const info = [];
        if (it.valor_medido) info.push(it.valor_medido);
        if (it.observacao)   info.push(it.observacao);
        if (info.length) {
            const infoTxt = doc.splitTextToSize(info.join(' · '), 65);
            doc.text(infoTxt.slice(0, 2), M + 128, y + 3);
        }

        y += Math.max(5, desc.length * 3);
    }

    // --- Fotos ---
    const itensComFoto = itensExecutados.filter(i => i.foto_url);
    if (itensComFoto.length > 0) {
        onp(`Baixando ${itensComFoto.length} foto(s)...`);
        if (y > 200) { doc.addPage(); y = 20; }
        y += 4;
        doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
        doc.setTextColor(...PDF_CONFIG.cor_texto);
        doc.text('FOTOS', M, y); y += 6;

        let colX = M;
        const w = 42, h = 32, gap = 5;

        for (const item of itensComFoto) {
            if (colX + w > PDF_CONFIG.largura - M) { colX = M; y += h + 12; }
            if (y + h > 270) { doc.addPage(); y = 20; colX = M; }
            try {
                const signed = await window.urlAssinada(item.foto_url, 300);
                if (signed) {
                    const dataUrl = await carregarImagemComoDataUrl(signed);
                    if (dataUrl) {
                        doc.addImage(dataUrl, 'JPEG', colX, y, w, h);
                        doc.setFontSize(6);
                        const legenda = doc.splitTextToSize(item.itens_checklist?.descricao || '', w);
                        doc.text(legenda.slice(0, 2), colX, y + h + 3);
                    }
                }
            } catch (e) { console.warn('Foto falhou:', e); }
            colX += w + gap;
        }
        y += h + 15;
    }

    // --- Observacoes gerais ---
    if (inspecao.observacoes_gerais) {
        if (y > 240) { doc.addPage(); y = 20; }
        doc.setFont('helvetica', 'bold'); doc.setFontSize(10);
        doc.text('OBSERVACOES GERAIS', M, y); y += 5;
        doc.setFont('helvetica', 'normal'); doc.setFontSize(9);
        const obsTxt = doc.splitTextToSize(inspecao.observacoes_gerais, PDF_CONFIG.largura - 2 * M);
        doc.text(obsTxt, M, y);
        y += obsTxt.length * 4 + 5;
    }

    // --- Assinaturas ---
    if (y > 220) { doc.addPage(); y = 20; }
    y = Math.max(y, 220);
    doc.setFont('helvetica', 'bold'); doc.setFontSize(10);
    doc.setTextColor(...PDF_CONFIG.cor_texto);
    doc.text('ASSINATURAS', M, y); y += 5;

    const wAss = 80, hAss = 30;

    // Mecanico
    if (inspecao.assinatura_mecanico) {
        try { doc.addImage(inspecao.assinatura_mecanico, 'PNG', M, y, wAss, hAss); }
        catch(e) { console.warn('assinatura mecanico:', e); }
    }
    doc.setDrawColor(...PDF_CONFIG.cor_cinza);
    doc.line(M, y + hAss + 1, M + wAss, y + hAss + 1);
    doc.setFont('helvetica', 'normal'); doc.setFontSize(8);
    doc.text('Mecanico', M, y + hAss + 5);
    doc.text(inspecao.mecanico_nome || '', M, y + hAss + 9);

    // Cliente
    const xC = PDF_CONFIG.largura - M - wAss;
    if (inspecao.assinatura_cliente) {
        try { doc.addImage(inspecao.assinatura_cliente, 'PNG', xC, y, wAss, hAss); }
        catch(e) { console.warn('assinatura cliente:', e); }
    }
    doc.line(xC, y + hAss + 1, xC + wAss, y + hAss + 1);
    doc.text('Cliente', xC, y + hAss + 5);
    doc.text(inspecao.nome_cliente_assinou || '', xC, y + hAss + 9);

    // --- Hash de integridade ---
    onp('Calculando hash SHA-256...');
    const conteudoParaHash = JSON.stringify({
        id: inspecao.id,
        moto: moto.placa,
        km: inspecao.km_registrado,
        data_fim: inspecao.data_fim,
        mecanico: inspecao.mecanico_nome,
        cliente: inspecao.nome_cliente_assinou,
        itens: itensExecutados.map(i => ({
            id: i.item_id, s: i.status,
            v: i.valor_medido, o: i.observacao
        }))
    });
    const hash = await calcularHashSha256(conteudoParaHash);

    // Footer com hash em todas as paginas
    const nPaginas = doc.internal.getNumberOfPages();
    for (let p = 1; p <= nPaginas; p++) {
        doc.setPage(p);
        doc.setFontSize(6);
        doc.setTextColor(...PDF_CONFIG.cor_claro);
        doc.text(`SHA-256: ${hash}`, M, 289);
        doc.text(`Pagina ${p}/${nPaginas} · Gerado ${new Date().toLocaleString('pt-BR')}`,
                 PDF_CONFIG.largura - M, 289, { align: 'right' });
    }

    onp('Finalizando PDF...');
    const blob = doc.output('blob');
    return { blob, hash };
}

/**
 * Upload do PDF para o Storage Supabase.
 * Atualiza inspecoes.pdf_url e inspecoes.hash_integridade.
 */
async function uploadPdfSupabase(inspecaoId, blob, hash) {
    const path = `${inspecaoId}/relatorio.pdf`;
    const { error: erroUp } = await window.sb.storage
        .from('inspecoes')
        .upload(path, blob, {
            contentType: 'application/pdf',
            upsert: true,
            cacheControl: '3600'
        });
    if (erroUp) throw erroUp;

    const { error: erroDb } = await window.sb
        .from('inspecoes')
        .update({ pdf_url: path, hash_integridade: hash })
        .eq('id', inspecaoId);
    if (erroDb) throw erroDb;

    return path;
}

/**
 * Gera URL assinada temporaria para download do PDF (bucket privado).
 */
async function obterUrlDownloadPdf(path, segundos = 3600) {
    const { data, error } = await window.sb.storage
        .from('inspecoes')
        .createSignedUrl(path, segundos);
    if (error) throw error;
    return data.signedUrl;
}

/**
 * Tenta Web Share API; fallback: copia URL para clipboard.
 */
async function compartilharPdf(url, placa) {
    if (navigator.share) {
        try {
            await navigator.share({
                title: `Inspecao ${placa}`,
                text: `Relatorio de inspecao - moto ${placa}`,
                url: url
            });
            return { compartilhado: true, metodo: 'share' };
        } catch (e) {
            if (e.name === 'AbortError') return { compartilhado: false, metodo: 'cancelado' };
            console.warn('Share falhou:', e);
        }
    }
    // Fallback
    try {
        await navigator.clipboard.writeText(url);
        return { compartilhado: true, metodo: 'clipboard' };
    } catch (e) {
        return { compartilhado: false, metodo: 'erro', url };
    }
}

/**
 * Download local direto do PDF.
 */
function baixarPdf(blob, nomeArquivo) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = nomeArquivo || 'relatorio.pdf';
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
        try { document.body.removeChild(a); } catch(_) {}
        URL.revokeObjectURL(url);
    }, 200);
}

// Exports globais
window.gerarPdfInspecao      = gerarPdfInspecao;
window.uploadPdfSupabase     = uploadPdfSupabase;
window.obterUrlDownloadPdf   = obterUrlDownloadPdf;
window.compartilharPdf       = compartilharPdf;
window.baixarPdf             = baixarPdf;
window.calcularHashSha256    = calcularHashSha256;
