[CmdletBinding()]
param(
    [ValidateRange(0, 200)]
    [int] $Gap = 20,

    [switch] $Daemon,

    [switch] $EnableWorkspace,

    [Alias('RestoreTiling')]
    [switch] $DisableWorkspace,

    [switch] $DryRun,

    [string] $StatePath = (Join-Path $HOME '.glzr/glazewm/grid-state.json'),

    [string] $ConfigPath = (Join-Path $HOME '.glzr/glazewm/grid-config.json'),

    [string] $LogPath = (Join-Path $HOME '.glzr/glazewm/grid-controller.log')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-GridLog {
    param([Parameter(Mandatory)][string] $Message)

    $directory = Split-Path -Parent $LogPath
    if ($directory) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $LogPath) -and
        (Get-Item -LiteralPath $LogPath).Length -gt 1MB) {
        Move-Item -LiteralPath $LogPath -Destination "$LogPath.previous" -Force
    }

    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffK'
    Add-Content -LiteralPath $LogPath -Value "$timestamp $Message"
}

function Resolve-GlazeWmCli {
    if ($env:GLAZEWM_CLI -and (Test-Path -LiteralPath $env:GLAZEWM_CLI)) {
        return $env:GLAZEWM_CLI
    }

    if ($IsMacOS) {
        $appCli = '/Applications/GlazeWM.app/Contents/MacOS/glazewm'
        if (Test-Path -LiteralPath $appCli) {
            return $appCli
        }
    }

    $command = Get-Command glazewm -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw 'GlazeWM CLI was not found. Set GLAZEWM_CLI to its full path.'
}

