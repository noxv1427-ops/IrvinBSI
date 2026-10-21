/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: { extend: { colors: { teal: { 900: '#0B4F4A', 600: '#00A19B', 800: '#0A625C', 200: '#9ADBD6' }, orange: '#F5A623', canvas: '#F3F9F8', card: '#FFFFFF', ink: '#12302E', muted: '#5F7A78', line: '#D5E6E4', success: '#16A34A', warning: '#F59E0B', danger: '#DC2626', neutral: '#6B7280' }, borderRadius: { card: '12px', input: '8px' }, boxShadow: { soft: '0 8px 30px rgba(11, 79, 74, 0.08)', deep: '0 20px 50px rgba(11, 79, 74, 0.18)' }, keyframes: { shimmer: { '0%': { backgroundPosition: '-200% 0' }, '100%': { backgroundPosition: '200% 0' } }, drift: { '0%, 100%': { transform: 'translate3d(-2%, -1%, 0)' }, '50%': { transform: 'translate3d(2%, 1%, 0)' } } }, animation: { shimmer: 'shimmer 2.4s ease-in-out infinite', drift: 'drift 18s ease-in-out infinite' } } },
  plugins: [],
};
