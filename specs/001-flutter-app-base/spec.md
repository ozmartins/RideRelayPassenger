# Feature Specification: Base do Aplicativo do Passageiro

**Feature Branch**: `001-flutter-app-base`

**Created**: 2026-09-15

**Status**: Draft

**Input**: User description: "Crie um app mobile vazio usando Flutter."

## Clarifications

### Session 2026-09-15

- Q: Qual o escopo de plataformas que o app base deve suportar/validar nesta etapa? → A: Android apenas
- Q: Qual identificador de aplicativo e nome de exibição usar para o app do passageiro? → A: `br.ufsc.tcc.caronas.passenger`, nome de exibição "Caronas Passageiro" (identificador já reservado pela feature equivalente do motorista)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Abrir o aplicativo do passageiro (Priority: P1)

Como pessoa que instalou o aplicativo do passageiro no celular, quero abrir o app e ver uma tela
inicial estável e identificada, para confirmar que o aplicativo está instalado e funcionando antes
de qualquer funcionalidade de caronas existir.

**Why this priority**: É o esqueleto sobre o qual todas as demais funcionalidades (autenticação por
chave, publicação e leitura de eventos em relays Nostr, busca de caronas) serão construídas. Sem uma
aplicação que compile, instale e abra, nenhuma outra história pode ser desenvolvida ou demonstrada.

**Independent Test**: Instalar o pacote gerado em um dispositivo/emulador, tocar no ícone e verificar
que a tela inicial aparece sem erro. Entrega valor como prova de que a base do protótipo está
operacional e pronta para receber as próximas features.

**Acceptance Scenarios**:

1. **Given** o aplicativo instalado em um dispositivo móvel, **When** o usuário toca no ícone do app,
   **Then** a tela inicial é exibida sem mensagens de erro ou telas de falha.
2. **Given** o aplicativo aberto na tela inicial, **When** o usuário envia o app para segundo plano e
   retorna a ele, **Then** a tela inicial continua exibida e responsiva.
3. **Given** o aplicativo aberto, **When** o usuário observa a tela inicial, **Then** o nome
   "Caronas Passageiro" está visível, identificando de qual das duas aplicações do protótipo se trata.
4. **Given** o aplicativo instalado, **When** o usuário procura o app na gaveta de aplicativos do
   sistema, **Then** ele aparece com o nome de exibição "Caronas Passageiro".

---

### User Story 2 - Executar o projeto em ambiente de desenvolvimento (Priority: P2)

Como autor do TCC, quero clonar/abrir o diretório do passageiro e executar um comando documentado
para rodar o aplicativo em um emulador ou dispositivo, para iterar rapidamente durante o
desenvolvimento do protótipo.

**Why this priority**: Não bloqueia a existência do app, mas é o que torna o trabalho subsequente
viável e reprodutível — inclusive para a banca reproduzir os resultados descritos no TCC.

**Independent Test**: A partir de um clone limpo do repositório, seguir os comandos documentados e
obter o aplicativo rodando em um emulador.

**Acceptance Scenarios**:

1. **Given** um clone limpo do repositório e o ambiente de desenvolvimento móvel instalado, **When**
   o desenvolvedor executa o comando documentado de execução, **Then** o aplicativo é compilado e
   iniciado no emulador/dispositivo conectado.
2. **Given** o projeto base, **When** o desenvolvedor executa o comando documentado de verificação
   estática e o comando de testes, **Then** ambos concluem sem erros e sem violações.

---

### User Story 3 - Base preparada para as próximas funcionalidades (Priority: P3)

Como autor do TCC, quero que o projeto base já esteja organizado em uma estrutura de pastas explícita
e com uma suíte de testes executável, para que as funcionalidades de caronas via Nostr sejam
adicionadas sem reorganizar o projeto depois.

**Why this priority**: É investimento em manutenibilidade. O app funciona sem isso, mas a ausência
gera retrabalho assim que a primeira funcionalidade real for implementada.

**Independent Test**: Verificar que a estrutura de diretórios documentada existe e que a suíte de
testes roda e passa, mesmo contendo apenas um teste de fumaça da tela inicial.

**Acceptance Scenarios**:

1. **Given** o projeto base, **When** a suíte de testes automatizados é executada, **Then** ela roda
   até o fim e todos os testes passam.
2. **Given** o projeto base, **When** um desenvolvedor procura onde adicionar uma nova tela, **Then**
   encontra um diretório de propósito claro e documentado para isso.

---

### Edge Cases

- O que acontece quando o dispositivo está sem conexão de rede? A tela inicial deve ser exibida
  normalmente, pois a base não depende de rede.
- O que acontece quando o app é aberto em dispositivos de tamanhos de tela muito diferentes
  (telefone pequeno e tablet)? O conteúdo da tela inicial permanece legível e sem sobreposição.
- Como o aplicativo se comporta ao ser reaberto após ser encerrado pelo sistema operacional por falta
  de memória? Ele reinicia na tela inicial, sem estado corrompido.
