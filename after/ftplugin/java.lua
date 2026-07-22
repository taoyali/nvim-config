-- after/ftplugin/java.lua
-- JDTLS LSP config for Java/Android development via nvim-jdtls plugin.
-- Called on every Java buffer; vim.lsp.start deduplicates by name+root_dir.

local jdtls = require("jdtls")

local root_markers = {
  "settings.gradle",
  "settings.gradle.kts",
  "build.gradle",
  "build.gradle.kts",
  "gradlew",
  "mvnw",
  "pom.xml",
  ".git",
}

local root_dir = vim.fs.root(0, root_markers)
if not root_dir then
  return
end

-- Persistent workspace directory unique to this project root
local project_hash = vim.fn.sha256(root_dir):sub(1, 8)
local workspace_dir = vim.fn.stdpath("data") .. "/jdtls_ws/" .. project_hash

-- Build command; add lombok agent if bundled with Mason
local mason_dir = vim.fn.stdpath("data") .. "/mason/packages/jdtls"
local lombok_jar = mason_dir .. "/lombok.jar"

local cmd = { "jdtls" }
if vim.uv.fs_stat(lombok_jar) then
  table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok_jar)
end
table.insert(cmd, "-data")
table.insert(cmd, workspace_dir)

-- jdtls itself needs a modern JDK, but this Android/Gradle project should be
-- imported with JDK 17. Keeping these separate prevents Eclipse Buildship from
-- accidentally reusing the old Java 8 plugin daemon or a too-new JDK daemon.
local jdtls_jdk_home = "/opt/homebrew/opt/openjdk@23/libexec/openjdk.jdk/Contents/Home"
local gradle_jdk_home = "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"

jdtls.start_or_attach({
  cmd = cmd,
  root_dir = root_dir,
  -- brew openjdk@23 formula currently provides JDK 25 (>= 21 required by jdtls)
  cmd_env = {
    JAVA_HOME = jdtls_jdk_home,
    -- Ensure Gradle daemon spawned by Eclipse Buildship uses the correct JDK
    GRADLE_OPTS = "-Dorg.gradle.java.home=" .. gradle_jdk_home,
  },

  settings = {
    java = {
      configuration = {
        -- "interactive" prompts before re-building Gradle configuration;
        -- "automatic" rebuilds on every change (heavier but more reliable).
        updateBuildConfiguration = "automatic",
        runtimes = {
          {
            name = "JavaSE-17",
            path = gradle_jdk_home,
            default = true,
          },
        },
      },
      eclipse = {
        downloadSources = true,
      },
      maven = {
        downloadSources = true,
      },
      import = {
        gradle = {
          enabled = true,
          -- Tell Eclipse Buildship (jdtls Gradle integration) which JDK to use.
          -- Without this, it may pick up a stale daemon running Java 8 from
          -- /Library/Internet Plug-Ins/JavaAppletPlugin.plugin.
          java = {
            home = gradle_jdk_home,
          },
        },
      },
      contentProvider = {
        preferred = "fernflower",
      },
      completion = {
        favoriteStaticMembers = {
          "org.hamcrest.MatcherAssert.assertThat",
          "org.junit.jupiter.api.Assertions.*",
          "org.junit.jupiter.api.Assertions.assertEquals",
          "org.junit.jupiter.api.Assertions.assertTrue",
          "org.mockito.Mockito.*",
          "org.mockito.ArgumentMatchers.*",
          "org.mockito.Mockito.mock",
          "org.mockito.Mockito.verify",
          "org.junit.Assert.*",
          "org.junit.Assert.assertEquals",
          "org.junit.Assert.assertTrue",
        },
        importOrder = {
          "java",
          "javax",
          "com",
          "org",
        },
      },
      sources = {
        organizeImports = {
          starThreshold = 9999,
          staticStarThreshold = 9999,
        },
      },
    },
  },
})