function Invoke-GlazeWm {
    param([Parameter(Mandatory)][string[]] $Arguments)

    $output = & $script:GlazeWmCli @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "GlazeWM command failed: $($Arguments -join ' ')`n$($output -join "`n")"
    }

    return $output
}

function New-GridState {
    return [pscustomobject][ordered]@{
        version = 1
        disabledWorkspaces = @()
        ownedWindows = @()
    }
}

function New-GridConfig {
    return [pscustomobject][ordered]@{
        version = 1
        excludedWindows = @()
    }
}

function Read-GridConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return New-GridConfig
    }

    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        if ($config.version -ne 1) {
            throw "Unsupported grid config version: $($config.version)"
        }

        $config.excludedWindows = @($config.excludedWindows)
        return $config
    }
    catch {
        Write-GridLog "Grid config is invalid; using no exclusions. $($_.Exception.Message)"
        return New-GridConfig
    }
}

function Test-WindowExcluded {
    param(
        [Parameter(Mandatory)] $Window,
        [Parameter(Mandatory)] $Config
    )

    foreach ($rule in @($Config.excludedWindows)) {
        $matched = $true
        $specifiedFields = 0
        $processProperty = $Window.PSObject.Properties['processName']
        $titleProperty = $Window.PSObject.Properties['title']
        $classProperty = $Window.PSObject.Properties['className']
        $fields = @{
            processNameRegex = if ($processProperty) { [string] $processProperty.Value } else { '' }
            titleRegex = if ($titleProperty) { [string] $titleProperty.Value } else { '' }
            classNameRegex = if ($classProperty) { [string] $classProperty.Value } else { '' }
        }

        foreach ($property in $fields.Keys) {
            if ($property -in $rule.PSObject.Properties.Name) {
                $specifiedFields++
                $pattern = [string] $rule.$property
                if (-not $fields[$property] -or $fields[$property] -notmatch $pattern) {
                    $matched = $false
                    break
                }
            }
        }

        if ($matched -and $specifiedFields -gt 0) {
            return $true
        }
    }

    return $false
}

function Read-GridState {
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return New-GridState
    }

    try {
        $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
        if ($state.version -ne 1) {
            throw "Unsupported state version: $($state.version)"
        }

        $state.disabledWorkspaces = @($state.disabledWorkspaces)
        $state.ownedWindows = @($state.ownedWindows)
        return $state
    }
    catch {
        Write-GridLog "State file is invalid; starting fresh. $($_.Exception.Message)"
        return New-GridState
    }
}

function Save-GridState {
    param([Parameter(Mandatory)] $State)

    $directory = Split-Path -Parent $StatePath
    if ($directory) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $temporaryPath = "$StatePath.$PID.tmp"
    $json = $State | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $StatePath -Force
}

function Invoke-WithStateLock {
    param([Parameter(Mandatory)][scriptblock] $Action)

    $mutex = [System.Threading.Mutex]::new(
        $false,
        'dotfiles.glazewm-grid-state'
    )
    $acquired = $false

    try {
        try {
            $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds(10))
        }
        catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
        }

        if (-not $acquired) {
            throw 'Timed out waiting for the grid-controller state lock.'
        }

        & $Action
    }
    finally {
        if ($acquired) {
            $mutex.ReleaseMutex()
        }
        $mutex.Dispose()
    }
}

function Get-DescendantWindows {
    param([Parameter(Mandatory)] $Container)

    foreach ($child in @($Container.children)) {
        if ($child.type -eq 'window') {
            $child
        }
        elseif ($null -ne $child.children) {
            Get-DescendantWindows -Container $child
        }
    }
}

function Get-DesktopSnapshot {
    $response = (Invoke-GlazeWm -Arguments @('query', 'monitors') | Out-String) |
        ConvertFrom-Json
    $records = @()

    foreach ($monitor in @($response.data.monitors)) {
        foreach ($workspace in @($monitor.children | Where-Object type -eq 'workspace')) {
            $records += [pscustomobject]@{
                Monitor = $monitor
                Workspace = $workspace
                Windows = @(Get-DescendantWindows -Container $workspace)
            }
        }
    }

    return $records
}

function Get-WindowHandleKey {
    param([Parameter(Mandatory)] $Window)
    return [string] $Window.handle
}

function Get-GridDimensions {
    param(
        [Parameter(Mandatory)][int] $WindowCount,
        [Parameter(Mandatory)][double] $Width,
        [Parameter(Mandatory)][double] $Height,
        [Parameter(Mandatory)][double] $ScaledGap
    )

    $landscape = $Width -ge $Height

    if ($WindowCount -le 2) {
        $columns = if ($landscape) { $WindowCount } else { 1 }
        $rows = if ($landscape) { 1 } else { $WindowCount }
    }
    elseif ($WindowCount -le 4) {
        $columns = 2
        $rows = 2
    }
    elseif ($WindowCount -le 6) {
        $columns = if ($landscape) { 3 } else { 2 }
        $rows = if ($landscape) { 2 } else { 3 }
    }
    elseif ($WindowCount -le 8) {
        $columns = if ($landscape) { 4 } else { 2 }
        $rows = if ($landscape) { 2 } else { 4 }
    }
    else {
        $bestSize = -1
        $columns = 1
        $rows = $WindowCount

        for ($candidateColumns = 1; $candidateColumns -le $WindowCount; $candidateColumns++) {
            $candidateRows = [Math]::Ceiling($WindowCount / $candidateColumns)
            $candidateWidth = ($Width - (($candidateColumns - 1) * $ScaledGap)) /
                $candidateColumns
            $candidateHeight = ($Height - (($candidateRows - 1) * $ScaledGap)) /
                $candidateRows
            $candidateSize = [Math]::Min($candidateWidth, $candidateHeight)

            if ($candidateSize -gt $bestSize) {
                $bestSize = $candidateSize
                $columns = $candidateColumns
                $rows = $candidateRows
            }
        }
    }

    return [pscustomobject]@{ Columns = $columns; Rows = $rows }
}

function Set-WindowTiling {
    param([Parameter(Mandatory)] $Window)

    if ($DryRun) {
        Write-Host "Restore to tiling: $($Window.title)"
        return
    }

    Invoke-GlazeWm -Arguments @(
        'command', '--id', $Window.id, 'set-tiling'
    ) | Out-Null
}

function Set-WindowFloatingPreserved {
    param([Parameter(Mandatory)] $Window)

    if ($DryRun -or $Window.state.type -eq 'floating') {
        return
    }

    Invoke-GlazeWm -Arguments @(
        'command', '--id', $Window.id, 'set-floating',
        '--centered=false', '--shown-on-top=false'
    ) | Out-Null
}

function Set-WindowGridSize {
    param(
        [Parameter(Mandatory)] $Window,
        [Parameter(Mandatory)][int] $Size
    )

    if ($DryRun) {
        Write-Host "Resize $($Window.title): ${Size}x${Size}"
        return
    }

    Set-WindowFloatingPreserved -Window $Window
    Invoke-GlazeWm -Arguments @(
        'command', '--id', $Window.id, 'size',
        '--height', "${Size}px"
    ) | Out-Null
    Invoke-GlazeWm -Arguments @(
        'command', '--id', $Window.id, 'size',
        '--width', "${Size}px"
    ) | Out-Null
}

function Set-WindowGridPosition {
    param(
        [Parameter(Mandatory)] $Window,
        [Parameter(Mandatory)][int] $X,
        [Parameter(Mandatory)][int] $Y
    )

    if ($DryRun) {
        Write-Host "Position $($Window.title): ${X},${Y}"
        return
    }

    Invoke-GlazeWm -Arguments @(
        'command', '--id', $Window.id, 'position',
        '--x-pos', [string] $X, '--y-pos', [string] $Y
    ) | Out-Null
}

function Get-LiveWindowSizes {
    $response = (Invoke-GlazeWm -Arguments @('query', 'windows') | Out-String) |
        ConvertFrom-Json
    $sizes = @{}

    foreach ($window in @($response.data.windows)) {
        $sizes[(Get-WindowHandleKey -Window $window)] = [pscustomobject]@{
            Width = [int] $window.width
            Height = [int] $window.height
        }
    }

    return $sizes
}

function Get-AdaptiveLayout {
    param(
        [Parameter(Mandatory)][object[]] $Rectangles,
        [Parameter(Mandatory)][int] $PreferredColumns,
        [Parameter(Mandatory)][double] $Width,
        [Parameter(Mandatory)][double] $Height,
        [Parameter(Mandatory)][double] $ScaledGap
    )

    $candidates = @()
    for ($columns = 1; $columns -le $Rectangles.Count; $columns++) {
        $rows = [int] [Math]::Ceiling($Rectangles.Count / $columns)
        $columnWidths = [int[]]::new($columns)
        $rowHeights = [int[]]::new($rows)

        for ($index = 0; $index -lt $Rectangles.Count; $index++) {
            $column = $index % $columns
            $row = [Math]::Floor($index / $columns)
            $columnWidths[$column] = [Math]::Max(
                $columnWidths[$column], [int] $Rectangles[$index].Width
            )
            $rowHeights[$row] = [Math]::Max(
                $rowHeights[$row], [int] $Rectangles[$index].Height
            )
        }

        $requiredWidth = ($columnWidths | Measure-Object -Sum).Sum +
            (($columns - 1) * $ScaledGap)
        $requiredHeight = ($rowHeights | Measure-Object -Sum).Sum +
            (($rows - 1) * $ScaledGap)
        $overflow = [Math]::Max(0, $requiredWidth - $Width) +
            [Math]::Max(0, $requiredHeight - $Height)
        $fits = $overflow -eq 0
        $preferencePenalty = [Math]::Abs($columns - $PreferredColumns)

        $candidates += [pscustomobject]@{
            Columns = $columns
            Rows = $rows
            ColumnWidths = $columnWidths
            RowHeights = $rowHeights
            RequiredWidth = $requiredWidth
            RequiredHeight = $requiredHeight
            Fits = $fits
            Overflow = $overflow
            PreferencePenalty = $preferencePenalty
        }
    }

    $fitting = @($candidates | Where-Object Fits)
    if ($fitting.Count -gt 0) {
        return $fitting |
            Sort-Object PreferencePenalty, RequiredWidth, RequiredHeight |
            Select-Object -First 1
    }

    return $candidates |
        Sort-Object Overflow, PreferencePenalty |
        Select-Object -First 1
}

function Set-WorkspaceGrid {
    param(
        [Parameter(Mandatory)] $Record,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Windows
    )

    if ($Windows.Count -eq 0) {
        return
    }

    $workspace = $Record.Workspace
    $scaleFactor = [double] $Record.Monitor.scaleFactor
    $scaledGap = [Math]::Max(0, [Math]::Round($Gap * $scaleFactor))
    $dimensions = Get-GridDimensions `
        -WindowCount $Windows.Count `
        -Width ([double] $workspace.width) `
        -Height ([double] $workspace.height) `
        -ScaledGap $scaledGap
    $columns = $dimensions.Columns
    $rows = $dimensions.Rows

    $availableWidth = [double] $workspace.width - (($columns - 1) * $scaledGap)
    $availableHeight = [double] $workspace.height - (($rows - 1) * $scaledGap)
    $cellSize = [Math]::Floor(
        [Math]::Min($availableWidth / $columns, $availableHeight / $rows)
    )

    if ($cellSize -le 0) {
        throw "Workspace '$($workspace.name)' is too small for its grid."
    }

    $gridWidth = ($columns * $cellSize) + (($columns - 1) * $scaledGap)
    $gridHeight = ($rows * $cellSize) + (($rows - 1) * $scaledGap)
    $originX = [Math]::Round(
        [double] $workspace.x + (([double] $workspace.width - $gridWidth) / 2)
    )
    $originY = [Math]::Round(
        [double] $workspace.y + (([double] $workspace.height - $gridHeight) / 2)
    )

    foreach ($window in $Windows) {
        try {
            Set-WindowGridSize -Window $window -Size ([int] $cellSize)
        }
        catch {
            Write-GridLog "Failed to resize window '$($window.title)': $($_.Exception.Message)"
        }
    }

    if (-not $DryRun) {
        Start-Sleep -Milliseconds 180
    }

    $liveSizes = if ($DryRun) { @{} } else { Get-LiveWindowSizes }
    $rectangles = @(
        foreach ($window in $Windows) {
            $handle = Get-WindowHandleKey -Window $window
            $actual = $liveSizes[$handle]
            [pscustomobject]@{
                Window = $window
                Width = if ($actual) { $actual.Width } else { [int] $cellSize }
                Height = if ($actual) { $actual.Height } else { [int] $cellSize }
            }
        }
    )
    $layout = Get-AdaptiveLayout `
        -Rectangles $rectangles `
        -PreferredColumns $columns `
        -Width ([double] $workspace.width) `
        -Height ([double] $workspace.height) `
        -ScaledGap $scaledGap

    $originX = [Math]::Round(
        [double] $workspace.x + (([double] $workspace.width - $layout.RequiredWidth) / 2)
    )
    $originY = [Math]::Round(
        [double] $workspace.y + (([double] $workspace.height - $layout.RequiredHeight) / 2)
    )
    $columnOffsets = @()
    $cursor = [double] $originX
    foreach ($width in $layout.ColumnWidths) {
        $columnOffsets += $cursor
        $cursor += $width + $scaledGap
    }
    $rowOffsets = @()
    $cursor = [double] $originY
    foreach ($height in $layout.RowHeights) {
        $rowOffsets += $cursor
        $cursor += $height + $scaledGap
    }

    for ($index = 0; $index -lt $rectangles.Count; $index++) {
        $column = $index % $layout.Columns
        $row = [Math]::Floor($index / $layout.Columns)
        $rectangle = $rectangles[$index]
        $x = [int] [Math]::Round(
            $columnOffsets[$column] +
                (($layout.ColumnWidths[$column] - $rectangle.Width) / 2)
        )
        $y = [int] [Math]::Round(
            $rowOffsets[$row] +
                (($layout.RowHeights[$row] - $rectangle.Height) / 2)
        )

        try {
            Set-WindowGridPosition -Window $rectangle.Window -X $x -Y $y
        }
        catch {
            Write-GridLog "Failed to position window '$($rectangle.Window.title)': $($_.Exception.Message)"
        }
    }

    if (-not $layout.Fits) {
        Write-GridLog (
            "Workspace '$($workspace.name)' cannot fit all application minimum sizes; " +
            "using the least-overflowing $($layout.Columns)x$($layout.Rows) layout."
        )
    }

    Write-Host (
        "Workspace $($workspace.name): $($Windows.Count) windows, " +
        "$($layout.Columns)x$($layout.Rows), adaptive sizes."
    )
}

