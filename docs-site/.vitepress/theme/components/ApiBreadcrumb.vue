<script setup lang="ts">
import { useData, useRoute, withBase } from 'vitepress'
import { computed } from 'vue'

const { frontmatter } = useData()
const route = useRoute()

const parts = computed(() => {
  // Extract package from path: /api/modularity_core/Foo -> modularity_core
  const match = route.path.match(/\/api\/([^/]+)\//)
  if (!match) return null

  const pkg = match[1]
  const category = frontmatter.value.category || 'Classes'
  const title = frontmatter.value.title || ''

  return { pkg, category, title }
})
</script>

<template>
  <div v-if="parts" class="api-breadcrumb">
    <a :href="withBase(`/api/${parts.pkg}/`)">{{ parts.pkg }}</a>
    <span class="separator"> › </span>
    <span>{{ parts.category }}</span>
    <span class="separator"> › </span>
    <span>{{ parts.title }}</span>
  </div>
</template>

<style scoped>
.api-breadcrumb {
  font-size: 0.85em;
  margin-bottom: 0.5em;
  color: var(--vp-c-text-3);
}

.api-breadcrumb a {
  text-decoration: none;
  color: var(--vp-c-text-2);
}

.api-breadcrumb a:hover {
  color: var(--vp-c-brand-1);
}

.separator {
  color: var(--vp-c-text-3);
}
</style>
