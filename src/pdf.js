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

    // --- Fase 8: itens avulsos (item_id NULL) ---
    const { data: avulsos } = await window.sb
        .from('inspecoes_itens')
        .select('*')
        .eq('inspecao_id', inspecaoId)
        .is('item_id', null)
        .order('id');

    // --- Fase 8: orcamento (pecas + servicos + totais) ---
    const { data: pecas } = await window.sb
        .from('inspecao_pecas')
        .select('*, pecas(codigo_re, descricao)')
        .eq('inspecao_id', inspecaoId)
        .order('id');

    const { data: servicos } = await window.sb
        .from('inspecao_servicos')
        .select('*')
        .eq('inspecao_id', inspecaoId)
        .order('id');

    const { data: totais } = await window.sb
        .from('vw_orcamento_inspecao')
        .select('*')
        .eq('inspecao_id', inspecaoId)
        .single();

    // --- Fase 9: vistoria de entrada ---
    const { data: recebimentos } = await window.sb
        .from('vw_recebimentos')
        .select('*')
        .eq('inspecao_id', inspecaoId)
        .limit(1);

    // --- Fase 9: recomendacoes futuras congeladas ---
    const { data: recomendacoes } = await window.sb
        .from('recomendacoes')
        .select('*')
        .eq('inspecao_id', inspecaoId)
        .order('prioridade');

    return {
        inspecao,
        itensExecutados: ordenados,
        progresso: progresso || {},
        avulsos: avulsos || [],
        pecas: pecas || [],
        servicos: servicos || [],
        totais: totais || null,
        recebimento: (recebimentos && recebimentos.length) ? recebimentos[0] : null,
        recomendacoes: recomendacoes || []
    };
}

/**
 * Gera o PDF completo da inspecao.
 * Retorna { blob, hash }.
 */
