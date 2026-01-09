/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        // macOS-style dark theme (matching Swift version)
        // Base colors - neutral dark grays
        'base': '#1c1c1e',           // Main background
        'mantle': '#161618',         // Darker background
        'crust': '#0d0d0f',          // Darkest background

        // Surface colors
        'surface-0': '#2c2c2e',      // Card background
        'surface-1': '#3a3a3c',      // Hover state
        'surface-2': '#48484a',      // Active state

        // Overlay colors
        'overlay-0': '#8e8e93',      // Muted text (good contrast)
        'overlay-1': '#a1a1a6',      // Lighter muted
        'overlay-2': '#b4b4b9',      // Lightest muted

        // Text colors
        'text': '#ffffff',           // Primary text
        'subtext-1': '#e5e5e7',      // Secondary text
        'subtext-0': '#c7c7cc',      // Tertiary text

        // Accent colors - matching Swift app
        'pink': '#ff6b9d',
        'mauve': '#a855f7',          // Purple (for donut chart)
        'red': '#ff6b6b',            // Softer red
        'peach': '#ffb347',          // Orange
        'yellow': '#ffd93d',         // Yellow
        'green': '#00d9ff',          // Cyan-green (Swift uses cyan for green accent)
        'teal': '#00d9ff',           // Teal/Cyan
        'sky': '#00d9ff',            // Cyan (primary accent)
        'blue': '#007aff',           // macOS blue
        'lavender': '#a855f7',       // Purple

        // Semantic aliases for the app
        'bg-primary': '#1c1c1e',      // Main background
        'bg-secondary': '#161618',    // Darker
        'bg-tertiary': '#0d0d0f',     // Darkest
        'bg-card': '#2c2c2e',         // Card background
        'bg-card-hover': '#3a3a3c',   // Card hover

        'border-primary': '#3a3a3c',  // Primary border
        'border-secondary': '#2c2c2e', // Secondary border
        'border-focus': '#007aff',    // Focus ring

        'text-primary': '#ffffff',    // Primary text
        'text-secondary': '#e5e5e7',  // Secondary text
        'text-muted': '#8e8e93',      // Muted text

        // Accent colors mapped to semantic names
        'accent-primary': '#00d9ff',  // Cyan
        'accent-green': '#00ff88',    // Bright green for positive
        'accent-cyan': '#00d9ff',     // Cyan
        'accent-purple': '#a855f7',   // Purple
        'accent-orange': '#ffb347',   // Orange
        'accent-yellow': '#ffd93d',   // Yellow
        'accent-red': '#ff6b6b',      // Red for negative
        'accent-blue': '#007aff',     // macOS blue
        'accent-pink': '#ff6b9d',     // Pink
        'accent-teal': '#00d9ff',     // Teal

        // Legacy aliases (for compatibility)
        surface: '#1c1c1e',
        'surface-light': '#161618',
        'surface-lighter': '#2c2c2e',
        accent: '#00d9ff',
      },
      fontFamily: {
        sans: [
          'Inter',
          '-apple-system',
          'BlinkMacSystemFont',
          'Segoe UI',
          'Roboto',
          'Oxygen',
          'Ubuntu',
          'sans-serif',
        ],
        mono: [
          'JetBrains Mono',
          'SF Mono',
          'Consolas',
          'Monaco',
          'Liberation Mono',
          'monospace',
        ],
      },
      // Consistent typography scale
      fontSize: {
        'xs': ['0.75rem', { lineHeight: '1rem' }],      // 12px
        'sm': ['0.8125rem', { lineHeight: '1.25rem' }], // 13px
        'base': ['0.875rem', { lineHeight: '1.5rem' }], // 14px
        'lg': ['1rem', { lineHeight: '1.5rem' }],       // 16px
        'xl': ['1.125rem', { lineHeight: '1.75rem' }],  // 18px
        '2xl': ['1.25rem', { lineHeight: '1.75rem' }],  // 20px
      },
      // Consistent spacing scale
      spacing: {
        '0.5': '0.125rem',  // 2px
        '1': '0.25rem',     // 4px
        '1.5': '0.375rem',  // 6px
        '2': '0.5rem',      // 8px
        '2.5': '0.625rem',  // 10px
        '3': '0.75rem',     // 12px
        '3.5': '0.875rem',  // 14px
        '4': '1rem',        // 16px
        '5': '1.25rem',     // 20px
        '6': '1.5rem',      // 24px
      },
      borderRadius: {
        'sm': '0.25rem',    // 4px
        'DEFAULT': '0.375rem', // 6px
        'md': '0.5rem',     // 8px
        'lg': '0.75rem',    // 12px
      },
      boxShadow: {
        'card': '0 2px 8px rgba(0, 0, 0, 0.4)',
        'card-hover': '0 4px 12px rgba(0, 0, 0, 0.5)',
        'glow-sm': '0 0 10px rgba(0, 217, 255, 0.2)',     // Cyan glow
        'glow-md': '0 0 20px rgba(0, 217, 255, 0.3)',     // Cyan glow
        'glow-green': '0 0 15px rgba(0, 255, 136, 0.25)', // Green glow
        'glow-purple': '0 0 15px rgba(168, 85, 247, 0.25)', // Purple glow
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'fade-in': 'fadeIn 0.2s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(-4px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
};
