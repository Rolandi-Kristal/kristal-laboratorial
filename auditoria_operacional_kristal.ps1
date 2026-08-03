
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$LibDir = Join-Path $ProjectRoot "lib"
$ScreensDir = Join-Path $LibDir "screens"
$HomeScreenPath = Join-Path $ScreensDir "home_screen.dart"
$OutDir = Join-Path $ProjectRoot "AUDITORIA_KRISTAL_OPERACIONAL"

if (!(Test-Path $ProjectRoot)) {
    throw "Projeto nao encontrado em $ProjectRoot"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Issues = New-Object System.Collections.Generic.List[Object]
$Routes = New-Object System.Collections.Generic.List[Object]

function Add-Issue {
    param(
        [string]$Severity,
        [string]$File,
        [string]$Line,
        [string]$Category,
        [string]$Evidence,
        [string]$Recommendation
    )

    $Issues.Add([PSCustomObject]@{
        Severidade = $Severity
        Arquivo = $File
        Linha = $Line
        Categoria = $Category
        Evidencia = $Evidence
        Recomendacao = $Recommendation
    }) | Out-Null
}

function Get-Relative {
    param([string]$Path)
    return $Path.Replace($ProjectRoot + "\", "")
}

Write-Host ""
Write-Host "======================================================="
Write-Host " KRISTAL - AUDITORIA OPERACIONAL TOTAL"
Write-Host "======================================================="
Write-Host ""

if (!(Test-Path $LibDir)) {
    Add-Issue "CRITICO" "lib" "-" "Estrutura" "Pasta lib nao encontrada." "Restaurar estrutura Flutter do projeto."
}

if (!(Test-Path $ScreensDir)) {
    Add-Issue "CRITICO" "lib\screens" "-" "Estrutura" "Pasta lib\screens nao encontrada." "Restaurar as telas do sistema."
}

if (!(Test-Path $HomeScreenPath)) {
    Add-Issue "CRITICO" "lib\screens\home_screen.dart" "-" "Roteamento" "home_screen.dart nao encontrado." "Restaurar home_screen.dart."
}
else {
    $HomeText = Get-Content -Path $HomeScreenPath -Raw -Encoding UTF8
    $HomeLines = Get-Content -Path $HomeScreenPath -Encoding UTF8

    # Captura modulos do home_screen por blocos _ModuleItem.
    $ModuleBlocks = [regex]::Matches($HomeText, "_ModuleItem\s*\((?s).*?\n\s*\),")
    foreach ($Match in $ModuleBlocks) {
        $Block = $Match.Value

        $Title = ""
        $Group = ""
        $Builder = ""
        $ModuleKey = ""

        $TitleMatch = [regex]::Match($Block, "title:\s*'([^']+)'")
        if ($TitleMatch.Success) { $Title = $TitleMatch.Groups[1].Value }

        $GroupMatch = [regex]::Match($Block, "group:\s*'([^']+)'")
        if ($GroupMatch.Success) { $Group = $GroupMatch.Groups[1].Value }

        $BuilderMatch = [regex]::Match($Block, "builder:\s*\([^)]*\)\s*=>\s*(?:const\s+)?([A-Za-z0-9_]+)\s*\(")
        if ($BuilderMatch.Success) { $Builder = $BuilderMatch.Groups[1].Value }

        $KeyMatch = [regex]::Match($Block, "moduleKey:\s*'([^']+)'")
        if ($KeyMatch.Success) { $ModuleKey = $KeyMatch.Groups[1].Value }

        if ($Title -ne "") {
            $Routes.Add([PSCustomObject]@{
                Grupo = $Group
                Menu = $Title
                BuilderClasse = $Builder
                ModuleKey = $ModuleKey
                Status = "PENDENTE_VERIFICACAO"
            }) | Out-Null
        }

        if ($Builder -ne "") {
            $ClassFound = Select-String -Path (Join-Path $LibDir "**\*.dart") -Pattern "class\s+$Builder\b" -ErrorAction SilentlyContinue
            if (!$ClassFound) {
                Add-Issue "CRITICO" (Get-Relative $HomeScreenPath) "-" "Rota/Menu" "Menu '$Title' usa '$Builder', mas a classe nao foi encontrada em lib." "Criar/recuperar a classe $Builder ou corrigir o builder do menu."
            }
        }
        elseif ($Title -ne "Dashboard") {
            Add-Issue "ALTO" (Get-Relative $HomeScreenPath) "-" "Rota/Menu" "Menu '$Title' nao possui builder direto identificado." "Conferir manualmente se a rota abre tela real."
        }
    }

    # Erros conhecidos de const indevido.
    foreach ($Pair in @(
        @{Class="PreAgendamentoScreen"; Evidence="const PreAgendamentoScreen()"},
        @{Class="AgendamentoPacientesScreen"; Evidence="const AgendamentoPacientesScreen()"}
    )) {
        if ($HomeText.Contains($Pair.Evidence)) {
            Add-Issue "ALTO" (Get-Relative $HomeScreenPath) "-" "Build/Const" $Pair.Evidence "Trocar para $($Pair.Class)() caso continue dando Not a constant expression."
        }
    }

    # Desenvolvedor no Dashboard/Home.
    if ($HomeText -match "AppConstants\.developerCredit|Desenvolvedor:\s*3") {
        Add-Issue "MEDIO" (Get-Relative $HomeScreenPath) "-" "Interface" "Credito do desenvolvedor aparece no home_screen/dashboard." "Remover do Dashboard se a regra atual for nao exibir desenvolvedor no painel."
    }
}

# Varredura geral de arquivos Dart.
$DartFiles = Get-ChildItem -Path $LibDir -Recurse -Filter "*.dart" -ErrorAction SilentlyContinue

$Patterns = @(
    @{Severity="ALTO"; Category="Placeholder"; Pattern="TODO|FIXME|placeholder|Placeholder|mock|Mock|simulado|Simulado|ficticio|fictício|em breve|Em breve|não implementado|nao implementado"},
    @{Severity="CRITICO"; Category="Funcao nao implementada"; Pattern="UnimplementedError|throw\s+UnimplementedError|UnsupportedError"},
    @{Severity="ALTO"; Category="Botao sem acao"; Pattern="onPressed:\s*null|onTap:\s*null"},
    @{Severity="ALTO"; Category="Botao vazio"; Pattern="onPressed:\s*\(\)\s*\{\s*\}|onTap:\s*\(\)\s*\{\s*\}"},
    @{Severity="MEDIO"; Category="SnackBar sem persistencia aparente"; Pattern="SnackBar\s*\("},
    @{Severity="ALTO"; Category="Exclusao fisica potencial"; Pattern="\.delete\s*\(|DELETE\s+FROM|delete\("}
)

foreach ($File in $DartFiles) {
    $Rel = Get-Relative $File.FullName
    $ContentLines = Get-Content -Path $File.FullName -Encoding UTF8

    for ($idx = 0; $idx -lt $ContentLines.Count; $idx++) {
        $LineText = $ContentLines[$idx]
        foreach ($P in $Patterns) {
            if ($LineText -match $P.Pattern) {
                $Recommendation = switch ($P.Category) {
                    "Placeholder" { "Substituir por funcionalidade real ou remover texto/fluxo de simulação." }
                    "Funcao nao implementada" { "Implementar a função real ou remover chamada." }
                    "Botao sem acao" { "Vincular botao a serviço, persistência, navegação ou ação real." }
                    "Botao vazio" { "Implementar ação real no callback." }
                    "SnackBar sem persistencia aparente" { "Conferir se o botão também grava/consulta dados reais, não apenas exibe mensagem." }
                    "Exclusao fisica potencial" { "Verificar se não apaga dado clínico/laboratorial protegido. Usar arquivamento lógico." }
                    default { "Revisar manualmente." }
                }

                Add-Issue $P.Severity $Rel ($idx + 1).ToString() $P.Category $LineText.Trim() $Recommendation
            }
        }
    }

    # Heuristica: tela com TextField mas sem sinais de gravação
    $FileText = [System.String]::Join("`n", $ContentLines)
    if ($Rel -like "lib\screens\*" -and $FileText -match "TextField|TextFormField" -and $FileText -notmatch "writeAsString|insert|update|salvar|save|create|repository|StoreService|DatabaseService|sqflite|File\(") {
        Add-Issue "ALTO" $Rel "-" "Formulario sem persistencia clara" "Tela possui campos de formulário, mas não foram encontrados sinais claros de gravação." "Conectar a serviço/repositório real e validar salvamento."
    }
}

# Verifica pubspec e assets básicos.
$Pubspec = Join-Path $ProjectRoot "pubspec.yaml"
if (!(Test-Path $Pubspec)) {
    Add-Issue "CRITICO" "pubspec.yaml" "-" "Flutter" "pubspec.yaml nao encontrado." "Restaurar pubspec.yaml."
}
else {
    $PubText = Get-Content -Path $Pubspec -Raw -Encoding UTF8
    foreach ($Dep in @("path_provider", "intl", "pdf", "printing", "sqflite_common_ffi")) {
        if ($PubText -notmatch "$Dep\s*:") {
            Add-Issue "MEDIO" "pubspec.yaml" "-" "Dependencia" "Dependencia '$Dep' nao encontrada." "Adicionar se o módulo correspondente estiver em uso."
        }
    }
}

# Exporta relatórios.
$IssuesCsv = Join-Path $OutDir "pendencias_funcionalidade.csv"
$RoutesCsv = Join-Path $OutDir "rotas_menus_home.csv"
$TxtReport = Join-Path $OutDir "AUDITORIA_OPERACIONAL_KRISTAL.txt"
$JsonReport = Join-Path $OutDir "resumo_auditoria.json"

$Issues | Export-Csv -Path $IssuesCsv -NoTypeInformation -Encoding UTF8
$Routes | Export-Csv -Path $RoutesCsv -NoTypeInformation -Encoding UTF8

$Critical = ($Issues | Where-Object { $_.Severidade -eq "CRITICO" }).Count
$High = ($Issues | Where-Object { $_.Severidade -eq "ALTO" }).Count
$Medium = ($Issues | Where-Object { $_.Severidade -eq "MEDIO" }).Count

$ReportLines = New-Object System.Collections.Generic.List[string]
$ReportLines.Add("KRISTAL LABORATORIAL - AUDITORIA OPERACIONAL TOTAL")
$ReportLines.Add("Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$ReportLines.Add("Projeto: $ProjectRoot")
$ReportLines.Add("")
$ReportLines.Add("RESUMO")
$ReportLines.Add("- Rotas/Menu encontrados no home_screen: $($Routes.Count)")
$ReportLines.Add("- Pendencias CRITICAS: $Critical")
$ReportLines.Add("- Pendencias ALTAS: $High")
$ReportLines.Add("- Pendencias MEDIAS: $Medium")
$ReportLines.Add("")
$ReportLines.Add("ARQUIVOS GERADOS")
$ReportLines.Add("- $IssuesCsv")
$ReportLines.Add("- $RoutesCsv")
$ReportLines.Add("- $JsonReport")
$ReportLines.Add("")
$ReportLines.Add("INTERPRETACAO")
if ($Critical -eq 0 -and $High -eq 0) {
    $ReportLines.Add("Nao foram encontradas pendencias criticas/altas pela auditoria automatica.")
    $ReportLines.Add("Ainda assim, cada fluxo deve ser testado manualmente.")
}
else {
    $ReportLines.Add("Existem pendencias que impedem afirmar 100% real/funcional.")
    $ReportLines.Add("Corrija primeiro CRITICO, depois ALTO, depois MEDIO.")
}
$ReportLines.Add("")
$ReportLines.Add("TOP 50 PENDENCIAS")
$Issues | Select-Object -First 50 | ForEach-Object {
    $ReportLines.Add("[$($_.Severidade)] $($_.Arquivo):$($_.Linha) - $($_.Categoria) - $($_.Evidencia)")
    $ReportLines.Add("  Recomendacao: $($_.Recomendacao)")
}
$ReportLines | Set-Content -Path $TxtReport -Encoding UTF8

$Summary = [PSCustomObject]@{
    projeto = $ProjectRoot
    data = (Get-Date).ToString("s")
    rotasMenus = $Routes.Count
    pendenciasCriticas = $Critical
    pendenciasAltas = $High
    pendenciasMedias = $Medium
    relatorioTxt = $TxtReport
    pendenciasCsv = $IssuesCsv
    rotasCsv = $RoutesCsv
}
$Summary | ConvertTo-Json -Depth 4 | Set-Content -Path $JsonReport -Encoding UTF8

Write-Host ""
Write-Host "Auditoria concluida."
Write-Host "Relatorio principal:"
Write-Host $TxtReport
Write-Host ""
Write-Host "Resumo:"
Write-Host "Rotas/Menu: $($Routes.Count)"
Write-Host "Criticas: $Critical"
Write-Host "Altas: $High"
Write-Host "Medias: $Medium"
Write-Host ""
Write-Host "Envie aqui o arquivo AUDITORIA_OPERACIONAL_KRISTAL.txt para correção final."
