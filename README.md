# RequisiPlusApp

Aplicativo iOS nativo em SwiftUI com visual azul e branco, menu glass e as areas:

- Inicio
- Requisicoes
- Feitos
- Perfil

## Estrutura

- `RequisiPlusApp/`: codigo-fonte SwiftUI
- `RequisiPlusApp.xcodeproj/`: projeto para abrir no Xcode

## Como abrir

1. Abra `RequisiPlusApp.xcodeproj` no Xcode.
2. Configure assinatura em `Signing & Capabilities`.
3. Rode no simulador ou dispositivo.

## Observacao

O projeto foi preparado em ambiente Windows, entao a compilacao final e geracao de `.ipa` devem ser feitas em um Mac com Xcode.

## Codemagic

O repositório agora inclui:

- `codemagic.yaml`: workflow base para gerar `.ipa` e enviar para TestFlight
- `RequisiPlusApp.xcodeproj/xcshareddata/xcschemes/RequisiPlusApp.xcscheme`: scheme compartilhado para CI

### O que configurar no Codemagic

1. Conectar o repositório no Codemagic.
2. Criar a integração com App Store Connect usando a API key da Apple.
3. Confirmar que o bundle id `br.com.prefeitura.requisiplus` existe na conta Apple Developer.
4. Em `codemagic.yaml`, preencher `APP_STORE_APPLE_ID` com o id numérico do app no App Store Connect.
5. Rodar o workflow `ios-release`.

### Fluxo esperado

1. O Codemagic aplica os perfis de assinatura.
2. Atualiza o build number usando o número da build do CI.
3. Gera o `.ipa`.
4. Publica no TestFlight.

### Antes da publicacao final

- Configurar `DEVELOPMENT_TEAM` no Xcode se quiser deixar o projeto pronto também para build local
- Validar icones do app e metadados da App Store
- Testar login, leitura e escrita no Supabase em um iPhone real
