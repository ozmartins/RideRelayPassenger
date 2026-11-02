# Quickstart: Nome do Usuário no Passageiro

Guia para validar manualmente, em aparelho ou emulador, que a feature funciona ponta a ponta.
Referências: [spec.md](./spec.md) (cenários de aceitação), [data-model.md](./data-model.md).

## Pré-requisitos

- Emulador ou aparelho Android disponível (`flutter emulators --launch Pixel_6_API34_1`, ou
  aparelho físico com depuração USB habilitada).
- App do passageiro sem dados previamente instalados, para testar a primeira execução:
  `adb uninstall br.ufsc.tcc.corridas.passenger` (ignorar erro se não estiver instalado), ou usar
  um emulador limpo.

## Cenário 1 — Primeira execução pede o nome (US1)

1. Instalar e abrir o app pela primeira vez: `flutter run` (de dentro de `passenger/`).
2. **Esperado**: a tela de solicitação de nome aparece antes de qualquer tela principal (SC-001).
3. Tentar confirmar sem digitar nada (ou só com espaços).
   **Esperado**: o app impede a confirmação e indica que o nome é obrigatório (cenário 3 do
   spec).
4. Digitar um nome válido (ex.: "Maria") e confirmar.
   **Esperado**: a tela principal do app é exibida em seguida (cenário 2 do spec; SC-002 — fluxo
   completo em menos de 15s).
5. Fechar o app completamente (não apenas minimizar) e reabrir.
   **Esperado**: a tela de solicitação de nome NÃO aparece de novo; o app vai direto à tela
   principal (FR-001, FR-009, SC-003).

## Cenário 2 — Alterar o nome já salvo (US2)

1. Com um nome já salvo (cenário 1 concluído), na tela principal, localizar e abrir a tela de
   alteração de nome.
   **Esperado**: acessível em no máximo 2 toques a partir da tela principal (SC-004).
2. **Esperado**: o campo já aparece preenchido com o nome atual (cenário 1 de US2).
3. Apagar o campo e tentar salvar.
   **Esperado**: o app impede o salvamento e indica que o nome é obrigatório (cenário 3 de US2).
4. Digitar um nome diferente e válido, salvar.
   **Esperado**: a tela retorna e o novo nome passa a ser o nome salvo (cenário 2 de US2).
5. Fechar e reabrir o app.
   **Esperado**: o novo nome persiste (FR-009, SC-003).
6. Abrir a tela de alteração de nome novamente, mudar o texto, mas sair sem salvar (voltar).
   **Esperado**: o nome anteriormente salvo permanece inalterado (cenário 4 de US2, FR-008).

## Cenário 3 — Edge case: interrupção antes de confirmar (primeira execução)

1. Com o app sem nome salvo, abrir a tela de solicitação de nome, digitar algo mas encerrar o
   app pelo sistema (ex.: removê-lo da lista de apps recentes) antes de confirmar.
2. Reabrir o app.
   **Esperado**: a tela de solicitação de nome aparece novamente — nenhum nome foi salvo.

## Verificação de não vazamento (Princípio I)

Não aplicável a esta feature: o nome não é material criptográfico, não é gerado a partir da
identidade Nostr e não interage com o armazenamento protegido (`flutter_secure_storage`). A
verificação de não vazamento do Princípio I continua coberta pelas features que tocam a
identidade (`IdentityService`), inalteradas por esta feature.

## Registro de resultados

Ao executar este quickstart, relatar no relatório de implementação (ou em commit) quais cenários
passaram e, se algum falhar, o que exatamente aconteceu — Princípio V exige que resultados
relatados como medição tenham sido medidos de fato, nunca estimados ou omitidos.
