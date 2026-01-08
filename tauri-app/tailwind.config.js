/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        // Base colors
        'bg-primary': '#0d1117',
        'bg-secondary': '#161b22',
        'bg-tertiary': '#1c2128',
        'bg-card': '#161b22',
        'bg-card-hover': '#1c2128',
        // Border colors
        'border-primary': '#30363d',
        'border-secondary': '#21262d',
        // Text colors
        'text-primary': '#e6edf3',
        'text-secondary': '#7d8590',
        'text-muted': '#484f58',
        // Accent colors
        'accent-green': '#22c55e',
        'accent-cyan': '#22d3ee',
        'accent-purple': '#a855f7',
        'accent-orange': '#f97316',
        'accent-yellow': '#eab308',
        'accent-red': '#ef4444',
        'accent-blue': '#3b82f6',
        'accent-pink': '#ec4899',
        // Legacy aliases (for compatibility)
        surface: '#0d1117',
        'surface-light': '#161b22',
        'surface-lighter': '#1c2128',
        accent: '#22d3ee',
      },
      fontFamily: {
        mono: ['SF Mono', 'Monaco', 'Menlo', 'monospace'],
      },
    },
  },
  plugins: [],
};
