-- Only attach where a tailwind/postcss config exists (e.g. art-website),
-- not in every CSS file everywhere.
return {
  root_markers = {
    'tailwind.config.js', 'tailwind.config.ts',
    'postcss.config.js', 'postcss.config.mjs',
  },
}