function Sync-GridCore {
    param(
        [Parameter(Mandatory)] $State,
        [Parameter(Mandatory)] $Config,
        [Parameter(Mandatory)][object[]] $Snapshot
    )

    $disabled = @{}
    foreach ($name in @($State.disabledWorkspaces)) {
        $disabled[[string] $name] = $true
    }

    $currentWindows = @{}
    foreach ($record in $Snapshot) {
        foreach ($window in $record.Windows) {
            $currentWindows[(Get-WindowHandleKey -Window $window)] = [pscustomobject]@{
                Window = $window
                WorkspaceName = [string] $record.Workspace.name
            }
        }
    }

    # Retain live owned windows in insertion order. If a managed window moves
    # to another workspace, append it to that workspace's order.
    $retained = @()
    $moved = @()
    foreach ($entry in @($State.ownedWindows)) {
        $handle = [string] $entry.handle
        if (-not $currentWindows.ContainsKey($handle)) {
            continue
        }

        $current = $currentWindows[$handle]
        if (Test-WindowExcluded -Window $current.Window -Config $Config) {
            try {
                Set-WindowFloatingPreserved -Window $current.Window
            }
            catch {
                Write-GridLog "Failed to float excluded window '$handle': $($_.Exception.Message)"
            }
            continue
        }

        if ($disabled.ContainsKey($current.WorkspaceName)) {
            try {
                Set-WindowTiling -Window $current.Window
            }
            catch {
                Write-GridLog "Failed to restore window '$handle': $($_.Exception.Message)"
            }
            continue
        }

        $updatedEntry = [pscustomobject]@{
            handle = $handle
            workspace = $current.WorkspaceName
        }
        if ([string] $entry.workspace -eq $current.WorkspaceName) {
            $retained += $updatedEntry
        }
        else {
            $moved += $updatedEntry
        }
    }
    $State.ownedWindows = @($retained) + @($moved)

    $owned = @{}
    foreach ($entry in @($State.ownedWindows)) {
        $owned[[string] $entry.handle] = $entry
    }

    # A window that remains tiling after GlazeWM's `window_rules` is a grid
    # candidate. A window already floating at this point belongs to GlazeWM's
    # app-specific floating rules and is deliberately left alone.
    foreach ($record in $Snapshot) {
        $workspaceName = [string] $record.Workspace.name
        if ($disabled.ContainsKey($workspaceName)) {
            continue
        }

        foreach ($window in @($record.Windows | Sort-Object y, x)) {
            $handle = Get-WindowHandleKey -Window $window
            if ($owned.ContainsKey($handle)) {
                continue
            }

            if (Test-WindowExcluded -Window $window -Config $Config) {
                try {
                    Set-WindowFloatingPreserved -Window $window
                }
                catch {
                    Write-GridLog "Failed to float excluded window '$handle': $($_.Exception.Message)"
                }
                continue
            }

            if ($window.state.type -eq 'tiling') {
                $entry = [pscustomobject]@{
                    handle = $handle
                    workspace = $workspaceName
                }
                $State.ownedWindows += $entry
                $owned[$handle] = $entry
            }
        }
    }

    $order = @{}
    for ($index = 0; $index -lt $State.ownedWindows.Count; $index++) {
        $order[[string] $State.ownedWindows[$index].handle] = $index
    }

    foreach ($record in $Snapshot) {
        $workspaceName = [string] $record.Workspace.name
        Write-Verbose (
            "Workspace {0}: displayed={1}, windows={2}, disabled={3}" -f
                $workspaceName,
                $record.Workspace.isDisplayed,
                $record.Windows.Count,
                $disabled.ContainsKey($workspaceName)
        )
        if ($disabled.ContainsKey($workspaceName) -or -not $record.Workspace.isDisplayed) {
            continue
        }

        $managedWindows = @(
            $record.Windows |
                Where-Object {
                    $handle = Get-WindowHandleKey -Window $_
                    $owned.ContainsKey($handle) -and
                        $_.state.type -notin @('minimized', 'fullscreen')
                } |
                Sort-Object { $order[(Get-WindowHandleKey -Window $_)] }
        )
        Write-Verbose "Workspace ${workspaceName}: managed=$($managedWindows.Count)"
        Set-WorkspaceGrid -Record $record -Windows $managedWindows
    }
}

