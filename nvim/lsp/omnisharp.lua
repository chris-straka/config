-- TxMonitoringPlatform uses the new XML solution format (.slnx),
-- which needs explicit roots.
return {
  root_markers = { '*.slnx', '*.sln', '*.csproj', 'omnisharp.json' },
}
