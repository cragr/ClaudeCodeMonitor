/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        surface: {
          DEFAULT: '#1a1a2e',
          light: '#232340',
          lighter: '#2d2d4a',
        },
        accent: {
          DEFAULT: '#6366f1',
          light: '#818cf8',
        },
      },
    },
  },
  plugins: [],
};