async function gerarPdfInspecao(inspecaoId, callbacks = {}) {
    const { onProgresso } = callbacks;
    const onp = (msg) => { if (onProgresso) onProgresso(msg); };

    onp('Coletando dados...');
    const { inspecao, itensExecutados, progresso, avulsos, pecas, servicos, totais,
            recebimento, recomendacoes } = await coletarDadosInspecao(inspecaoId);
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
    doc.text(`OS ${inspecao.numero_os || inspecao.id.substring(0, 8).toUpperCase()}`, PDF_CONFIG.largura - M, 15, { align: 'right' });
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

    // --- Fase 9: Bloco VISTORIA DE ENTRADA ---
    if (recebimento) {
        if (y > 225) { doc.addPage(); y = 20; }

        doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
        doc.setTextColor(...PDF_CONFIG.cor_texto);
        doc.text('VISTORIA DE ENTRADA', M, y); y += 6;

        doc.setFont('helvetica', 'normal'); doc.setFontSize(9);
        const dataRec = recebimento.recebido_em
            ? new Date(recebimento.recebido_em).toLocaleString('pt-BR') : '-';
        doc.text(`Recebida em: ${dataRec}`, M, y);
        doc.text(`Km entrada: ${(recebimento.km_entrada || 0).toLocaleString('pt-BR')}`, M + 90, y);
        y += 5;

        doc.text(`Combustivel: ${recebimento.combustivel_texto || '-'}`, M, y);
        doc.text(`Fotos: ${recebimento.fotos_tiradas || 0}/4`, M + 90, y);
        y += 5;

        const acess = [];
        if (recebimento.tem_bau)        acess.push('bau');
        if (recebimento.tem_capacete)   acess.push('capacete');
        if (recebimento.tem_documentos) acess.push('documentos');
        if (recebimento.outros_acessorios) acess.push(recebimento.outros_acessorios);
        doc.text(`Acessorios: ${acess.length ? acess.join(', ') : 'nenhum'}`, M, y);
        y += 5;

        if (recebimento.avarias_texto) {
            doc.setFont('helvetica', 'bold');
            doc.text('Avarias na entrada:', M, y); y += 4;
            doc.setFont('helvetica', 'normal');
            const la = doc.splitTextToSize(recebimento.avarias_texto, PDF_CONFIG.largura - 2 * M - 4);
            doc.text(la, M, y);
            y += la.length * 4;
        }

        if (recebimento.tem_assinatura) {
            doc.setTextColor(...PDF_CONFIG.cor_verde);
            doc.text(`Estado de entrada conferido e assinado por ${recebimento.nome_cliente || '-'}`, M, y);
            doc.setTextColor(...PDF_CONFIG.cor_texto);
            y += 5;
        }
        y += 4;
    }

    // --- Fase 8: Bloco RELATO DO CLIENTE (antes do checklist) ---
    if (inspecao.queixa_cliente || inspecao.resolucao_queixa) {
        if (y > 230) { doc.addPage(); y = 20; }

        doc.setFillColor(254, 243, 199);                 // amarelo claro
        const alturaBloco = inspecao.resolucao_queixa ? 30 : 18;
        doc.rect(M, y - 4, PDF_CONFIG.largura - 2 * M, alturaBloco, 'F');

        doc.setTextColor(...PDF_CONFIG.cor_texto);
        doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
        doc.text('RELATO DO CLIENTE', M + 2, y + 1); y += 6;

        doc.setFont('helvetica', 'normal'); doc.setFontSize(9);
        if (inspecao.queixa_cliente) {
            const linhas = doc.splitTextToSize(inspecao.queixa_cliente, PDF_CONFIG.largura - 2 * M - 6);
            doc.text(linhas, M + 2, y);
            y += linhas.length * 4 + 3;
        }

        if (inspecao.resolucao_queixa) {
            doc.setFont('helvetica', 'bold'); doc.setFontSize(9);
            doc.text('Resolucao:', M + 2, y); y += 4;
            doc.setFont('helvetica', 'normal');
            const linhasR = doc.splitTextToSize(inspecao.resolucao_queixa, PDF_CONFIG.largura - 2 * M - 6);
            doc.text(linhasR, M + 2, y);
            y += linhasR.length * 4 + 3;
        }
        y += 5;
    }

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

    // --- Fase 8: ITENS ADICIONAIS (achados fora do checklist) ---
    if (avulsos && avulsos.length > 0) {
        if (y > 235) { doc.addPage(); y = 20; }
        y += 4;

        doc.setFillColor(...PDF_CONFIG.cor_secundaria);
        doc.rect(M, y, PDF_CONFIG.largura - 2 * M, 6, 'F');
        doc.setTextColor(255, 255, 255); doc.setFont('helvetica', 'bold'); doc.setFontSize(9);
        doc.text('ITENS ADICIONAIS (fora do checklist padrao)', M + 2, y + 4);
        y += 8;

        doc.setTextColor(...PDF_CONFIG.cor_texto);
        doc.setFont('helvetica', 'normal'); doc.setFontSize(8);

        const statusMapA = {
            ok:     { txt: 'OK',   cor: PDF_CONFIG.cor_verde },
            nao_ok: { txt: 'N-OK', cor: PDF_CONFIG.cor_vermelho },
            na:     { txt: 'N/A',  cor: PDF_CONFIG.cor_cinza }
        };

        for (const av of avulsos) {
            if (y > 255) { doc.addPage(); y = 20; }
            const d = doc.splitTextToSize(av.descricao_avulsa || '-', 95);
            doc.text(d, M + 2, y + 3);

            const sa = statusMapA[av.status] || { txt: '-', cor: PDF_CONFIG.cor_cinza };
            doc.setTextColor(...sa.cor); doc.setFont('helvetica', 'bold');
            doc.text(sa.txt, M + 105, y + 3);
            doc.setTextColor(...PDF_CONFIG.cor_texto); doc.setFont('helvetica', 'normal');

            if (av.observacao) {
                const o = doc.splitTextToSize(av.observacao, 65);
                doc.text(o.slice(0, 2), M + 128, y + 3);
            }
            y += Math.max(5, d.length * 3);
        }
        y += 3;
    }

    // --- Fase 8: ORCAMENTO ---
    const temOrcamento = (pecas && pecas.length > 0) || (servicos && servicos.length > 0);
    if (temOrcamento) {
        if (y > 210) { doc.addPage(); y = 20; }
        y += 4;

        doc.setFillColor(...PDF_CONFIG.cor_secundaria);
        doc.rect(M, y, PDF_CONFIG.largura - 2 * M, 6, 'F');
        doc.setTextColor(255, 255, 255); doc.setFont('helvetica', 'bold'); doc.setFontSize(9);
        doc.text('ORCAMENTO', M + 2, y + 4);
        doc.text('QTD', M + 110, y + 4);
        doc.text('UNIT.', M + 130, y + 4);
        doc.text('TOTAL', PDF_CONFIG.largura - M - 2, y + 4, { align: 'right' });
        y += 8;

        doc.setTextColor(...PDF_CONFIG.cor_texto);
        doc.setFont('helvetica', 'normal'); doc.setFontSize(8);

        const brl = (v) => (Number(v) || 0).toLocaleString('pt-BR',
            { style: 'currency', currency: 'BRL' });

        // Pecas
        if (pecas && pecas.length > 0) {
            doc.setFillColor(240, 240, 240);
            doc.rect(M, y, PDF_CONFIG.largura - 2 * M, 5, 'F');
            doc.setFont('helvetica', 'bold');
            doc.text('Pecas', M + 2, y + 3.5);
            doc.setFont('helvetica', 'normal');
            y += 6;

            for (const pc of pecas) {
                if (y > 255) { doc.addPage(); y = 20; }
                const nome = pc.pecas
                    ? `${pc.pecas.codigo_re ? pc.pecas.codigo_re + ' - ' : ''}${pc.pecas.descricao}`
                    : (pc.descricao_livre || '-');
                const nomeTxt = doc.splitTextToSize(nome, 100);
                doc.text(nomeTxt.slice(0, 1), M + 2, y + 3);
                doc.text(String(Number(pc.quantidade) || 0), M + 110, y + 3);
                doc.text(brl(pc.preco_aplicado), M + 130, y + 3);
                doc.text(brl((pc.quantidade || 0) * (pc.preco_aplicado || 0)),
                         PDF_CONFIG.largura - M - 2, y + 3, { align: 'right' });
                y += 5;
            }
        }

        // Servicos
        if (servicos && servicos.length > 0) {
            if (y > 250) { doc.addPage(); y = 20; }
            doc.setFillColor(240, 240, 240);
            doc.rect(M, y, PDF_CONFIG.largura - 2 * M, 5, 'F');
            doc.setFont('helvetica', 'bold');
            doc.text('Mao de obra', M + 2, y + 3.5);
            doc.setFont('helvetica', 'normal');
            y += 6;

            for (const sv of servicos) {
                if (y > 255) { doc.addPage(); y = 20; }
                const dTxt = doc.splitTextToSize(sv.descricao || '-', 100);
                doc.text(dTxt.slice(0, 1), M + 2, y + 3);
                doc.text(`${Number(sv.horas) || 0}h`, M + 110, y + 3);
                doc.text(brl(sv.valor_hora), M + 130, y + 3);
                doc.text(brl((sv.horas || 0) * (sv.valor_hora || 0)),
                         PDF_CONFIG.largura - M - 2, y + 3, { align: 'right' });
                y += 5;
            }
        }

        // Total
        if (y > 250) { doc.addPage(); y = 20; }
        y += 2;
        doc.setDrawColor(...PDF_CONFIG.cor_secundaria);
        doc.setLineWidth(0.4);
        doc.line(M, y, PDF_CONFIG.largura - M, y);
        y += 5;

        const tot = totais || { total_pecas: 0, total_servicos: 0, total_geral: 0 };
        doc.setFontSize(9);
        doc.text(`Pecas: ${brl(tot.total_pecas)}`, M + 2, y);
        doc.text(`Mao de obra: ${brl(tot.total_servicos)}`, M + 55, y);
        doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
        doc.text(`TOTAL: ${brl(tot.total_geral)}`,
                 PDF_CONFIG.largura - M - 2, y, { align: 'right' });
        doc.setFont('helvetica', 'normal'); doc.setFontSize(8);
        y += 7;

        // Aprovacao previa (CDC art. 40)
        if (tot.orcamento_aprovado) {
            doc.setTextColor(...PDF_CONFIG.cor_verde);
            const dataAp = tot.orcamento_aprovado_em
                ? new Date(tot.orcamento_aprovado_em).toLocaleString('pt-BR') : '';
            doc.text(`Orcamento aprovado por ${tot.nome_aprovador_orcamento || '-'} em ${dataAp}`,
                     M + 2, y);
        } else {
            doc.setTextColor(...PDF_CONFIG.cor_vermelho);
            doc.text('Orcamento NAO aprovado pelo cliente', M + 2, y);
        }
        doc.setTextColor(...PDF_CONFIG.cor_texto);
        y += 6;
    }

    // --- Fase 9: RECOMENDACOES FUTURAS ---
    if (recomendacoes && recomendacoes.length > 0) {
        if (y > 225) { doc.addPage(); y = 20; }
        y += 4;

        doc.setFillColor(219, 234, 254);                 // azul claro
        const alt = 10 + recomendacoes.length * 6;
        doc.rect(M, y - 4, PDF_CONFIG.largura - 2 * M, alt, 'F');

        doc.setTextColor(...PDF_CONFIG.cor_texto);
        doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
        doc.text('RECOMENDACOES PARA A PROXIMA REVISAO', M + 2, y + 1); y += 7;

        doc.setFont('helvetica', 'normal'); doc.setFontSize(8);
        for (const rc of recomendacoes) {
            if (y > 262) { doc.addPage(); y = 20; }
            const urgente = rc.prioridade === 'urgente';

            doc.setTextColor(...(urgente ? PDF_CONFIG.cor_vermelho : PDF_CONFIG.cor_texto));
            doc.setFont('helvetica', urgente ? 'bold' : 'normal');

            let txt = `${urgente ? '[URGENTE] ' : ''}${rc.descricao}`;
            if (rc.medicao_atual != null) {
                txt += ` - medido ${rc.medicao_atual} ${rc.unidade || ''}`;
            }
            if (rc.previsao_km) {
                txt += ` - trocar por volta de ${Number(rc.previsao_km).toLocaleString('pt-BR')} km`;
            }
            const lt = doc.splitTextToSize(txt, PDF_CONFIG.largura - 2 * M - 6);
            doc.text(lt.slice(0, 2), M + 2, y + 2);
            y += Math.max(5, lt.slice(0, 2).length * 4);
        }
        doc.setTextColor(...PDF_CONFIG.cor_texto);
        doc.setFont('helvetica', 'normal');
        y += 5;
    }

    // --- Fotos ---
    const itensComFoto = itensExecutados.filter(i => i.foto_url || i.foto_antes_url || i.foto_depois_url);
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
