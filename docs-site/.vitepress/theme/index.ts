import DefaultTheme from 'vitepress/theme'
import { useData, useRoute } from 'vitepress'
import codeblocksFold from 'vitepress-plugin-codeblocks-fold'
import 'vitepress-plugin-codeblocks-fold/style/index.css'
import './custom.css'
import DartPad from './components/DartPad.vue'
import ApiBreadcrumb from './components/ApiBreadcrumb.vue'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('DartPad', DartPad)
    app.component('ApiBreadcrumb', ApiBreadcrumb)
  },
  setup() {
    const { frontmatter } = useData()
    const route = useRoute()
    codeblocksFold({ route, frontmatter }, true, 400)
  }
}
