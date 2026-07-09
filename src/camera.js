// =====================================================================
// REVISAO-MOTO :: Camera - captura, compressao e upload de fotos
// =====================================================================
// Estrategia: input file com capture=environment (funciona em qualquer
// celular sem precisar getUserMedia + permissoes complicadas).
// Comprime no navegador antes de upload para respeitar limite do bucket.
// =====================================================================

const CAMERA_CONFIG = {
    max_width: 1600,           // px (largura maxima apos compressao)
    quality: 0.75,             // 0-1 (jpeg quality)
    tamanho_max_kb: 800,       // ideal manter abaixo disso
    bucket: 'inspecoes'
};

/**
 * Abre input file oculto para captura de foto pela camera do celular.
 * Retorna Promise com o File selecionado, ou null se cancelou.
 */
function capturarFoto() {
    return new Promise((resolve) => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.capture = 'environment';  // camera traseira em mobile
        input.style.display = 'none';
        document.body.appendChild(input);

        // Detecta cancelamento (nem sempre confiavel entre navegadores)
        let resolvido = false;
        const finalizar = (valor) => {
            if (resolvido) return;
            resolvido = true;
            document.body.removeChild(input);
            resolve(valor);
        };

        input.addEventListener('change', () => {
            const arquivo = input.files && input.files[0];
            finalizar(arquivo || null);
        });

        // Fallback: se o foco voltar a janela sem selecao apos 30s, cancela
        setTimeout(() => finalizar(null), 5 * 60 * 1000);

        input.click();
    });
}

/**
 * Comprime imagem via canvas.
 * Retorna Promise<Blob> em image/jpeg.
 */
function comprimirImagem(file, maxWidth = CAMERA_CONFIG.max_width, quality = CAMERA_CONFIG.quality) {
    return new Promise((resolve, reject) => {
        const url = URL.createObjectURL(file);
        const img = new Image();
        img.onload = () => {
            try {
                const escala = Math.min(1, maxWidth / img.width);
                const w = Math.round(img.width * escala);
                const h = Math.round(img.height * escala);
                const canvas = document.createElement('canvas');
                canvas.width = w;
                canvas.height = h;
                const ctx = canvas.getContext('2d');
                ctx.fillStyle = '#ffffff';
                ctx.fillRect(0, 0, w, h);
                ctx.drawImage(img, 0, 0, w, h);
                canvas.toBlob((blob) => {
                    URL.revokeObjectURL(url);
                    if (blob) resolve(blob);
                    else reject(new Error('Falha na compressao'));
                }, 'image/jpeg', quality);
            } catch (e) {
                URL.revokeObjectURL(url);
                reject(e);
            }
        };
        img.onerror = () => {
            URL.revokeObjectURL(url);
            reject(new Error('Falha ao carregar imagem'));
        };
        img.src = url;
    });
}

/**
 * Faz upload da foto para o Supabase Storage no bucket 'inspecoes'.
 * Path: {inspecao_id}/{item_id}.jpg
 * Retorna Promise<{path, publicUrl}>
 */
async function uploadFotoSupabase(inspecaoId, itemId, blob) {
    if (!window.sb) throw new Error('Cliente Supabase nao inicializado');

    const path = `${inspecaoId}/${itemId}.jpg`;
    const { error } = await window.sb.storage
        .from(CAMERA_CONFIG.bucket)
        .upload(path, blob, {
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600'
        });

    if (error) throw error;

    return { path, publicUrl: null };  // bucket eh privado, usar getSignedUrl
}

/**
 * Gera URL assinada temporaria para exibir foto do bucket privado.
 */
async function urlAssinada(path, segundos = 3600) {
    if (!window.sb || !path) return null;
    const { data, error } = await window.sb.storage
        .from(CAMERA_CONFIG.bucket)
        .createSignedUrl(path, segundos);
    if (error) {
        console.warn('Falha ao gerar URL assinada:', error);
        return null;
    }
    return data.signedUrl;
}

/**
 * Fluxo completo: captura, comprime, sobe e retorna path salvo.
 * Chamar dentro de handler de clique no botao "Tirar foto".
 */
async function tirarFoto(inspecaoId, itemId, callbacks = {}) {
    const { onIniciando, onCapturando, onComprimindo, onEnviando, onSucesso, onErro } = callbacks;
    try {
        if (onCapturando) onCapturando();
        const arquivo = await capturarFoto();
        if (!arquivo) return null;  // cancelou

        if (onComprimindo) onComprimindo();
        const blobComprimido = await comprimirImagem(arquivo);
        const kb = Math.round(blobComprimido.size / 1024);
        console.log(`Foto comprimida: ${arquivo.size / 1024 | 0}KB -> ${kb}KB`);

        if (onEnviando) onEnviando(kb);
        const { path } = await uploadFotoSupabase(inspecaoId, itemId, blobComprimido);

        if (onSucesso) onSucesso(path, kb);
        return path;
    } catch (e) {
        console.error('Erro ao tirar foto:', e);
        if (onErro) onErro(e);
        return null;
    }
}

// Exports globais
window.capturarFoto = capturarFoto;
window.comprimirImagem = comprimirImagem;
window.uploadFotoSupabase = uploadFotoSupabase;
window.urlAssinada = urlAssinada;
window.tirarFoto = tirarFoto;
