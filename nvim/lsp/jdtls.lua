-- Library go-to-definition lands on real sources: jdtls downloads the
-- -sources jars for Gradle dependencies on import. Takes effect on the
-- next editor start (existing workspaces reimport automatically).
return {
  settings = {
    java = {
      eclipse = { downloadSources = true },
      maven = { downloadSources = true },
    },
  },
}
