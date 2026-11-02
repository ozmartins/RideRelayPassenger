# Quickstart — Receber, persistir e decidir entre orçamentos

Pressupõe o app do motorista rodando em outro aparelho/emulador, com a feature 007+009 dele
funcionando, e um relay em comum.

## Cenários

1. Solicitar uma corrida (feature 006). No motorista, enviar um orçamento para ela. **Esperado**:
   modal aparece no passageiro com nome, marca/modelo/ano, preço e tempo estimado do motorista.
2. Enviar um segundo orçamento (de outro motorista/aparelho) para a mesma solicitação. **Esperado**:
   a modal passa a mostrar os dois, sem substituir o primeiro.
3. Reiniciar o app do passageiro depois do cenário 1 (antes de aceitar). **Esperado**: o orçamento
   persistido continua no banco (inspecionável, não há requisito de reabrir a modal automaticamente).
4. Com dois orçamentos na modal, tocar "Aceitar" em um deles. **Esperado**: modal fecha; no
   motorista aceito, inspecionar publicação (`kind: 20003`); no outro motorista, `kind: 20004`.
5. Sem relay conectado, tocar "Aceitar". **Esperado**: mensagem informando que não foi enviado;
   modal continua aberta.

## Verificação automatizada

```bash
flutter analyze
flutter test
```