function Invoke-GridSync {
    Invoke-WithStateLock {
        $state = Read-GridState
        $config = Read-GridConfig
        $snapshot = @(Get-DesktopSnapshot)
        Sync-GridCore -State $state -Config $config -Snapshot $snapshot
        if (-not $DryRun) {
            Save-GridState -State $state
        }
    }
}

function Set-FocusedWorkspaceEnabled {
    param([Parameter(Mandatory)][bool] $Enabled)

    Invoke-WithStateLock {
        $state = Read-GridState
        $config = Read-GridConfig
        $snapshot = @(Get-DesktopSnapshot)
        $focused = $snapshot |
            Where-Object { $_.Workspace.hasFocus } |
            Select-Object -First 1

        if (-not $focused) {
            throw 'No focused workspace was found.'
        }

        $workspaceName = [string] $focused.Workspace.name
        if ($Enabled) {
            $state.disabledWorkspaces = @(
                $state.disabledWorkspaces | Where-Object { [string] $_ -ne $workspaceName }
            )
        }
        elseif ($workspaceName -notin @($state.disabledWorkspaces)) {
            $state.disabledWorkspaces += $workspaceName
        }

        Sync-GridCore -State $state -Config $config -Snapshot $snapshot
        if (-not $DryRun) {
            Save-GridState -State $state
        }

        $action = if ($Enabled) { 'enabled' } else { 'disabled' }
        Write-Host "Grid $action for workspace $workspaceName."
    }
}

