-- =====================================================================
-- REVISAO-MOTO :: Seed de motos de demonstracao
-- =====================================================================
-- OPCIONAL: insere 5 motos de exemplo para testar a UI da Fase 2.
-- Nao rode em producao - sao dados ficticios.
-- =====================================================================

INSERT INTO motos (placa, chassi, renavam, modelo_id, ano, cor, proprietario, telefone, email, data_compra, km_atual, observacoes)
SELECT 'ABC-1234', 'ME3U3CXAAPMX12345', '12345678901', m.id, 2024, 'Vermelho', 'Mario Cezar dos Santos Junior', '(27) 99999-0001', 'mario.cezar@ifes.edu.br', '2024-06-15', 8500, 'Moto principal - Shotgun do prof. Mario' FROM modelos m WHERE m.nome = 'Shotgun 650'
ON CONFLICT (placa) DO NOTHING;

INSERT INTO motos (placa, chassi, renavam, modelo_id, ano, cor, proprietario, telefone, email, data_compra, km_atual, observacoes)
SELECT 'DEF-5678', 'ME3U3CXAAPMX67890', '23456789012', m.id, 2023, 'Preto', 'Joao da Silva', '(27) 98888-0002', 'joao@exemplo.com', '2023-03-10', 22000, 'Cliente regular' FROM modelos m WHERE m.nome = 'Classic 350'
ON CONFLICT (placa) DO NOTHING;

INSERT INTO motos (placa, chassi, renavam, modelo_id, ano, cor, proprietario, telefone, email, data_compra, km_atual, observacoes)
SELECT 'GHI-9012', 'ME3U3CXAAPMX11111', '34567890123', m.id, 2025, 'Azul', 'Pedro Souza', '(27) 97777-0003', 'pedro@exemplo.com', '2025-01-20', 1200, 'Acabou de comprar - 1a revisao em breve' FROM modelos m WHERE m.nome = 'Interceptor 650'
ON CONFLICT (placa) DO NOTHING;

INSERT INTO motos (placa, chassi, renavam, modelo_id, ano, cor, proprietario, telefone, email, data_compra, km_atual, observacoes)
SELECT 'JKL-3456', 'ME3U3CXAAPMX22222', '45678901234', m.id, 2022, 'Verde', 'Maria Oliveira', '(27) 96666-0004', 'maria@exemplo.com', '2022-11-05', 45000, 'Off-road frequente' FROM modelos m WHERE m.nome = 'Himalayan 450'
ON CONFLICT (placa) DO NOTHING;

INSERT INTO motos (placa, chassi, renavam, modelo_id, ano, cor, proprietario, telefone, email, data_compra, km_atual, observacoes)
SELECT 'MNO-7890', 'ME3U3CXAAPMX33333', '56789012345', m.id, 2024, 'Cinza', 'Carlos Mendes', '(27) 95555-0005', 'carlos@exemplo.com', '2024-08-20', 12000, NULL FROM modelos m WHERE m.nome = 'Hunter 350'
ON CONFLICT (placa) DO NOTHING;
