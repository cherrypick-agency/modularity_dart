import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'
import { apiSidebar } from './generated/api-sidebar'
import { guideSidebar } from './generated/guide-sidebar'
import { dartpadPlugin } from './theme/plugins/dartpad'
import { apiLinkerPlugin } from './theme/plugins/api-linker'

export default withMermaid(defineConfig({
  title: 'Modularity',
  description: 'Modular architecture framework for Dart & Flutter',
  base: '/modularity_dart/',
  ignoreDeadLinks: [
    /\/api\//,
  ],
  markdown: {
    config: (md) => {
      md.use(dartpadPlugin)
      md.use(apiLinkerPlugin)
    },
  },
  mermaid: {
    theme: 'neutral',
  },
  themeConfig: {
    search: {
      provider: 'local',
    },
    nav: [
      { text: 'Guide', link: '/guide/' },
      { text: 'Comparison', link: '/comparison/' },
      { text: 'API Reference', link: '/api/' },
    ],
    sidebar: {
      ...apiSidebar,
      ...guideSidebar,
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/cherrypick-agency/modularity_dart' }],
  },
}))
