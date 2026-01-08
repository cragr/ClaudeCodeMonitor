/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        // Background colors - neutral grays
        'bg-primary': '#1a1d21',
        'bg-secondary': '#22262b',
        'bg-tertiary': '#282c33',
        'bg-card': '#282c33',
        'bg-card-hover': '#2f343c',
        // Border colors
        'border-primary': '#3d424a',
        'border-secondary': '#2f343c',
        'border-focus': '#5b9a8b',
        // Text colors
        'text-primary': '#e8eaed',
        'text-secondary': '#9aa0a9',
        'text-muted': '#6b727c',
        // Accent colors - muted palette
        'accent-primary': '#5b9a8b',
        'accent-green': '#6b9b7a',
        'accent-cyan': '#5b9a8b',
        'accent-purple': '#9b7bb8',
        'accent-orange': '#c4896b',
        'accent-yellow': '#c9a855',
        'accent-red': '#c47272',
        'accent-blue': '#6b8fc4',
        'accent-pink': '#b87b9b',
        // Legacy aliases (for compatibility)
        surface: '#1a1d21',
        'surface-light': '#22262b',
        'surface-lighter': '#282c33',
        accent: '#5b9a8b',
      },
      fontFamily: {
        mono: ['SF Mono', 'Consolas', 'Monaco', 'Menlo', 'monospace'],
      },
    },
  },
  plugins: [],
};
