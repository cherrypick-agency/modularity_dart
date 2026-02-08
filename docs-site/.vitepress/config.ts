import { defineConfig } from 'vitepress'
import { apiSidebar } from './generated/api-sidebar'
import { guideSidebar } from './generated/guide-sidebar'

export default defineConfig({
  title: 'Modularity',
  description: 'Modular architecture framework for Dart & Flutter',
  ignoreDeadLinks: true,
  themeConfig: {
    search: {
      provider: 'local',
    },
    nav: [
      { text: 'Guide', link: '/guide/' },
      { text: 'API Reference', link: '/api/' },
    ],
    sidebar: {
      ...apiSidebar,
      ...guideSidebar,
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/cherrypick-agency/modularity_dart' }],
  },
})