function Start-GridDaemon {
    $daemonMutex = [System.Threading.Mutex]::new(
        $false,
        'dotfiles.glazewm-grid-daemon'
    )
    $acquired = $false

    try {
        try {
            $acquired = $daemonMutex.WaitOne(0)
        }
        catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
        }

        if (-not $acquired) {
            Write-GridLog 'A grid-controller daemon is already running.'
            return
        }

        Write-GridLog "Grid-controller daemon started (PID $PID)."
        $events = @(
            'application_exiting',
            'window_managed',
            'window_unmanaged',
            'focused_container_moved',
            'workspace_activated',
            'monitor_added',
            'monitor_updated',
            'monitor_removed',
            'user_config_changed'
        )

        while ($true) {
            try {
                Invoke-GridSync
            }
            catch {
                Write-GridLog "Initial sync failed: $($_.Exception.Message)"
            }

            $applicationExiting = $false
            try {
                & $script:GlazeWmCli sub --events @events 2>&1 |
                    ForEach-Object {
                        $line = [string] $_
                        if ($line -match 'application_exiting') {
                            $applicationExiting = $true
                            return
                        }

                        Start-Sleep -Milliseconds 120
                        try {
                            Invoke-GridSync
                        }
                        catch {
                            Write-GridLog "Event sync failed: $($_.Exception.Message)"
                        }
                    }
            }
            catch {
                Write-GridLog "Event subscription failed: $($_.Exception.Message)"
            }

            if ($applicationExiting) {
                break
            }

            Write-GridLog 'GlazeWM event stream ended; retrying in 2 seconds.'
            Start-Sleep -Seconds 2
        }
    }
    finally {
        Write-GridLog "Grid-controller daemon stopped (PID $PID)."
        if ($acquired) {
            $daemonMutex.ReleaseMutex()
        }
        $daemonMutex.Dispose()
    }
}

$script:GlazeWmCli = Resolve-GlazeWmCli

if ($Daemon) {
    Start-GridDaemon
}
elseif ($DisableWorkspace) {
    Set-FocusedWorkspaceEnabled -Enabled $false
}
elseif ($EnableWorkspace) {
    Set-FocusedWorkspaceEnabled -Enabled $true
}
else {
    Invoke-GridSync
}
