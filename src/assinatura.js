// =====================================================================
// REVISAO-MOTO :: Assinatura - canvas com pointer events
// =====================================================================
// Suporta touch (mobile) e mouse (desktop) via PointerEvent API.
// touch-action: none no CSS impede scroll durante desenho.
// =====================================================================

/**
 * Cria um controlador de assinatura para um canvas.
 * @param {HTMLCanvasElement} canvas
 * @param {Object} opcoes  { cor, espessura, corFundo }
 * @returns { limpar, exportarPng, foiTocado, reinicializar }
 */
function criarAssinatura(canvas, opcoes = {}) {
    const ctx = canvas.getContext('2d');
    const config = {
        cor:      opcoes.cor      || '#000000',
        espessura:opcoes.espessura|| 2.2,
        corFundo: opcoes.corFundo || '#ffffff'
    };
    let desenhando = false;
    let tocado = false;
    let ultimoX = 0;
    let ultimoY = 0;

    function inicializarCanvas() {
        const dpr = window.devicePixelRatio || 1;
        const rect = canvas.getBoundingClientRect();
        canvas.width  = Math.max(1, rect.width  * dpr);
        canvas.height = Math.max(1, rect.height * dpr);
        // Redefine transformacao e aplica DPR
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

        // Fundo branco (para PDF ficar legivel)
        ctx.fillStyle = config.corFundo;
        ctx.fillRect(0, 0, rect.width, rect.height);

        // Traço
        ctx.strokeStyle = config.cor;
        ctx.lineWidth   = config.espessura;
        ctx.lineCap     = 'round';
        ctx.lineJoin    = 'round';
    }

    function posicao(e) {
        const rect = canvas.getBoundingClientRect();
        return { x: e.clientX - rect.left, y: e.clientY - rect.top };
    }

    function onDown(e) {
        e.preventDefault();
        desenhando = true;
        tocado = true;
        const p = posicao(e);
        ultimoX = p.x; ultimoY = p.y;
        try { canvas.setPointerCapture(e.pointerId); } catch(_) {}
    }

    function onMove(e) {
        if (!desenhando) return;
        e.preventDefault();
        const p = posicao(e);
        ctx.beginPath();
        ctx.moveTo(ultimoX, ultimoY);
        ctx.lineTo(p.x, p.y);
        ctx.stroke();
        ultimoX = p.x; ultimoY = p.y;
    }

    function onUp(e) {
        desenhando = false;
        try {
            if (e && e.pointerId !== undefined && canvas.hasPointerCapture(e.pointerId)) {
                canvas.releasePointerCapture(e.pointerId);
            }
        } catch(_) {}
    }

    function limpar() {
        const rect = canvas.getBoundingClientRect();
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        inicializarCanvas();
        tocado = false;
    }

    function foiTocado() {
        return tocado;
    }

    /**
     * Retorna assinatura como data URL base64 PNG.
     */
    function exportarPng() {
        return canvas.toDataURL('image/png');
    }

    // Registra listeners
    canvas.addEventListener('pointerdown',   onDown);
    canvas.addEventListener('pointermove',   onMove);
    canvas.addEventListener('pointerup',     onUp);
    canvas.addEventListener('pointercancel', onUp);
    canvas.addEventListener('pointerleave',  onUp);

    // Impede scroll durante desenho em mobile
    canvas.style.touchAction = 'none';

    // Reinicializa em resize (canvas perde contexto ao redimensionar)
    window.addEventListener('resize', () => setTimeout(inicializarCanvas, 100));

    inicializarCanvas();

    return {
        limpar,
        exportarPng,
        foiTocado,
        reinicializar: inicializarCanvas
    };
}

// Export global
window.criarAssinatura = criarAssinatura;