- O que acontece quando o dispositivo usa tema escuro do sistema? A tela inicial permanece legível.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST existir como um aplicativo móvel instalável e executável, independente
  do aplicativo do motorista, residindo no diretório `Prototipo/passenger/`.
- **FR-002**: O sistema MUST exibir, ao ser iniciado, uma única tela inicial vazia de funcionalidades
  de negócio, contendo apenas a identificação do aplicativo do passageiro.
- **FR-003**: O sistema MUST NOT incluir qualquer conteúdo de demonstração gerado automaticamente
  pelo ferramental de criação de projeto (por exemplo, contador de exemplo e seus textos).
- **FR-004**: O sistema MUST iniciar e permanecer estável sem exigir conexão de rede, credenciais,
  cadastro ou qualquer configuração prévia do usuário.
- **FR-005**: O sistema MUST ser executável em dispositivos Android; iOS, web e desktop estão fora do
  escopo desta feature e não precisam ser gerados nem validados.
- **FR-006**: O projeto MUST possuir uma suíte de testes automatizados executável por um comando
  único, contendo ao menos um teste que verifica que a tela inicial é renderizada.
- **FR-007**: O projeto MUST possuir verificação estática de código (lint/análise) executável por um
  comando único, sem violações no estado inicial.
- **FR-008**: O projeto MUST organizar o código-fonte em uma estrutura de diretórios explícita que
  separe, no mínimo, ponto de entrada da aplicação, telas/interface e código compartilhado.
- **FR-009**: Os comandos de execução, verificação estática e teste MUST estar documentados no
  repositório, incluindo como executar um único teste.
- **FR-010**: O aplicativo MUST ser identificado pelo nome de exibição "Caronas Passageiro" e pelo
  identificador de aplicativo `br.ufsc.tcc.caronas.passenger`, distinto de `br.ufsc.tcc.caronas.driver`
  usado pelo aplicativo do motorista, de modo que ambos possam coexistir no mesmo dispositivo.
- **FR-011**: O projeto MUST NOT introduzir, nesta feature, qualquer dependência de rede, de
  protocolo Nostr, de criptografia ou de backend — a base é deliberadamente inerte.
  > **Superado em 2026-09-15, após a entrega e validação desta feature.** Por decisão do autor,
  > `dart_nostr: ^10.0.1` foi adicionado ao projeto para antecipar a investigação de viabilidade do
  > protocolo. O requisito permanece aqui como registro fiel do escopo em que a base foi construída e
  > validada — não foi violado durante a implementação. Ver a revisão D9-R1 em
  > [research.md](./research.md), incluindo a pendência da permissão `INTERNET` no build de release.

### Key Entities

Não se aplica: esta feature não introduz dados persistidos nem entidades de domínio.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A partir de um clone limpo, um desenvolvedor consegue ter o aplicativo rodando em um
  emulador em menos de 15 minutos seguindo apenas a documentação do repositório.
- **SC-002**: O aplicativo abre e exibe a tela inicial em menos de 3 segundos em um dispositivo
  Android de configuração mediana.
- **SC-003**: 100% dos testes automatizados da suíte passam e a verificação estática reporta zero
  violações no estado inicial do projeto.
- **SC-004**: O aplicativo é instalado e aberto com sucesso em pelo menos um dispositivo Android ou
  emulador Android, sem falhas de inicialização.
- **SC-005**: Nenhum texto ou elemento de demonstração do ferramental padrão permanece visível na
  aplicação.

## Assumptions

- O ferramental de desenvolvimento móvel escolhido é Flutter, conforme indicado explicitamente na
  descrição da feature e no nome do diretório da feature.
- Android é o único alvo de plataforma desta feature (decidido na clarificação): o ambiente de
  desenvolvimento é Linux, onde builds iOS não podem ser produzidos nem verificados. O código
  permanece multiplataforma por construção, mas iOS é trabalho futuro.
- O desenvolvedor possui ambiente de desenvolvimento móvel já instalado e configurado localmente; a
  configuração desse ambiente não faz parte do escopo desta feature.
- "App vazio" significa um aplicativo funcional com uma única tela sem funcionalidades de negócio, e
  não um diretório de projeto sem código.
- O aplicativo do passageiro não possui backend próprio e, no futuro, comunicará exclusivamente por
  eventos assinados em relays Nostr; nada disso é implementado nesta feature.
- O namespace `br.ufsc.tcc.caronas` é compartilhado pelas duas apps do protótipo; o sufixo
  `.passenger` foi reservado para esta app pela feature equivalente do motorista
  (`Prototipo/driver/specs/001-flutter-app-base/`).
- Idioma de interface: português do Brasil, coerente com o restante do trabalho.
- Não há restrições de acessibilidade, analytics ou distribuição em lojas de aplicativos nesta
  feature; o alvo é execução local para demonstração acadêmica.
- A constituição do projeto (`.specify/memory/constitution.md`) ainda é o template não preenchido,
  portanto nenhuma restrição de governança específica foi aplicada a esta especificação.
