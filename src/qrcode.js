// =====================================================================
// REVISAO-MOTO :: QR Code - gerador e scanner
// =====================================================================
// Gerador: usa qrcode-generator (biblioteca leve, disponivel via CDN)
// Scanner: usa BarcodeDetector nativo (Chrome mobile) com fallback getUserMedia
// =====================================================================

// ================================================================
// GERADOR
// ================================================================
/**
 * Gera QR Code para uma placa. Ao ser escaneado, abre inspecao.html?placa=XXX
 * Retorna elemento <canvas> com QR.
 */
function gerarQrParaPlaca(placa, tamanho = 256) {
    const url = urlInspecaoPorPlaca(placa);
    return gerarQr(url, tamanho);
}

function urlInspecaoPorPlaca(placa) {
    const base = location.origin + location.pathname.replace(/[^/]*$/, '');
    return `${base}inspecao.html?placa=${encodeURIComponent(placa)}`;
}

/**
 * Gera QR Code SVG a partir de qualquer texto.
 * Usa qrcode-generator (leve, sem dependencias).
 */
function gerarQr(texto, tamanho = 256) {
    if (typeof qrcode === 'undefined') {
        console.error('qrcode-generator nao carregado (adicione o CDN no HTML)');
        return null;
    }
    // Tipo 4 (33x33), correcao L (basica) - suporta URLs curtas
    const qr = qrcode(0, 'M');
    qr.addData(texto);
    qr.make();
    // Retorna string SVG que pode ser inserida no HTML
    return qr.createSvgTag({
        cellSize: Math.max(2, Math.floor(tamanho / qr.getModuleCount())),
        margin: 2,
        scalable: true
    });
}

// ================================================================
// SCANNER
// ================================================================
let streamAtivo = null;
let scannerRodando = false;

/**
 * Inicia scanner de QR usando a camera traseira.
 * @param {HTMLVideoElement} videoEl - elemento <video> onde a camera vai ser exibida
 * @param {Function} onResultado - callback(texto_decodificado) quando ler QR
 * @param {Function} onErro - callback(erro) em falhas
 */
async function iniciarScanner(videoEl, onResultado, onErro) {
    if (scannerRodando) return;

    try {
        streamAtivo = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: { ideal: 'environment' } }
        });
        videoEl.srcObject = streamAtivo;
        videoEl.setAttribute('playsinline', 'true');
        await videoEl.play();
    } catch (e) {
        onErro && onErro(e);
        return;
    }

    scannerRodando = true;

    // Preferencia: BarcodeDetector nativo (Chrome Android)
    if ('BarcodeDetector' in window) {
        const detector = new BarcodeDetector({ formats: ['qr_code'] });
        loopBarcodeDetector(videoEl, detector, onResultado);
    } else {
        // Fallback: informar usuario que precisa de outro navegador
        onErro && onErro(new Error('BarcodeDetector nao suportado - use Chrome Android'));
    }
}

async function loopBarcodeDetector(videoEl, detector, onResultado) {
    while (scannerRodando) {
        try {
            const codigos = await detector.detect(videoEl);
            if (codigos.length > 0) {
                pararScanner();
                onResultado(codigos[0].rawValue);
                return;
            }
        } catch (_) { /* continua */ }
        await new Promise(r => setTimeout(r, 200));
    }
}

function pararScanner() {
    scannerRodando = false;
    if (streamAtivo) {
        streamAtivo.getTracks().forEach(t => t.stop());
        streamAtivo = null;
    }
}

/**
 * Extrai a placa do resultado do scan (se for URL da inspecao).
 */
function extrairPlacaDoQr(texto) {
    if (!texto) return null;
    // URL do proprio app: ...inspecao.html?placa=XXX
    try {
        const url = new URL(texto);
        const placa = url.searchParams.get('placa');
        if (placa) return placa.toUpperCase();
    } catch (_) { /* nao eh URL */ }
    // Ou o proprio conteudo eh a placa
    if (/^[A-Z0-9-]{4,10}$/i.test(texto.trim())) return texto.trim().toUpperCase();
    return null;
}

// ================================================================
// EXPORTS
// ================================================================
window.qrMoto = {
    gerarQr,
    gerarQrParaPlaca,
    urlInspecaoPorPlaca,
    iniciarScanner,
    pararScanner,
    extrairPlacaDoQr
};
