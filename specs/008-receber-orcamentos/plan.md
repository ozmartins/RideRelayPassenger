# Implementation Plan: Receber, persistir e decidir entre orçamentos

**Branch**: `008-receber-orcamentos` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

## Summary

O passageiro passa a se inscrever em `kind: 20002`. Um orçamento recebido referenciando a
solicitação ativa é decodificado (`ReceivedQuote`), persistido via `sqflite` (nova dependência) e
adicionado a uma lista observável que alimenta uma modal (`RideQuotesModal`) — aberta no primeiro
orçamento, atualizada nos seguintes. "Aceitar" publica `kind: 20003` para o motorista escolhido e
`kind: 20004` para cada um dos demais já recebidos (emenda 07 do contrato, já escrita e replicada
no motorista).

## Technical Context

**Language/Version**: Dart 3.x / Flutter (sem mudança)

**Primary Dependencies**: `sqflite` (nova — D1 de `research.md`, mesma biblioteca já usada pelo
motorista desde a feature 003 dele)

**Storage**: SQLite via `sqflite`, tabela `received_quotes` (D2 de `research.md`)

**Testing**: `flutter_test`; dublê de `ReceivedQuoteStore` em memória (Princípio II por analogia);
`EventFeed` testado com payloads assinados de verdade, como já é o padrão deste app

**Target Platform**: Android

**Project Type**: mobile-app (Flutter), único projeto

**Performance Goals**: modal atualizada em até 1 s após a persistência (SC-001)

**Constraints**: um orçamento fora da solicitação ativa MUST NOT ser persistido nem exibido
(FR-003); aceitar MUST publicar exatamente uma aceitação e uma recusa por orçamento concorrente
(FR-008, FR-009, SC-003); depois de aceito, nenhum orçamento novo da mesma solicitação reabre a
modal (FR-012)

**Scale/Scope**: uma solicitação ativa por vez nesta sessão do app (Assumptions do `spec.md`)

## Constitution Check

Avaliação contra `.specify/memory/constitution.md` v2.4.0:

| Princípio / Restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | N/A — não toca a chave privada de forma diferente do já existente `publishRideRequest`. |
| II. Assinatura e verificação nascem com teste | **Aplica-se.** A recepção do `kind: 20002` (já verificada pelo `EventFeed` existente) e as novas publicações (`publishQuoteAcceptance`/`publishQuoteRejection`) MUST ter teste cobrindo caso válido — cumprido em tasks.md. |
| III. Dependência de terceiros exige decisão registrada | **Aplica-se.** `sqflite` é dependência nova. Decisão registrada em `research.md` D1. **PASS.** |
| IV. O contrato de evento vem antes do código | **Aplica-se.** Emenda 07 (kinds 20003/20004) já escrita e replicada no motorista antes desta implementação. **PASS.** |
| V. Simplicidade proporcional | **Aplica-se.** D3/D4 de `research.md` (lista observável simples, sem deduplicar por motorista) registram as decisões e alternativas descartadas. **PASS.** |
| Restrições de Segurança e Privacidade | N/A — `sqflite` é armazenamento local, sem chamada a serviço de terceiros; nenhuma exceção de roteamento/geocodificação envolvida. |

**Resultado**: PASS.

## Project Structure

```text
lib/
├── domain/
│   ├── nostr_event.dart          # alterado — ganha `tags`
│   └── received_quote.dart       # novo — Entidade "Orçamento recebido"
├── services/
│   ├── event_feed.dart           # alterado — acceptedKinds configurável, publishQuoteAcceptance/Rejection
│   └── received_quote_store.dart # novo — abstração + SqfliteReceivedQuoteStore
├── screens/
│   ├── ride_quotes_modal.dart    # novo
│   └── map_screen.dart           # alterado — rastreia solicitação ativa, persiste orçamentos, abre/atualiza a modal
└── main.dart                      # alterado — acceptedKinds ganha 20002; injeta ReceivedQuoteStore

test/
├── domain/received_quote_test.dart
├── services/
│   ├── event_feed_test.dart        # alterado
│   └── received_quote_store_test.dart
└── screens/
    ├── ride_quotes_modal_test.dart
    └── map_screen_test.dart        # alterado
```

**Structure Decision**: segue o layout existente. `ReceivedQuoteStore` segue o mesmo padrão de
abstração + implementação real confinada de `CadastroStore`/`SqfliteCadastroStore` do motorista
(Princípio III).
