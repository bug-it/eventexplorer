🛡️ Event Explorer








Interface moderna em HTML para análise avançada de logs do Windows (Application, System e Security) usando PowerShell.

📌 Sobre o Projeto

O Event Explorer é uma ferramenta que coleta eventos do Windows Event Log via Get-WinEvent e gera um painel HTML interativo com filtros dinâmicos, organização por severidade e visualização detalhada das mensagens.

O objetivo é fornecer uma alternativa visual e rápida ao Event Viewer nativo do Windows.

🚀 Recursos

📂 Abas separadas por log (Application / System / Security)

🔎 Filtro por ID (suporte múltiplo: 1001,7031)

🎯 Filtro por nível (Informações, Aviso, Erro, Crítico)

📅 Ordenação global por data (mais recente primeiro)

🧾 Mensagem expansível (<details>)

🎨 Tema dark moderno

📄 HTML standalone (não depende de servidor)

⚡ Abertura automática no navegador

🖥️ Demonstração

Após executar o script, será gerado:

%TEMP%\Event_Explorer.html

A interface contém:

Cabeçalho com host e timestamp

Tabs de navegação

Toolbar de filtros

Tabela responsiva sem scroll horizontal

Destaque visual por severidade

⚙️ Requisitos

Windows 10 / 11 / Server 2016+

PowerShell 5.1 ou superior

Permissão administrativa (para ler log Security)

▶️ Como Usar
.\EventExplorer.ps1

Se o navegador não abrir automaticamente:

ii $env:TEMP\Event_Explorer.html
🧠 Como Funciona

Verifica logs habilitados (Application, System, Security)

Coleta eventos com limite individual por log

Normaliza níveis de severidade

Ordena globalmente por data/hora

Renderiza HTML com CSS e JavaScript embutidos

Abre automaticamente no navegador padrão

🔍 Estrutura Técnica
Coleta de eventos
Get-WinEvent -LogName <LogName> -MaxEvents <Limite>
Níveis Normalizados
Original	Normalizado
Information	Informações
Warning	Aviso
Error	Erro
Critical	Crítico
🛠 Customização

Você pode alterar no início do script:

$MaxEventsPerLog = 2000
$OutputFile      = Join-Path $env:TEMP 'Event_Explorer.html'
📈 Roadmap

 Atualização em tempo real

 Exportação CSV

 Filtro por intervalo de datas

 Busca por texto completo

 Estatísticas por ID

 Dashboard gráfico

🔐 Observações de Segurança

O log Security exige execução como administrador.

O script não modifica nenhum evento — apenas leitura.

O HTML gerado é local e não envia dados externamente.

📄 Licença

MIT License — livre para uso e modificação.

🤝 Contribuição

Pull requests são bem-vindos.
Para mudanças significativas, abra uma issue antes para discussão.
